// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    uint256 private _nextTokenId;

    constructor() ERC20("Test", "TEST") {}

    function mint(address recipient_, uint256 amount_) external {
        _mint(recipient_, amount_);
    }
}
