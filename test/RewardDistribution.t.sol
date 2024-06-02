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

    function _lockNFTAs(address account_) private {
        uint256 tokenId = nft.mint(account_);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(account_);
        nft.setApprovalForAll(address(locker), true);
        locker.lock(tokenIds);
        vm.stopPrank();
    }

    function _addRewardToken(address token_) private {
        vm.startPrank(admin);
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = token_;
        locker.addRewardTokens(rewardTokens);
    }

    function _distributeRewardToken(MockToken token_, uint256 amount_) private {
        token_.mint(admin, amount_);
        vm.startPrank(admin);
        token_.approve(address(locker), amount_);
        locker.distributeRewardToken(address(token_), amount_);
        vm.stopPrank();
    }

    function _claimRewardAs(address account_) private {
        vm.startPrank(account_);
        locker.claim(account_);
        vm.stopPrank();
    }

    function test_distributeRewardToken_Claimables() public {
        _addRewardToken(address(token0));
        _addRewardToken(address(token1));

        _lockNFTAs(alice);
        _lockNFTAs(bob);

        // Epoch 1
        _distributeRewardToken(token0, 10 ether);
        _distributeRewardToken(token1, 10 ether);

        assertEq(locker.claimable(alice, address(token0)), 5 ether, "alice claimable invalid epoch 1");
        assertEq(locker.claimable(bob, address(token0)), 5 ether, "bob claimable invalid epoch 1");
        assertEq(locker.claimable(alice, address(token1)), 5 ether, "alice claimable invalid epoch 1");
        assertEq(locker.claimable(bob, address(token1)), 5 ether, "bob claimable invalid epoch 1");

        // Epoch 2
        _lockNFTAs(alice);
        _distributeRewardToken(token0, 3 ether);

        assertEq(locker.claimable(alice, address(token0)), 7 ether, "alice claimable invalid epoch 2");
        assertEq(locker.claimable(bob, address(token0)), 6 ether, "bob claimable invalid epoch 2");
        assertEq(locker.claimable(alice, address(token1)), 5 ether, "alice claimable invalid epoch 1");
        assertEq(locker.claimable(bob, address(token1)), 5 ether, "bob claimable invalid epoch 1");

        // Claim
        _claimRewardAs(bob);

        assertEq(token0.balanceOf(bob), 6 ether, "invalid bob balance token0");
        assertEq(token1.balanceOf(bob), 5 ether, "invalid bob balance token1");

        assertEq(locker.claimable(alice, address(token0)), 7 ether, "alice claimable invalid epoch 2");
        assertEq(locker.claimable(bob, address(token0)), 0, "bob claimable invalid epoch 2");
        assertEq(locker.claimable(alice, address(token1)), 5 ether, "alice claimable invalid epoch 1");
        assertEq(locker.claimable(bob, address(token1)), 0, "bob claimable invalid epoch 1");
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
