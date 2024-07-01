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

    function test_getLocks() public {
        uint256 tokenId = nft.mint(alice);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(alice);
        nft.setApprovalForAll(address(locker), true);
        vm.stopPrank();

        vm.startPrank(bob);
        nft.setApprovalForAll(address(locker), true);
        vm.stopPrank();

        vm.startPrank(alice);
        locker.lock(tokenIds);
        vm.stopPrank();

        tokenId = nft.mint(bob);
        tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(bob);
        locker.lock(tokenIds);
        vm.stopPrank();

        LlamaLocker.NFTLock[] memory locks = locker.getLocks();
        assertEq(locks[0].owner, alice, "invalid lock alice");
        assertEq(locks[1].owner, bob, "invalid lock bob");

        locks = locker.getLocksByOwner(alice);
        assertEq(locks[0].owner, alice, "invalid lock alice");

        locks = locker.getLocksByOwner(bob);
        assertEq(locks[0].owner, bob, "invalid lock bob");
    }
}
