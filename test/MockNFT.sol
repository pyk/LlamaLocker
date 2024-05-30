// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockNFT is ERC721 {
    uint256 private _nextTokenId;

    constructor() ERC721("Test", "TEST") {}

    function mint(address recipient_) external returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        _mint(recipient_, tokenId);
    }
}
