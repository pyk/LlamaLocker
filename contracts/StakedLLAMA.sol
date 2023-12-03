// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title Staked LLAMA
 * @author sepyke.eth
 * @dev Stake contract for LLAMA ERC721
 */
contract StakedLLAMA is Ownable2Step {
  struct RewardTokenData {
    uint256 periodFinish;
    uint256 rewardRate;
    uint256 lastUpdateTime;
    uint256 rewardPerTokenStored;
  }

  IERC20[] public rewardTokens;
  IERC721 public nft;
  mapping(IERC20 => RewardTokenData) private rewardTokenData;

  error RewardTokenExists();
  error RewardTokenInvalid();

  event RewardTokenAdded(IERC20 rewardToken);

  constructor(address owner_, address nft_) Ownable(owner_) {
    nft = IERC721(nft_);
  }

  function rewardTokensCount() external view returns (uint256 count_) {
    count_ = rewardTokens.length;
  }

  function getRewardTokenData(IERC20 rewardToken_) external view returns (RewardTokenData memory data_) {
    data_ = rewardTokenData[rewardToken_];
  }

  function addRewardToken(IERC20 rewardToken_) external onlyOwner {
    if (rewardTokenData[IERC20(rewardToken_)].lastUpdateTime > 0) revert RewardTokenExists();
    if (address(rewardToken_) == address(this) || address(rewardToken_) == address(nft)) revert RewardTokenInvalid();

    rewardTokens.push(IERC20(rewardToken_));
    rewardTokenData[rewardToken_].lastUpdateTime = block.timestamp;
    rewardTokenData[rewardToken_].periodFinish = block.timestamp;

    emit RewardTokenAdded(rewardToken_);
  }
}
