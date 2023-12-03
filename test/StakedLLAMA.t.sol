// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {StakedLLAMA} from "contracts/StakedLLAMA.sol";

/**
 * @title Staked LLAMA Test
 * @author sepyke.eth
 * @dev Testing for LLAMA's staking contract
 */
contract StakedLLAMATest is Test {
  StakedLLAMA sLLAMA;

  address owner = vm.addr(0x11A);
  address llama = 0xe127cE638293FA123Be79C25782a5652581Db234;
  IERC20 crv = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);

  function setUp() public {
    sLLAMA = new StakedLLAMA(owner, llama);
  }

  function testFail_AddRewardTokenAsNonOwner() public {
    sLLAMA.addRewardToken(crv);
  }

  function test_AddRewardAsOwner() public {
    vm.startPrank(owner);
    sLLAMA.addRewardToken(crv);

    assertEq(sLLAMA.rewardTokensCount(), 1);
    StakedLLAMA.RewardTokenData memory data = sLLAMA.getRewardTokenData(crv);
    assertEq(data.lastUpdateTime, block.timestamp);
    assertEq(data.periodFinish, block.timestamp);
  }
}
