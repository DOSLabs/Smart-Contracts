// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SECONDVesting is Ownable, ReentrancyGuard {
  IERC20 public token;

  uint256 public tgePercent;
  uint256 public tgeReleaseTimestamp;
  uint256 public startReleaseTimestamp;
  uint256 public endReleaseTimestamp;

  mapping(address => uint256) private _locks;
  mapping(address => uint256) private _released;
  mapping(address => uint256) private _tgeReleased;

  constructor() Ownable(msg.sender) {}

  function configuration(address erc, uint256[] calldata values) public virtual onlyOwner {
    require(erc != address(0), "invalid address");
    require(values.length == 4, "invalid length");
    require(values[0] <= 100, "tgePercent > 100");
    require(values[1] < values[2], "tgeReleaseTimestamp > startReleaseTimestamp");
    require(values[2] < values[3], "startReleaseTimestamp > endReleaseTimestamp");
    token = IERC20(erc);
    tgePercent = values[0];
    tgeReleaseTimestamp = values[1];
    startReleaseTimestamp = values[2];
    endReleaseTimestamp = values[3];
  }

  function balance() public view virtual returns (uint256) {
    return token.balanceOf(address(this));
  }

  function emergencyWithdraw(address account) public virtual onlyOwner {
    token.transfer(account, balance());
  }

  function setLockAmounts(address[] calldata accounts, uint256[] calldata values) public virtual onlyOwner {
    require(accounts.length == values.length, "accounts and values length mismatch");
    for (uint256 i = 0; i < accounts.length; ++i) {
      _locks[accounts[i]] = values[i];
    }
  }

  function lockOf(address account) public view virtual returns (uint256) {
    return _locks[account];
  }

  function released(address account) public view virtual returns (uint256) {
    return _released[account];
  }

  function tgeReleased(address account) public view virtual returns (uint256) {
    return _tgeReleased[account];
  }

  function canUnlockAmount(address account) public view virtual returns (uint256) {
    uint256 timestamp = block.timestamp;
    uint256 currentLock = lockOf(account) - tgeReleased(account);
    uint256 currentReleased = released(account) - tgeReleased(account);

    if (timestamp < startReleaseTimestamp) {
      return 0;
    } else if (timestamp >= endReleaseTimestamp) {
      return currentLock - currentReleased;
    } else {
      uint256 releasedTime = timestamp - startReleaseTimestamp;
      uint256 totalVestingTime = endReleaseTimestamp - startReleaseTimestamp;
      return (currentLock * releasedTime) / totalVestingTime - currentReleased;
    }
  }

  function tgeUnlock(address account) public virtual nonReentrant {
    require(block.timestamp > tgeReleaseTimestamp, "still locked");
    require(lockOf(account) > released(account), "no locked");
    require(tgeReleased(account) == 0 && block.timestamp < startReleaseTimestamp, "invalid unlock");

    uint256 value = (lockOf(account) * tgePercent) / 100;

    _released[account] += value;
    _tgeReleased[account] = value;
    token.transfer(account, value);
  }

  function unlock(address account) public virtual nonReentrant {
    require(block.timestamp > startReleaseTimestamp, "still locked");
    require(lockOf(account) > released(account), "no locked");

    uint256 value = canUnlockAmount(account);
    require(value > 0, "zero unlock");

    _released[account] += value;
    token.transfer(account, value);
  }
}
