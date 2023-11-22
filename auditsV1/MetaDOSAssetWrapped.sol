// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OERC1155Upgradeable.sol";

contract MetaDOSAssetWrapped is OERC1155Upgradeable {
    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    function initialize(string calldata uri_, string calldata name_, string calldata symbol_, address endpoint_) public initializer {
        require(bytes(uri_).length != 0, "invalid uri_");
        require(bytes(name_).length != 0, "invalid name_");
        require(bytes(symbol_).length != 0, "invalid symbol_");
        require(endpoint_ != address(0), "invalid endpoint_");

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
