// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./ERC1155EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol";

contract ERC1155NftUpgradeable is
    IERC1155ReceiverUpgradeable,
    ERC1155EnumerableUpgradeable,
    OwnableUpgradeable
{
    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Operators address
    mapping(address => bool) private _operators;

    // Signers address
    mapping(address => bool) private _signers;

    // Blacklist address
    mapping(address => bool) private _blacklist;

    // Mapping signature to used
    mapping(bytes => bool) private _usedSignatures;

    // Mapping token id to total supply max
    mapping(uint256 => uint256) private _totalSupplyMax;

    struct TokenLock {
        address sender;
        address receiver;
        uint256 amount;
    }
    // Mapping from account to list of owned TokenLock
    mapping(address => mapping(uint256 => TokenLock[])) private _tokensLock;

    /**
     * @dev See UseSignature.
     */
    event UseSignature(
        address indexed account,
        uint256 none,
        uint256[] ids,
        uint256[] amounts,
        bytes signature
    );

    /**
     * @dev See {Initializable-initializer}.
     */
    function initialize(
        string memory uri_,
        string memory name_,
        string memory symbol_
    ) public initializer {
        __Ownable_init();
        __ERC1155_init(uri_);
        _name = name_;
        _symbol = symbol_;
        _operators[_msgSender()] = true;
    }

    /**
     * @dev See {IERC1155ReceiverUpgradeable-onERC1155Received}.
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * @dev See {IERC1155ReceiverUpgradeable-onERC1155BatchReceived}.
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @dev Throws if called by any account other than the operator.
     */
    modifier onlyOperator() {
        require(_operators[_msgSender()], "Caller is not the operator");
        _;
    }

    /**
     * @dev Throws if called by any account other than the signer.
     */
    modifier onlySigner() {
        require(_signers[_msgSender()], "Caller is not the signer");
        _;
    }

    /**
     * @dev Check operator.
     */
    function isOperator(address account) public view virtual returns (bool) {
        return _operators[account];
    }

    /**
     * @dev Set operator.
     */
    function setOperator(address account) public virtual onlyOwner {
        _operators[account] = true;
    }

    /**
     * @dev Del operator.
     */
    function delOperator(address account) public virtual onlyOwner {
        delete _operators[account];
    }

    /**
     * @dev Check signer.
     */
    function isSigner(address account) public view virtual returns (bool) {
        return _signers[account];
    }

    /**
     * @dev Set signer.
     */
    function setSigner(address account) public virtual onlyOwner {
        _signers[account] = true;
    }

    /**
     * @dev Del signer.
     */
    function delSigner(address account) public virtual onlyOwner {
        delete _signers[account];
    }

    /**
     * @dev Check blacklist.
     */
    function isBlacklist(address account) public view virtual returns (bool) {
        return _blacklist[account];
    }

    /**
     * @dev Set blacklist.
     */
    function setBlacklist(address account) public virtual onlyOperator {
        _blacklist[account] = true;
    }

    /**
     * @dev Del blacklist.
     */
    function delBlacklist(address account) public virtual onlyOperator {
        delete _blacklist[account];
    }

    /**
     * @dev Check signature.
     */
    function usedSignature(
        bytes memory signature
    ) public view virtual returns (bool) {
        return _usedSignatures[signature];
    }

    /**
     * @dev Destroy signature.
     */
    function destroySignature(
        bytes memory signature
    ) public virtual onlySigner {
        _usedSignatures[signature] = true;
    }

    /**
     * @dev Check token locked.
     */
    function _locked(
        address account,
        uint256 id,
        uint256 amount
    ) internal view virtual returns (bool) {
        uint256 total = amount;
        TokenLock[] memory items = _tokensLock[account][id];
        for (uint256 i = 0; i < items.length; i++) {
            total += items[i].amount;
        }
        return total > balanceOf(account, id);
    }

    /**
     * @dev Get TokenLock.
     */
    function tokensLock(
        address receiver,
        uint256 id
    ) public view virtual returns (TokenLock[] memory) {
        return _tokensLock[receiver][id];
    }

    /**
     * @dev Lock.
     */
    function lock(
        address sender,
        address receiver,
        uint256 id,
        uint256 amount
    ) public virtual {
        require(exists(id), "Lock for nonexistent token");
        require(!_locked(sender, id, amount), "Token is locked");

        safeTransferFrom(sender, receiver, id, amount, "");

        TokenLock[] storage items = _tokensLock[receiver][id];
        items.push(TokenLock(sender, receiver, amount));
    }

    /**
     * @dev Unlock.
     */
    function unlock(
        address receiver,
        uint256 id,
        uint256 index
    ) public virtual {
        require(exists(id), "Unlock for nonexistent token");

        TokenLock[] storage items = _tokensLock[receiver][id];
        address sender = items[index].sender;

        require(
            sender == _msgSender() || isOperator(_msgSender()),
            "Caller is not sender nor operator"
        );

        items[index] = items[items.length - 1];
        items.pop();
    }

    /**
     * @dev Repay.
     */
    function repay(address receiver, uint256 id, uint256 index) public virtual {
        require(exists(id), "Repay for nonexistent token");

        TokenLock[] storage items = _tokensLock[receiver][id];
        address sender = items[index].sender;
        uint256 amount = items[index].amount;

        require(
            receiver == _msgSender() || isOperator(_msgSender()),
            "Caller is not receiver nor operator"
        );

        items[index] = items[items.length - 1];
        items.pop();

        _safeTransferFrom(receiver, sender, id, amount, "");
    }

    /**
     * @dev Token name.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Token symbol.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Set token URI.
     */
    function setTokenURI(string memory uri) public virtual onlyOwner {
        _setURI(uri);
    }

    /**
     * @dev Set total supply max.
     */
    function setTotalSupplyMax(
        uint256[] memory ids,
        uint256[] memory amounts
    ) public virtual onlyOwner {
        for (uint256 i = 0; i < ids.length; i++) {
            bool ok = (amounts[i] > totalSupplyMax(ids[i]));
            require(ok, "Amount has not exceeds total supply max");
            _totalSupplyMax[ids[i]] = amounts[i];
        }
    }

    /**
     * @dev Total supply max.
     */
    function totalSupplyMax(uint256 id) public view virtual returns (uint256) {
        return _totalSupplyMax[id];
    }

    /**
     * @dev See {ERC1155-_mintBatch}.
     */
    function mint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public virtual onlyOwner {
        _mint(to, ids, amounts);
    }

    /**
     * @dev See {ERC1155-_mintBatch}.
     */
    function mint(
        uint256 none,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory signature
    ) public virtual {
        address to = _msgSender();
        bytes32 msgEncode = keccak256(abi.encodePacked(to, none, ids, amounts));
        bytes32 msgHash = ECDSAUpgradeable.toEthSignedMessageHash(msgEncode);
        address signer = ECDSAUpgradeable.recover(msgHash, signature);

        require(isSigner(signer), "Signature invalid");
        require(!_usedSignatures[signature], "Signature already used");

        _mint(to, ids, amounts);
        _usedSignatures[signature] = true;

        emit UseSignature(to, none, ids, amounts, signature);
    }

    /**
     * @dev See {ERC1155-_mintBatch}.
     */
    function _mint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 total = totalSupply(ids[i]) + amounts[i];
            bool ok = (total <= totalSupplyMax(ids[i]));
            require(ok, "Mint amount exceeds total supply max");
        }
        _mintBatch(to, ids, amounts, "");
    }

    /**
     * @dev See {ERC1155-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        if (from != address(0) && from != to) {
            require(!isBlacklist(from), "Sender in blacklist");
            for (uint256 i = 0; i < ids.length; i++) {
                require(!_locked(from, ids[i], amounts[i]), "Token is locked");
            }
        }
    }
}
