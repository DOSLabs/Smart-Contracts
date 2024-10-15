// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTAdapter.sol";

contract USDTAdapter is Ownable, OFTAdapter {
  constructor(address token_, address endpoint_, address admin_) Ownable(admin_) OFTAdapter(token_, endpoint_, admin_) {}
}
