// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MetaDOSINOProxy is TransparentUpgradeableProxy {
    constructor(address logic_, address admin_) TransparentUpgradeableProxy(logic_, admin_, "") {}
}
