// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Faucet is Ownable {
    // Amount per request
    uint256 private _amount;

    /**
     * @dev Deposit.
     */
    function deposit() public payable virtual {}

    /**
     * @dev Balance.
     */
    function balance() public view virtual returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Get amount.
     */
    function getAmount() public view virtual returns (uint256) {
        return _amount;
    }

    /**
     * @dev Set amount.
     */
    function setAmount(uint256 amount) public virtual onlyOwner {
        _amount = amount;
    }

    /**
     * @dev Withdraw.
     */
    function withdraw() public virtual onlyOwner {
        (bool ok, ) = payable(owner()).call{value: balance()}("");
        require(ok, "Failed to send balance for owner");
    }

    /**
     * @dev Faucet.
     */
    function faucet(address receiver) public payable virtual {
        require(msg.value == _amount, "Amount has not been enough");
        (bool ok, ) = payable(receiver).call{value: msg.value}("");
        require(ok, "Failed to send balance for receiver");
    }
}
