// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test} from "forge-std/Test.sol";

import {LlamaLocker} from "../src/LlamaLocker.sol";
import {MockNFT} from "./MockNFT.sol";
import {MockToken} from "./MockToken.sol";

contract RewardDistributionTest is Test {
    MockNFT public nft;
    MockToken public token0;
    MockToken public token1;
    LlamaLocker public locker;

    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        token0 = new MockToken();
        token1 = new MockToken();
        nft = new MockNFT();
        locker = new LlamaLocker(admin, address(nft));
    }

    function test_distributeRewardToken_Valid() public {
        uint256 tokenId = nft.mint(alice);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(alice);
        nft.setApprovalForAll(address(locker), true);
        vm.stopPrank();

        vm.startPrank(bob);
        nft.setApprovalForAll(address(locker), true);
        vm.stopPrank();

        vm.startPrank(charlie);
        nft.setApprovalForAll(address(locker), true);
        vm.stopPrank();

        // epoch 0
        vm.warp(1714608000);

        vm.startPrank(alice);
        locker.lock(tokenIds);
        vm.stopPrank();

        vm.startPrank(admin);
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(token0);
        locker.addRewardTokens(rewardTokens);
        vm.stopPrank();

        assertEq(locker.claimable(alice, address(token0)), 0, "alice claimable invalid epoch 0");
        assertEq(locker.claimable(bob, address(token0)), 0, "bob claimable invalid epoch 0");
        assertEq(locker.claimable(charlie, address(token0)), 0, "charlie claimable invalid epoch 0");

        // epoch 1
        vm.warp(1715212800);

        tokenId = nft.mint(bob);
        tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(bob);
        locker.lock(tokenIds);
        vm.stopPrank();

        uint256 rewardAmount = 10 ether;
        token0.mint(admin, rewardAmount);

        vm.startPrank(admin);
        token0.approve(address(locker), rewardAmount);
        locker.distributeRewardToken(address(token0), rewardAmount);
        vm.stopPrank();

        assertEq(locker.claimable(alice, address(token0)), 10 ether, "alice claimable invalid epoch 1");
        assertEq(locker.claimable(bob, address(token0)), 0, "bob claimable invalid epoch 1");
        assertEq(locker.claimable(charlie, address(token0)), 0, "charlie claimable invalid epoch 1");

        // epoch 2
        vm.warp(1715817600);

        assertEq(locker.claimable(alice, address(token0)), 10 ether, "alice claimable invalid epoch 2.1");
        assertEq(locker.claimable(bob, address(token0)), 0, "bob claimable invalid epoch 2.1");
        assertEq(locker.claimable(charlie, address(token0)), 0, "charlie claimable invalid epoch 2.1");
    }

    function test_distributeRewardToken_Unauthorized() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        locker.distributeRewardToken(address(0), 1 ether);
    }

    function test_distributeRewardToken_InvalidRewardToken() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidRewardToken.selector));
        locker.distributeRewardToken(makeAddr("random-token"), 1 ether);
    }

    function test_distributeRewardToken_InvalidRewardAmount() public {
        vm.startPrank(admin);
        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = address(token0);
        rewardTokens[1] = address(token1);
        locker.addRewardTokens(rewardTokens);

        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidRewardAmount.selector));
        locker.distributeRewardToken(address(token0), 0);
    }

    function test_distributeRewardToken_InvalidTotalShares() public {
        vm.startPrank(admin);
        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = address(token0);
        rewardTokens[1] = address(token1);
        locker.addRewardTokens(rewardTokens);

        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidTotalShares.selector));
        locker.distributeRewardToken(address(token0), 10 ether);
    }
}
