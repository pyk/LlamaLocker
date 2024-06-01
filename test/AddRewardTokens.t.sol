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
        vm.startPrank(admin);

        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = address(token0);
        rewardTokens[1] = address(token1);

        locker.addRewardTokens(rewardTokens);

        assertEq(locker.getRewardTokenCount(), 2, "invalid reward token count");
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
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidTokenCount.selector));
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
