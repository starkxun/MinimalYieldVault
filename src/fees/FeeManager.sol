// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FeeManager
 * @notice 模块4: 费用管理系统
 * @dev 管理 Performance Fee 和 Withdrawal Fee
 */
contract FeeManager is Ownable {
    // ============ State Variables ============

    /// @notice Performance Fee 比例（基点，10000 = 100%）
    uint256 public performanceFeeBps;

    /// @notice Withdrawal Fee 比例（基点）
    uint256 public withdrawalFeeBps;

    /// @notice 费用接收地址
    address public feeRecipient;

    /// @notice 累计收取的 Performance Fee
    uint256 public totalPerformanceFeesCollected;

    /// @notice 累计收取的 Withdrawal Fee
    uint256 public totalWithdrawalFeesCollected;

    /// @notice 是否启用 Performance Fee
    bool public performanceFeeEnabled;

    /// @notice 是否启用 Withdrawal Fee
    bool public withdrawalFeeEnabled;

    // ============ Constants ============
    uint256 public constant MAX_PERFORMANCE_FEE = 5000; // 最大 50%
    uint256 public constant MAX_WITHDRAWAL_FEE = 500; // 最大 5%
    uint256 private constant MAX_BPS = 10000;

    // ============ Events ============
    event PerformanceFeeCollected(uint256 amount, uint256 profit);
    event WithdrawalFeeCollected(uint256 amount, uint256 withdrawn);
    event PerformanceFeeUpdated(uint256 oldFee, uint256 newFee);
    event WithdrawalFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event PerformanceFeeToggled(bool enabled);
    event WithdrawalFeeToggled(bool enabled);

    // ============ Errors ============
    error FeeTooHigh();
    error ZeroAddress();
    error InvalidFeeAmount();

    // ============ Constructor ============
    constructor(address _feeRecipient, uint256 _performanceFeeBps, uint256 _withdrawalFeeBps) Ownable(msg.sender) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_performanceFeeBps > MAX_PERFORMANCE_FEE) revert FeeTooHigh();
        if (_withdrawalFeeBps > MAX_WITHDRAWAL_FEE) revert FeeTooHigh();

        feeRecipient = _feeRecipient;
        performanceFeeBps = _performanceFeeBps;
        withdrawalFeeBps = _withdrawalFeeBps;

        performanceFeeEnabled = _performanceFeeBps > 0;
        withdrawalFeeEnabled = _withdrawalFeeBps > 0;
    }

    // ============ External Functions ============

    /**
     * @notice 计算 Performance Fee
     * @param profit 收益金额
     * @return feeAmount 应收取的费用
     */
    function calculatePerformanceFee(uint256 profit) external view returns (uint256 feeAmount) {
        if (!performanceFeeEnabled || profit == 0) {
            return 0;
        }
        feeAmount = (profit * performanceFeeBps) / MAX_BPS;
    }

    /**
     * @notice 计算 Withdrawal Fee
     * @param amount 提取金额
     * @return feeAmount 应收取的费用
     */
    function calculateWithdrawalFee(uint256 amount) external view returns (uint256 feeAmount) {
        if (!withdrawalFeeEnabled || amount == 0) {
            return 0;
        }
        feeAmount = (amount * withdrawalFeeBps) / MAX_BPS;
    }

    /**
     * @notice 记录 Performance Fee 收取
     * @param feeAmount 收取的费用
     * @param profit 总收益
     */
    function recordPerformanceFee(uint256 feeAmount, uint256 profit) external onlyOwner {
        if (feeAmount > profit) revert InvalidFeeAmount();

        totalPerformanceFeesCollected += feeAmount;

        emit PerformanceFeeCollected(feeAmount, profit);
    }

    /**
     * @notice 记录 Withdrawal Fee 收取
     * @param feeAmount 收取的费用
     * @param withdrawn 提取金额
     */
    function recordWithdrawalFee(uint256 feeAmount, uint256 withdrawn) external onlyOwner {
        if (feeAmount > withdrawn) revert InvalidFeeAmount();

        totalWithdrawalFeesCollected += feeAmount;

        emit WithdrawalFeeCollected(feeAmount, withdrawn);
    }

    /**
     * @notice 设置 Performance Fee 比例
     * @param _performanceFeeBps 新的费率（基点）
     */
    function setPerformanceFee(uint256 _performanceFeeBps) external onlyOwner {
        if (_performanceFeeBps > MAX_PERFORMANCE_FEE) revert FeeTooHigh();

        uint256 oldFee = performanceFeeBps;
        performanceFeeBps = _performanceFeeBps;

        emit PerformanceFeeUpdated(oldFee, _performanceFeeBps);
    }

    /**
     * @notice 设置 Withdrawal Fee 比例
     * @param _withdrawalFeeBps 新的费率（基点）
     */
    function setWithdrawalFee(uint256 _withdrawalFeeBps) external onlyOwner {
        if (_withdrawalFeeBps > MAX_WITHDRAWAL_FEE) revert FeeTooHigh();

        uint256 oldFee = withdrawalFeeBps;
        withdrawalFeeBps = _withdrawalFeeBps;

        emit WithdrawalFeeUpdated(oldFee, _withdrawalFeeBps);
    }

    /**
     * @notice 设置费用接收地址
     * @param _feeRecipient 新的接收地址
     */
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();

        address oldRecipient = feeRecipient;
        feeRecipient = _feeRecipient;

        emit FeeRecipientUpdated(oldRecipient, _feeRecipient);
    }

    /**
     * @notice 切换 Performance Fee 开关
     * @param enabled 是否启用
     */
    function togglePerformanceFee(bool enabled) external onlyOwner {
        performanceFeeEnabled = enabled;
        emit PerformanceFeeToggled(enabled);
    }

    /**
     * @notice 切换 Withdrawal Fee 开关
     * @param enabled 是否启用
     */
    function toggleWithdrawalFee(bool enabled) external onlyOwner {
        withdrawalFeeEnabled = enabled;
        emit WithdrawalFeeToggled(enabled);
    }

    // ============ View Functions ============

    /**
     * @notice 获取所有费用配置
     */
    function getFeeConfiguration()
        external
        view
        returns (uint256 perfFeeBps, uint256 withdrawFeeBps, address recipient, bool perfEnabled, bool withdrawEnabled)
    {
        return (performanceFeeBps, withdrawalFeeBps, feeRecipient, performanceFeeEnabled, withdrawalFeeEnabled);
    }

    /**
     * @notice 获取累计费用统计
     */
    function getTotalFeesCollected()
        external
        view
        returns (uint256 performanceFees, uint256 withdrawalFees, uint256 totalFees)
    {
        performanceFees = totalPerformanceFeesCollected;
        withdrawalFees = totalWithdrawalFeesCollected;
        totalFees = performanceFees + withdrawalFees;
    }
}
