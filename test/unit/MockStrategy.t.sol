// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/strategies/MockStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title MockStrategyTest
 * @notice 模块3 单元测试：MockStrategy
 */
contract MockStrategyTest is Test {
    MockStrategy public strategy;
    MockERC20 public asset;
    
    address public vault = address(1);
    address public user = address(2);
    
    uint256 constant INITIAL_BALANCE = 10000e18;
    uint256 constant APY_10_PERCENT = 1000; // 10% APY

    function setUp() public {
        asset = new MockERC20();
        
        // 从 vault 地址部署 strategy
        vm.prank(vault);
        strategy = new MockStrategy(vault, address(asset), APY_10_PERCENT);
        
        // 给 vault mint 一些资产
        asset.mint(vault, INITIAL_BALANCE);
    }

    // ============ Constructor Tests ============

    function test_constructor() public view {
        assertEq(strategy.vault(), vault);
        assertEq(address(strategy.asset()), address(asset));
        assertEq(strategy.apyBps(), APY_10_PERCENT);
        assertTrue(strategy.isActive());
        assertEq(strategy.investedAssets(), 0);
        assertEq(strategy.totalYieldGenerated(), 0);
    }

    // ============ Invest Tests ============

    function test_invest() public {
        uint256 investAmount = 1000e18;
        
        vm.startPrank(vault);
        asset.approve(address(strategy), investAmount);
        strategy.invest(investAmount);
        vm.stopPrank();

        assertEq(strategy.investedAssets(), investAmount);
        assertEq(asset.balanceOf(address(strategy)), investAmount);
    }

    function test_invest_RevertIf_NotVault() public {
        vm.prank(user);
        vm.expectRevert(BaseStrategy.OnlyVault.selector);
        strategy.invest(1000e18);
    }

    function test_invest_RevertIf_NotActive() public {
        vm.prank(vault);
        strategy.deactivate();

        vm.prank(vault);
        vm.expectRevert(BaseStrategy.StrategyNotActive.selector);
        strategy.invest(1000e18);
    }

    // ============ Harvest Tests ============

    function test_harvest_noYield() public {
        // 投资但不等待时间
        vm.startPrank(vault);
        asset.approve(address(strategy), 1000e18);
        strategy.invest(1000e18);
        
        (uint256 profit, uint256 loss) = strategy.harvest();
        vm.stopPrank();

        assertEq(profit, 0);
        assertEq(loss, 0);
    }

    function test_harvest_withYield() public {
        uint256 investAmount = 1000e18;
        
        // 投资
        vm.startPrank(vault);
        asset.approve(address(strategy), investAmount);
        strategy.invest(investAmount);
        
        // 时间流逝 365 天（1年）
        vm.warp(block.timestamp + 365 days);
        
        // 收获
        (uint256 profit, uint256 loss) = strategy.harvest();
        vm.stopPrank();

        // 10% APY，1年后应该有 100e18 的收益
        assertApproxEqRel(profit, 100e18, 0.01e18); // 1% 误差
        assertEq(loss, 0);
        assertEq(strategy.totalYieldHarvested(), profit);
    }

    function test_harvest_multipleHarvests() public {
        uint256 investAmount = 1000e18;
        
        vm.startPrank(vault);
        asset.approve(address(strategy), investAmount);
        strategy.invest(investAmount);
        
        // 第一次收获（半年后）
        vm.warp(block.timestamp + 182 days);
        (uint256 profit1, ) = strategy.harvest();
        
        // 第二次收获（再半年后）
        vm.warp(block.timestamp + 183 days);
        (uint256 profit2, ) = strategy.harvest();
        vm.stopPrank();

        // 两次收获的总和应该约等于 1 年的收益
        // 注意：由于第一次收获后 investedAssets 增加了，第二次收获会基于更大的本金
        // 所以总收益会略大于 100e18
        uint256 totalProfit = profit1 + profit2;
        assertGt(totalProfit, 100e18); // 应该大于简单的 100
        assertLt(totalProfit, 110e18); // 但不应该太大
    }

    function test_harvest_withLoss() public {
        uint256 investAmount = 1000e18;
        
        vm.startPrank(vault);
        asset.approve(address(strategy), investAmount);
        strategy.invest(investAmount);
        
        // 启用亏损模拟：10% 亏损
        strategy.toggleLossSimulation(true, 1000);
        
        vm.warp(block.timestamp + 365 days);
        
        (uint256 profit, uint256 loss) = strategy.harvest();
        vm.stopPrank();

        assertEq(profit, 0);
        assertEq(loss, 100e18); // 10% 的 1000e18
    }

    // ============ Withdraw Tests ============

    function test_withdraw() public {
        uint256 investAmount = 1000e18;
        
        vm.startPrank(vault);
        asset.approve(address(strategy), investAmount);
        strategy.invest(investAmount);
        
        uint256 withdrawAmount = 300e18;
        uint256 balanceBefore = asset.balanceOf(vault);
        
        uint256 withdrawn = strategy.withdraw(withdrawAmount);
        vm.stopPrank();

        assertEq(withdrawn, withdrawAmount);
        assertEq(strategy.investedAssets(), investAmount - withdrawAmount);
        assertEq(asset.balanceOf(vault), balanceBefore + withdrawAmount);
    }

    function test_withdraw_RevertIf_InsufficientAssets() public {
        vm.startPrank(vault);
        asset.approve(address(strategy), 1000e18);
        strategy.invest(1000e18);
        
        vm.expectRevert(BaseStrategy.InsufficientAssets.selector);
        strategy.withdraw(2000e18);
        vm.stopPrank();
    }

    // ============ Emergency Withdraw Tests ============

    function test_emergencyWithdraw() public {
        uint256 investAmount = 1000e18;
        
        vm.startPrank(vault);
        asset.approve(address(strategy), investAmount);
        strategy.invest(investAmount);
        
        uint256 amount = strategy.emergencyWithdraw();
        vm.stopPrank();

        assertEq(amount, investAmount);
        assertEq(strategy.investedAssets(), 0);
        assertFalse(strategy.isActive());
        assertEq(asset.balanceOf(vault), INITIAL_BALANCE);
    }

    // ============ View Functions Tests ============

    function test_totalAssets() public {
        uint256 investAmount = 1000e18;
        
        vm.startPrank(vault);
        asset.approve(address(strategy), investAmount);
        strategy.invest(investAmount);
        vm.stopPrank();

        // 立即检查
        assertEq(strategy.totalAssets(), investAmount);

        // 时间流逝
        vm.warp(block.timestamp + 365 days);
        
        // 应该包含未收获的收益
        uint256 expected = investAmount + 100e18; // 10% APY
        assertApproxEqRel(strategy.totalAssets(), expected, 0.01e18);
    }

    function test_pendingYield() public {
        uint256 investAmount = 1000e18;
        
        vm.startPrank(vault);
        asset.approve(address(strategy), investAmount);
        strategy.invest(investAmount);
        vm.stopPrank();

        // 时间流逝半年
        vm.warp(block.timestamp + 182 days);
        
        uint256 pending = strategy.pendingYield();
        
        // 半年应该有约 50e18 的收益
        assertApproxEqRel(pending, 50e18, 0.02e18);
    }

    function test_expectedYearlyYield() public {
        uint256 investAmount = 1000e18;
        
        vm.startPrank(vault);
        asset.approve(address(strategy), investAmount);
        strategy.invest(investAmount);
        vm.stopPrank();

        uint256 expected = strategy.expectedYearlyYield();
        assertEq(expected, 100e18); // 10% of 1000
    }

    // ============ APY Management Tests ============

    function test_setAPY() public {
        uint256 newAPY = 2000; // 20%
        
        vm.prank(vault);
        strategy.setAPY(newAPY);

        assertEq(strategy.apyBps(), newAPY);
    }

    function test_setAPY_RevertIf_NotVault() public {
        vm.prank(user);
        vm.expectRevert(BaseStrategy.OnlyVault.selector);
        strategy.setAPY(2000);
    }

    function test_setAPY_RevertIf_TooHigh() public {
        vm.prank(vault);
        vm.expectRevert(MockStrategy.InvalidAPY.selector);
        strategy.setAPY(100001); // > 1000%
    }

    // ============ Loss Simulation Tests ============

    function test_toggleLossSimulation() public {
        vm.prank(vault);
        strategy.toggleLossSimulation(true, 500); // 5% loss

        assertTrue(strategy.shouldSimulateLoss());
        assertEq(strategy.lossBps(), 500);
    }

    function test_toggleLossSimulation_RevertIf_InvalidRate() public {
        vm.prank(vault);
        vm.expectRevert(MockStrategy.InvalidLossRate.selector);
        strategy.toggleLossSimulation(true, 10001); // > 100%
    }

    // ============ Fuzz Tests ============

    function testFuzz_invest(uint256 amount) public {
        vm.assume(amount > 0 && amount <= INITIAL_BALANCE);

        vm.startPrank(vault);
        asset.approve(address(strategy), amount);
        strategy.invest(amount);
        vm.stopPrank();

        assertEq(strategy.investedAssets(), amount);
    }

    function testFuzz_harvest_variableTime(uint256 timeElapsed) public {
        vm.assume(timeElapsed > 0 && timeElapsed <= 365 days * 10);
        
        uint256 investAmount = 1000e18;
        
        vm.startPrank(vault);
        asset.approve(address(strategy), investAmount);
        strategy.invest(investAmount);
        
        vm.warp(block.timestamp + timeElapsed);
        
        (uint256 profit, ) = strategy.harvest();
        vm.stopPrank();

        // 收益应该随时间线性增长
        uint256 expectedProfit = (investAmount * APY_10_PERCENT * timeElapsed) / (10000 * 365 days);
        assertApproxEqRel(profit, expectedProfit, 0.01e18);
    }
}