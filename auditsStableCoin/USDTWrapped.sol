// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

contract USDTWrapped is Ownable, OFT {
  constructor(string memory name_, string memory symbol_, address endpoint_, address admin_) Ownable(admin_) OFT(name_, symbol_, endpoint_, admin_) {}

  function withdraw() public virtual onlyOwner {
    (bool ok, ) = payable(owner()).call{value: address(this).balance}("");
    require(ok, "failed to send balance for owner");
  }

  function withdrawERC20(IERC20 erc20) public virtual onlyOwner {
    erc20.transfer(owner(), erc20.balanceOf(address(this)));
  }
}
