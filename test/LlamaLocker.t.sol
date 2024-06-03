// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {LlamaLocker} from "../src/LlamaLocker.sol";
import {MockNFT} from "./MockNFT.sol";

contract LlamaLockerTest is Test {
    LlamaLocker private locker;

    address private admin = makeAddr("admin");
    MockNFT private nft = new MockNFT();

    function setUp() public {
        vm.warp(1706482182); // NOTE: Sun Jan 28 2024 22:49:42 GMT+0000
        locker =
            new LlamaLocker(admin, address(nft), 0x308b32884ae9d1e08a3e1d00ac6934fa79bf7ae30358cff55dda90c8aebedf9c);
    }

    function test_renounceOwnership_InvalidAction() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(LlamaLocker.InvalidAction.selector));
        locker.renounceOwnership();
    }
}
