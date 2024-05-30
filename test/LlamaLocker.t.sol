// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721, IERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Test, console2} from "forge-std/Test.sol";

import {LlamaLocker} from "../src/LlamaLocker.sol";

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
    //                           Yield                            //
    //************************************************************//

    /// @dev addTokens should revert if non-owner call the function
    function testAddTokensAsNonOwnerRevert() public {
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = crv;

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        locker.addTokens(tokens);
    }

    /// @dev addTokens should revert if token already exists
    function testAddTokensExistsRevert() public {
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = crv;

        vm.startPrank(owner);
        locker.addTokens(tokens);

        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.TokenExists.selector));
        locker.addTokens(tokens);
    }

    function testAddTokens() public {
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = crv;

        vm.startPrank(owner);
        locker.addTokens(tokens);

        LlamaLocker.YieldInfo memory states = locker.getYieldInfo(crv);
        assertEq(states.updatedAt, block.timestamp);
        assertEq(states.epochEndAt, block.timestamp);
        assertEq(states.amountPerSecond, 0);
        assertEq(states.amountPerNFTStored, 0);

        assertEq(locker.getTokenCount(), 1);
    }

    //************************************************************//
    //                     Distribute Reward                      //
    //************************************************************//

    // function testDistributeAsNonOwnerRevert() public {
    //     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
    //     locker.distribute(crv, 1 ether);
    // }

    // function testDistributeTokenNotExistsRevert() public {
    //     vm.startPrank(owner);
    //     vm.expectRevert(abi.encodeWithSelector(LlamaLocker.RewardTokenNotExists.selector));
    //     locker.distribute(crv, 1 ether);
    // }

    // function testDistributeAmountInvalidRevert() public {
    //     vm.startPrank(owner);
    //     locker.addRewardToken(crv);

    //     vm.expectRevert(abi.encodeWithSelector(LlamaLocker.RewardAmountInvalid.selector));
    //     locker.distribute(crv, 0);
    // }

    // function testDistributeNoLockersRevert() public {
    //     vm.startPrank(owner);
    //     locker.addRewardToken(crv);

    //     vm.expectRevert(abi.encodeWithSelector(LlamaLocker.NoLockers.selector));
    //     locker.distribute(crv, 1 ether);
    // }

    // function testDistributeReward() public {
    //     uint256 blockTimestamp = 1702302996;
    //     vm.warp(blockTimestamp);

    //     // Admin add reward token
    //     vm.startPrank(owner);
    //     locker.addRewardToken(crv);
    //     vm.stopPrank();

    //     uint256 tokenId1 = nft.mint(alice);
    //     LlamaLocker.LockInput[] memory lockInputs = new LlamaLocker.LockInput[](2);
    //     lockInputs[0] = LlamaLocker.LockInput({tokenId: tokenId1, recipient: alice});

    //     // Alice lock NFT
    //     vm.warp(blockTimestamp + 100);
    //     vm.startPrank(alice);
    //     nft.setApprovalForAll(address(locker), true);
    //     locker.lock(lockInputs);
    //     vm.stopPrank();

    //     // Admin distribute 10_000 CRV as reward
    //     vm.warp(blockTimestamp + 100 + 500);
    //     vm.startPrank(owner);
    //     deal(address(crv), owner, 10_000 ether);
    //     crv.safeIncreaseAllowance(address(locker), 10_000 ether);
    //     locker.distribute(crv, 10_000 ether);
    //     vm.stopPrank();

    //     // Check reward states
    //     LlamaLocker.RewardState memory rewardState = locker.getRewardState(crv);
    //     assertEq(rewardState.updatedAt, 1702303596);
    //     assertEq(rewardState.epochEndAt, 1702908396); // block.timestamp + REWARD_DURATION
    //     assertEq(rewardState.rewardPerSecond, 16534391534391534); // 0.016 CRV per second
    //     assertEq(rewardState.rewardPerNFTStored, 0);

    //     // Admin distribute 20_000 as reward again
    //     vm.warp(blockTimestamp + 100 + 500 + 500);
    //     vm.startPrank(owner);
    //     deal(address(crv), owner, 20_000 ether);
    //     crv.safeIncreaseAllowance(address(locker), 20_000 ether);
    //     locker.distribute(crv, 20_000 ether);
    //     vm.stopPrank();

    //     // Check reward states
    //     rewardState = locker.getRewardState(crv);
    //     assertEq(rewardState.updatedAt, 1702304096);
    //     assertEq(rewardState.epochEndAt, 1702908896); // block.timestamp + REWARD_DURATION
    //     assertEq(rewardState.rewardPerSecond, 49589505298003974); // 0.04 CRV per second
    //     assertEq(rewardState.rewardPerNFTStored, 8267195767195767000); // 8.267 CRV per locked NFT

    //     // Check distributed CRV
    //     assertEq(crv.balanceOf(address(locker)), 30_000 ether);
    // }

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
        lockInputs[0] = LlamaLocker.LockInput({nftId: tokenId1, recipient: alice});
        lockInputs[1] = LlamaLocker.LockInput({nftId: tokenId2, recipient: alice});

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
        lockInputs[0] = LlamaLocker.LockInput({nftId: tokenId1, recipient: alice});
        lockInputs[1] = LlamaLocker.LockInput({nftId: tokenId2, recipient: alice});

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
        lockInputs[0] = LlamaLocker.LockInput({nftId: tokenId1, recipient: alice});
        lockInputs[1] = LlamaLocker.LockInput({nftId: tokenId2, recipient: alice});
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
