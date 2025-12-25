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
 * @title InflationAttackTest
 * @notice 测试 Inflation Attack（通胀攻击 / 首次存款攻击）
 * @dev 攻击者尝试通过首次小额存款 + 捐赠来操纵 share price
 */
contract InflationAttackTest is Test {
    MinimalVault public vault;
    VaultToken public vaultToken;
    MockStrategy public strategy;
    MockERC20 public asset;

    address public owner = address(1);
    address public attacker = address(2);
    address public victim = address(3);

    uint256 constant ATTACKER_BALANCE = 1_000_000e18;
    uint256 constant VICTIM_BALANCE = 10_000e18;

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

        asset.mint(attacker, ATTACKER_BALANCE);
        asset.mint(victim, VICTIM_BALANCE);

        vm.prank(attacker);
        asset.approve(address(vault), type(uint256).max);

        vm.prank(victim);
        asset.approve(address(vault), type(uint256).max);
    }

    /**
     * @notice 测试：经典的 Inflation Attack 被 MINIMUM_SHARES 阻止
     */
    function test_inflationAttack_blockedByMinimumShares() public {
        console.log("=== Inflation Attack Test ===");
        console.log("MINIMUM_SHARES:", vault.MINIMUM_SHARES());

        // ❌ 攻击步骤 1：尝试用极小金额首次存款
        vm.prank(attacker);
        vm.expectRevert(MinimalVault.FirstDepositTooSmall.selector);
        vault.deposit(1); // 只存 1 wei

        console.log("Attack FAILED: Cannot deposit less than MINIMUM_SHARES");

        // ✅ 必须存入至少 MINIMUM_SHARES
        uint256 minShares = vault.MINIMUM_SHARES();
        vm.prank(attacker);
        uint256 attackerShares = vault.deposit(minShares);

        console.log("Attacker forced to deposit:", vault.MINIMUM_SHARES());
        console.log("Attacker got shares:", attackerShares);

        // 攻击步骤 2：捐赠大量资产（transfer 不需要额外的 approve）
        uint256 donationAmount = 100_000e18;
        vm.prank(attacker);
        asset.transfer(address(vault), donationAmount);
        console.log("Attacker donates:", donationAmount);

        // 攻击步骤 3：受害者存款
        vm.prank(victim);
        uint256 victimShares = vault.deposit(10_000e18);
        console.log("Victim deposits 10000e18, gets shares:", victimShares);

        // ✅ 验证：受害者获得了合理的 shares（不是 0）
        assertGt(victimShares, 0, "Victim should get non-zero shares");

        // 由于捐赠不影响 totalAssets，受害者应该获得接近 1:1 的 shares
        assertGt(victimShares, 9_000e18, "Victim should get fair shares");
    }

    /**
     * @notice 测试：即使首次存款是 MINIMUM_SHARES，攻击仍然失败
     */
    function test_inflationAttack_stillFailsWithMinimumDeposit() public {
        // 攻击者存入 MINIMUM_SHARES
        uint256 minShares2 = vault.MINIMUM_SHARES();
        vm.prank(attacker);
        uint256 attackerShares = vault.deposit(minShares2);

        // 攻击者捐赠（transfer 不需要额外的 approve）
        uint256 donationAmount = 50_000e18;
        vm.prank(attacker);
        asset.transfer(address(vault), donationAmount);

        // 计算攻击成本
        uint256 attackCost = vault.MINIMUM_SHARES() + donationAmount;

        // 受害者存款
        vm.prank(victim);
        uint256 victimDeposit = 5_000e18;
        uint256 victimShares = vault.deposit(victimDeposit);

        // 攻击者赎回
        vm.prank(attacker);
        uint256 attackerReturned = vault.redeem(attackerShares);

        console.log("Attack cost:", attackCost);
        console.log("Attack gain:", attackerReturned);
        console.log("Net loss:", attackCost - attackerReturned);

        // ✅ 验证：攻击者亏损
        assertLt(attackerReturned, attackCost, "Attacker loses money");

        // ✅ 验证：受害者没有损失
        vm.prank(victim);
        uint256 victimReturned = vault.redeem(victimShares);
        assertApproxEqRel(victimReturned, victimDeposit, 0.01e18, "Victim gets back their deposit");
    }

    /**
     * @notice 测试：MINIMUM_SHARES 的作用机制
     */
    function test_inflationAttack_minimumSharesMechanism() public {
        console.log("=== MINIMUM_SHARES Defense Mechanism ===");

        uint256 minShares = vault.MINIMUM_SHARES();
        console.log("MINIMUM_SHARES:", minShares);

        // 尝试不同的首次存款金额
        uint256[] memory testAmounts = new uint256[](5);
        testAmounts[0] = 1; // 1 wei
        testAmounts[1] = minShares / 2; // 一半
        testAmounts[2] = minShares - 1; // 刚好差 1
        testAmounts[3] = minShares; // 恰好等于
        testAmounts[4] = minShares * 2; // 2 倍

        for (uint256 i = 0; i < testAmounts.length; i++) {
            // 每次循环创建新的部署者地址
            address deployer = address(uint160(1000 + i));

            // 以 deployer 身份创建所有合约
            vm.startPrank(deployer);

            VaultToken newVaultToken = new VaultToken("Test", "TEST");

            MinimalVault newVault = new MinimalVault(address(asset), address(newVaultToken), 8000);

            // 现在设置 vault
            newVaultToken.setVault(address(newVault));

            MockStrategy newStrategy = new MockStrategy(address(newVault), address(asset), 1000);

            newVault.setStrategy(address(newStrategy));
            vm.stopPrank();

            // 攻击者授权新 vault
            vm.prank(attacker);
            asset.approve(address(newVault), type(uint256).max);

            uint256 testAmount = testAmounts[i];

            vm.prank(attacker);
            if (testAmount < minShares) {
                // 应该 revert
                vm.expectRevert(MinimalVault.FirstDepositTooSmall.selector);
                newVault.deposit(testAmount);
                console.log("Amount", testAmount, "- REJECTED");
            } else {
                // 应该成功
                uint256 shares = newVault.deposit(testAmount);
                console.log("Amount", testAmount, "- ACCEPTED, shares:", shares);
            }
        }
    }

    /**
     * @notice Fuzz 测试：各种首次存款金额
     */
    function testFuzz_inflationAttack_variousFirstDeposits(uint256 firstDeposit, uint256 donationAmount) public {
        firstDeposit = bound(firstDeposit, vault.MINIMUM_SHARES(), ATTACKER_BALANCE / 4);
        donationAmount = bound(donationAmount, 1e18, ATTACKER_BALANCE / 4);

        // 攻击者首次存款
        vm.prank(attacker);
        uint256 attackerShares = vault.deposit(firstDeposit);

        // 攻击者捐赠
        vm.prank(attacker);
        asset.transfer(address(vault), donationAmount);

        // 受害者存款
        vm.prank(victim);
        uint256 victimShares = vault.deposit(5_000e18);

        // ✅ 受害者总是能获得 shares
        assertGt(victimShares, 0, "Victim always gets shares");

        // 攻击者赎回
        vm.prank(attacker);
        uint256 attackerReturned = vault.redeem(attackerShares);

        // ✅ 攻击者总是亏损
        uint256 totalCost = firstDeposit + donationAmount;
        assertLt(attackerReturned, totalCost, "Attacker always loses");
    }

    /**
     * @notice 测试：对比有无 MINIMUM_SHARES 的区别
     */
    function test_inflationAttack_comparisonWithoutProtection() public {
        console.log("=== Comparison: With vs Without MINIMUM_SHARES ===");

        // 场景：没有 MINIMUM_SHARES 保护时的情况
        console.log("\nWithout MINIMUM_SHARES protection:");
        console.log("1. Attacker deposits 1 wei, gets 1 share");
        console.log("2. Attacker donates 100_000e18");
        console.log("3. Share price = 100_000e18 / 1 share = 100_000e18 per share");
        console.log("4. Victim deposits 10_000e18");
        console.log("   Victim gets: 10_000 / 100_000 = 0.1 shares -> rounds to 0!");
        console.log("5. Victim gets NOTHING, loses all funds!");

        console.log("\nWith MINIMUM_SHARES protection:");
        console.log("1. Attacker MUST deposit >= 1000 (MINIMUM_SHARES)");
        console.log("2. Even with donation, share price manipulation is limited");
        console.log("3. Victim always gets non-zero shares");
        console.log("4. Attack is economically unprofitable");

        // 实际验证 - 使用 attacker 身份
        vm.startPrank(attacker);
        uint256 shares = vault.deposit(vault.MINIMUM_SHARES());

        asset.transfer(address(vault), 100_000e18);
        vm.stopPrank();

        vm.prank(victim);
        uint256 victimShares = vault.deposit(10_000e18);

        console.log("\nActual result:");
        console.log("Victim shares:", victimShares);

        assertGt(victimShares, 0, "Protection works: victim gets shares");
    }
}
