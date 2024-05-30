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
        locker = new LlamaLocker(admin, address(nft));
    }

    function test_epochs_InitialEpoch() public {
        vm.warp(1717026037);
        LlamaLocker llama = new LlamaLocker(admin, address(nft));
        uint48 start = llama.epochs(0);
        assertEq(start, 1716422400, "invalid epoch start");

        vm.expectRevert();
        llama.epochs(1);
    }

    function test_lock_ok() public {
        vm.warp(1714608000);
        LlamaLocker llama = new LlamaLocker(admin, address(nft));

        uint256 tokenId = nft.mint(alice);
        LlamaLocker.LockInput[] memory lockInputs = new LlamaLocker.LockInput[](1);
        lockInputs[0] = LlamaLocker.LockInput({nftId: tokenId, recipient: alice});

        // lock() should backfill epochs
        vm.warp(1717026037);
        vm.startPrank(alice);
        nft.setApprovalForAll(address(llama), true);
        llama.lock(lockInputs);
        vm.stopPrank();

        assertEq(llama.epochs(0), 1714608000, "invalid epoch 0");
        assertEq(llama.epochs(1), 1715212800, "invalid epoch 1");
        assertEq(llama.epochs(2), 1715817600, "invalid epoch 2");
        assertEq(llama.epochs(3), 1716422400, "invalid epoch 3");

        vm.expectRevert();
        llama.epochs(4);

        // lock() should increase totalLockedNFT
        assertEq(llama.totalLockedNFT(), 1, "invalid total locked NFT");

        // lock() should valid
        (address owner, uint256 lockedAtEpochIndex, address recipient) = llama.locks(tokenId);
        assertEq(owner, alice, "invalid lock owner");
        assertEq(lockedAtEpochIndex, 3, "invalid lock epoch index");
        assertEq(recipient, alice, "invalid yield recipient");
    }

    function test_lock_InvalidLockCount() public {
        LlamaLocker.LockInput[] memory lockInputs = new LlamaLocker.LockInput[](0);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidLockCount.selector));
        locker.lock(lockInputs);
    }

    function test_lock_InvalidYieldRecipient() public {
        uint256 tokenId = nft.mint(alice);
        LlamaLocker.LockInput[] memory lockInputs = new LlamaLocker.LockInput[](1);
        lockInputs[0] = LlamaLocker.LockInput({nftId: tokenId, recipient: address(0)});

        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidYieldRecipient.selector));
        locker.lock(lockInputs);
    }

    function test_unlock_ok() public {
        uint256 deployTimestamp = 1714608000;
        uint256 lockTimestamp = 1717026037;

        vm.warp(deployTimestamp);
        LlamaLocker llama = new LlamaLocker(admin, address(nft));

        uint256 tokenId = nft.mint(alice);
        LlamaLocker.LockInput[] memory lockInputs = new LlamaLocker.LockInput[](1);
        lockInputs[0] = LlamaLocker.LockInput({nftId: tokenId, recipient: alice});

        vm.warp(lockTimestamp);
        vm.startPrank(alice);
        nft.setApprovalForAll(address(llama), true);
        llama.lock(lockInputs);
        vm.stopPrank();

        uint256[] memory unlockInputs = new uint256[](1);
        unlockInputs[0] = tokenId;

        // Unlock window at week 5
        vm.warp(lockTimestamp + 30 days);
        vm.startPrank(alice);
        llama.unlock(unlockInputs);
        vm.stopPrank();

        // Should decrease total locked nft
        assertEq(llama.totalLockedNFT(), 0, "invalid total locked nft");

        // Should backfill the epochs
        assertEq(llama.epochs(0), 1714608000, "invalid epoch 0");
        assertEq(llama.epochs(1), 1715212800, "invalid epoch 1");
        assertEq(llama.epochs(2), 1715817600, "invalid epoch 2");
        assertEq(llama.epochs(3), 1716422400, "invalid epoch 3");
        assertEq(llama.epochs(4), 1717027200, "invalid epoch 4");
        assertEq(llama.epochs(5), 1717632000, "invalid epoch 5");
        assertEq(llama.epochs(6), 1718236800, "invalid epoch 6");
        assertEq(llama.epochs(7), 1718841600, "invalid epoch 7");
        assertEq(llama.epochs(8), 1719446400, "invalid epoch 8");

        vm.expectRevert();
        llama.epochs(9);

        // NFT should be transfered
        assertEq(nft.ownerOf(tokenId), alice, "invalid nft owner");
    }

    function test_unlock_InvalidUnlockCount() public {
        uint256[] memory unlockInputs = new uint256[](0);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidUnlockCount.selector));
        locker.unlock(unlockInputs);
    }

    function test_unlock_InvalidLockOwner() public {
        uint256 tokenId = nft.mint(alice);
        LlamaLocker.LockInput[] memory lockInputs = new LlamaLocker.LockInput[](1);
        lockInputs[0] = LlamaLocker.LockInput({nftId: tokenId, recipient: alice});

        vm.startPrank(alice);
        nft.setApprovalForAll(address(locker), true);
        locker.lock(lockInputs);
        vm.stopPrank();

        uint256[] memory unlockInputs = new uint256[](1);
        unlockInputs[0] = tokenId;

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidLockOwner.selector));
        locker.unlock(unlockInputs);
        vm.stopPrank();
    }

    function test_unlock_InvalidUnlockWindow() public {
        vm.warp(1714608000);
        LlamaLocker llama = new LlamaLocker(admin, address(nft));

        uint256 tokenId = nft.mint(alice);
        LlamaLocker.LockInput[] memory lockInputs = new LlamaLocker.LockInput[](1);
        lockInputs[0] = LlamaLocker.LockInput({nftId: tokenId, recipient: alice});

        uint256 lockTimestamp = 1717026037;
        vm.warp(lockTimestamp);
        vm.startPrank(alice);
        nft.setApprovalForAll(address(llama), true);
        llama.lock(lockInputs);
        vm.stopPrank();

        uint256[] memory unlockInputs = new uint256[](1);
        unlockInputs[0] = tokenId;

        // Before unlock window
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidUnlockWindow.selector));
        llama.unlock(unlockInputs);
        vm.stopPrank();

        // Before unlock window week 1
        vm.warp(lockTimestamp + 6 days);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidUnlockWindow.selector));
        llama.unlock(unlockInputs);
        vm.stopPrank();

        // Before unlock window week 2
        vm.warp(lockTimestamp + 12 days);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidUnlockWindow.selector));
        llama.unlock(unlockInputs);
        vm.stopPrank();

        // Before unlock window week 3
        vm.warp(lockTimestamp + 18 days);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidUnlockWindow.selector));
        llama.unlock(unlockInputs);
        vm.stopPrank();

        // Before unlock window week 4
        vm.warp(lockTimestamp + 24 days);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidUnlockWindow.selector));
        llama.unlock(unlockInputs);
        vm.stopPrank();

        // week 5 can be unlocked (~30 days)

        // After unlock window week 6
        vm.warp(lockTimestamp + 36 days);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidUnlockWindow.selector));
        llama.unlock(unlockInputs);
        vm.stopPrank();
    }
}
