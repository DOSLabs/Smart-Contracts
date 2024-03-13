// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";

contract MetaDOS is OwnableUpgradeable, ERC2771ContextUpgradeable, EIP712Upgradeable, NoncesUpgradeable, ERC1155SupplyUpgradeable {
  using ECDSA for bytes32;
  using ERC165Checker for address;

  // Mint hash
  bytes32 public constant MINT_HASH = keccak256("MintRequest(address to,uint256[] ids,uint256[] values,uint256 nonce)");

  // Buy hash
  bytes32 public constant BUY_HASH = keccak256("BuyRequest(address to,uint256[] ids,uint256[] values,uint256 nonce,address payment,uint256 price)");

  // Redeem hash
  bytes32 public constant REDEEM_HASH = keccak256("RedeemRequest(address to,uint256[] ids,uint256[] values,uint256 nonce,uint256[] ids1,uint256[] values1)");

  // Exchange hash
  bytes32 public constant EXCHANGE_HASH = keccak256("ExchangeRequest(address to,uint256[] ids,uint256[] values,uint256 nonce,uint256[] ids1,uint256[] values1,address erc)");

  // Token name
  string public name;

  // Token symbol
  string public symbol;

  // Bridge address
  address public bridge;

  // Signer address
  address public signer;

  // Operator address
  address public operator;

  // Blacklist address
  mapping(address => bool) private _blacklist;

  // Token ID locked
  mapping(uint256 => bool) private _idLockeds;

  // Mapping from token ID to account balance locked
  mapping(uint256 => mapping(address => uint256)) private _balanceLockeds;

  event UseNonce(address indexed to, uint256 nonce);

  event MintSignature(address indexed to, uint256[] ids, uint256[] values, bytes signature);

  event BuySignature(address indexed to, uint256[] ids, uint256[] values, bytes signature);

  event RedeemSignature(address indexed to, uint256[] ids, uint256[] values, bytes signature, uint256[] ids1, uint256[] values1);

  event ExchangeSignature(address indexed to, uint256[] ids, uint256[] values, bytes signature, uint256[] ids1, uint256[] values1);

  constructor(address forwarder_) ERC2771ContextUpgradeable(forwarder_) {}

  function _msgSender() internal view virtual override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (address) {
    return super._msgSender();
  }

  function _msgData() internal view virtual override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (bytes calldata) {
    return super._msgData();
  }

  function _contextSuffixLength() internal view virtual override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (uint256) {
    return super._contextSuffixLength();
  }

  function initialize(string calldata name_, string calldata symbol_, string calldata uri_) public initializer {
    require(bytes(uri_).length != 0, "invalid uri_");
    require(bytes(name_).length != 0, "invalid name_");
    require(bytes(symbol_).length != 0, "invalid symbol_");

    name = name_;
    symbol = symbol_;

    __ERC1155_init(uri_);
    __EIP712_init(name_, "1");
    __Ownable_init(_msgSender());
  }

  function setBridge(address addr) public virtual onlyOwner {
    bridge = addr;
  }

  function setSigner(address addr) public virtual onlyOwner {
    signer = addr;
  }

  function setOperator(address addr) public virtual onlyOwner {
    operator = addr;
  }

  function isBlacklist(address account) public view virtual returns (bool) {
    return _blacklist[account];
  }

  function setBlacklist(address account, bool enable) public virtual {
    require(operator == _msgSender(), "caller is not operator");
    _blacklist[account] = enable;
  }

  function isIdLocked(uint256 id) public view virtual returns (bool) {
    return _idLockeds[id];
  }

  function setIdLocked(uint256 id, bool enable) public virtual {
    require(operator == _msgSender(), "caller is not operator");
    _idLockeds[id] = enable;
  }

  function balanceOfLocked(address account, uint256 id) public view virtual returns (uint256) {
    return _balanceLockeds[id][account];
  }

  function lockBalance(address account, uint256 id, uint256 value) public virtual {
    require(operator == _msgSender(), "caller is not operator");
    _balanceLockeds[id][account] = value;
  }

  function useNonce(address to) public virtual {
    require(to == _msgSender() || signer == _msgSender(), "caller is not sender nor signer");
    emit UseNonce(to, _useNonce(to));
  }

  function burn(uint256[] calldata ids, uint256[] calldata values) public virtual {
    _burnBatch(_msgSender(), ids, values);
  }

  function mint(address to, uint256[] calldata ids, uint256[] calldata values, bytes calldata signature) public virtual {
    bytes32 structHash = keccak256(abi.encode(MINT_HASH, to, keccak256(abi.encodePacked(ids)), keccak256(abi.encodePacked(values)), nonces(to)));
    require(signer == _hashTypedDataV4(structHash).recover(signature), "signature does not match request");

    _useNonce(to);
    _mintBatch(to, ids, values, "");

    emit MintSignature(to, ids, values, signature);
  }

  function buy(address to, uint256[] calldata ids, uint256[] calldata values, bytes calldata signature, address payment, uint256 price) public virtual {
    bytes32 structHash = keccak256(abi.encode(BUY_HASH, to, keccak256(abi.encodePacked(ids)), keccak256(abi.encodePacked(values)), nonces(to), payment, price));
    require(signer == _hashTypedDataV4(structHash).recover(signature), "signature does not match request");

    _useNonce(to);
    IERC20(payment).transferFrom(_msgSender(), owner(), price);
    _mintBatch(to, ids, values, "");

    emit BuySignature(to, ids, values, signature);
  }

  function redeem(uint256[] calldata ids, uint256[] calldata values, bytes calldata signature, uint256[] calldata ids1, uint256[] calldata values1) public virtual {
    address to = _msgSender();

    bytes32 structHash = keccak256(abi.encode(REDEEM_HASH, to, keccak256(abi.encodePacked(ids)), keccak256(abi.encodePacked(values)), nonces(to), keccak256(abi.encodePacked(ids1)), keccak256(abi.encodePacked(values1))));
    require(signer == _hashTypedDataV4(structHash).recover(signature), "signature does not match request");

    _useNonce(to);
    _burnBatch(to, ids1, values1);
    _mintBatch(to, ids, values, "");

    emit RedeemSignature(to, ids, values, signature, ids1, values1);
  }

  function exchange(uint256[] calldata ids, uint256[] calldata values, bytes calldata signature, uint256[] calldata ids1, uint256[] calldata values1, address erc) public virtual {
    address to = _msgSender();

    bytes32 structHash = keccak256(abi.encode(EXCHANGE_HASH, to, keccak256(abi.encodePacked(ids)), keccak256(abi.encodePacked(values)), nonces(to), keccak256(abi.encodePacked(ids1)), keccak256(abi.encodePacked(values1)), erc));
    require(signer == _hashTypedDataV4(structHash).recover(signature), "signature does not match request");

    _useNonce(to);
    if (erc.supportsInterface(type(IERC721).interfaceId)) {
      IERC721(erc).safeTransferFrom(to, owner(), ids1[0], "");
    } else {
      IERC1155(erc).safeBatchTransferFrom(to, owner(), ids1, values1, "");
    }
    _mintBatch(to, ids, values, "");

    emit ExchangeSignature(to, ids, values, signature, ids1, values1);
  }

  function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public virtual override {
    address sender = _msgSender();
    if (sender.code.length > 0 && sender == bridge) {
      if (from == bridge) _mintBatch(to, ids, amounts, data);
      else if (to == bridge) _burnBatch(from, ids, amounts);
    } else {
      super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }
  }

  function _locked(address from, address to, uint256 id, uint256 value) internal view virtual returns (bool) {
    return (balanceOf(from, id) - value < balanceOfLocked(from, id)) || (to != address(0) && to != owner() && isIdLocked(id));
  }

  function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal virtual override {
    if (from != address(0)) {
      require(!isBlacklist(from), "sender in blacklist");
      for (uint256 i = 0; i < ids.length; i++) {
        require(!_locked(from, to, ids[i], values[i]), "token already locked");
      }
    }
    super._update(from, to, ids, values);
  }
}
