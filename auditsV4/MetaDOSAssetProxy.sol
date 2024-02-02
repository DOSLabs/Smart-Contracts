// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MetaDOSAssetProxy is TransparentUpgradeableProxy {
  constructor(address logic_) TransparentUpgradeableProxy(logic_, msg.sender, "") {}
}
