// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract ERC1155Marketplace is Ownable {
    // Nft contract address
    IERC1155 private _nft;

    // Token contract address
    IERC20 private _token;

    // Tax fee (percentage)
    uint256 private constant TAX_FEE = 10;

    // Operators address
    mapping(address => bool) private _operators;

    struct Listing {
        address seller;
        uint256 id;
        uint256 price;
        uint256 amount;
    }
    // Mapping from token id to Listing
    mapping(uint256 => Listing[]) _listing;

    /**
     * @dev Constructor.
     */
    constructor(IERC1155 nft_, IERC20 token_) {
        _nft = nft_;
        _token = token_;
        _operators[_msgSender()] = true;
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
    function revoke(address seller, uint256 id) public virtual {
        require(
            seller == _msgSender() || _operators[_msgSender()],
            "Caller is not owner nor operator"
        );

        (bool found, uint256 index) = (false, 0);
        Listing[] storage items = _listing[id];

        for (uint256 i = 0; i < items.length; i++) {
            if (seller == items[i].seller) {
                (found, index) = (true, i);
            }
        }

        if (found) {
            items[index] = items[items.length - 1];
            items.pop();
        }
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

        uint256 price = 0;
        (bool found, uint256 index) = (false, 0);
        Listing[] storage items = _listing[id];

        for (uint256 i = 0; i < items.length; i++) {
            if (seller == items[i].seller && amount <= items[i].amount) {
                price += amount * items[i].price;
                (found, index) = (true, i);
            }
        }

        require(found, "Amount has not been enough");
        require(
            price <= _token.allowance(buyer, address(this)),
            "Buyer doesn't approve marketplace to spend payment amount"
        );

        uint256 ownerFee = (price * TAX_FEE) / 100;
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
