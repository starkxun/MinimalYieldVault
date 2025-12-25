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
 * @title DonationAttackTest
 * @notice 测试 Donation Attack（捐赠攻击）
 * @dev 攻击者尝试通过直接转账资产到 Vault 来操纵 share price
 */
contract DonationAttackTest is Test {
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

        // 给攻击者和受害者分配资产
        asset.mint(attacker, ATTACKER_BALANCE);
        asset.mint(victim, VICTIM_BALANCE);

        vm.prank(attacker);
        asset.approve(address(vault), type(uint256).max);

        vm.prank(victim);
        asset.approve(address(vault), type(uint256).max);
    }

    /**
     * @notice 测试：攻击者无法通过直接转账操纵 share price
     * @dev 经典的 Donation Attack 流程
     */
    function test_donationAttack_cannotManipulateSharePrice() public {
        console.log("=== Donation Attack Test ===");

        // 1. 攻击者首次小额存款
        vm.prank(attacker);
        uint256 attackerShares = vault.deposit(1e18);
        console.log("Attacker deposits 1e18, gets shares:", attackerShares);
        console.log("Share price after attacker deposit:", vault.sharePrice());

        // 2. 攻击者尝试直接转账大量资产到 Vault
        uint256 donationAmount = 100_000e18;
        vm.prank(attacker);
        asset.transfer(address(vault), donationAmount);
        console.log("Attacker donates:", donationAmount);

        // 3. 检查 share price 是否被操纵
        uint256 sharePriceAfterDonation = vault.sharePrice();
        console.log("Share price after donation:", sharePriceAfterDonation);

        // ✅ 关键验证：捐赠不应该影响 share price
        // 因为 totalAssets() 是基于 Vault 的会计系统，而不是简单的 balanceOf
        assertEq(sharePriceAfterDonation, 1e18, "Share price should remain 1:1 despite donation");

        // 4. 受害者存款
        vm.prank(victim);
        uint256 victimShares = vault.deposit(10_000e18);
        console.log("Victim deposits 10000e18, gets shares:", victimShares);

        // ✅ 验证：受害者应该获得公平的 shares（1:1）
        assertEq(victimShares, 10_000e18, "Victim should get fair shares despite attacker's donation");

        // 5. 攻击者尝试赎回
        vm.prank(attacker);
        uint256 attackerReturned = vault.redeem(attackerShares);
        console.log("Attacker redeems, gets:", attackerReturned);

        // ✅ 验证：攻击者无法通过捐赠获利
        // 攻击者花费：1e18 (deposit) + 100_000e18 (donation) = 100_001e18
        // 攻击者获得：约 1e18
        // 攻击损失：约 100_000e18
        assertLt(attackerReturned, 2e18, "Attacker should not profit from donation attack");

        console.log("Attack cost:", 1e18 + donationAmount);
        console.log("Attack gain:", attackerReturned);
        console.log("Net loss:", (1e18 + donationAmount) - attackerReturned);
    }

    /**
     * @notice 测试：捐赠的资产会进入 idle，但不影响 share price
     */
    function test_donationAttack_assetsGoToIdle() public {
        // 首次存款
        vm.prank(attacker);
        vault.deposit(1000e18);

        uint256 idleBefore = vault.totalIdleAssets();
        uint256 vaultBalanceBefore = asset.balanceOf(address(vault));

        // 攻击者捐赠
        uint256 donationAmount = 10_000e18;
        vm.prank(attacker);
        asset.transfer(address(vault), donationAmount);

        uint256 idleAfter = vault.totalIdleAssets();
        uint256 vaultBalanceAfter = asset.balanceOf(address(vault));

        // ✅ Vault 余额增加了
        assertEq(
            vaultBalanceAfter, vaultBalanceBefore + donationAmount, "Vault balance should increase by donation amount"
        );

        // ✅ 但 totalIdleAssets 没有增加（因为没有通过 deposit）
        assertEq(idleAfter, idleBefore, "totalIdleAssets should NOT increase from donation");

        // ✅ totalAssets 也没有增加
        uint256 totalAssets = vault.totalAssets();
        assertLt(totalAssets, vaultBalanceAfter, "totalAssets should be less than actual vault balance");
    }

    /**
     * @notice 测试：即使有捐赠，用户的 deposit/redeem 仍然公平
     */
    function test_donationAttack_fairDepositRedeem() public {
        // 攻击者先存款
        vm.prank(attacker);
        vault.deposit(1000e18);

        // 攻击者捐赠大量资产
        vm.prank(attacker);
        asset.transfer(address(vault), 100_000e18);

        // 受害者存款
        uint256 victimDeposit = 5000e18;
        vm.prank(victim);
        uint256 victimShares = vault.deposit(victimDeposit);

        // 受害者立即赎回
        vm.prank(victim);
        uint256 victimReturned = vault.redeem(victimShares);

        // ✅ 验证：受害者没有损失（允许精度误差）
        assertApproxEqRel(
            victimReturned, victimDeposit, 0.001e18, "Victim should get back their deposit despite donation"
        );
    }

    /**
     * @notice Fuzz 测试：不同捐赠金额都无法操纵
     */
    function testFuzz_donationAttack_cannotProfit(uint256 donationAmount) public {
        donationAmount = bound(donationAmount, 1e18, ATTACKER_BALANCE / 2);

        // 攻击者存款
        vm.prank(attacker);
        uint256 shares = vault.deposit(1e18);

        // 攻击者捐赠
        vm.prank(attacker);
        asset.transfer(address(vault), donationAmount);

        // 攻击者赎回
        vm.prank(attacker);
        uint256 returned = vault.redeem(shares);

        // ✅ 攻击者总是亏损的
        uint256 totalCost = 1e18 + donationAmount;
        assertLt(returned, totalCost, "Attacker should always lose money");
    }

    /**
     * @notice 测试：为什么攻击失败？验证防御机制
     */
    function test_donationAttack_whyItFails() public {
        console.log("=== Why Donation Attack Fails ===");

        // 1. 攻击者存款
        vm.prank(attacker);
        vault.deposit(1000e18);

        console.log("After attacker deposit:");
        console.log("  totalAssets:", vault.totalAssets());
        console.log("  totalIdleAssets:", vault.totalIdleAssets());
        console.log("  totalInvestedAssets:", vault.totalInvestedAssets());
        console.log("  vault balance:", asset.balanceOf(address(vault)));

        // 2. 攻击者捐赠
        vm.prank(attacker);
        asset.transfer(address(vault), 50_000e18);

        console.log("\nAfter donation:");
        console.log("  totalAssets:", vault.totalAssets());
        console.log("  totalIdleAssets:", vault.totalIdleAssets());
        console.log("  totalInvestedAssets:", vault.totalInvestedAssets());
        console.log("  vault balance:", asset.balanceOf(address(vault)));

        // ✅ 关键发现：
        // totalAssets 不是基于 balanceOf，而是基于内部会计
        // 所以捐赠的资产不会被计入 totalAssets

        uint256 totalAssets = vault.totalAssets();
        uint256 vaultBalance = asset.balanceOf(address(vault));

        assertTrue(totalAssets < vaultBalance, "totalAssets should be less than vault balance after donation");

        console.log("\nDefense: totalAssets ignores donated funds!");
    }
}
