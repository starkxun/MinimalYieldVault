// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
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
 * @title VaultFuzzTest
 * @notice 模糊测试：随机输入测试 Vault 的健壮性
 */
contract VaultFuzzTest is Test {
    MinimalVault public vault;
    VaultToken public vaultToken;
    MockStrategy public strategy;
    MockERC20 public asset;

    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);

    uint256 constant MAX_SUPPLY = 1_000_000e18;

    function setUp() public {
        asset = new MockERC20();

        vm.prank(owner);
        vaultToken = new VaultToken("Vault Shares", "vShares");

        vm.prank(owner);
        vault = new MinimalVault(address(asset), address(vaultToken), 8000);

        vm.prank(owner);
        vaultToken.setVault(address(vault));

        vm.prank(address(vault));
        strategy = new MockStrategy(address(vault), address(asset), 1000);

        vm.prank(owner);
        vault.setStrategy(address(strategy));

        // Mint 大量资产给用户
        asset.mint(user1, MAX_SUPPLY);
        asset.mint(user2, MAX_SUPPLY);

        vm.prank(user1);
        asset.approve(address(vault), type(uint256).max);

        vm.prank(user2);
        asset.approve(address(vault), type(uint256).max);
    }

    // ============ Deposit Fuzz Tests ============

    function testFuzz_deposit_randomAmount(uint256 amount) public {
        // 限制范围：MINIMUM_SHARES 到 MAX_SUPPLY
        amount = bound(amount, vault.MINIMUM_SHARES(), MAX_SUPPLY);

        vm.prank(user1);
        uint256 shares = vault.deposit(amount);

        // 验证基本属性
        assertGe(shares, vault.MINIMUM_SHARES());
        assertEq(vaultToken.balanceOf(user1), shares);
        assertGe(vault.totalAssets(), amount);
    }

    function testFuzz_deposit_multipleUsers(
        uint256 amount1,
        uint256 amount2
    ) public {
        amount1 = bound(amount1, vault.MINIMUM_SHARES(), MAX_SUPPLY / 2);
        amount2 = bound(amount2, vault.MINIMUM_SHARES(), MAX_SUPPLY / 2);

        // User1 存款
        vm.prank(user1);
        uint256 shares1 = vault.deposit(amount1);

        // User2 存款
        vm.prank(user2);
        uint256 shares2 = vault.deposit(amount2);

        // 验证 shares 总和
        assertEq(vaultToken.totalSupply(), shares1 + shares2);
        assertGe(vault.totalAssets(), amount1 + amount2);
    }

    // ============ Redeem Fuzz Tests ============

    function testFuzz_depositAndRedeem(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, vault.MINIMUM_SHARES(), MAX_SUPPLY / 2);

        // 存款
        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount);

        // 立即赎回
        vm.prank(user1);
        uint256 assetsReturned = vault.redeem(shares);

        // 不应该亏损（没有费用时）
        assertGe(assetsReturned, depositAmount);
    }

    function testFuzz_partialRedeem(
        uint256 depositAmount,
        uint256 redeemRatio
    ) public {
        depositAmount = bound(depositAmount, vault.MINIMUM_SHARES(), MAX_SUPPLY / 2);
        redeemRatio = bound(redeemRatio, 1, 100); // 1% 到 100%

        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount);

        uint256 sharesToRedeem = (shares * redeemRatio) / 100;
        if (sharesToRedeem == 0) sharesToRedeem = 1;

        vm.prank(user1);
        uint256 returned = vault.redeem(sharesToRedeem);

        // 验证剩余 shares
        assertEq(vaultToken.balanceOf(user1), shares - sharesToRedeem);
    }

    // ============ With Yield Fuzz Tests ============

    function testFuzz_depositWithYield(
        uint256 depositAmount,
        uint256 timeElapsed
    ) public {
        depositAmount = bound(depositAmount, vault.MINIMUM_SHARES(), MAX_SUPPLY / 4);
        timeElapsed = bound(timeElapsed, 1 days, 365 days);

        // 存款
        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount);

        // 时间流逝
        vm.warp(block.timestamp + timeElapsed);

        // 模拟收益生成
        uint256 expectedProfit = strategy.pendingYield();
        if (expectedProfit > 0) {
            asset.mint(address(strategy), expectedProfit);
        }

        // 收获
        vm.prank(owner);
        vault.harvest();

        // 赎回应该获得本金 + 收益
        vm.prank(user1);
        uint256 returned = vault.redeem(shares);

        assertGe(returned, depositAmount);
    }

    // ============ Share Price Fuzz Tests ============

    function testFuzz_sharePriceNeverZero(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, vault.MINIMUM_SHARES(), MAX_SUPPLY / 2);

        uint256 priceBefore = vault.sharePrice();
        assertGt(priceBefore, 0);

        vm.prank(user1);
        vault.deposit(depositAmount);

        uint256 priceAfter = vault.sharePrice();
        assertGt(priceAfter, 0);
    }

    function testFuzz_sharePriceMonotonic(
        uint256 depositAmount,
        uint256 timeElapsed
    ) public {
        depositAmount = bound(depositAmount, vault.MINIMUM_SHARES(), MAX_SUPPLY / 4);
        timeElapsed = bound(timeElapsed, 1 days, 365 days);

        vm.prank(user1);
        vault.deposit(depositAmount);

        uint256 priceBefore = vault.sharePrice();

        vm.warp(block.timestamp + timeElapsed);

        uint256 expectedProfit = strategy.pendingYield();
        if (expectedProfit > 0) {
            asset.mint(address(strategy), expectedProfit);
        }

        vm.prank(owner);
        vault.harvest();

        uint256 priceAfter = vault.sharePrice();

        // Share price 应该增加或保持不变（不会减少）
        assertGe(priceAfter, priceBefore);
    }

    // ============ Precision Fuzz Tests ============

    function testFuzz_noDustLoss(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, vault.MINIMUM_SHARES(), MAX_SUPPLY / 2);

        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount);

        uint256 previewAmount = vault.previewRedeem(shares);

        vm.prank(user1);
        uint256 actualAmount = vault.redeem(shares);

        // 实际金额应该接近预览金额（允许 1 wei 误差）
        assertApproxEqAbs(actualAmount, previewAmount, 1);
    }

    // ============ Edge Case Fuzz Tests ============

    function testFuzz_minimumDeposit(uint256 extra) public {
        extra = bound(extra, 0, 1000e18);
        
        uint256 amount = vault.MINIMUM_SHARES() + extra;

        vm.prank(user1);
        uint256 shares = vault.deposit(amount);

        assertGe(shares, vault.MINIMUM_SHARES());
    }

    function testFuzz_largeDeposit(uint256 multiplier) public {
        multiplier = bound(multiplier, 100, 1000);
        
        uint256 amount = vault.MINIMUM_SHARES() * multiplier;
        if (amount > MAX_SUPPLY / 2) amount = MAX_SUPPLY / 2;

        vm.prank(user1);
        uint256 shares = vault.deposit(amount);

        assertGt(shares, 0);
        assertEq(vaultToken.balanceOf(user1), shares);
    }

    // ============ Investment Ratio Fuzz Tests ============

    function testFuzz_investmentRatio(uint256 amount, uint256 ratio) public {
        amount = bound(amount, vault.MINIMUM_SHARES(), MAX_SUPPLY / 4);
        ratio = bound(ratio, 1000, 9000); // 10% 到 90%

        vm.prank(owner);
        vault.setInvestRatio(ratio);

        vm.prank(user1);
        vault.deposit(amount);

        uint256 invested = vault.totalInvestedAssets();
        uint256 idle = vault.totalIdleAssets();

        // 验证投资比例大致正确（允许小误差）
        uint256 expectedInvested = (amount * ratio) / 10000;
        assertApproxEqRel(invested, expectedInvested, 0.02e18);
    }

    // ============ Multiple Operations Fuzz Tests ============

    function testFuzz_depositRedeemDepositRedeem(
        uint256 amount1,
        uint256 amount2,
        uint256 redeemRatio
    ) public {
        amount1 = bound(amount1, vault.MINIMUM_SHARES(), MAX_SUPPLY / 4);
        amount2 = bound(amount2, vault.MINIMUM_SHARES(), MAX_SUPPLY / 4);
        redeemRatio = bound(redeemRatio, 10, 90);

        // 第一次存款
        vm.prank(user1);
        uint256 shares1 = vault.deposit(amount1);

        // 部分赎回
        uint256 redeemShares = (shares1 * redeemRatio) / 100;
        vm.prank(user1);
        vault.redeem(redeemShares);

        // 第二次存款
        vm.prank(user1);
        uint256 shares2 = vault.deposit(amount2);

        // 全部赎回
        uint256 remainingShares = vaultToken.balanceOf(user1);
        vm.prank(user1);
        vault.redeem(remainingShares);

        // 最终 shares 应该为 0
        assertEq(vaultToken.balanceOf(user1), 0);
    }
}