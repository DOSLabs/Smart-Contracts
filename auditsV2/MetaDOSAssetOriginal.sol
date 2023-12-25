// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";

contract MetaDOSAssetOriginal is OwnableUpgradeable, EIP712Upgradeable, ERC1155SupplyUpgradeable {
    using ECDSAUpgradeable for bytes32;

    // Mint request
    bytes32 public constant MINT_REQUEST_HASH = keccak256("MintRequest(address to,uint256 id,uint256 value,uint256 nonce)");

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Forwarder address
    address private _forwarder;

    // Signers address
    mapping(address => bool) private _signers;

    // Operators address
    mapping(address => bool) private _operators;

    // Blacklist address
    mapping(address => bool) private _blacklist;

    // Mapping address to nonce
    mapping(address => uint256) private _nonces;

    // Mapping token id to total supply max
    mapping(uint256 => uint256) private _totalSupplyMax;

    struct TokenLock {
        address sender;
        address receiver;
        uint256 value;
    }
    // Mapping from account to list of owned TokenLock
    mapping(address => mapping(uint256 => TokenLock[])) private _tokenLock;

    event MintSignature(address indexed from, uint256 indexed id, uint256 value, bytes signature);

    function initialize(string calldata uri_, string calldata name_, string calldata symbol_) public initializer {
        require(bytes(uri_).length != 0, "invalid uri_");
        require(bytes(name_).length != 0, "invalid name_");
        require(bytes(symbol_).length != 0, "invalid symbol_");

        __Ownable_init();
        __ERC1155_init(uri_);
        __EIP712_init(name_, "1");

        _name = name_;
        _symbol = symbol_;
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

    function isSigner(address account) public view virtual returns (bool) {
        return _signers[account];
    }

    function setSigner(address account, bool enable) public virtual onlyOwner {
        require(account != address(0), "invalid address");
        _signers[account] = enable;
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

    function useNonce(address account) public virtual onlyOwner {
        require(account != address(0), "invalid address");
        _useNonce(account);
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

    function lock(address receiver, uint256 id, uint256 value) public virtual {
        address sender = _msgSender();

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

    function nonces(address account) public view virtual returns (uint256) {
        return _nonces[account];
    }

    function _useNonce(address account) internal virtual returns (uint256) {
        return _nonces[account]++;
    }

    function totalSupplyMax(uint256 id) public view virtual returns (uint256) {
        return _totalSupplyMax[id];
    }

    function setTotalSupplyMax(uint256 id, uint256 value) public virtual onlyOwner {
        require(value != 0, "total supply max can not be set to 0");
        require(value >= totalSupply(id), "supply max is too low");
        _totalSupplyMax[id] = value;
    }

    function burn(uint256 id, uint256 value) public virtual {
        _burn(_msgSender(), id, value);
    }

    function mint(address to, uint256 id, uint256 value, bytes calldata signature) public virtual {
        require(value != 0, "can not mint zero");
        require(to != address(0), "mint to the zero address");

        bytes32 structHash = keccak256(abi.encode(MINT_REQUEST_HASH, to, id, value, nonces(to)));
        address signer = _hashTypedDataV4(structHash).recover(signature);
        require(isSigner(signer), "signature does not match request");

        uint256 total = totalSupply(id) + value;
        require(total <= totalSupplyMax(id), "mint value exceeds total supply max");

        _useNonce(to);
        _mint(to, id, value, "");

        emit MintSignature(to, id, value, signature);
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
