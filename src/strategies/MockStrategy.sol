// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseStrategy.sol";

/**
 * @title MockStrategy
 * @notice 模块3: 模拟收益的 Strategy
 * @dev 通过简单的线性增长模拟 APY
 */
contract MockStrategy is BaseStrategy {
    
    // ============ State Variables ============
    
    /// @notice 年化收益率（基点，10000 = 100%）
    uint256 public apyBps;
    
    /// @notice 上次收获时间
    uint256 public lastHarvestTime;
    
    /// @notice 累计产生的收益
    uint256 public totalYieldGenerated;
    
    /// @notice 累计收获的收益
    uint256 public totalYieldHarvested;
    
    /// @notice 是否模拟亏损
    bool public shouldSimulateLoss;
    
    /// @notice 亏损比例（基点）
    uint256 public lossBps;

    // ============ Constants ============
    uint256 private constant MAX_BPS = 10000;
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    // ============ Events ============
    event APYUpdated(uint256 oldAPY, uint256 newAPY);
    event LossSimulationToggled(bool enabled, uint256 lossBps);

    // ============ Errors ============
    error InvalidAPY();
    error InvalidLossRate();

    // ============ Constructor ============
    constructor(
        address _vault,
        address _asset,
        uint256 _apyBps
    ) BaseStrategy(_vault, _asset) {
        if (_apyBps > MAX_BPS * 10) revert InvalidAPY(); // 最大 1000% APY
        apyBps = _apyBps;
        lastHarvestTime = block.timestamp;
    }

    // ============ External Functions ============

    /**
     * @notice 设置 APY
     * @param _apyBps 新的 APY（基点）
     */
    function setAPY(uint256 _apyBps) external onlyVault {
        if (_apyBps > MAX_BPS * 10) revert InvalidAPY();
        uint256 oldAPY = apyBps;
        apyBps = _apyBps;
        emit APYUpdated(oldAPY, _apyBps);
    }

    /**
     * @notice 切换亏损模拟
     * @param _shouldSimulateLoss 是否模拟亏损
     * @param _lossBps 亏损比例（基点）
     */
    function toggleLossSimulation(bool _shouldSimulateLoss, uint256 _lossBps) external onlyVault {
        if (_lossBps > MAX_BPS) revert InvalidLossRate();
        shouldSimulateLoss = _shouldSimulateLoss;
        lossBps = _lossBps;
        emit LossSimulationToggled(_shouldSimulateLoss, _lossBps);
    }

    // ============ Internal Functions ============

    /**
     * @dev 投资逻辑：只是记录，实际上资产已经在合约中
     */
    function _invest(uint256 /* amount */) internal override {
        // MockStrategy 不需要额外的投资逻辑
        // 资产已经通过 BaseStrategy.invest() 转入
        lastHarvestTime = block.timestamp;
    }

    /**
     * @dev 收获逻辑：计算时间差产生的收益
     */
    function _harvest() internal override returns (uint256 profit, uint256 loss) {
        if (investedAssets == 0) {
            return (0, 0);
        }

        uint256 timeElapsed = block.timestamp - lastHarvestTime;
        
        if (shouldSimulateLoss) {
            // 模拟亏损
            loss = (investedAssets * lossBps) / MAX_BPS;
            profit = 0;
        } else {
            // 计算收益: profit = principal * APY * time / year
            profit = (investedAssets * apyBps * timeElapsed) / (MAX_BPS * SECONDS_PER_YEAR);
            loss = 0;
            
            // 记录产生的收益
            totalYieldGenerated += profit;
            
            // ⚠️ 重要：MockStrategy 需要实际"创造"这些收益
            // 在真实策略中，收益来自外部协议
            // 在 Mock 中，我们需要从某处获得这些 token
            // 这里我们不实际转账，只是更新账面数字
        }
        
        totalYieldHarvested += profit;
        lastHarvestTime = block.timestamp;
    }

    /**
     * @dev 取回逻辑：从策略中取回指定数量的资产
     */
    function _withdraw(uint256 amount) internal override returns (uint256 actualAmount) {
        // 在 MockStrategy 中，资产就在合约里，直接返回
        actualAmount = amount;
        
        // 实际策略可能需要从第三方协议中取回资产
        // 这里简化处理
    }

    /**
     * @dev 紧急提取：取回所有资产
     */
    function _emergencyWithdraw() internal override returns (uint256 amount) {
        amount = asset.balanceOf(address(this));
    }

    /**
     * @dev 计算总资产：已投资 + 未收获的收益
     */
    function _totalAssets() internal view override returns (uint256) {
        if (investedAssets == 0) {
            return 0;
        }

        if (shouldSimulateLoss) {
            // 亏损模式：直接返回 investedAssets
            // 因为亏损已经在 harvest 时从 investedAssets 中扣除了
            return investedAssets;
        }

        uint256 timeElapsed = block.timestamp - lastHarvestTime;
        uint256 pendingProfit = (investedAssets * apyBps * timeElapsed) / (MAX_BPS * SECONDS_PER_YEAR);
        
        return investedAssets + pendingProfit;
    }

    /**
     * @dev 估算当前盈亏
     */
    function _estimatedProfit() internal view override returns (uint256 profit, uint256 loss) {
        if (investedAssets == 0) {
            return (0, 0);
        }

        if (shouldSimulateLoss) {
            loss = (investedAssets * lossBps) / MAX_BPS;
            profit = 0;
        } else {
            uint256 timeElapsed = block.timestamp - lastHarvestTime;
            profit = (investedAssets * apyBps * timeElapsed) / (MAX_BPS * SECONDS_PER_YEAR);
            loss = 0;
        }
    }

    // ============ View Functions ============

    /**
     * @notice 获取当前未收获的收益
     */
    function pendingYield() external view returns (uint256) {
        if (investedAssets == 0 || shouldSimulateLoss) {
            return 0;
        }
        
        uint256 timeElapsed = block.timestamp - lastHarvestTime;
        return (investedAssets * apyBps * timeElapsed) / (MAX_BPS * SECONDS_PER_YEAR);
    }

    /**
     * @notice 获取预期年化收益
     */
    function expectedYearlyYield() external view returns (uint256) {
        if (investedAssets == 0) {
            return 0;
        }
        return (investedAssets * apyBps) / MAX_BPS;
    }

    /**
     * @notice 获取当前有效 APY
     */
    function currentAPY() external view returns (uint256) {
        return apyBps;
    }
}