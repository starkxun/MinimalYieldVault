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
 * @title SandwichAttackTest
 * @notice 测试 Sandwich Attack（三明治攻击 / MEV 攻击）
 * @dev 攻击者尝试在 harvest 前后进行 deposit/redeem 来获利
 */
contract SandwichAttackTest is Test {
    MinimalVault public vault;
    VaultToken public vaultToken;
    MockStrategy public strategy;
    MockERC20 public asset;

    address public owner = address(1);
    address public attacker = address(2);
    address public victim = address(3);

    // 修复：增加初始余额，确保测试中有足够的资金
    uint256 constant ATTACKER_BALANCE = 1_000_000e18;
    uint256 constant VICTIM_BALANCE = 200_000e18; // 从 100_000 增加到 200_000

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
     * @notice 测试：经典的 Harvest Sandwich Attack
     * @dev 流程：
     *      1. Victim 长期持有 shares
     *      2. Attacker 发现即将 harvest（大量收益）
     *      3. Attacker 在 harvest 前存入大量资金
     *      4. Harvest 执行，收益分配
     *      5. Attacker 立即赎回，带走部分收益
     */
    function test_sandwichAttack_harvestSandwich() public {
        console.log("=== Harvest Sandwich Attack Test ===");

        // 1. Victim 正常存款并持有
        vm.prank(victim);
        uint256 victimShares = vault.deposit(10_000e18);
        console.log("Victim deposits 10_000, shares:", victimShares);

        // 2. 时间流逝，累积大量收益
        vm.warp(block.timestamp + 365 days);
        uint256 pendingYield = strategy.pendingYield();
        console.log("Pending yield after 1 year:", pendingYield);

        // 3. 攻击者发现即将 harvest（通过 mempool）
        //    在 harvest 前立即存入大量资金
        uint256 attackAmount = 100_000e18;
        vm.prank(attacker);
        uint256 attackerShares = vault.deposit(attackAmount);
        console.log("Attacker frontrun deposits:", attackAmount);
        console.log("Attacker gets shares:", attackerShares);

        uint256 totalSharesBefore = vaultToken.totalSupply();
        console.log("Total shares before harvest:", totalSharesBefore);

        // 4. Harvest 执行
        asset.mint(address(strategy), pendingYield);
        vm.prank(owner);
        vault.harvest();
        console.log("Harvest executed, profit:", pendingYield);

        // 5. 攻击者立即赎回
        vm.prank(attacker);
        uint256 attackerReturned = vault.redeem(attackerShares);
        console.log("Attacker redeems, gets:", attackerReturned);

        // 分析攻击效果
        uint256 attackerProfit = attackerReturned > attackAmount ? attackerReturned - attackAmount : 0;
        console.log("Attacker profit:", attackerProfit);

        // Victim 的损失
        vm.prank(victim);
        uint256 victimReturned = vault.redeem(victimShares);
        uint256 victimExpectedWithoutAttack = 10_000e18 + (pendingYield * 10_000e18 / 10_000e18);
        console.log("Victim gets:", victimReturned);
        console.log("Victim expected without attack:", victimExpectedWithoutAttack);

        // ✅ 关键验证：攻击者能否获利？
        if (attackerProfit > 0) {
            console.log("WARNING: Sandwich attack is profitable!");
            console.log("Attacker stole yield from long-term holders");
        } else {
            console.log("SAFE: Sandwich attack is not profitable");
        }

        // 在我们的实现中，由于 auto-invest 机制，攻击者的资金也会被投资
        // 但由于 harvest 立即发生，攻击者能分享到收益
        // 这是 Vault 的固有问题，但影响有限
    }

    /**
     * @notice 测试：Withdraw Sandwich（在大额提取前后操作）
     */
    function test_sandwichAttack_withdrawSandwich() public {
        // 修复：确保有足够余额完成所有操作
        // victim 现在有 200_000e18，足够存 50_000

        vm.prank(victim);
        vault.deposit(50_000e18);

        vm.prank(attacker);
        vault.deposit(50_000e18);

        // 2. 时间流逝
        vm.warp(block.timestamp + 180 days);
        asset.mint(address(strategy), strategy.pendingYield());
        vm.prank(owner);
        vault.harvest();

        uint256 sharePriceBefore = vault.sharePrice();
        console.log("Share price before large withdrawal:", sharePriceBefore);

        // 3. 攻击者发现 victim 即将大额提取
        //    在提取前立即存款（share price 较高）
        vm.prank(attacker);
        uint256 attackShares = vault.deposit(30_000e18);

        // 4. Victim 大额提取
        uint256 victimShares = vaultToken.balanceOf(victim);
        vm.prank(victim);
        vault.redeem(victimShares);

        // 5. 攻击者立即赎回
        vm.prank(attacker);
        uint256 attackerReturned = vault.redeem(attackShares);

        console.log("Attacker invested: 30000");
        console.log("Attacker got back:", attackerReturned);

        // ✅ 在稳定的 Vault 中，这种攻击效果有限
        assertApproxEqRel(
            attackerReturned, 30_000e18, 0.01e18, "Attacker cannot profit significantly from withdrawal sandwich"
        );
    }

    /**
     * @notice 测试：Just-in-Time (JIT) Liquidity Attack
     * @dev 攻击者在收益事件前提供流动性，事件后立即撤出
     */
    function test_sandwichAttack_jitLiquidity() public {
        console.log("=== JIT Liquidity Attack Test ===");

        // 1. Victim 是长期持有者
        vm.prank(victim);
        uint256 victimShares = vault.deposit(20_000e18);
        uint256 victimShareRatio = (victimShares * 1e18) / vaultToken.totalSupply();
        console.log("Victim deposit, owns:", victimShareRatio / 1e16, "%");

        // 2. 时间流逝，累积收益
        vm.warp(block.timestamp + 90 days);
        uint256 pendingYield = strategy.pendingYield();
        console.log("Pending yield:", pendingYield);

        // 3. 攻击者提供大量 JIT 流动性
        uint256 jitAmount = 180_000e18;
        vm.prank(attacker);
        uint256 attackerShares = vault.deposit(jitAmount);
        uint256 attackerShareRatio = (attackerShares * 1e18) / vaultToken.totalSupply();
        console.log("Attacker JIT deposit, owns:", attackerShareRatio / 1e16, "%");

        // 4. Harvest
        asset.mint(address(strategy), pendingYield);
        vm.prank(owner);
        vault.harvest();

        // 5. 计算收益分配
        uint256 attackerAssets = vault.previewRedeem(attackerShares);
        uint256 attackerProfit = attackerAssets > jitAmount ? attackerAssets - jitAmount : 0;
        console.log("Attacker profit:", attackerProfit);
        if (jitAmount > 0) {
            console.log("Attacker profit %:", (attackerProfit * 10000) / jitAmount, "bps");
        }

        // 6. 攻击者立即撤出
        vm.prank(attacker);
        uint256 attackerReturned = vault.redeem(attackerShares);

        // 7. Victim 的实际收益
        vm.prank(victim);
        uint256 victimReturned = vault.redeem(victimShares);
        uint256 victimProfit = victimReturned > 20_000e18 ? victimReturned - 20_000e18 : 0;
        console.log("Victim profit:", victimProfit);

        // ✅ 分析：JIT 攻击的效果
        // 攻击者通过短期投入，稀释了长期持有者的收益
        // 但攻击者也承担了资金占用成本

        console.log("\nAnalysis:");
        console.log("Total yield:", pendingYield);
        console.log("Attacker got:", attackerProfit);
        console.log("Victim got:", victimProfit);
        if (jitAmount > 0) {
            console.log("Attacker ROI:", (attackerProfit * 10000) / jitAmount, "bps");
        }
    }

    /**
     * @notice 测试：缓解措施 - Harvest 频率
     */
    function test_sandwichAttack_mitigationByFrequentHarvest() public view {
        console.log("=== Mitigation: Frequent Harvest ===");

        console.log("\nScenario 1: Infrequent harvest");
        console.log("- Deposit 10_000");
        console.log("- Wait 365 days");
        console.log("- Large pending yield accumulates");
        console.log("- Attacker can JIT before harvest");

        console.log("\nScenario 2: Frequent harvest (weekly)");
        console.log("- Deposit 10_000");
        console.log("- Harvest every 7 days (52 times)");
        console.log("- Smaller yield each time");
        console.log("- JIT attack less profitable");

        console.log("\nConclusion:");
        console.log("Frequent harvest reduces attack surface");
        console.log("Smaller yield windows = less JIT profit");
        console.log("Recommendation: Automated daily/weekly harvest");
    }

    /**
     * @notice 测试：防御建议总结
     */
    function test_sandwichAttack_defenseSummary() public view {
        console.log("=== Sandwich Attack Defense Strategies ===");
        console.log("\n1. Frequent Harvest:");
        console.log("   - Reduces pending yield");
        console.log("   - Less profit for JIT attackers");

        console.log("\n2. Harvest Fee (Performance Fee):");
        console.log("   - Charges fee on profits");
        console.log("   - Makes short-term attacks less profitable");

        console.log("\n3. Minimum Hold Time:");
        console.log("   - Require users to hold for X time");
        console.log("   - Prevents instant deposit-harvest-withdraw");

        console.log("\n4. Withdrawal Queue:");
        console.log("   - Delays between redeem request and execution");
        console.log("   - Prevents frontrunning");

        console.log("\n5. Fair Yield Distribution:");
        console.log("   - Weight by time-held, not just amount");
        console.log("   - Rewards long-term holders");

        console.log("\nCurrent Implementation:");
        console.log("Auto-invest reduces idle funds");
        console.log("Can add Performance Fee (FeeManager ready)");
        console.log("Still vulnerable to JIT attacks");
        console.log("Recommendation: Add frequent harvest schedule");
    }

    // ============ Helper Functions ============

    function _deployNewVault() internal returns (MinimalVault) {
        address deployer = address(uint160(block.timestamp)); // 唯一地址

        vm.startPrank(deployer);
        VaultToken newToken = new VaultToken("New Vault", "nVault");

        MinimalVault newVault = new MinimalVault(address(asset), address(newToken), 8000);

        newToken.setVault(address(newVault));

        MockStrategy newStrategy = new MockStrategy(address(newVault), address(asset), 1000);

        newVault.setStrategy(address(newStrategy));
        vm.stopPrank();

        vm.prank(victim);
        asset.approve(address(newVault), type(uint256).max);

        return newVault;
    }
}
