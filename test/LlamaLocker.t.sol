// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {IERC721, ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {LlamaLocker} from "contracts/LlamaLocker.sol";

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
  LlamaLocker locker;

  address owner = vm.addr(0x11A);
  address alice = vm.addr(0xA11CE);
  NFT nft = new NFT();
  IERC20 crv = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);

  function setUp() public {
    locker = new LlamaLocker(owner, address(nft));
  }

  function testRenounceOwnershipRevert() public {
    vm.startPrank(owner);
    vm.expectRevert(abi.encodeWithSelector(LlamaLocker.RenounceInvalid.selector));
    locker.renounceOwnership();
  }

  // ☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆
  //                         Add Reward Token
  // ☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆☆

  function testFail_AddRewardTokenAsNonOwner() public {
    locker.addRewardToken(crv);
  }

  function testFail_AddRewardTokenExists() public {
    vm.startPrank(owner);
    locker.addRewardToken(crv);
    locker.addRewardToken(crv);
  }

  function testFail_AddRewardTokenInvalidZero() public {
    vm.startPrank(owner);
    locker.addRewardToken(IERC20(address(0)));
  }

  function test_AddRewardTokenStates() public {
    vm.startPrank(owner);
    locker.addRewardToken(crv);

    LlamaLocker.RewardState memory states = locker.getRewardState(crv);
    assertEq(states.updatedAt, block.timestamp);
    assertEq(states.endAt, block.timestamp);
    assertEq(states.rewardPerSecond, 0);
    assertEq(states.rewardPerTokenStored, 0);

    assertEq(locker.getRewardTokenCount(), 1);
  }

  // function test_AddRewardAsOwner() public {
  //   vm.startPrank(owner);
  //   locker.addRewardToken(crv);

  //   assertEq(locker.rewardTokensCount(), 1);
  //   LlamaLocker.RewardTokenData memory data = locker.getRewardTokenData(crv);
  //   assertEq(data.lastUpdatedAt, block.timestamp);
  //   assertEq(data.periodFinish, block.timestamp);
  // }

  // function testFail_AddRewardAsNonOwner() public {
  //   locker.addReward(crv, 1 ether);
  // }

  // function testFail_AddRewardWithInvalidAmount() public {
  //   vm.startPrank(owner);
  //   locker.addRewardToken(crv);
  //   locker.addReward(crv, 0 ether);
  // }

  // function testFail_AddRewardWithInvalidToken() public {
  //   vm.startPrank(owner);
  //   locker.addReward(crv, 1 ether);
  // }

  // function test_AddRewardOncePerEpoch() public {
  //   vm.startPrank(owner);
  //   locker.addRewardToken(crv);
  //   locker.addReward(crv, 1 ether);

  //   LlamaLocker.RewardTokenData memory data = locker.getRewardTokenData(crv);
  //   assertEq(data.periodFinish, block.timestamp + locker.REWARD_DURATION());
  //   assertEq(data.rewardPerSecond, 1 ether / locker.REWARD_DURATION());
  //   assertEq(data.lastUpdatedAt, block.timestamp);
  // }

  function testFail_LockZeroToken() public {
    uint256[] memory tokenIds = new uint256[](0);
    locker.lock(tokenIds);
  }

  function test_LockNFTTransferred() public {
    uint256 tokenId1 = nft.mint(alice);
    uint256 tokenId2 = nft.mint(alice);
    uint256[] memory tokenIds = new uint256[](2);
    tokenIds[0] = tokenId1;
    tokenIds[1] = tokenId2;

    vm.startPrank(alice);
    nft.setApprovalForAll(address(locker), true);
    locker.lock(tokenIds);
    vm.stopPrank();

    assertEq(nft.ownerOf(tokenId1), address(locker));
    assertEq(nft.ownerOf(tokenId2), address(locker));
  }

  function testFail_UnlockInvalidOwner() public {
    uint256 tokenId1 = nft.mint(alice);
    uint256 tokenId2 = nft.mint(alice);
    uint256[] memory tokenIds = new uint256[](2);
    tokenIds[0] = tokenId1;
    tokenIds[1] = tokenId2;

    vm.startPrank(alice);
    nft.setApprovalForAll(address(locker), true);
    locker.lock(tokenIds);
    vm.stopPrank();

    vm.startPrank(owner);
    locker.unlock(tokenIds);
  }

  function test_UnlockNFTTransfered() public {
    uint256 tokenId1 = nft.mint(alice);
    uint256 tokenId2 = nft.mint(alice);
    uint256[] memory tokenIds = new uint256[](2);
    tokenIds[0] = tokenId1;
    tokenIds[1] = tokenId2;

    vm.startPrank(alice);
    nft.setApprovalForAll(address(locker), true);
    locker.lock(tokenIds);
    locker.unlock(tokenIds);
    vm.stopPrank();

    assertEq(nft.ownerOf(tokenId1), alice);
    assertEq(nft.ownerOf(tokenId2), alice);
  }
}
