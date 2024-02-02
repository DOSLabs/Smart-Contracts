// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";

contract MetaDOSAsset is OwnableUpgradeable, EIP712Upgradeable, NoncesUpgradeable, ERC1155SupplyUpgradeable {
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
  string private _name;

  // Token symbol
  string private _symbol;

  // Bridge address
  address private _bridge;

  // Forwarder address
  address private _forwarder;

  // Signers address
  mapping(address => bool) private _signers;

  // Operators address
  mapping(address => bool) private _operators;

  // Blacklist address
  mapping(address => bool) private _blacklist;

  // Token ID locked
  mapping(uint256 => bool) private _idLockeds;

  // Mapping from token ID to account balance locked
  mapping(uint256 => mapping(address => uint256)) private _balanceLockeds;

  event MintSignature(address indexed to, uint256[] ids, uint256[] values, bytes signature);

  event BuySignature(address indexed to, uint256[] ids, uint256[] values, bytes signature);

  event RedeemSignature(address indexed to, uint256[] ids, uint256[] values, bytes signature, uint256[] ids1, uint256[] values1);

  event ExchangeSignature(address indexed to, uint256[] ids, uint256[] values, bytes signature, uint256[] ids1, uint256[] values1);

  function initialize(string calldata uri_, string calldata name_, string calldata symbol_) public initializer {
    require(bytes(uri_).length != 0, "invalid uri_");
    require(bytes(name_).length != 0, "invalid name_");
    require(bytes(symbol_).length != 0, "invalid symbol_");

    __Ownable_init(_msgSender());
    __ERC1155_init(uri_);
    __EIP712_init(name_, "1");

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

  function _msgSender() internal view virtual override returns (address) {
    if (forwarder() == msg.sender && msg.data.length >= 20) {
      return address(bytes20(msg.data[msg.data.length - 20:]));
    } else {
      return super._msgSender();
    }
  }

  function _msgData() internal view virtual override returns (bytes calldata) {
    if (forwarder() == msg.sender && msg.data.length >= 20) {
      return msg.data[:msg.data.length - 20];
    } else {
      return super._msgData();
    }
  }

  function isSigner(address account) public view virtual returns (bool) {
    return _signers[account];
  }

  function setSigner(address account, bool enable) public virtual onlyOwner {
    _signers[account] = enable;
  }

  function isOperator(address account) public view virtual returns (bool) {
    return _operators[account];
  }

  function setOperator(address account, bool enable) public virtual onlyOwner {
    _operators[account] = enable;
  }

  function isBlacklist(address account) public view virtual returns (bool) {
    return _blacklist[account];
  }

  function setBlacklist(address account, bool enable) public virtual {
    require(isOperator(_msgSender()), "caller is not operator");
    _blacklist[account] = enable;
  }

  function isIdLocked(uint256 id) public view virtual returns (bool) {
    return _idLockeds[id];
  }

  function setIdLocked(uint256 id, bool enable) public virtual {
    require(isOperator(_msgSender()), "caller is not operator");
    _idLockeds[id] = enable;
  }

  function balanceOfLocked(address account, uint256 id) public view virtual returns (uint256) {
    return _balanceLockeds[id][account];
  }

  function lockBalance(address account, uint256 id, uint256 value) public virtual {
    require(isOperator(_msgSender()), "caller is not operator");
    _balanceLockeds[id][account] = value;
  }

  function useNonce(address account) public virtual {
    require(account == _msgSender() || isOperator(_msgSender()), "caller is not sender nor operator");
    _useNonce(account);
  }

  function name() public view virtual returns (string memory) {
    return _name;
  }

  function symbol() public view virtual returns (string memory) {
    return _symbol;
  }

  function burn(uint256[] calldata ids, uint256[] calldata values) public virtual {
    _burnBatch(_msgSender(), ids, values);
  }

  function mint(address to, uint256[] calldata ids, uint256[] calldata values, bytes calldata signature) public virtual {
    bytes32 structHash = keccak256(abi.encode(MINT_HASH, to, keccak256(abi.encodePacked(ids)), keccak256(abi.encodePacked(values)), nonces(to)));
    address signer = _hashTypedDataV4(structHash).recover(signature);
    require(isSigner(signer), "signature does not match request");

    _useNonce(to);
    _mintBatch(to, ids, values, "");

    emit MintSignature(to, ids, values, signature);
  }

  function buy(address to, uint256[] calldata ids, uint256[] calldata values, bytes calldata signature, address payment, uint256 price) public virtual {
    bytes32 structHash = keccak256(abi.encode(BUY_HASH, to, keccak256(abi.encodePacked(ids)), keccak256(abi.encodePacked(values)), nonces(to), payment, price));
    address signer = _hashTypedDataV4(structHash).recover(signature);
    require(isSigner(signer), "signature does not match request");

    _useNonce(to);
    IERC20(payment).transferFrom(_msgSender(), owner(), price);
    _mintBatch(to, ids, values, "");

    emit BuySignature(to, ids, values, signature);
  }

  function redeem(uint256[] calldata ids, uint256[] calldata values, bytes calldata signature, uint256[] calldata ids1, uint256[] calldata values1) public virtual {
    address to = _msgSender();

    bytes32 structHash = keccak256(abi.encode(REDEEM_HASH, to, keccak256(abi.encodePacked(ids)), keccak256(abi.encodePacked(values)), nonces(to), keccak256(abi.encodePacked(ids1)), keccak256(abi.encodePacked(values1))));
    address signer = _hashTypedDataV4(structHash).recover(signature);
    require(isSigner(signer), "signature does not match request");

    _useNonce(to);
    _burnBatch(to, ids1, values1);
    _mintBatch(to, ids, values, "");

    emit RedeemSignature(to, ids, values, signature, ids1, values1);
  }

  function exchange(uint256[] calldata ids, uint256[] calldata values, bytes calldata signature, uint256[] calldata ids1, uint256[] calldata values1, address erc) public virtual {
    address to = _msgSender();

    bytes32 structHash = keccak256(abi.encode(EXCHANGE_HASH, to, keccak256(abi.encodePacked(ids)), keccak256(abi.encodePacked(values)), nonces(to), keccak256(abi.encodePacked(ids1)), keccak256(abi.encodePacked(values1)), erc));
    address signer = _hashTypedDataV4(structHash).recover(signature);
    require(isSigner(signer), "signature does not match request");

    _useNonce(to);
    if (erc.supportsInterface(type(IERC721).interfaceId)) {
      IERC721(erc).safeTransferFrom(to, owner(), ids1[0], "");
    } else {
      IERC1155(erc).safeBatchTransferFrom(to, owner(), ids1, values1, "");
    }
    _mintBatch(to, ids, values, "");

    emit ExchangeSignature(to, ids, values, signature, ids1, values1);
  }

  function isContract(address addr) public view virtual returns (bool) {
    return (addr.code.length > 0);
  }

  function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public virtual override {
    if (isContract(_msgSender()) && _msgSender() == bridge()) {
      if (from == bridge()) _mintBatch(to, ids, amounts, data);
      else if (to == bridge()) _burnBatch(from, ids, amounts);
    } else {
      super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }
  }

  function _locked(address from, address to, uint256 id, uint256 value) internal view virtual returns (bool) {
    return (balanceOf(from, id) - value < balanceOfLocked(from, id)) || (to != address(0) && to != owner() && isIdLocked(id));
  }

  function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal virtual override {
    super._update(from, to, ids, values);

    if (from != address(0)) {
      require(!isBlacklist(from), "sender in blacklist");
      for (uint256 i = 0; i < ids.length; i++) {
        require(!_locked(from, to, ids[i], values[i]), "token already locked");
      }
    }
  }
}
