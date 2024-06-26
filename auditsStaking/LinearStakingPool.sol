// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract LinearStakingPool is OwnableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20 for IERC20;
  using SafeCast for uint256;
  using EnumerableSet for EnumerableSet.UintSet;

  uint64 private constant ONE_YEAR_IN_SECONDS = 365 days;

  // maximum 35 days delay
  uint64 public constant LINEAR_MAXIMUM_DELAY_DURATION = 35 days;

  // The accepted token
  IERC20 public linearAcceptedToken;

  // The reward distribution address
  address public linearRewardDistributor;

  // Info of each pool
  LinearPoolInfo[] public linearPoolInfo;

  // Info of each user that stakes in pools
  mapping(uint256 => mapping(address => LinearStakingData)) public linearStakingData;

  // Info of pending withdrawals.
  mapping(uint256 => mapping(address => LinearPendingWithdrawal)) public linearPendingWithdrawals;

  // The flexible lock duration. Users who stake in the flexible pool will be affected by this
  uint256 public linearFlexLockDuration;

  event LinearPoolCreated(uint256 indexed poolId, uint256 APR);
  event LinearDeposit(uint256 indexed poolId, address indexed account, uint256 amount);
  event LinearWithdraw(uint256 indexed poolId, address indexed account, uint256 amount);
  event LinearRewardsHarvested(uint256 indexed poolId, address indexed account, uint256 reward);
  event LinearPendingWithdraw(uint256 indexed poolId, address indexed account, uint256 amount);
  event LinearEmergencyWithdraw(uint256 indexed poolId, address indexed account, uint256 amount);

  struct LinearPoolInfo {
    uint256 cap;
    uint256 totalStaked;
    uint256 minInvestment;
    uint256 maxInvestment;
    uint256 APR;
    uint256 emergencyAPR;
    uint256 lockDuration;
    uint256 delayDuration;
    uint64 startJoinTime;
    uint64 endJoinTime;
    bool allowEmergencyWithdraw;
  }

  struct LinearStakingData {
    uint256 balance;
    uint256 joinTime;
    uint256 updatedTime;
    uint256 reward;
  }

  struct LinearPendingWithdrawal {
    uint256 amount;
    uint256 reward;
    uint256 applicableAt;
  }

  /**
   * @notice initialize the contract, get called in the first time deploy
   * @param token_ the token that the pools will use as staking and reward token
   */
  function initialize(address token_) public initializer {
    require(token_ != address(0), "invalid address");
    linearAcceptedToken = IERC20(token_);

    __ReentrancyGuard_init();
    __Ownable_init(_msgSender());
  }

  /**
   * @notice Validate pool by pool ID
   * @param _poolId id of the pool
   */
  modifier linearValidatePoolById(uint256 _poolId) {
    require(_poolId < linearPoolInfo.length, "LinearStakingPool: Pool are not exist");
    _;
  }

  /**
   * @notice Return total number of pools
   */
  function linearPoolLength() external view returns (uint256) {
    return linearPoolInfo.length;
  }

  /**
   * @notice Return total tokens staked in a pool
   * @param _poolId id of the pool
   */
  function linearTotalStaked(uint256 _poolId) external view linearValidatePoolById(_poolId) returns (uint256) {
    return linearPoolInfo[_poolId].totalStaked;
  }

  /**
   * @notice Add a new pool with different APR and conditions. Can only be called by the owner.
   * @param _cap the maximum number of staking tokens the pool will receive. If this limit is reached, users can not deposit into this pool.
   * @param _minInvestment the minimum investment amount users need to use in order to join the pool.
   * @param _maxInvestment the maximum investment amount users can deposit to join the pool.
   * @param _APR the APR rate of the pool.
   * @param _emergencyAPR the emergency APR rate of the pool.
   * @param _lockDuration the duration users need to wait before being able to withdraw and claim the rewards.
   * @param _delayDuration the duration users need to wait to receive the principal amount, after unstaking from the pool.
   * @param _startJoinTime the time when users can start to join the pool. It's zero means user able to join anytime.
   * @param _endJoinTime the time when users can no longer join the pool.
   * @param _allowEmergencyWithdraw the allow emergency withdraw feature of the pool.
   */
  function linearAddPool(uint256 _cap, uint256 _minInvestment, uint256 _maxInvestment, uint256 _APR, uint256 _emergencyAPR, uint256 _lockDuration, uint256 _delayDuration, uint64 _startJoinTime, uint64 _endJoinTime, bool _allowEmergencyWithdraw) external onlyOwner {
    require(_endJoinTime >= block.timestamp && _endJoinTime > _startJoinTime, "LinearStakingPool: invalid end join time");
    require(_delayDuration <= LINEAR_MAXIMUM_DELAY_DURATION, "LinearStakingPool: delay duration is too long");

    linearPoolInfo.push(LinearPoolInfo({cap: _cap, totalStaked: 0, minInvestment: _minInvestment, maxInvestment: _maxInvestment, APR: _APR, emergencyAPR: _emergencyAPR, lockDuration: _lockDuration, delayDuration: _delayDuration, startJoinTime: _startJoinTime, endJoinTime: _endJoinTime, allowEmergencyWithdraw: _allowEmergencyWithdraw}));
    emit LinearPoolCreated(linearPoolInfo.length - 1, _APR);
  }

  /**
   * @notice Update the given pool's info. Can only be called by the owner.
   * @param _poolId id of the pool
   * @param _cap the maximum number of staking tokens the pool will receive. If this limit is reached, users can not deposit into this pool.
   * @param _minInvestment minimum investment users need to use in order to join the pool.
   * @param _maxInvestment the maximum investment amount users can deposit to join the pool.
   * @param _endJoinTime the time when users can no longer join the pool.
   */
  function linearSetPool(uint256 _poolId, uint256 _cap, uint256 _minInvestment, uint256 _maxInvestment, uint64 _endJoinTime) external onlyOwner linearValidatePoolById(_poolId) {
    LinearPoolInfo storage pool = linearPoolInfo[_poolId];

    require(_endJoinTime >= block.timestamp && _endJoinTime > pool.startJoinTime, "LinearStakingPool: invalid end join time");

    linearPoolInfo[_poolId].cap = _cap;
    linearPoolInfo[_poolId].minInvestment = _minInvestment;
    linearPoolInfo[_poolId].maxInvestment = _maxInvestment;
    linearPoolInfo[_poolId].endJoinTime = _endJoinTime;
  }

  /**
   * @notice Set the flexible lock time. This will affects the flexible pool.  Can only be called by the owner.
   * @param _flexLockDuration the minimum lock duration
   */
  function linearSetFlexLockDuration(uint256 _flexLockDuration) external onlyOwner {
    require(_flexLockDuration <= LINEAR_MAXIMUM_DELAY_DURATION, "LinearStakingPool: flexible lock duration is too long");
    linearFlexLockDuration = _flexLockDuration;
  }

  /**
   * @notice Set the reward distributor. Can only be called by the owner.
   * @param _linearRewardDistributor the reward distributor
   */
  function linearSetRewardDistributor(address _linearRewardDistributor) external onlyOwner {
    require(_linearRewardDistributor != address(0), "LinearStakingPool: invalid reward distributor");
    linearRewardDistributor = _linearRewardDistributor;
  }

  /**
   * @notice Set the approval amount of distributor. Can only be called by the owner.
   * @param _amount amount of approval
   */
  function linearApproveSelfDistributor(uint256 _amount) external onlyOwner {
    require(linearRewardDistributor == address(this), "LinearStakingPool: distributor is difference pool");
    linearAcceptedToken.forceApprove(linearRewardDistributor, _amount);
  }

  /**
   * @notice Deposit token to earn rewards
   * @param _poolId id of the pool
   * @param _amount amount of token to deposit
   */
  function linearDeposit(uint256 _poolId, uint256 _amount) external nonReentrant linearValidatePoolById(_poolId) {
    address account = _msgSender();
    _linearDeposit(_poolId, _amount, account);

    linearAcceptedToken.safeTransferFrom(account, address(this), _amount);
    emit LinearDeposit(_poolId, account, _amount);
  }

  /**
   * @notice Claim pending withdrawal
   * @param _poolId id of the pool
   */
  function linearClaimPendingWithdraw(uint256 _poolId) external nonReentrant linearValidatePoolById(_poolId) {
    address account = _msgSender();
    LinearPendingWithdrawal storage pending = linearPendingWithdrawals[_poolId][account];
    uint256 amount = pending.amount;
    uint256 reward = pending.reward;
    require(amount > 0, "LinearStakingPool: nothing is currently pending");
    require(pending.applicableAt <= block.timestamp, "LinearStakingPool: not released yet");
    delete linearPendingWithdrawals[_poolId][account];
    linearAcceptedToken.safeTransfer(account, amount);
    emit LinearWithdraw(_poolId, account, amount);

    if (reward > 0) {
      require(linearRewardDistributor != address(0), "LinearStakingPool: invalid reward distributor");
      linearAcceptedToken.safeTransferFrom(linearRewardDistributor, account, reward);
      emit LinearRewardsHarvested(_poolId, account, reward);
    }
  }

  /**
   * @notice Withdraw token from a pool
   * @param _poolId id of the pool
   * @param _amount amount to withdraw
   */
  function linearWithdraw(uint256 _poolId, uint256 _amount) external nonReentrant linearValidatePoolById(_poolId) {
    address account = _msgSender();
    LinearPoolInfo storage pool = linearPoolInfo[_poolId];
    LinearStakingData storage stakingData = linearStakingData[_poolId][account];

    uint256 lockDuration = pool.lockDuration > 0 ? pool.lockDuration : linearFlexLockDuration;

    require(block.timestamp >= stakingData.joinTime + lockDuration, "LinearStakingPool: still locked");

    require(stakingData.balance >= _amount, "LinearStakingPool: invalid withdraw amount");

    _linearClaimReward(_poolId, false);

    uint256 reward = stakingData.reward;

    stakingData.reward = 0;
    stakingData.balance -= _amount;

    if (pool.delayDuration == 0) {
      linearAcceptedToken.safeTransfer(account, _amount);
      emit LinearWithdraw(_poolId, account, _amount);
      return;
    }

    LinearPendingWithdrawal storage pending = linearPendingWithdrawals[_poolId][account];

    pending.reward += reward;
    pending.amount += _amount;
    pending.applicableAt = block.timestamp + pool.delayDuration;
  }

  /**
   * @notice Gets number of reward tokens of a user from a pool
   * @param _poolId id of the pool
   * @param _account address of a user
   * @param _emergency emergency withdraw of the pool
   * @return reward earned reward of a user
   */
  function linearPendingReward(uint256 _poolId, address _account, bool _emergency) public view linearValidatePoolById(_poolId) returns (uint256 reward) {
    LinearPoolInfo storage pool = linearPoolInfo[_poolId];
    LinearStakingData storage stakingData = linearStakingData[_poolId][_account];

    uint256 startTime = stakingData.updatedTime > 0 ? stakingData.updatedTime : block.timestamp;

    uint256 endTime = block.timestamp;
    if (pool.lockDuration > 0 && stakingData.joinTime + pool.lockDuration < block.timestamp) {
      endTime = stakingData.joinTime + pool.lockDuration;
    }

    uint256 stakedTimeInSeconds = endTime > startTime ? endTime - startTime : 0;

    if (_emergency) {
      uint256 pendingReward = ((stakingData.balance * stakedTimeInSeconds * pool.emergencyAPR) / ONE_YEAR_IN_SECONDS) / 100;
      reward = pool.allowEmergencyWithdraw ? (((stakingData.reward * pool.emergencyAPR) / pool.APR) + pendingReward) : 0;
    } else {
      uint256 pendingReward = ((stakingData.balance * stakedTimeInSeconds * pool.APR) / ONE_YEAR_IN_SECONDS) / 100;
      reward = stakingData.reward + pendingReward;
    }
  }

  /**
   * @notice Gets number of deposited tokens in a pool
   * @param _poolId id of the pool
   * @param _account address of a user
   * @return total token deposited in a pool by a user
   */
  function linearBalanceOf(uint256 _poolId, address _account) external view linearValidatePoolById(_poolId) returns (uint256) {
    return linearStakingData[_poolId][_account].balance;
  }

  /**
   * @notice Withdraw without caring about rewards. EMERGENCY ONLY.
   * @param _poolId id of the pool
   */
  function linearEmergencyWithdraw(uint256 _poolId) external nonReentrant linearValidatePoolById(_poolId) {
    LinearPoolInfo storage pool = linearPoolInfo[_poolId];
    require(pool.allowEmergencyWithdraw, "LinearStakingPool: emergency withdrawal is not allowed yet");

    address account = _msgSender();
    LinearStakingData storage stakingData = linearStakingData[_poolId][account];

    require(stakingData.balance > 0, "LinearStakingPool: nothing to withdraw");

    _linearClaimReward(_poolId, true);

    uint256 reward = stakingData.reward;
    uint256 amount = stakingData.balance;

    delete linearStakingData[_poolId][account];

    if (pool.delayDuration == 0) {
      linearAcceptedToken.safeTransfer(account, amount);
      emit LinearEmergencyWithdraw(_poolId, account, amount);
      return;
    }

    LinearPendingWithdrawal storage pending = linearPendingWithdrawals[_poolId][account];

    pending.reward += reward;
    pending.amount += amount;
    pending.applicableAt = block.timestamp + pool.delayDuration;
  }

  function _linearDeposit(uint256 _poolId, uint256 _amount, address account) internal {
    LinearPoolInfo storage pool = linearPoolInfo[_poolId];
    LinearStakingData storage stakingData = linearStakingData[_poolId][account];

    require(block.timestamp >= pool.startJoinTime, "LinearStakingPool: pool is not started yet");

    require(block.timestamp <= pool.endJoinTime, "LinearStakingPool: pool is already closed");

    require(stakingData.balance + _amount >= pool.minInvestment, "LinearStakingPool: insufficient amount");

    if (pool.maxInvestment > 0) {
      require(stakingData.balance + _amount <= pool.maxInvestment, "LinearStakingPool: too large amount");
    }

    if (pool.cap > 0) {
      require(pool.totalStaked + _amount <= pool.cap, "LinearStakingPool: pool is full");
    }

    _linearHarvest(_poolId, account, false);

    stakingData.balance += _amount;
    stakingData.joinTime = block.timestamp;

    pool.totalStaked += _amount;
  }

  function _linearClaimReward(uint256 _poolId, bool _emergency) internal {
    address account = _msgSender();
    LinearPoolInfo storage pool = linearPoolInfo[_poolId];
    LinearStakingData storage stakingData = linearStakingData[_poolId][account];

    _linearHarvest(_poolId, account, _emergency);

    if (stakingData.reward > 0 && pool.delayDuration == 0) {
      require(linearRewardDistributor != address(0), "LinearStakingPool: invalid reward distributor");
      uint256 reward = stakingData.reward;
      stakingData.reward = 0;
      linearAcceptedToken.safeTransferFrom(linearRewardDistributor, account, reward);
      emit LinearRewardsHarvested(_poolId, account, reward);
    }
  }

  function _linearHarvest(uint256 _poolId, address _account, bool _emergency) private {
    LinearStakingData storage stakingData = linearStakingData[_poolId][_account];

    stakingData.reward = linearPendingReward(_poolId, _account, _emergency);
    stakingData.updatedTime = block.timestamp;
  }
}
