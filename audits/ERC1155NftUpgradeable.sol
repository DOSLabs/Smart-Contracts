// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./ERC1155EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ERC1155NftUpgradeable is
    ERC1155EnumerableUpgradeable,
    OwnableUpgradeable
{
    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Operators address
    mapping(address => bool) private _operators;

    // Blacklist address
    mapping(address => bool) private _blacklist;

    struct TokenLock {
        address sender;
        address receiver;
        uint256 expireAt;
        uint256 amount;
    }
    // Mapping from account to list of owned TokenLock
    mapping(address => mapping(uint256 => TokenLock[])) private _tokensLock;

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
     * @dev Throws if called by any account other than the operator.
     */
    modifier onlyOperator() {
        require(_operators[_msgSender()], "Caller is not the operator");
        _;
    }

    /**
     * @dev Set operator.
     */
    function setOperator(address account) public virtual onlyOwner {
        require(account != address(0), "Set operator for the zero address");
        _operators[account] = true;
    }

    /**
     * @dev Del operator.
     */
    function delOperator(address account) public virtual onlyOwner {
        require(account != address(0), "Del operator for the zero address");
        delete _operators[account];
    }

    /**
     * @dev Set blacklist.
     */
    function setBlacklist(address account) public virtual onlyOperator {
        require(account != address(0), "Set blacklist for the zero address");
        _blacklist[account] = true;
    }

    /**
     * @dev Del blacklist.
     */
    function delBlacklist(address account) public virtual onlyOperator {
        require(account != address(0), "Del blacklist for the zero address");
        delete _blacklist[account];
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
            if (block.timestamp <= items[i].expireAt) {
                total += items[i].amount;
            }
        }

        return total > balanceOf(account, id);
    }

    /**
     * @dev Get TokenLock.
     */
    function tokensLock(
        address account,
        uint256 id
    ) public view virtual returns (TokenLock[] memory) {
        return _tokensLock[account][id];
    }

    /**
     * @dev Lock.
     */
    function lock(
        address sender,
        address receiver,
        uint256 id,
        uint256 duration,
        uint256 amount
    ) public virtual {
        require(exists(id), "Lock for nonexistent token");
        require(!_locked(sender, id, amount), "Token is locked");

        safeTransferFrom(sender, receiver, id, amount, "");

        bool found = false;
        uint256 expireAt = block.timestamp + duration;
        TokenLock[] storage items = _tokensLock[receiver][id];

        for (uint256 i = 0; i < items.length; i++) {
            if (block.timestamp > items[i].expireAt) {
                items[i] = TokenLock(sender, receiver, expireAt, amount);
                found = true;
                break;
            }
        }

        if (!found) items.push(TokenLock(sender, receiver, expireAt, amount));
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
        uint256 expireAt = items[index].expireAt;

        require(block.timestamp <= expireAt, "Token is not locked");
        require(
            sender == _msgSender() || _operators[_msgSender()],
            "Caller is not sender nor operator"
        );

        items[index].expireAt = 0;
    }

    /**
     * @dev Revoke.
     */
    function revoke(
        address receiver,
        uint256 id,
        uint256 index
    ) public virtual {
        require(exists(id), "Revoke for nonexistent token");

        TokenLock[] storage items = _tokensLock[receiver][id];
        address sender = items[index].sender;
        uint256 amount = items[index].amount;
        uint256 expireAt = items[index].expireAt;

        require(block.timestamp <= expireAt, "Token is not locked");
        require(
            receiver == _msgSender() || _operators[_msgSender()],
            "Caller is not receiver nor operator"
        );

        items[index].expireAt = 0;
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
     * @dev See {ERC1155-_mintBatch}.
     */
    function mint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public virtual onlyOwner {
        for (uint256 i = 0; i < ids.length; i++) {
            require(!exists(ids[i]), "Token already minted");
        }
        _mintBatch(to, ids, amounts, "");
    }

    /**
     * @dev See {ERC1155-_burnBatch}.
     */
    function burn(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public virtual {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "Caller is not owner nor approved"
        );

        _burnBatch(from, ids, amounts);
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
            require(!_blacklist[from], "Sender in blacklist");
            for (uint256 i = 0; i < ids.length; i++) {
                require(!_locked(from, ids[i], amounts[i]), "Token is locked");
            }
        }
    }
}
