// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/core/MinimalVault.sol";
import "../../src/core/VaultToken.sol";
import "../../src/strategies/MockStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title VaultStrategyFlowTest
 * @notice 集成测试：Vault + Strategy 完整流程
 */
contract VaultStrategyFlowTest is Test {
    MinimalVault public vault;
    VaultToken public vaultToken;
    MockStrategy public strategy;
    MockERC20 public asset;

    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);

    uint256 constant INITIAL_BALANCE = 10000e18;
    uint256 constant APY_20_PERCENT = 2000;
    uint256 constant INVEST_RATIO_80_PERCENT = 8000;

    function setUp() public {
        // 部署资产
        asset = new MockERC20();

        // 部署 vault token
        vm.prank(owner);
        vaultToken = new VaultToken("Vault Shares", "vShares");

        // 部署 vault
        vm.prank(owner);
        vault = new MinimalVault(address(asset), address(vaultToken), INVEST_RATIO_80_PERCENT);

        // 设置 vault 为 vaultToken 的 minter
        vm.prank(owner);
        vaultToken.setVault(address(vault));

        // 部署 strategy
        vm.prank(address(vault));
        strategy = new MockStrategy(address(vault), address(asset), APY_20_PERCENT);

        // 设置 strategy
        vm.prank(owner);
        vault.setStrategy(address(strategy));

        // 给用户 mint 资产
        asset.mint(user1, INITIAL_BALANCE);
        asset.mint(user2, INITIAL_BALANCE);

        // 用户授权
        vm.prank(user1);
        asset.approve(address(vault), type(uint256).max);

        vm.prank(user2);
        asset.approve(address(vault), type(uint256).max);
    }

    // ============ Helper Functions ============

    /**
     * @notice 辅助函数：模拟 Strategy 产生收益
     * @dev 在真实场景中，收益来自外部协议（如 Aave）
     *      在测试中，我们需要手动 mint token 给 Strategy
     */
    function _simulateYieldGeneration() internal {
        // 计算预期收益
        uint256 expectedProfit = strategy.pendingYield();
        
        if (expectedProfit > 0) {
            // Mint 收益 token 给 Strategy
            asset.mint(address(strategy), expectedProfit);
        }
    }

    // ============ 基础流程测试 ============

    function test_fullFlow_depositInvestHarvestRedeem() public {
        // 1. User1 存款（会自动触发投资）
        vm.prank(user1);
        uint256 shares1 = vault.deposit(1000e18);
        
        assertEq(shares1, 1000e18);
        // 存款后会自动投资 80%
        assertEq(vault.totalInvestedAssets(), 800e18);
        assertEq(vault.totalIdleAssets(), 200e18);

        // 2. 时间流逝 1 年
        vm.warp(block.timestamp + 365 days);

        // 3. 模拟收益生成（在真实场景中，这来自外部协议）
        _simulateYieldGeneration();

        // 4. 收获收益
        vm.prank(owner);
        vault.harvest();

        // Strategy 应该产生了约 160e18 的收益（800 * 20%）
        assertApproxEqRel(vault.totalInvestedAssets(), 960e18, 0.01e18);

        // 5. User1 赎回全部
        uint256 totalShares = vaultToken.balanceOf(user1);
        
        vm.prank(user1);
        uint256 assetsReturned = vault.redeem(totalShares);

        // 应该获得本金 + 收益
        assertGt(assetsReturned, 1000e18);
        assertApproxEqRel(assetsReturned, 1160e18, 0.02e18);
    }

    function test_autoInvest_onDeposit() public {
        // 首次存款会自动触发投资
        vm.prank(user1);
        vault.deposit(1000e18);

        // 检查是否自动投资了
        assertGt(vault.totalInvestedAssets(), 0);
        assertEq(vault.totalInvestedAssets(), 800e18); // 80%
    }

    function test_multipleUsers_withYield() public {
        // User1 存入 1000
        vm.prank(user1);
        vault.deposit(1000e18);

        // 时间流逝半年
        vm.warp(block.timestamp + 182 days);

        // 模拟收益生成
        _simulateYieldGeneration();

        // 收获半年的收益
        vm.prank(owner);
        vault.harvest();

        uint256 totalAssetsBeforeUser2 = vault.totalAssets();

        // User2 存入 1000
        vm.prank(user2);
        uint256 shares2 = vault.deposit(1000e18);

        // User2 应该获得更少的 shares（因为 share price 增加了）
        assertLt(shares2, 1000e18);

        // 再过半年
        vm.warp(block.timestamp + 183 days);
        
        // 再次模拟收益生成
        _simulateYieldGeneration();

        vm.prank(owner);
        vault.harvest();

        // 获取 User1 和 User2 的 shares
        uint256 user1Shares = vaultToken.balanceOf(user1);
        uint256 user2Shares = vaultToken.balanceOf(user2);

        // User1 赎回
        vm.prank(user1);
        uint256 assets1 = vault.redeem(user1Shares);

        // User2 赎回
        vm.prank(user2);
        uint256 assets2 = vault.redeem(user2Shares);

        // User1 应该获得更多收益（存的时间更长）
        assertGt(assets1, assets2);
    }

    // ============ Share Price 测试 ============

    function test_sharePrice_increasesWithYield() public {
        vm.prank(user1);
        vault.deposit(1000e18);

        uint256 priceBefore = vault.sharePrice();

        // 时间流逝 1 年
        vm.warp(block.timestamp + 365 days);

        // 模拟收益生成
        _simulateYieldGeneration();

        // 收获收益
        vm.prank(owner);
        vault.harvest();

        uint256 priceAfter = vault.sharePrice();

        // Share price 应该增加了
        assertGt(priceAfter, priceBefore);
        
        // 大约增加了 16%（80% 投资 * 20% APY）
        uint256 expectedIncrease = priceBefore * 16 / 100;
        assertApproxEqRel(priceAfter, priceBefore + expectedIncrease, 0.02e18);
    }

    // ============ 策略切换测试 ============

    function test_switchStrategy() public {
        // 存款并投资
        vm.prank(user1);
        vault.deposit(1000e18);

        uint256 investedBefore = vault.totalInvestedAssets();
        uint256 idleBefore = vault.totalIdleAssets();

        // 部署新策略
        vm.prank(address(vault));
        MockStrategy newStrategy = new MockStrategy(address(vault), address(asset), 3000); // 30% APY

        // 切换策略
        vm.prank(owner);
        vault.setStrategy(address(newStrategy));

        // 资金应该从旧策略取回，变为闲置
        assertEq(vault.totalInvestedAssets(), 0);
        assertEq(vault.totalIdleAssets(), investedBefore + idleBefore);

        // 重新投资到新策略
        vm.prank(owner);
        vault.invest();

        assertGt(vault.totalInvestedAssets(), 0);
    }

    // ============ 大额赎回测试 ============

    function test_largeRedeem_withdrawsFromStrategy() public {
        // User1 存 1000
        vm.prank(user1);
        vault.deposit(1000e18);

        // 大部分资金在 Strategy 中
        assertEq(vault.totalInvestedAssets(), 800e18);
        assertEq(vault.totalIdleAssets(), 200e18);

        // User1 尝试赎回 500（大于 idle）
        vm.prank(user1);
        vault.redeem(500e18);

        // 应该从 Strategy 中取回了部分资金
        assertLt(vault.totalInvestedAssets(), 800e18);
    }

    // ============ 亏损场景测试 ============

    function test_handleLoss() public {
        vm.prank(user1);
        vault.deposit(1000e18);

        // 记录初始状态
        assertEq(vault.totalIdleAssets(), 200e18);
        assertEq(vault.totalInvestedAssets(), 800e18);
        assertEq(vault.totalAssets(), 1000e18);

        // 启用亏损模拟：10% 亏损
        vm.prank(address(vault));
        strategy.toggleLossSimulation(true, 1000);

        // 时间流逝
        vm.warp(block.timestamp + 365 days);

        // 收获亏损
        vm.prank(owner);
        vault.harvest();

        // harvest 后：investedAssets 减少 80 (800 * 10%)
        // 新的 invested = 720
        assertApproxEqAbs(vault.totalInvestedAssets(), 720e18, 1e18);
        
        // totalAssets = 200 (idle) + 720 (invested) = 920
        assertApproxEqAbs(vault.totalAssets(), 920e18, 1e18);

        // User1 赎回全部
        uint256 user1Shares = vaultToken.balanceOf(user1);
        
        vm.prank(user1);
        uint256 returned = vault.redeem(user1Shares);
        
        // 应该拿回约 920 (亏损了 8%)
        assertApproxEqAbs(returned, 920e18, 1e18);
        assertLt(returned, 1000e18);
    }

    // ============ 投资比例测试 ============

    function test_investRatio_respected() public {
        // 设置投资比例为 50%
        vm.prank(owner);
        vault.setInvestRatio(5000);

        vm.prank(user1);
        vault.deposit(1000e18);

        // 应该只投资了 50%
        assertApproxEqRel(vault.totalInvestedAssets(), 500e18, 0.01e18);
        assertApproxEqRel(vault.totalIdleAssets(), 500e18, 0.01e18);
    }

    // ============ 极端场景测试 ============

    function test_smallDeposit_afterLargeYield() public {
        // 大额存款
        vm.prank(user1);
        vault.deposit(10000e18);

        // 长时间累积收益
        vm.warp(block.timestamp + 365 days * 5);
        
        // 模拟 5 年的收益生成
        _simulateYieldGeneration();

        vm.prank(owner);
        vault.harvest();

        uint256 priceBefore = vault.sharePrice();

        // 小额存款
        vm.prank(user2);
        uint256 shares = vault.deposit(1e18);

        // 小额存款应该获得很少的 shares
        assertLt(shares, 1e18);
        
        // Share price 不应该被稀释
        uint256 priceAfter = vault.sharePrice();
        assertApproxEqRel(priceAfter, priceBefore, 0.001e18);
    }

    // ============ View Functions 测试 ============

    function test_getStrategyInfo() public {
        vm.prank(user1);
        vault.deposit(1000e18);

        (
            address strategyAddress,
            bool isStrategyActive,
            uint256 investedAmount,
            uint256 strategyTotalAssets
        ) = vault.getStrategyInfo();

        assertEq(strategyAddress, address(strategy));
        assertTrue(isStrategyActive);
        assertEq(investedAmount, 800e18);
        assertGt(strategyTotalAssets, 0);
    }

    // ============ Fuzz Tests ============

    function testFuzz_depositAndRedeem_withYield(
        uint256 depositAmount,
        uint256 timeElapsed
    ) public {
        vm.assume(depositAmount >= vault.MINIMUM_SHARES() && depositAmount <= INITIAL_BALANCE / 2);
        vm.assume(timeElapsed > 0 && timeElapsed <= 365 days);

        // 存款
        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount);

        // 时间流逝
        vm.warp(block.timestamp + timeElapsed);

        // 模拟收益生成
        _simulateYieldGeneration();

        // 收获
        vm.prank(owner);
        vault.harvest();

        // 赎回
        vm.prank(user1);
        uint256 returned = vault.redeem(shares);

        // 应该获得本金 + 收益
        assertGe(returned, depositAmount);
    }
}