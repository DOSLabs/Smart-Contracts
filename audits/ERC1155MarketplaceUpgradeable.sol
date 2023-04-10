// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";

contract ERC1155MarketplaceUpgradeable is OwnableUpgradeable {
    // Nft address
    IERC1155Upgradeable private _nft;

    // Token address
    IERC20Upgradeable private _token;

    // Fee (percentage)
    uint256 private _fee = 5;

    struct Listing {
        address seller;
        uint256 id;
        uint256 price;
        uint256 amount;
    }
    // Mapping from token id to Listing
    mapping(uint256 => Listing[]) _listing;

    /**
     * @dev See {Initializable-initializer}.
     */
    function initialize(
        IERC1155Upgradeable nft_,
        IERC20Upgradeable token_
    ) public initializer {
        __Ownable_init();
        _nft = nft_;
        _token = token_;
    }

    /**
     * @dev Get fee.
     */
    function getFee() public view virtual returns (uint256) {
        return _fee;
    }

    /**
     * @dev Set fee.
     */
    function setFee(uint256 fee) public virtual onlyOwner {
        _fee = fee;
    }

    /**
     * @dev Detail.
     */
    function detail(uint256 id) public view virtual returns (Listing[] memory) {
        return _listing[id];
    }

    /**
     * @dev Sell.
     */
    function sell(uint256 id, uint256 price, uint256 amount) public virtual {
        address seller = _msgSender();

        require(
            amount <= _nft.balanceOf(seller, id),
            "You are not the owner of this NFT"
        );
        require(
            _nft.isApprovedForAll(seller, address(this)),
            "Marketplace is not approved to transfer this NFT"
        );

        bool found = false;
        Listing[] storage items = _listing[id];

        for (uint256 i = 0; i < items.length; i++) {
            if (seller == items[i].seller) {
                items[i] = Listing(seller, id, price, amount);
                found = true;
                break;
            }
        }

        if (!found) items.push(Listing(seller, id, price, amount));
    }

    /**
     * @dev Revoke.
     */
    function revoke(uint256 id) public virtual {
        address sender = _msgSender();

        (bool found, uint256 index) = (false, 0);
        Listing[] storage items = _listing[id];

        for (uint256 i = 0; i < items.length; i++) {
            if (sender == items[i].seller) {
                (found, index) = (true, i);
            }
        }

        require(found, "You are not the owner of this NFT");

        items[index] = items[items.length - 1];
        items.pop();
    }

    /**
     * @dev Buy.
     */
    function buy(address seller, uint256 id, uint256 amount) public virtual {
        address buyer = _msgSender();

        require(
            _nft.isApprovedForAll(seller, address(this)),
            "Marketplace is not approved to transfer this NFT"
        );

        (bool found, uint256 index, uint256 price) = (false, 0, 0);
        Listing[] storage items = _listing[id];

        for (uint256 i = 0; i < items.length; i++) {
            if (seller == items[i].seller && amount <= items[i].amount) {
                (found, index, price) = (true, i, amount * items[i].price);
            }
        }

        require(found, "Amount has not been enough");
        require(
            price <= _token.allowance(buyer, address(this)),
            "Buyer doesn't approve marketplace to spend payment amount"
        );

        uint256 ownerFee = (price * _fee) / 100;
        uint256 sellerFee = price - ownerFee;

        _token.transferFrom(buyer, owner(), ownerFee);
        _token.transferFrom(buyer, seller, sellerFee);

        _nft.safeTransferFrom(seller, buyer, id, amount, "");

        if (amount < items[index].amount) {
            items[index].amount -= amount;
        } else {
            items[index] = items[items.length - 1];
            items.pop();
        }
    }
}
