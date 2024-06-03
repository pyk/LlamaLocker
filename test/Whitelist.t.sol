// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test} from "forge-std/Test.sol";

import {LlamaLocker} from "../src/LlamaLocker.sol";
import {MockNFT} from "./MockNFT.sol";

contract RewardDistributionTest is Test {
    MockNFT public nft;
    LlamaLocker public locker;

    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        nft = new MockNFT();
        locker =
            new LlamaLocker(admin, address(nft), 0x308b32884ae9d1e08a3e1d00ac6934fa79bf7ae30358cff55dda90c8aebedf9c);
    }

    function test_setRoot_Unauthorized() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        locker.setRoot(0x308b32884ae9d1e08a3e1d00ac6934fa79bf7ae30358cff55dda90c8aebedf9d);
    }

    function test_setRoot_InvalidAction() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidAction.selector));
        locker.setRoot(0x308b32884ae9d1e08a3e1d00ac6934fa79bf7ae30358cff55dda90c8aebedf9c);
    }

    function test_setRoot_Valid() public {
        vm.startPrank(admin);
        locker.setRoot(0x308b32884ae9d1e08a3e1d00ac6934fa79bf7ae30358cff55dda90c8aebedf9d);
        assertEq(locker.root(), 0x308b32884ae9d1e08a3e1d00ac6934fa79bf7ae30358cff55dda90c8aebedf9d);
    }

    function test_disableWhitelist_Unauthorized() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        locker.disableWhitelist();
    }

    function test_disableWhitelist_InvalidAction() public {
        vm.startPrank(admin);
        locker.disableWhitelist();

        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidAction.selector));
        locker.disableWhitelist();
    }

    function test_disableWhitelist_Valid() public {
        vm.startPrank(admin);
        locker.disableWhitelist();
        assertTrue(locker.whitelistDisabled());
    }

    function test_lock_InvalidAction() public {
        uint256 tokenId = nft.mint(bob);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(bob);
        nft.setApprovalForAll(address(locker), true);
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = 0xf62cc5025e4db7152af0690e768a8881468c90d0639e04429b8be7bd50d627d4;
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidAction.selector));
        locker.lock(proofs, tokenIds);
    }

    function test_lock_Valid() public {
        uint256 tokenId = nft.mint(alice);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.startPrank(alice);
        nft.setApprovalForAll(address(locker), true);
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = 0xf62cc5025e4db7152af0690e768a8881468c90d0639e04429b8be7bd50d627d4;
        locker.lock(proofs, tokenIds);

        assertEq(nft.ownerOf(tokenId), address(locker));
    }
}
