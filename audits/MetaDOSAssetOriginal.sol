// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol";

contract MetaDOSAssetOriginal is OERC1155Upgradeable, IERC1155ReceiverUpgradeable {
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

    event UseSignature(address indexed from, uint256 id, uint256 nonce, uint256 value, bytes signature);

    function initialize(string memory uri_, string memory name_, string memory symbol_, address endpoint_, address forwarder_) public initializer {
        __OERC1155Upgradeable_init(uri_, endpoint_);
        _name = name_;
        _symbol = symbol_;
        _forwarder = forwarder_;
    }

    function setForwarder(address forwarder) public virtual onlyOwner {
        _forwarder = forwarder;
    }

    function getForwarder() public view virtual returns (address) {
        return _forwarder;
    }

    function _msgSender() internal view virtual override returns (address sender) {
        if (getForwarder() == msg.sender) {
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (getForwarder() == msg.sender) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    modifier onlySigner() {
        require(_signers[_msgSender()], "Caller is not the signer");
        _;
    }

    function isSigner(address account) public view virtual returns (bool) {
        return _signers[account];
    }

    function setSigner(address account) public virtual onlyOwner {
        _signers[account] = true;
    }

    function delSigner(address account) public virtual onlyOwner {
        delete _signers[account];
    }

    function getNonce(address account) public view virtual returns (uint256) {
        return _nonces[account];
    }

    function setNonce(address account) public virtual onlySigner {
        _nonces[account]++;
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

    function setTotalSupplyMax(uint256[] memory ids, uint256[] memory amounts) public virtual onlyOwner {
        for (uint256 i = 0; i < ids.length; i++) {
            _totalSupplyMax[ids[i]] = amounts[i];
        }
    }

    function totalSupplyMax(uint256 id) public view virtual returns (uint256) {
        return _totalSupplyMax[id];
    }

    function mint(address to, uint256 id, uint256 nonce, uint256 amount, bytes memory signature) public virtual {
        bytes32 msgEncode = keccak256(abi.encodePacked(to, id, nonce, amount));
        bytes32 msgHash = ECDSAUpgradeable.toEthSignedMessageHash(msgEncode);
        address signer = ECDSAUpgradeable.recover(msgHash, signature);

        require(isSigner(signer) && getNonce(to) == nonce, "Signature does not match request");

        uint256 total = totalSupply(id) + amount;
        bool ok = (total <= totalSupplyMax(id));
        require(ok, "Mint amount exceeds total supply max");

        _mint(to, id, amount, "");
        _nonces[to]++;

        emit UseSignature(to, id, nonce, amount, signature);
    }
}
