// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract LinearStakingPoolProxy is TransparentUpgradeableProxy {
  constructor(address logic_, address owner_) TransparentUpgradeableProxy(logic_, owner_, "") {}
}
