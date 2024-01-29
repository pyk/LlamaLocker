// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {IERC721, ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/access/Ownable2Step.sol";
import {SafeCast} from "@openzeppelin/utils/math/SafeCast.sol";

import {LlamaLocker} from "@src/LlamaLocker.sol";

contract NFT is ERC721 {
    uint256 private _nextTokenId;

    constructor() ERC721("Test", "TEST") {}

    function mint(address recipient_) external returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        _mint(recipient_, tokenId);
    }
}

/**
 * @title Llama Locker Test
 * @author sepyke.eth
 * @dev Testing for LLAMA's locker contract
 */
contract LlamaLockerTest is Test {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    LlamaLocker private locker;

    address private owner = vm.addr(0x11A);
    address private alice = vm.addr(0xA11CE);
    NFT private nft = new NFT();
    IERC20 private crv = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);

    function setUp() public {
        vm.warp(1706482182); // NOTE: Sun Jan 28 2024 22:49:42 GMT+0000
        locker = new LlamaLocker(owner, address(nft));
    }

    function testRenounceOwnershipRevert() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.RenounceInvalid.selector));
        locker.renounceOwnership();
    }

    //************************************************************//
    //                           Epoch                            //
    //************************************************************//

    function testEpochFirst() public {
        LlamaLocker.Epoch memory epoch = locker.getEpoch(0);
        assertEq(epoch.startAt, 1706140800);
    }

    /// @dev Calling lock() should backfill epochs
    function testEpochBackfillOnLock() public {
        uint256 tokenId1 = nft.mint(alice);
        uint256 tokenId2 = nft.mint(alice);
        LlamaLocker.LockInput[] memory lockInputs = new LlamaLocker.LockInput[](2);
        lockInputs[0] = LlamaLocker.LockInput({tokenId: tokenId1.toUint8(), recipient: alice});
        lockInputs[1] = LlamaLocker.LockInput({tokenId: tokenId2.toUint8(), recipient: alice});

        vm.startPrank(alice);
        nft.setApprovalForAll(address(locker), true);
        vm.warp(1709769610); // enter epoch index 6
        locker.lock(lockInputs);
        vm.stopPrank();

        assertEq(locker.getEpoch(0).startAt, 1706140800);
        assertEq(locker.getEpoch(1).startAt, 1706745600);
        assertEq(locker.getEpoch(2).startAt, 1707350400);
        assertEq(locker.getEpoch(3).startAt, 1707955200);
        assertEq(locker.getEpoch(4).startAt, 1708560000);
        assertEq(locker.getEpoch(5).startAt, 1709164800);
        assertEq(locker.getEpoch(6).startAt, 1709769600);

        // panic: array out-of-bounds access
        vm.expectRevert();
        locker.getEpoch(7);
    }

    /// @dev Calling unlock() should backfill epochs
    function testEpochBackfillOnUnlock() public {
        uint256 tokenId1 = nft.mint(alice);
        uint256 tokenId2 = nft.mint(alice);
        LlamaLocker.LockInput[] memory lockInputs = new LlamaLocker.LockInput[](2);
        lockInputs[0] = LlamaLocker.LockInput({tokenId: tokenId1.toUint8(), recipient: alice});
        lockInputs[1] = LlamaLocker.LockInput({tokenId: tokenId2.toUint8(), recipient: alice});

        uint256[] memory unlockInputs = new uint256[](2);
        unlockInputs[0] = tokenId1;
        unlockInputs[1] = tokenId2;

        vm.startPrank(alice);
        nft.setApprovalForAll(address(locker), true);
        locker.lock(lockInputs);
        vm.warp(1709164900); // enter epoch index 5
        locker.unlock(unlockInputs);
        vm.stopPrank();

        assertEq(locker.getEpoch(0).startAt, 1706140800);
        assertEq(locker.getEpoch(1).startAt, 1706745600);
        assertEq(locker.getEpoch(2).startAt, 1707350400);
        assertEq(locker.getEpoch(3).startAt, 1707955200);
        assertEq(locker.getEpoch(4).startAt, 1708560000);
        assertEq(locker.getEpoch(5).startAt, 1709164800);

        // panic: array out-of-bounds access
        vm.expectRevert();
        locker.getEpoch(6);
    }

    //************************************************************//
    //                      Add Reward Token                      //
    //************************************************************//

    function testAddRewardTokenAsNonOwnerRevert() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        locker.addRewardToken(crv);
    }

    function testAddRewardTokenExistsRevert() public {
        vm.startPrank(owner);
        locker.addRewardToken(crv);

        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.RewardTokenExists.selector));
        locker.addRewardToken(crv);
    }

    function testAddRewardTokenStates() public {
        vm.startPrank(owner);
        locker.addRewardToken(crv);

        LlamaLocker.RewardState memory states = locker.getRewardState(crv);
        assertEq(states.updatedAt, block.timestamp);
        assertEq(states.epochEndAt, block.timestamp);
        assertEq(states.rewardPerSecond, 0);
        assertEq(states.rewardPerNFTStored, 0);

        assertEq(locker.getRewardTokenCount(), 1);
    }

    //************************************************************//
    //                     Distribute Reward                      //
    //************************************************************//

    function testDistributeAsNonOwnerRevert() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        locker.distribute(crv, 1 ether);
    }

    function testDistributeTokenNotExistsRevert() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.RewardTokenNotExists.selector));
        locker.distribute(crv, 1 ether);
    }

    function testDistributeAmountInvalidRevert() public {
        vm.startPrank(owner);
        locker.addRewardToken(crv);

        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.RewardAmountInvalid.selector));
        locker.distribute(crv, 0);
    }

    function testDistributeNoLockersRevert() public {
        vm.startPrank(owner);
        locker.addRewardToken(crv);

        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.NoLockers.selector));
        locker.distribute(crv, 1 ether);
    }

    function testDistributeReward() public {
        uint256 blockTimestamp = 1702302996;
        vm.warp(blockTimestamp);

        // Admin add reward token
        vm.startPrank(owner);
        locker.addRewardToken(crv);
        vm.stopPrank();

        uint256 tokenId1 = nft.mint(alice);
        LlamaLocker.LockInput[] memory lockInputs = new LlamaLocker.LockInput[](2);
        lockInputs[0] = LlamaLocker.LockInput({tokenId: tokenId1.toUint8(), recipient: alice});

        // Alice lock NFT
        vm.warp(blockTimestamp + 100);
        vm.startPrank(alice);
        nft.setApprovalForAll(address(locker), true);
        locker.lock(lockInputs);
        vm.stopPrank();

        // Admin distribute 10_000 CRV as reward
        vm.warp(blockTimestamp + 100 + 500);
        vm.startPrank(owner);
        deal(address(crv), owner, 10_000 ether);
        crv.safeIncreaseAllowance(address(locker), 10_000 ether);
        locker.distribute(crv, 10_000 ether);
        vm.stopPrank();

        // Check reward states
        LlamaLocker.RewardState memory rewardState = locker.getRewardState(crv);
        assertEq(rewardState.updatedAt, 1702303596);
        assertEq(rewardState.epochEndAt, 1702908396); // block.timestamp + REWARD_DURATION
        assertEq(rewardState.rewardPerSecond, 16534391534391534); // 0.016 CRV per second
        assertEq(rewardState.rewardPerNFTStored, 0);

        // Admin distribute 20_000 as reward again
        vm.warp(blockTimestamp + 100 + 500 + 500);
        vm.startPrank(owner);
        deal(address(crv), owner, 20_000 ether);
        crv.safeIncreaseAllowance(address(locker), 20_000 ether);
        locker.distribute(crv, 20_000 ether);
        vm.stopPrank();

        // Check reward states
        rewardState = locker.getRewardState(crv);
        assertEq(rewardState.updatedAt, 1702304096);
        assertEq(rewardState.epochEndAt, 1702908896); // block.timestamp + REWARD_DURATION
        assertEq(rewardState.rewardPerSecond, 49589505298003974); // 0.04 CRV per second
        assertEq(rewardState.rewardPerNFTStored, 8267195767195767000); // 8.267 CRV per locked NFT

        // Check distributed CRV
        assertEq(crv.balanceOf(address(locker)), 30_000 ether);
    }

    //************************************************************//
    //                          Lock NFT                          //
    //************************************************************//

    function testLockEmpty() public {
        LlamaLocker.LockInput[] memory lockInputs = new LlamaLocker.LockInput[](0);

        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.Empty.selector));
        locker.lock(lockInputs);
    }

    function testLockNFT() public {
        uint256 tokenId1 = nft.mint(alice);
        uint256 tokenId2 = nft.mint(alice);
        LlamaLocker.LockInput[] memory lockInputs = new LlamaLocker.LockInput[](2);
        lockInputs[0] = LlamaLocker.LockInput({tokenId: tokenId1.toUint8(), recipient: alice});
        lockInputs[1] = LlamaLocker.LockInput({tokenId: tokenId2.toUint8(), recipient: alice});

        vm.startPrank(alice);
        nft.setApprovalForAll(address(locker), true);
        locker.lock(lockInputs);
        vm.stopPrank();

        // NFT should be transfered to locker
        assertEq(nft.ownerOf(tokenId1), address(locker));
        assertEq(nft.ownerOf(tokenId2), address(locker));

        // total locked NFT should be increased
        assertEq(locker.totalLockedNFT(), 2);
    }

    //************************************************************//
    //                         Unlock NFT                         //
    //************************************************************//

    function testUnlockEmpty() public {
        uint256[] memory inputs = new uint256[](0);

        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.Empty.selector));
        locker.unlock(inputs);
    }

    function testUnlockNFTInvalidOwner() public {
        uint256 tokenId1 = nft.mint(alice);
        uint256 tokenId2 = nft.mint(alice);
        LlamaLocker.LockInput[] memory lockInputs = new LlamaLocker.LockInput[](2);
        lockInputs[0] = LlamaLocker.LockInput({tokenId: tokenId1.toUint8(), recipient: alice});
        lockInputs[1] = LlamaLocker.LockInput({tokenId: tokenId2.toUint8(), recipient: alice});

        vm.startPrank(alice);
        nft.setApprovalForAll(address(locker), true);
        locker.lock(lockInputs);
        vm.stopPrank();

        // enter epoch index 5; so nft is unlockable
        vm.warp(1709164900);
        uint256[] memory unlockInputs = new uint256[](2);
        unlockInputs[0] = tokenId1;
        unlockInputs[1] = tokenId2;

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.NotOwner.selector));
        locker.unlock(unlockInputs);
    }

    function testUnlockNFTValid() public {
        uint256 tokenId1 = nft.mint(alice);
        uint256 tokenId2 = nft.mint(alice);
        LlamaLocker.LockInput[] memory lockInputs = new LlamaLocker.LockInput[](2);
        lockInputs[0] = LlamaLocker.LockInput({tokenId: tokenId1.toUint8(), recipient: alice});
        lockInputs[1] = LlamaLocker.LockInput({tokenId: tokenId2.toUint8(), recipient: alice});
        uint256[] memory unlockInputs = new uint256[](2);
        unlockInputs[0] = tokenId1;
        unlockInputs[1] = tokenId2;

        vm.startPrank(alice);
        nft.setApprovalForAll(address(locker), true);
        locker.lock(lockInputs);
        // enter epoch index 5; so nft is unlockable
        vm.warp(1709164900);
        locker.unlock(unlockInputs);
        vm.stopPrank();

        // Unlocked NFT should be transferred
        assertEq(nft.ownerOf(tokenId1), alice);
        assertEq(nft.ownerOf(tokenId2), alice);
        assertEq(locker.totalLockedNFT(), 0);
    }
}
