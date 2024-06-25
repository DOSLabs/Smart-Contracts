// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract LinearStakingPool is OwnableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20 for IERC20;
  using SafeCast for uint256;

  uint64 private constant ONE_YEAR_IN_SECONDS = 365 days;

  // The accepted token
  IERC20 public linearAcceptedToken;

  // The reward distribution address
  address public linearRewardDistributor;

  // Info of each pool
  LinearPoolInfo[] public linearPoolInfos;

  // Info of each user that stakes in pools
  mapping(uint256 => mapping(address => LinearStakingData[])) public linearStakingDatas;

  enum Status {
    Staking,
    PendingWithdrawal,
    Withdrawn
  }

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
    uint256 amount;
    uint256 reward;
    uint256 stakeTime;
    uint256 unstakeTime;
    uint256 withdrawTime;
    uint256 applicableAt;
    Status status;
  }

  function initialize(address _token) public initializer {
    require(_token != address(0), "invalid address");
    linearAcceptedToken = IERC20(_token);

    __ReentrancyGuard_init();
    __Ownable_init(_msgSender());
  }

  modifier linearValidatePoolById(uint256 _poolId) {
    require(_poolId < linearPoolInfos.length, "LinearStakingPool: PoolId are not exist");
    _;
  }

  modifier linearValidateStakeById(
    uint256 _poolId,
    uint256 _stakeId,
    address _account
  ) {
    require(_stakeId < linearStakingDatas[_poolId][_account].length, "LinearStakingPool: StakeId are not exist");
    _;
  }

  function linearSetRewardDistributor(address _linearRewardDistributor) external onlyOwner {
    require(_linearRewardDistributor != address(0), "LinearStakingPool: invalid reward distributor");
    linearRewardDistributor = _linearRewardDistributor;
  }

  function linearAddPool(uint256 _cap, uint256 _minInvestment, uint256 _maxInvestment, uint256 _APR, uint256 _emergencyAPR, uint256 _lockDuration, uint256 _delayDuration, uint64 _startJoinTime, uint64 _endJoinTime, bool _allowEmergencyWithdraw) external onlyOwner {
    require(_endJoinTime >= block.timestamp && _endJoinTime > _startJoinTime, "LinearStakingPool: invalid end join time");
    linearPoolInfos.push(LinearPoolInfo({cap: _cap, totalStaked: 0, minInvestment: _minInvestment, maxInvestment: _maxInvestment, APR: _APR, emergencyAPR: _emergencyAPR, lockDuration: _lockDuration, delayDuration: _delayDuration, startJoinTime: _startJoinTime, endJoinTime: _endJoinTime, allowEmergencyWithdraw: _allowEmergencyWithdraw}));
  }

  function linearUpdatePool(uint256 _poolId, uint256 _cap, uint256 _minInvestment, uint256 _maxInvestment, uint256 _delayDuration, uint64 _endJoinTime, bool _allowEmergencyWithdraw) external onlyOwner linearValidatePoolById(_poolId) {
    LinearPoolInfo storage pool = linearPoolInfos[_poolId];
    require(_endJoinTime >= block.timestamp && _endJoinTime > pool.startJoinTime, "LinearStakingPool: invalid end join time");

    linearPoolInfos[_poolId].cap = _cap;
    linearPoolInfos[_poolId].minInvestment = _minInvestment;
    linearPoolInfos[_poolId].maxInvestment = _maxInvestment;
    linearPoolInfos[_poolId].delayDuration = _delayDuration;
    linearPoolInfos[_poolId].endJoinTime = _endJoinTime;
    linearPoolInfos[_poolId].allowEmergencyWithdraw = _allowEmergencyWithdraw;
  }

  function linearPoolViews() public view returns (LinearPoolInfo[] memory) {
    return linearPoolInfos;
  }

  function linearStakingViews(uint256 _poolId, address _account) public view returns (LinearStakingData[] memory) {
    return linearStakingDatas[_poolId][_account];
  }

  function linearPendingReward(uint256 _poolId, uint256 _stakeId, bool _emergency) public view linearValidatePoolById(_poolId) linearValidateStakeById(_poolId, _stakeId, _msgSender()) returns (uint256 reward) {
    address account = _msgSender();

    LinearPoolInfo storage pool = linearPoolInfos[_poolId];
    LinearStakingData storage stakingData = linearStakingDatas[_poolId][account][_stakeId];

    uint256 startTime = stakingData.stakeTime;

    uint256 endTime = block.timestamp;
    if (pool.lockDuration > 0 && stakingData.stakeTime + pool.lockDuration < block.timestamp) {
      endTime = stakingData.stakeTime + pool.lockDuration;
    }

    uint256 stakedTimeInSeconds = endTime > startTime ? endTime - startTime : 0;

    if (_emergency) {
      reward = pool.allowEmergencyWithdraw ? ((stakingData.amount * stakedTimeInSeconds * pool.emergencyAPR) / ONE_YEAR_IN_SECONDS) / 100 : 0;
    } else {
      reward = ((stakingData.amount * stakedTimeInSeconds * pool.APR) / ONE_YEAR_IN_SECONDS) / 100;
    }
  }

  function linearStake(uint256 _poolId, uint256 _amount) external nonReentrant linearValidatePoolById(_poolId) {
    address account = _msgSender();

    LinearPoolInfo storage pool = linearPoolInfos[_poolId];
    LinearStakingData[] storage stakingDatas = linearStakingDatas[_poolId][account];

    require(block.timestamp >= pool.startJoinTime, "LinearStakingPool: pool is not started yet");

    require(block.timestamp <= pool.endJoinTime, "LinearStakingPool: pool is already closed");

    require(_amount >= pool.minInvestment, "LinearStakingPool: insufficient amount");

    if (pool.cap > 0) {
      require(pool.totalStaked + _amount <= pool.cap, "LinearStakingPool: pool is full");
    }

    if (pool.maxInvestment > 0) {
      uint256 stakingDataAmount = 0;
      for (uint256 i = 0; i < stakingDatas.length; i++) {
        if (stakingDatas[i].status == Status.Staking) stakingDataAmount += stakingDatas[i].amount;
      }
      require(stakingDataAmount + _amount <= pool.maxInvestment, "LinearStakingPool: max investment amount");
    }

    pool.totalStaked += _amount;
    stakingDatas.push(LinearStakingData(_amount, 0, block.timestamp, 0, 0, 0, Status.Staking));

    linearAcceptedToken.safeTransferFrom(account, address(this), _amount);
  }

  function linearUnstake(uint256 _poolId, uint256 _stakeId, bool _emergency) external nonReentrant linearValidatePoolById(_poolId) linearValidateStakeById(_poolId, _stakeId, _msgSender()) {
    address account = _msgSender();

    LinearPoolInfo storage pool = linearPoolInfos[_poolId];
    LinearStakingData[] storage stakingDatas = linearStakingDatas[_poolId][account];

    require(stakingDatas[_stakeId].status == Status.Staking, "LinearStakingPool: not staked yet");

    if (_emergency) {
      require(pool.allowEmergencyWithdraw, "LinearStakingPool: emergency withdrawal is not allowed yet");
      if (block.timestamp >= stakingDatas[_stakeId].stakeTime + pool.lockDuration) _emergency = false;
    } else {
      require(block.timestamp >= stakingDatas[_stakeId].stakeTime + pool.lockDuration, "LinearStakingPool: still locked");
    }

    pool.totalStaked -= stakingDatas[_stakeId].amount;

    stakingDatas[_stakeId].unstakeTime = block.timestamp;
    stakingDatas[_stakeId].reward = linearPendingReward(_poolId, _stakeId, _emergency);

    if (pool.delayDuration == 0) {
      stakingDatas[_stakeId].withdrawTime = block.timestamp;
      stakingDatas[_stakeId].status = Status.Withdrawn;

      linearAcceptedToken.safeTransfer(account, stakingDatas[_stakeId].amount);
      linearAcceptedToken.safeTransferFrom(linearRewardDistributor, account, stakingDatas[_stakeId].reward);
    } else {
      stakingDatas[_stakeId].applicableAt = block.timestamp + pool.delayDuration;
      stakingDatas[_stakeId].status = Status.PendingWithdrawal;
    }
  }

  function linearPendingWithdraw(uint256 _poolId, uint256 _stakeId) external nonReentrant linearValidatePoolById(_poolId) linearValidateStakeById(_poolId, _stakeId, _msgSender()) {
    address account = _msgSender();

    LinearStakingData[] storage stakingDatas = linearStakingDatas[_poolId][account];

    require(stakingDatas[_stakeId].applicableAt <= block.timestamp, "LinearStakingPool: not released yet");
    require(stakingDatas[_stakeId].status == Status.PendingWithdrawal, "LinearStakingPool: not waiting for withdrawal yet");

    stakingDatas[_stakeId].withdrawTime = block.timestamp;
    stakingDatas[_stakeId].status = Status.Withdrawn;

    linearAcceptedToken.safeTransfer(account, stakingDatas[_stakeId].amount);
    linearAcceptedToken.safeTransferFrom(linearRewardDistributor, account, stakingDatas[_stakeId].reward);
  }
}
