// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";

abstract contract ERC1155EnumerableUpgradeable is
    Initializable,
    ERC1155SupplyUpgradeable
{
    function __ERC1155Enumerable_init() internal onlyInitializing {}

    function __ERC1155Enumerable_init_unchained() internal onlyInitializing {}

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    // Mapping account address to token count
    mapping(address => uint256) private _balanceOfOwner;

    // Mapping from account to list of owned token ids
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from account to list of owned token index
    mapping(address => mapping(uint256 => uint256)) private _ownedTokensIndex;

    /**
     * @dev See {ERC1155Enumerable-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        require(
            account != address(0),
            "ERC1155Enumerable: balance query for the zero address"
        );
        return _balanceOfOwner[account];
    }

    /**
     * @dev See {ERC1155Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(
        address account,
        uint256 index
    ) public view virtual returns (uint256) {
        require(
            index < _balanceOfOwner[account],
            "ERC721Enumerable: account index out of bounds"
        );
        return _ownedTokens[account][index + 1];
    }

    /**
     * @dev See {ERC1155Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {ERC1155Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual returns (uint256) {
        require(
            index < totalSupply(),
            "ERC721Enumerable: global index out of bounds"
        );
        return _allTokens[index];
    }

    /**
     * @dev {ERC1155Enumerable-tokensOfOwner}.
     */
    function tokensOfOwner(
        address account
    ) public view virtual returns (uint256[] memory) {
        uint256 count = balanceOf(account);
        uint256[] memory ids = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            ids[i] = tokenOfOwnerByIndex(account, i);
        }

        return ids;
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
     * @dev {ERC1155Enumerable-_addTokenToOwner}.
     */
    function _addTokenToOwner(address to, uint256 id) private {
        if (balanceOf(to, id) > 0 && _ownedTokensIndex[to][id] == 0) {
            uint256 length = ++_balanceOfOwner[to];
            _ownedTokens[to][length] = id;
            _ownedTokensIndex[to][id] = length;
        }
    }

    /**
     * @dev {ERC1155Enumerable-_addTokenToAllTokens}.
     */
    function _addTokenToAllTokens(uint256 id) private {
        if (exists(id) && _allTokensIndex[id] == 0) {
            _allTokens.push(id);
            _allTokensIndex[id] = _allTokens.length;
        }
    }

    /**
     * @dev {ERC1155Enumerable-_removeTokenFromOwner}.
     */
    function _removeTokenFromOwner(address from, uint256 id) private {
        if (balanceOf(from, id) == 0 && _ownedTokensIndex[from][id] > 0) {
            // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
            // then delete the last slot (swap and pop).

            uint256 lastTokenIndex = _balanceOfOwner[from];
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

            _balanceOfOwner[from] -= 1;
        }
    }

    /**
     * @dev {ERC1155Enumerable-_removeTokenFromAllTokens}.
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
