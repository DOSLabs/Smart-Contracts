// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";

contract MetaDOSINO is
    OwnableUpgradeable,
    ERC1155SupplyUpgradeable,
    IERC1155ReceiverUpgradeable
{
    // Token address
    IERC20Upgradeable private _token;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping token id to price
    mapping(uint256 => uint256) private _prices;

    // Mapping token id to total supply max
    mapping(uint256 => uint256) private _totalSupplyMax;

    function initialize(
        IERC20Upgradeable token_,
        string memory uri_,
        string memory name_,
        string memory symbol_
    ) public initializer {
        __Ownable_init();
        __ERC1155_init(uri_);
        _name = name_;
        _token = token_;
        _symbol = symbol_;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function token() public view virtual returns (IERC20Upgradeable) {
        return _token;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function setTokenURI(string memory uri) public virtual onlyOwner {
        _setURI(uri);
    }

    function setPrice(
        uint256[] memory ids,
        uint256[] memory prices
    ) public virtual onlyOwner {
        for (uint256 i = 0; i < ids.length; i++) {
            _prices[ids[i]] = prices[i];
        }
    }

    function getPrice(uint256 id) public view virtual returns (uint256) {
        return _prices[id];
    }

    function setTotalSupplyMax(
        uint256[] memory ids,
        uint256[] memory amounts
    ) public virtual onlyOwner {
        for (uint256 i = 0; i < ids.length; i++) {
            _totalSupplyMax[ids[i]] = amounts[i];
        }
    }

    function totalSupplyMax(uint256 id) public view virtual returns (uint256) {
        return _totalSupplyMax[id];
    }

    function mint(uint256 id, uint256 amount) public virtual {
        uint256 total = totalSupply(id) + amount;
        bool ok = (total <= totalSupplyMax(id));
        require(ok, "Mint amount exceeds total supply max");

        address minter = _msgSender();
        uint256 price = _prices[id] * amount;

        require(
            price <= _token.allowance(minter, address(this)),
            "Buyer doesn't approve marketplace to spend payment amount"
        );

        _token.transferFrom(minter, owner(), price);
        _mint(minter, id, amount, "");
    }
}
