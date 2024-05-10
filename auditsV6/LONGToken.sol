// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

contract LONGToken is Ownable, OFT {
  uint256 public tgeEndTime;
  address public liquidityPool;

  constructor(string memory name_, string memory symbol_, address endpoint_, address admin_) Ownable(admin_) OFT(name_, symbol_, endpoint_, admin_) {
    uint chainId;
    assembly {
      chainId := chainid()
    }
    if (chainId == 43113 || chainId == 43114) _mint(admin_, 999_999_999 * 10 ** decimals());
  }

  function burn(uint256 value) public virtual {
    _burn(_msgSender(), value);
  }

  function withdraw() public virtual onlyOwner {
    (bool ok, ) = payable(owner()).call{value: address(this).balance}("");
    require(ok, "failed to send balance for owner");
  }

  function withdrawERC20(IERC20 erc20) public virtual onlyOwner {
    erc20.transfer(owner(), erc20.balanceOf(address(this)));
  }

  function setLiquidityPool(uint256 _tgeEndTime, address _liquidityPool) public virtual onlyOwner {
    require(liquidityPool == address(0), "liquidity pool already set");
    tgeEndTime = _tgeEndTime;
    liquidityPool = _liquidityPool;
  }

  function _update(address from, address to, uint256 amount) internal virtual override {
    if (liquidityPool == address(0)) {
      require(from == owner() || to == owner(), "trading not available");
    }
    if (block.timestamp < tgeEndTime && from != owner() && to != liquidityPool) {
      require(balanceOf(to) + amount <= (totalSupply() / 167), "require that a receiving wallet will not hold more than 0.6% of supply while launching");
    }
    super._update(from, to, amount);
  }
}
