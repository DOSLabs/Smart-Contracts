// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

contract SECONDToken is Ownable, ERC2771Context, OFT {
  string private _name;
  string private _symbol;

  constructor(string memory name_, string memory symbol_, address endpoint_, address forwarder_, address admin_) Ownable(admin_) ERC2771Context(forwarder_) OFT(name_, symbol_, endpoint_, admin_) {
    _name = name_;
    _symbol = symbol_;

    uint chainId;
    assembly {
      chainId := chainid()
    }
    if (chainId == 43113 || chainId == 43114) _mint(admin_, 10_000_000_000 * 10 ** decimals());
  }

  function _msgSender() internal view virtual override(Context, ERC2771Context) returns (address) {
    return super._msgSender();
  }

  function _msgData() internal view virtual override(Context, ERC2771Context) returns (bytes calldata) {
    return super._msgData();
  }

  function _contextSuffixLength() internal view virtual override(Context, ERC2771Context) returns (uint256) {
    return super._contextSuffixLength();
  }

  function name() public view virtual override returns (string memory) {
    return _name;
  }

  function symbol() public view virtual override returns (string memory) {
    return _symbol;
  }

  function burn(uint256 value) public virtual {
    _burn(_msgSender(), value);
  }
}
