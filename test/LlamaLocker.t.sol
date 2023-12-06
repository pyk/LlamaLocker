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

  function test_AddRewardAsOwner() public {
    vm.startPrank(owner);
    locker.addRewardToken(crv);

    assertEq(locker.rewardTokensCount(), 1);
    LlamaLocker.RewardTokenData memory data = locker.getRewardTokenData(crv);
    assertEq(data.lastUpdateTime, block.timestamp);
    assertEq(data.periodFinish, block.timestamp);
  }

  function testFail_LockZeroToken() public {
    uint256[] memory tokenIds = new uint256[](0);
    locker.lock(tokenIds);
  }

  function test_LockNFTTransferred() public {
    uint256 tokenId1 = nft.mint(alice);
    uint256 tokenId2 = nft.mint(alice);

    vm.startPrank(alice);
    nft.setApprovalForAll(address(locker), true);
    uint256[] memory tokenIds = new uint256[](2);
    tokenIds[0] = tokenId1;
    tokenIds[1] = tokenId2;
    locker.lock(tokenIds);
    vm.stopPrank();

    assertEq(nft.ownerOf(tokenId1), address(locker));
    assertEq(nft.ownerOf(tokenId2), address(locker));
  }
}