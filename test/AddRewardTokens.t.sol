// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test} from "forge-std/Test.sol";

import {LlamaLocker} from "../src/LlamaLocker.sol";
import {MockNFT} from "./MockNFT.sol";
import {MockToken} from "./MockToken.sol";

contract AddRewardTokensTest is Test {
    MockNFT public nft;
    MockToken public token0;
    MockToken public token1;
    LlamaLocker public locker;

    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        token0 = new MockToken();
        token1 = new MockToken();
        nft = new MockNFT();
        locker = new LlamaLocker(admin, address(nft));
    }

    function test_addRewardTokens_Valid() public {
        vm.warp(1714608000);
        LlamaLocker llama = new LlamaLocker(admin, makeAddr("nft"));

        vm.startPrank(admin);

        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = address(token0);
        rewardTokens[1] = address(token1);

        vm.warp(1717026037);
        llama.addRewardTokens(rewardTokens);

        // addRewardTokens() should backfill epochs
        assertEq(llama.epochs(0), 1714608000, "invalid epoch 0");
        assertEq(llama.epochs(1), 1715212800, "invalid epoch 1");
        assertEq(llama.epochs(2), 1715817600, "invalid epoch 2");
        assertEq(llama.epochs(3), 1716422400, "invalid epoch 3");

        vm.expectRevert();
        llama.epochs(4);

        // addRewardTokens() should increase token count
        assertEq(llama.getRewardTokenCount(), 2, "invalid reward token count");

        // addRewardTokens() should set initial values
        (uint208 amountPerSecond, uint48 epochEndAt, uint208 amountPerNFTStored, uint48 updatedAt) =
            llama.rewardTokenInfos(address(token0));
        assertEq(amountPerSecond, 0, "invalid token0 amountPerSecond");
        assertEq(epochEndAt, block.timestamp, "invalid token0 epochEndAt");
        assertEq(amountPerNFTStored, 0, "invalid token0 amountPerNFTStored");
        assertEq(updatedAt, block.timestamp, "invalid token0 updatedAt");

        (amountPerSecond, epochEndAt, amountPerNFTStored, updatedAt) = llama.rewardTokenInfos(address(token1));
        assertEq(amountPerSecond, 0, "invalid token1 amountPerSecond");
        assertEq(epochEndAt, block.timestamp, "invalid token1 epochEndAt");
        assertEq(amountPerNFTStored, 0, "invalid token1 amountPerNFTStored");
        assertEq(updatedAt, block.timestamp, "invalid token1 updatedAt");
    }

    function test_addRewardTokens_Unauthorized() public {
        address[] memory rewardTokens = new address[](0);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        locker.addRewardTokens(rewardTokens);
    }

    function test_addRewardTokens_InvalidRewardTokenCount() public {
        address[] memory rewardTokens = new address[](0);
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidRewardTokenCount.selector));
        locker.addRewardTokens(rewardTokens);
    }

    function test_addRewardTokens_InvalidRewardToken() public {
        vm.startPrank(admin);

        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(0);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidRewardToken.selector));
        locker.addRewardTokens(rewardTokens);

        rewardTokens = new address[](1);
        rewardTokens[0] = address(token0);
        locker.addRewardTokens(rewardTokens);

        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidRewardToken.selector));
        locker.addRewardTokens(rewardTokens);
    }
}
