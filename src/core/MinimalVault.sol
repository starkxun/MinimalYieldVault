// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./VaultToken.sol";
import "../strategies/BaseStrategy.sol";

/**
 * @title MinimalVault (v2 - 集成 Strategy)
 * @notice 模块2: Vault 主逻辑（含 Strategy 集成）
 * @dev 实现 deposit/redeem + Strategy 投资/收获
 */
contract MinimalVault is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ============ State Variables ============
    
    /// @notice 底层资产（如 USDC）
    IERC20 public immutable asset;
    
    /// @notice Vault shares token
    VaultToken public immutable shares;
    
    /// @notice 当前活跃的 Strategy
    BaseStrategy public strategy;
    
    /// @notice Vault 中的闲置资产（未投资到 Strategy）
    uint256 public totalIdleAssets;
    
    /// @notice Strategy 中投资的资产
    uint256 public totalInvestedAssets;

    /// @notice 防止初始攻击的最小 shares
    uint256 public constant MINIMUM_SHARES = 1e3;

    /// @notice 是否已完成首次存款
    bool public initialized;
    
    /// @notice 投资比例（基点，10000 = 100%）
    uint256 public investRatioBps;
    
    /// @notice 最大投资比例
    uint256 public constant MAX_INVEST_RATIO = 9500; // 95%

    // ============ Constants ============
    uint256 private constant MAX_BPS = 10000;

    // ============ Events ============
    event Deposit(address indexed user, uint256 assets, uint256 shares);
    event Redeem(address indexed user, uint256 shares, uint256 assets);
    event StrategySet(address indexed oldStrategy, address indexed newStrategy);
    event Invested(uint256 amount);
    event Harvested(uint256 profit, uint256 loss);
    event InvestRatioUpdated(uint256 oldRatio, uint256 newRatio);

    // ============ Errors ============
    error ZeroAmount();
    error ZeroShares();
    error InsufficientAssets();
    error FirstDepositTooSmall();
    error InvalidInvestRatio();
    error InvalidStrategy();

    // ============ Constructor ============
    constructor(
        address _asset, 
        address _shares,
        uint256 _investRatioBps
    ) Ownable(msg.sender) {
        asset = IERC20(_asset);
        shares = VaultToken(_shares);
        
        if (_investRatioBps > MAX_INVEST_RATIO) revert InvalidInvestRatio();
        investRatioBps = _investRatioBps;
    }

    // ============ External Functions ============

    /**
     * @notice 存入资产，获得 shares
     * @param assets 存入的资产数量
     * @return sharesAmount 获得的 shares 数量
     */
    function deposit(uint256 assets) external nonReentrant returns (uint256 sharesAmount) {
        if (assets == 0) revert ZeroAmount();

        // 计算应该 mint 多少 shares
        sharesAmount = previewDeposit(assets);
        if (sharesAmount == 0) revert ZeroShares();

        // 首次存款保护
        if (!initialized) {
            if (sharesAmount < MINIMUM_SHARES) revert FirstDepositTooSmall();
            initialized = true;
        }

        // 转入资产
        asset.safeTransferFrom(msg.sender, address(this), assets);

        // 更新闲置资产
        totalIdleAssets += assets;

        // Mint shares
        shares.mint(msg.sender, sharesAmount);

        emit Deposit(msg.sender, assets, sharesAmount);

        // 如果有 Strategy 且闲置资金足够，自动投资
        _autoInvest();
    }

    /**
     * @notice 赎回 shares，取回资产
     * @param sharesAmount 赎回的 shares 数量
     * @return assetsAmount 取回的资产数量
     */
    function redeem(uint256 sharesAmount) external nonReentrant returns (uint256 assetsAmount) {
        if (sharesAmount == 0) revert ZeroAmount();

        // 计算能取回多少资产
        assetsAmount = previewRedeem(sharesAmount);
        if (assetsAmount == 0) revert ZeroShares();
        
        uint256 totalAvailable = totalAssets();
        if (assetsAmount > totalAvailable) revert InsufficientAssets();

        // 检查闲置资金是否足够
        if (assetsAmount > totalIdleAssets) {
            // 需要从 Strategy 取回部分资金
            uint256 needed = assetsAmount - totalIdleAssets;
            _withdrawFromStrategy(needed);
        }

        // 更新闲置资产
        totalIdleAssets -= assetsAmount;

        // Burn shares
        shares.burn(msg.sender, sharesAmount);

        // 转出资产
        asset.safeTransfer(msg.sender, assetsAmount);

        emit Redeem(msg.sender, sharesAmount, assetsAmount);
    }

    /**
     * @notice 手动投资到 Strategy
     */
    function invest() external onlyOwner nonReentrant {
        _invest();
    }

    /**
     * @notice 手动收获 Strategy 的收益
     */
    function harvest() external onlyOwner nonReentrant {
        _harvest();
    }

    /**
     * @notice 设置 Strategy
     * @param _strategy 新的 Strategy 地址
     */
    function setStrategy(address _strategy) external onlyOwner {
        if (_strategy == address(0)) revert InvalidStrategy();
        
        address oldStrategy = address(strategy);
        
        // 如果之前有 Strategy，先取回所有资金
        if (oldStrategy != address(0)) {
            uint256 withdrawn = strategy.emergencyWithdraw();
            totalInvestedAssets = 0;
            totalIdleAssets += withdrawn;
        }
        
        strategy = BaseStrategy(_strategy);
        
        emit StrategySet(oldStrategy, _strategy);
    }

    /**
     * @notice 设置投资比例
     * @param _investRatioBps 新的投资比例（基点）
     */
    function setInvestRatio(uint256 _investRatioBps) external onlyOwner {
        if (_investRatioBps > MAX_INVEST_RATIO) revert InvalidInvestRatio();
        uint256 oldRatio = investRatioBps;
        investRatioBps = _investRatioBps;
        emit InvestRatioUpdated(oldRatio, _investRatioBps);
    }

    // ============ Internal Functions ============

    /**
     * @dev 自动投资逻辑
     */
    function _autoInvest() internal {
        if (address(strategy) == address(0)) return;
        if (!strategy.isActive()) return;
        
        uint256 total = totalAssets();
        uint256 targetInvested = (total * investRatioBps) / MAX_BPS;
        
        if (targetInvested > totalInvestedAssets) {
            uint256 toInvest = targetInvested - totalInvestedAssets;
            if (toInvest > totalIdleAssets) {
                toInvest = totalIdleAssets;
            }
            
            if (toInvest > 0) {
                _investAmount(toInvest);
            }
        }
    }

    /**
     * @dev 投资指定金额到 Strategy
     */
    function _investAmount(uint256 amount) internal {
        if (amount == 0) return;
        
        // 授权 Strategy
        asset.approve(address(strategy), amount);
        
        // 调用 Strategy 的 invest
        strategy.invest(amount);
        
        // 更新状态
        totalIdleAssets -= amount;
        totalInvestedAssets += amount;
        
        emit Invested(amount);
    }

    /**
     * @dev 投资所有可用资金
     */
    function _invest() internal {
        if (address(strategy) == address(0)) return;
        if (!strategy.isActive()) return;
        
        uint256 toInvest = (totalIdleAssets * investRatioBps) / MAX_BPS;
        
        if (toInvest > 0) {
            _investAmount(toInvest);
        }
    }

    /**
     * @dev 从 Strategy 取回资金
     */
    function _withdrawFromStrategy(uint256 amount) internal {
        if (address(strategy) == address(0)) return;
        
        // 不能取回超过 Strategy 实际投资的资产
        uint256 toWithdraw = amount;
        if (toWithdraw > totalInvestedAssets) {
            toWithdraw = totalInvestedAssets;
        }
        
        if (toWithdraw == 0) return;
        
        uint256 withdrawn = strategy.withdraw(toWithdraw);
        
        totalInvestedAssets -= withdrawn;
        totalIdleAssets += withdrawn;
    }

    /**
     * @dev 收获 Strategy 收益
     */
    function _harvest() internal {
        if (address(strategy) == address(0)) return;
        if (!strategy.isActive()) return;
        
        (uint256 profit, uint256 loss) = strategy.harvest();
        
        if (profit > loss) {
            uint256 netProfit = profit - loss;
            totalInvestedAssets += netProfit;
        } else if (loss > profit) {
            uint256 netLoss = loss - profit;
            totalInvestedAssets = totalInvestedAssets > netLoss 
                ? totalInvestedAssets - netLoss 
                : 0;
        }
        
        emit Harvested(profit, loss);
    }

    // ============ View Functions ============

    /**
     * @notice 获取 Vault 的总资产
     */
    function totalAssets() public view returns (uint256) {
        uint256 strategyAssets = address(strategy) != address(0) 
            ? strategy.totalAssets() 
            : 0;
        
        return totalIdleAssets + strategyAssets;
    }

    /**
     * @notice 预览存入 assets 能获得多少 shares
     */
    function previewDeposit(uint256 assets) public view returns (uint256) {
        uint256 supply = shares.totalSupply();
        
        if (supply == 0) {
            return assets;
        }
        
        return (assets * supply) / totalAssets();
    }

    /**
     * @notice 预览赎回 shares 能获得多少 assets
     */
    function previewRedeem(uint256 sharesAmount) public view returns (uint256) {
        uint256 supply = shares.totalSupply();
        
        if (supply == 0) {
            return 0;
        }
        
        return (sharesAmount * totalAssets()) / supply;
    }

    /**
     * @notice 获取当前 share 价格
     */
    function sharePrice() external view returns (uint256) {
        uint256 supply = shares.totalSupply();
        if (supply == 0) {
            return 1e18;
        }
        return (totalAssets() * 1e18) / supply;
    }

    /**
     * @notice 获取用户的资产价值
     */
    function balanceOfAssets(address user) external view returns (uint256) {
        uint256 userShares = shares.balanceOf(user);
        return previewRedeem(userShares);
    }

    /**
     * @notice 获取 Strategy 信息
     */
    function getStrategyInfo() external view returns (
        address strategyAddress,
        bool isStrategyActive,
        uint256 investedAmount,
        uint256 strategyTotalAssets
    ) {
        strategyAddress = address(strategy);
        isStrategyActive = strategyAddress != address(0) && strategy.isActive();
        investedAmount = totalInvestedAssets;
        strategyTotalAssets = isStrategyActive ? strategy.totalAssets() : 0;
    }
}