// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";

contract MetaDOSAssetWrapped is OwnableUpgradeable, ERC1155SupplyUpgradeable {
    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Bridge address
    address private _bridge;

    // Forwarder address
    address private _forwarder;

    // Operators address
    mapping(address => bool) private _operators;

    // Blacklist address
    mapping(address => bool) private _blacklist;

    struct TokenLock {
        address sender;
        address receiver;
        uint256 value;
    }
    // Mapping from account to list of owned TokenLock
    mapping(address => mapping(uint256 => TokenLock[])) private _tokenLock;

    function initialize(string calldata uri_, string calldata name_, string calldata symbol_) public initializer {
        require(bytes(uri_).length != 0, "invalid uri_");
        require(bytes(name_).length != 0, "invalid name_");
        require(bytes(symbol_).length != 0, "invalid symbol_");

        __Ownable_init();
        __ERC1155_init(uri_);

        _name = name_;
        _symbol = symbol_;
    }

    function bridge() public view virtual returns (address) {
        return _bridge;
    }

    function setBridge(address addr) public virtual onlyOwner {
        require(addr != address(0), "invalid address");
        _bridge = addr;
    }

    function forwarder() public view virtual returns (address) {
        return _forwarder;
    }

    function setForwarder(address addr) public virtual onlyOwner {
        require(addr != address(0), "invalid address");
        _forwarder = addr;
    }

    function _msgSender() internal view virtual override returns (address sender) {
        if (forwarder() == msg.sender) {
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (forwarder() == msg.sender) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }

    function isOperator(address account) public view virtual returns (bool) {
        return _operators[account];
    }

    function setOperator(address account, bool enable) public virtual onlyOwner {
        require(account != address(0), "invalid address");
        _operators[account] = enable;
    }

    function isBlacklist(address account) public view virtual returns (bool) {
        return _blacklist[account];
    }

    function setBlacklist(address account, bool enable) public virtual onlyOwner {
        require(account != address(0), "invalid address");
        _blacklist[account] = enable;
    }

    function tokenLock(address account, uint256 id) public view virtual returns (TokenLock[] memory) {
        return _tokenLock[account][id];
    }

    function _locked(address account, uint256 id, uint256 value) internal view virtual returns (bool) {
        uint256 total = value;
        TokenLock[] memory items = _tokenLock[account][id];
        for (uint256 i = 0; i < items.length; i++) {
            total += items[i].value;
        }
        return total > balanceOf(account, id);
    }

    function lock(address sender, address receiver, uint256 id, uint256 value) public virtual {
        require(exists(id), "lock for nonexistent token");
        require(!_locked(sender, id, value), "token already locked");

        _safeTransferFrom(sender, receiver, id, value, "");

        TokenLock[] storage items = _tokenLock[receiver][id];
        items.push(TokenLock(sender, receiver, value));
    }

    function unlock(address receiver, uint256 id, uint256 index) public virtual {
        require(exists(id), "unlock for nonexistent token");

        TokenLock[] storage items = _tokenLock[receiver][id];
        address sender = items[index].sender;

        require(sender == _msgSender() || isOperator(_msgSender()), "caller is not sender nor operator");

        items[index] = items[items.length - 1];
        items.pop();
    }

    function repay(address receiver, uint256 id, uint256 index) public virtual {
        require(exists(id), "repay for nonexistent token");

        TokenLock[] storage items = _tokenLock[receiver][id];
        address sender = items[index].sender;
        uint256 value = items[index].value;

        require(receiver == _msgSender() || isOperator(_msgSender()), "caller is not receiver nor operator");

        items[index] = items[items.length - 1];
        items.pop();

        _safeTransferFrom(receiver, sender, id, value, "");
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public virtual override {
        if (_msgSender() == bridge() && from == bridge()) {
            require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
            require(to != address(0), "ERC1155: transfer to the zero address");

            for (uint256 i = 0; i < ids.length; ++i) {
                uint256 balance = balanceOf(from, ids[i]);
                if (amounts[i] <= balance) {
                    super.safeTransferFrom(from, to, ids[i], amounts[i], data);
                } else {
                    _mint(to, ids[i], amounts[i] - balance, data);
                    super.safeTransferFrom(from, to, ids[i], balance, data);
                }
            }
        } else {
            super.safeBatchTransferFrom(from, to, ids, amounts, data);
        }
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory values, bytes memory data) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, values, data);

        if (from != address(0) && from != to) {
            require(!isBlacklist(from), "sender in blacklist");
            for (uint256 i = 0; i < ids.length; i++) {
                require(!_locked(from, ids[i], values[i]), "token already locked");
            }
        }
    }
}
