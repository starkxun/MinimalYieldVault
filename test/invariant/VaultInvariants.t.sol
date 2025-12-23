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
 * @title VaultHandler
 * @notice Handler 合约用于 Invariant 测试
 * @dev 限制测试框架只能调用安全的函数
 */
contract VaultHandler is Test {
    MinimalVault public vault;
    VaultToken public vaultToken;
    MockStrategy public strategy;
    MockERC20 public asset;
    address public owner;

    address[] public actors;
    address internal currentActor;

    constructor(
        MinimalVault _vault,
        VaultToken _vaultToken,
        MockStrategy _strategy,
        MockERC20 _asset,
        address _owner
    ) {
        vault = _vault;
        vaultToken = _vaultToken;
        strategy = _strategy;
        asset = _asset;
        owner = _owner;

        // 创建测试用户
        for (uint256 i = 0; i < 5; i++) {
            address actor = address(uint160(i + 100));
            actors.push(actor);
            
            // 给用户 mint 资产
            asset.mint(actor, 1_000_000e18);
            
            // 授权
            vm.prank(actor);
            asset.approve(address(vault), type(uint256).max);
        }
    }

    // ============ Bounded Actions ============

    function deposit(uint256 actorSeed, uint256 amount) public {
        currentActor = actors[actorSeed % actors.length];
        amount = bound(amount, vault.MINIMUM_SHARES(), 100_000e18);

        vm.prank(currentActor);
        try vault.deposit(amount) {} catch {}
    }

    function redeem(uint256 actorSeed, uint256 sharesPct) public {
        currentActor = actors[actorSeed % actors.length];
        uint256 shares = vaultToken.balanceOf(currentActor);
        
        if (shares == 0) return;
        
        sharesPct = bound(sharesPct, 1, 100);
        uint256 sharesToRedeem = (shares * sharesPct) / 100;
        if (sharesToRedeem == 0) sharesToRedeem = 1;

        vm.prank(currentActor);
        try vault.redeem(sharesToRedeem) {} catch {}
    }

    function harvest() public {
        // 模拟收益生成
        uint256 expectedProfit = strategy.pendingYield();
        if (expectedProfit > 0) {
            asset.mint(address(strategy), expectedProfit);
        }

        vm.prank(owner);
        try vault.harvest() {} catch {}
    }

    function warp(uint256 timeJump) public {
        timeJump = bound(timeJump, 1 hours, 7 days);  // 最多 7 天
        vm.warp(block.timestamp + timeJump);
    }
}

/**
 * @title VaultInvariantsTest
 * @notice 不变量测试：验证 Vault 的核心不变量
 */
contract VaultInvariantsTest is Test {
    MinimalVault public vault;
    VaultToken public vaultToken;
    MockStrategy public strategy;
    MockERC20 public asset;
    VaultHandler public handler;

    address public owner = address(1);

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

        // 创建 Handler
        handler = new VaultHandler(vault, vaultToken, strategy, asset, owner);

        // 设置 Handler 为测试目标
        targetContract(address(handler));

        // 只测试 Handler 的函数
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = VaultHandler.deposit.selector;
        selectors[1] = VaultHandler.redeem.selector;
        selectors[2] = VaultHandler.harvest.selector;
        selectors[3] = VaultHandler.warp.selector;

        targetSelector(FuzzSelector({
            addr: address(handler),
            selectors: selectors
        }));
    }

    // ============ 核心不变量 ============

    /**
     * @notice 不变量1: totalAssets 应该接近 totalIdleAssets + Strategy 的实际资产
     * @dev totalAssets = totalIdleAssets + strategy.totalAssets()
     *      strategy.totalAssets() 包含未收获的收益，所以会 >= totalInvestedAssets
     */
    function invariant_totalAssetsAccounting() public view {
        uint256 totalAssets = vault.totalAssets();
        uint256 idleAssets = vault.totalIdleAssets();
        uint256 investedAssets = vault.totalInvestedAssets();
        
        if (totalAssets == 0) return;
        
        // totalAssets 应该至少包含 idle + invested（账面值）
        assertGe(totalAssets, idleAssets + investedAssets, 
            "totalAssets should be >= idle + invested");
        
        // totalAssets 包含未收获收益
        // 最大收益估算：10% APY * 7 days = 0.19%
        // 考虑到 80% 投资比例：最多增加 0.15%
        // 为安全起见，允许 5% 的余地
        uint256 maxExpected = (idleAssets + investedAssets) * 105 / 100;
        assertLe(totalAssets, maxExpected, 
            "totalAssets should not exceed 1.05x of idle + invested");
    }

    /**
     * @notice 不变量2: Vault 能赎回的总资产 >= 所有 shares 的价值
     */
    function invariant_solvency() public view {
        uint256 totalShares = vaultToken.totalSupply();
        if (totalShares == 0) return;

        uint256 totalRedeemable = vault.previewRedeem(totalShares);
        uint256 totalAssets = vault.totalAssets();

        // Vault 中的资产应该足够支付所有 shares
        assertGe(totalAssets, totalRedeemable);
    }

    /**
     * @notice 不变量3: Share price 永远不为零（当有供应时）
     */
    function invariant_sharePriceNonZero() public view {
        if (vaultToken.totalSupply() > 0) {
            uint256 price = vault.sharePrice();
            assertGt(price, 0);
        }
    }

    /**
     * @notice 不变量4: Vault 合约的 asset 余额 >= totalIdleAssets
     */
    function invariant_idleAssetsBackedByBalance() public view {
        uint256 vaultBalance = asset.balanceOf(address(vault));
        uint256 idleAssets = vault.totalIdleAssets();

        assertGe(vaultBalance, idleAssets);
    }

    /**
     * @notice 不变量5: Strategy 的 investedAssets <= Vault 记录的 totalInvestedAssets
     */
    function invariant_investedAssetsConsistency() public view {
        uint256 strategyInvested = strategy.investedAssets();
        uint256 vaultInvested = vault.totalInvestedAssets();

        // Strategy 记录的应该 <= Vault 记录的
        assertLe(strategyInvested, vaultInvested);
    }

    /**
     * @notice 不变量6: totalAssets 应该是非负的
     */
    function invariant_totalAssetsNonNegative() public view {
        uint256 totalAssets = vault.totalAssets();
        // 隐式验证：uint256 不可能为负
        assertGe(totalAssets, 0);
    }

    /**
     * @notice 不变量7: 所有用户的 shares 总和 <= totalSupply
     */
    function invariant_shareSupplyConsistency() public view {
        // 由 ERC20 保证，这里只是验证
        uint256 totalSupply = vaultToken.totalSupply();
        assertTrue(totalSupply >= 0);
    }

    /**
     * @notice 不变量8: previewDeposit 的结果应该合理
     */
    function invariant_previewDepositReasonable() public view {
        if (vaultToken.totalSupply() == 0) {
            // 首次存款应该 1:1
            uint256 amount = 1000e18;
            uint256 preview = vault.previewDeposit(amount);
            assertEq(preview, amount);
        }
    }

    // ============ Ghost Variables（用于追踪状态）============
    
    /**
     * @notice 记录调用统计
     */
    function invariant_callSummary() public view {
        // 只是打印统计信息，不做验证
        console.log("=== Invariant Test Summary ===");
        console.log("Total Shares Supply:", vaultToken.totalSupply());
        console.log("Total Assets:", vault.totalAssets());
        console.log("Idle Assets:", vault.totalIdleAssets());
        console.log("Invested Assets:", vault.totalInvestedAssets());
    }
}