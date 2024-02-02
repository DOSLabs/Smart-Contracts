// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SECONDToken is Ownable, ERC20 {
  // Admin address
  address private _admin;

  // Forwarder address
  address private _forwarder;

  constructor(string memory name_, string memory symbol_, address admin_) Ownable(_msgSender()) ERC20(name_, symbol_) {
    _admin = admin_;
    _mint(_admin, 10_000_000_000 * 10 ** decimals());
  }

  function admin() public view virtual returns (address) {
    return _admin;
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

  function burn(uint256 value) public virtual {
    _burn(_msgSender(), value);
  }
}
