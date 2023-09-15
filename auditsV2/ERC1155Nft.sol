// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract ERC1155Nft is ERC1155Supply, Ownable {
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
    // Mapping from owner to list of owned TokenLock
    mapping(address => mapping(uint256 => TokenLock[])) private _tokensLock;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    // Mapping owner address to token count
    mapping(address => uint256) private _tokensOfOwner;

    // Mapping from owner to list of owned token ids
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from owner to list of owned token index
    mapping(address => mapping(uint256 => uint256)) private _ownedTokensIndex;

    /**
     * @dev See {ERC1155-constructor}.
     */
    constructor(
        string memory uri_,
        string memory name_,
        string memory symbol_
    ) ERC1155(uri_) {
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
        address owner,
        uint256 id,
        uint256 amount
    ) internal view virtual returns (bool) {
        uint256 total = amount;
        TokenLock[] memory items = _tokensLock[owner][id];

        for (uint256 i = 0; i < items.length; i++) {
            if (block.timestamp <= items[i].expireAt) {
                total += items[i].amount;
            }
        }

        return total > balanceOf(owner, id);
    }

    /**
     * @dev Get TokenLock.
     */
    function tokensLock(
        address owner,
        uint256 id
    ) public view virtual returns (TokenLock[] memory) {
        return _tokensLock[owner][id];
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
     * @dev See {ERC1155-_mint}.
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount
    ) public virtual onlyOwner {
        require(!exists(id), "Token already minted");
        _mint(to, id, amount, "");
    }

    /**
     * @dev See {ERC1155-_mintBatch}.
     */
    function mintBatch(
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
     * @dev See {ERC1155-_burn}.
     */
    function burn(address from, uint256 id, uint256 amount) public virtual {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "Caller is not owner nor approved"
        );

        _burn(from, id, amount);
    }

    /**
     * @dev See {ERC1155-_burnBatch}.
     */
    function burnBatch(
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
     * @dev See {ERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) public virtual {
        safeTransferFrom(from, to, id, amount, "");
    }

    /**
     * @dev See {ERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public virtual {
        safeBatchTransferFrom(from, to, ids, amounts, "");
    }

    /**
     * @dev Total supply.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev Token ids of owner address.
     */
    function tokensOfOwner(
        address owner
    ) public view virtual returns (uint256[] memory) {
        uint256 count = _tokensOfOwner[owner];
        uint256[] memory ids = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            ids[i] = _ownedTokens[owner][i + 1];
        }

        return ids;
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

    /**
     * @dev See {ERC1155-_afterTokenTransfer}.
     */
    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._afterTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            if (from == address(0)) {
                _addTokenToAllTokens(ids[i]);
            } else if (from != to) {
                _removeTokenFromOwner(from, ids[i]);
            }
            if (to == address(0)) {
                _removeTokenFromAllTokens(ids[i]);
            } else if (to != from) {
                _addTokenToOwner(to, ids[i]);
            }
        }
    }

    /**
     * @dev Add token to owner.
     */
    function _addTokenToOwner(address to, uint256 id) private {
        if (balanceOf(to, id) > 0 && _ownedTokensIndex[to][id] == 0) {
            uint256 length = ++_tokensOfOwner[to];
            _ownedTokens[to][length] = id;
            _ownedTokensIndex[to][id] = length;
        }
    }

    /**
     * @dev Add token to all tokens.
     */
    function _addTokenToAllTokens(uint256 id) private {
        if (exists(id) && _allTokensIndex[id] == 0) {
            _allTokens.push(id);
            _allTokensIndex[id] = _allTokens.length;
        }
    }

    /**
     * @dev Remove token from owner.
     */
    function _removeTokenFromOwner(address from, uint256 id) private {
        if (balanceOf(from, id) == 0 && _ownedTokensIndex[from][id] > 0) {
            // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
            // then delete the last slot (swap and pop).

            uint256 lastTokenIndex = _tokensOfOwner[from];
            uint256 tokenIndex = _ownedTokensIndex[from][id];

            // When the token to delete is the last token, the swap operation is unnecessary
            if (tokenIndex != lastTokenIndex) {
                uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

                _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
                _ownedTokensIndex[from][lastTokenId] = tokenIndex; // Update the moved token's index
            }

            // This also deletes the contents at the last position of the array
            delete _ownedTokensIndex[from][id];
            delete _ownedTokens[from][lastTokenIndex];

            _tokensOfOwner[from] -= 1;
        }
    }

    /**
     * @dev Remove token from all tokens.
     */
    function _removeTokenFromAllTokens(uint256 id) private {
        if (!exists(id) && _allTokensIndex[id] > 0) {
            // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
            // then delete the last slot (swap and pop).

            uint256 lastTokenIndex = _allTokens.length;
            uint256 tokenIndex = _allTokensIndex[id];

            // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
            // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
            // an 'if' statement (like in _removeTokenFromOwner)
            uint256 lastTokenId = _allTokens[lastTokenIndex - 1];

            _allTokens[tokenIndex - 1] = lastTokenId; // Move the last token to the slot of the to-delete token
            _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

            // This also deletes the contents at the last position of the array
            delete _allTokensIndex[id];
            _allTokens.pop();
        }
    }
}
