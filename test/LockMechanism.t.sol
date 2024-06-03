// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {LlamaLocker} from "../src/LlamaLocker.sol";
import {MockNFT} from "./MockNFT.sol";

contract LockMechanismTest is Test {
    MockNFT public nft;
    LlamaLocker public locker;

    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        nft = new MockNFT();
        locker =
            new LlamaLocker(admin, address(nft), 0x308b32884ae9d1e08a3e1d00ac6934fa79bf7ae30358cff55dda90c8aebedf9c);

        vm.startPrank(admin);
        locker.disableWhitelist();
        vm.stopPrank();
    }

    function test_lock_Valid() public {
        uint256 tokenId = nft.mint(alice);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(alice);
        nft.setApprovalForAll(address(locker), true);
        vm.stopPrank();

        vm.startPrank(bob);
        nft.setApprovalForAll(address(locker), true);
        vm.stopPrank();

        // epoch 0
        vm.warp(1714608000);

        vm.startPrank(alice);
        locker.lock(tokenIds);
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), address(locker));

        // epoch 1
        vm.warp(1715212800);
        tokenId = nft.mint(bob);
        tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(bob);
        locker.lock(tokenIds);
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), address(locker));

        // epoch 2
        vm.warp(1715817600);
        tokenId = nft.mint(alice);
        tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(alice);
        locker.lock(tokenIds);
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), address(locker));

        // epoch 3
        vm.warp(1716422400);
        assertEq(nft.ownerOf(tokenId), address(locker));
    }

    function test_lock_InvalidTokenCount() public {
        uint256[] memory tokenIds = new uint256[](0);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidTokenCount.selector));
        locker.lock(tokenIds);
    }

    function test_unlock_ValidUnlockWindow() public {
        uint256 lockTimestamp = 1717026037;

        uint256 tokenId = nft.mint(alice);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(alice);
        nft.setApprovalForAll(address(locker), true);
        vm.stopPrank();

        vm.warp(lockTimestamp);
        vm.startPrank(alice);
        locker.lock(tokenIds);
        vm.stopPrank();

        // Unlock window is available at week 5
        vm.warp(lockTimestamp + 30 days);

        vm.startPrank(alice);
        locker.unlock(tokenIds);
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), alice, "nft owner invalid");
    }

    function test_unlock_InvalidTokenCount() public {
        uint256[] memory tokenIds = new uint256[](0);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidTokenCount.selector));
        locker.unlock(tokenIds);
    }

    function test_unlock_InvalidLockOwner() public {
        uint256 tokenId = nft.mint(alice);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(alice);
        nft.setApprovalForAll(address(locker), true);
        locker.lock(tokenIds);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidLockOwner.selector));
        locker.unlock(tokenIds);
        vm.stopPrank();
    }

    function test_unlock_InvalidUnlockWindow() public {
        uint256 tokenId = nft.mint(alice);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(alice);
        nft.setApprovalForAll(address(locker), true);
        vm.stopPrank();

        uint256 lockTimestamp = 1714608000;

        vm.warp(lockTimestamp);
        vm.startPrank(alice);
        locker.lock(tokenIds);
        vm.stopPrank();

        // Before unlock window
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidUnlockWindow.selector));
        locker.unlock(tokenIds);
        vm.stopPrank();

        // Before unlock window week 1
        vm.warp(lockTimestamp + 6 days);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidUnlockWindow.selector));
        locker.unlock(tokenIds);
        vm.stopPrank();

        // Before unlock window week 2
        vm.warp(lockTimestamp + 12 days);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidUnlockWindow.selector));
        locker.unlock(tokenIds);
        vm.stopPrank();

        // Before unlock window week 3
        vm.warp(lockTimestamp + 18 days);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidUnlockWindow.selector));
        locker.unlock(tokenIds);
        vm.stopPrank();

        // Before unlock window week 4
        vm.warp(lockTimestamp + 24 days);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidUnlockWindow.selector));
        locker.unlock(tokenIds);
        vm.stopPrank();

        // week 5 can be unlocked (~30 days)

        // After unlock window week 6
        vm.warp(lockTimestamp + 36 days);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidUnlockWindow.selector));
        locker.unlock(tokenIds);
        vm.stopPrank();
    }
}
