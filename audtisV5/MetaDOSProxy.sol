// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MetaDOSProxy is TransparentUpgradeableProxy {
  string public name;
  string public symbol;

  constructor(string memory name_, string memory symbol_, address logic_, address owner_) TransparentUpgradeableProxy(logic_, owner_, "") {
    name = name_;
    symbol = symbol_;
  }

  receive() external payable virtual {}
}
