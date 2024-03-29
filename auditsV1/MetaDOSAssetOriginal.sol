// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";

contract MetaDOSAssetOriginal is EIP712Upgradeable, OERC1155Upgradeable {
    using ECDSAUpgradeable for bytes32;

    // Mint request
    bytes32 private constant _MINT_REQUEST_HASH = keccak256("MintRequest(address to,uint256 id,uint256 value,uint256 nonce)");

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Forwarder address
    address private _forwarder;

    // Signers address
    mapping(address => bool) private _signers;

    // Mapping address to nonce
    mapping(address => uint256) private _nonces;

    // Mapping token id to total supply max
    mapping(uint256 => uint256) private _totalSupplyMax;

    event MintSignature(address indexed from, uint256 indexed id, uint256 value, bytes signature);

    function initialize(string calldata uri_, string calldata name_, string calldata symbol_, address endpoint_) public initializer {
        require(bytes(uri_).length != 0, "invalid uri_");
        require(bytes(name_).length != 0, "invalid name_");
        require(bytes(symbol_).length != 0, "invalid symbol_");
        require(endpoint_ != address(0), "invalid endpoint_");

        __OERC1155Upgradeable_init(uri_, endpoint_);
        __EIP712_init(name_, "1");
        _name = name_;
        _symbol = symbol_;
    }

    function forwarder() public view virtual returns (address) {
        return _forwarder;
    }

    function setForwarder(address fwd) public virtual onlyOwner {
        require(fwd != address(0), "invalid address");
        _forwarder = fwd;
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

    function useNonce(address account) public virtual onlyOwner {
        require(account != address(0), "invalid address");
        _useNonce(account);
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

        bytes32 structHash = keccak256(abi.encode(_MINT_REQUEST_HASH, to, id, value, nonces(to)));
        address signer = _hashTypedDataV4(structHash).recover(signature);
        require(isSigner(signer), "signature does not match request");

        uint256 total = totalSupply(id) + value;
        require(total <= totalSupplyMax(id), "mint value exceeds total supply max");

        _useNonce(to);
        _mint(to, id, value, "");

        emit MintSignature(to, id, value, signature);
    }
}
