// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OERC1155Upgradeable.sol";

contract MetaDOSAssetWrapped is OERC1155Upgradeable {
    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    function initialize(string calldata uri_, string calldata name_, string calldata symbol_, address endpoint_) public initializer {
        __OERC1155Upgradeable_init(uri_, endpoint_);
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }
}
