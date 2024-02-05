// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SECONDToken is ERC20 {
  address public admin;

  constructor(string memory name_, string memory symbol_, address admin_) ERC20(name_, symbol_) {
    admin = admin_;
    _mint(admin, 10_000_000_000 * 10 ** decimals());
  }

  function burn(uint256 value) public virtual {
    _burn(_msgSender(), value);
  }
}
