// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract AdminUpgradeableProxy is TransparentUpgradeableProxy {
    constructor(
        address logic_,
        address admin_
    ) TransparentUpgradeableProxy(logic_, admin_, "") {}
}
