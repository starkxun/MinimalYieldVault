// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title BaseStrategy
 * @notice Strategy 基类 - 定义所有 Strategy 的标准接口
 * @dev 所有具体 Strategy 应该继承这个合约
 */
abstract contract BaseStrategy {
    using SafeERC20 for IERC20;

    // ============ State Variables ============

    /// @notice Vault 地址（只有 Vault 能调用关键函数）
    address public immutable vault;

    /// @notice 底层资产
    IERC20 public immutable asset;

    /// @notice Strategy 中投资的总资产
    uint256 public investedAssets;

    /// @notice Strategy 是否激活
    bool public isActive;

    // ============ Events ============
    event Invested(uint256 amount);
    event Harvested(uint256 profit, uint256 loss);
    event Withdrawn(uint256 amount);
    event EmergencyWithdrawn(uint256 amount);
    event StrategyActivated();
    event StrategyDeactivated();

    // ============ Errors ============
    error OnlyVault();
    error StrategyNotActive();
    error StrategyAlreadyActive();
    error InsufficientAssets();

    // ============ Modifiers ============
    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    modifier whenActive() {
        if (!isActive) revert StrategyNotActive();
        _;
    }

    // ============ Constructor ============
    constructor(address _vault, address _asset) {
        vault = _vault;
        asset = IERC20(_asset);
        isActive = true; // 默认激活
    }

    // ============ External Functions ============

    /**
     * @notice 投资资产到策略中
     * @param amount 投资金额
     */
    function invest(uint256 amount) external virtual onlyVault whenActive {
        if (amount == 0) return;

        // 从 Vault 转入资产
        asset.safeTransferFrom(vault, address(this), amount);

        investedAssets += amount;

        // 子类实现具体的投资逻辑
        _invest(amount);

        emit Invested(amount);
    }

    /**
     * @notice 收获收益并报告给 Vault
     * @return profit 盈利金额
     * @return loss 亏损金额
     */
    function harvest() external virtual onlyVault whenActive returns (uint256 profit, uint256 loss) {
        // 子类实现具体的收获逻辑
        (profit, loss) = _harvest();

        // 更新投资金额
        if (profit > loss) {
            investedAssets += (profit - loss);
        } else {
            investedAssets -= (loss - profit);
        }

        emit Harvested(profit, loss);
    }

    /**
     * @notice 从策略中取回资产
     * @param amount 取回金额
     * @return actualAmount 实际取回的金额
     */
    function withdraw(uint256 amount) external virtual onlyVault returns (uint256 actualAmount) {
        if (amount == 0) return 0;
        if (amount > investedAssets) revert InsufficientAssets();

        // 子类实现具体的取回逻辑
        actualAmount = _withdraw(amount);

        investedAssets -= actualAmount;

        // 转回给 Vault
        asset.safeTransfer(vault, actualAmount);

        emit Withdrawn(actualAmount);
    }

    /**
     * @notice 紧急提取所有资产
     * @return amount 提取的金额
     */
    function emergencyWithdraw() external virtual onlyVault returns (uint256 amount) {
        amount = _emergencyWithdraw();

        investedAssets = 0;
        isActive = false;

        // 转回给 Vault
        if (amount > 0) {
            asset.safeTransfer(vault, amount);
        }

        emit EmergencyWithdrawn(amount);
    }

    /**
     * @notice 激活策略
     */
    function activate() external onlyVault {
        if (isActive) revert StrategyAlreadyActive();
        isActive = true;
        emit StrategyActivated();
    }

    /**
     * @notice 停用策略
     */
    function deactivate() external onlyVault {
        if (!isActive) revert StrategyNotActive();
        isActive = false;
        emit StrategyDeactivated();
    }

    // ============ View Functions ============

    /**
     * @notice 获取策略当前总资产（包括未实现收益）
     * @return 总资产价值
     */
    function totalAssets() external view virtual returns (uint256) {
        return _totalAssets();
    }

    /**
     * @notice 估算当前的盈亏
     * @return profit 估算盈利
     * @return loss 估算亏损
     */
    function estimatedProfit() external view virtual returns (uint256 profit, uint256 loss) {
        return _estimatedProfit();
    }

    // ============ Internal Functions (子类实现) ============

    /**
     * @dev 具体的投资逻辑（子类实现）
     */
    function _invest(uint256 amount) internal virtual;

    /**
     * @dev 具体的收获逻辑（子类实现）
     */
    function _harvest() internal virtual returns (uint256 profit, uint256 loss);

    /**
     * @dev 具体的取回逻辑（子类实现）
     */
    function _withdraw(uint256 amount) internal virtual returns (uint256 actualAmount);

    /**
     * @dev 具体的紧急提取逻辑（子类实现）
     */
    function _emergencyWithdraw() internal virtual returns (uint256 amount);

    /**
     * @dev 计算总资产（子类实现）
     */
    function _totalAssets() internal view virtual returns (uint256);

    /**
     * @dev 估算盈亏（子类实现）
     */
    function _estimatedProfit() internal view virtual returns (uint256 profit, uint256 loss);
}
