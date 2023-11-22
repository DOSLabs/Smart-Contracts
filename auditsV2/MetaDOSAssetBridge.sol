// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@layerzerolabs/solidity-examples/contracts/token/onft1155/ProxyONFT1155.sol";

contract MetaDOSAssetBridge is ProxyONFT1155 {
    address private _forwarder;

    constructor(address endpoint_, address token_) ProxyONFT1155(endpoint_, token_) {}

    function forwarder() public view virtual returns (address) {
        return _forwarder;
    }

    function setForwarder(address addr) public virtual onlyOwner {
        require(addr != address(0), "invalid address");
        _forwarder = addr;
    }

    function _msgSender() internal view virtual override returns (address sender) {
        if (forwarder() == msg.sender) {
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (forwarder() == msg.sender) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }
}
