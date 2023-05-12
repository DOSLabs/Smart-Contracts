// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/onft/ERC1155/IONFT1155Upgradeable.sol";
import "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/onft/ERC1155/ONFT1155CoreUpgradeable.sol";

contract OERC1155Upgradeable is
    ERC1155SupplyUpgradeable,
    ONFT1155CoreUpgradeable,
    IONFT1155Upgradeable
{
    function __OERC1155Upgradeable_init(
        string memory uri_,
        address endpoint_
    ) internal onlyInitializing {
        __Ownable_init_unchained();
        __ERC1155_init_unchained(uri_);
        __LzAppUpgradeable_init_unchained(endpoint_);
    }

    function __OERC1155Upgradeable_init_unchained() internal onlyInitializing {}

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(
            ONFT1155CoreUpgradeable,
            ERC1155Upgradeable,
            IERC165Upgradeable
        )
        returns (bool)
    {
        return
            interfaceId == type(IONFT1155Upgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _debitFrom(
        address _from,
        uint16,
        bytes memory,
        uint[] memory _tokenIds,
        uint[] memory _amounts
    ) internal virtual override {
        address spender = _msgSender();
        require(
            spender == _from || isApprovedForAll(_from, spender),
            "OERC1155: send caller is not owner nor approved"
        );
        _burnBatch(_from, _tokenIds, _amounts);
    }

    function _creditTo(
        uint16,
        address _toAddress,
        uint[] memory _tokenIds,
        uint[] memory _amounts
    ) internal virtual override {
        _mintBatch(_toAddress, _tokenIds, _amounts, "");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint[50] private __gap;
}
