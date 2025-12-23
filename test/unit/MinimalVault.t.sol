// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/core/MinimalVault.sol";
import "../../src/core/VaultToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice 测试用的 ERC20 token（如 USDC）
 */
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title MinimalVaultTest
 * @notice 模块2 单元测试：MinimalVault
 */
contract MinimalVaultTest is Test {
    MinimalVault public vault;
    VaultToken public vaultToken;
    MockERC20 public asset;

    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);

    uint256 constant INITIAL_BALANCE = 10000e18;

    function setUp() public {
        // 部署 asset token
        asset = new MockERC20();

        // 部署 vault token
        vm.prank(owner);
        vaultToken = new VaultToken("Vault Shares", "vShares");

        // 部署 vault（由 owner 部署，以便 owner 为 vault 的 owner）
        vm.prank(owner);
        vault = new MinimalVault(address(asset), address(vaultToken), 0);

        // 设置 vault 为 vaultToken 的 minter
        vm.prank(owner);
        vaultToken.setVault(address(vault));

        // 给用户 mint 一些 asset
        asset.mint(user1, INITIAL_BALANCE);
        asset.mint(user2, INITIAL_BALANCE);

        // 用户授权 vault
        vm.prank(user1);
        asset.approve(address(vault), type(uint256).max);

        vm.prank(user2);
        asset.approve(address(vault), type(uint256).max);
    }

    // ============ Constructor Tests ============

    function test_constructor() public view {
        assertEq(address(vault.asset()), address(asset));
        assertEq(address(vault.shares()), address(vaultToken));
        assertEq(vault.totalAssets(), 0);
        assertFalse(vault.initialized());
    }

    // ============ Deposit Tests ============

    function test_deposit_firstDeposit() public {
        uint256 depositAmount = 1000e18;

        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount);

        // 首次存款：1:1 兑换
        assertEq(shares, depositAmount);
        assertEq(vaultToken.balanceOf(user1), depositAmount);
        assertEq(vault.totalAssets(), depositAmount);
        assertEq(asset.balanceOf(address(vault)), depositAmount);
        assertTrue(vault.initialized());
    }

    function test_deposit_secondDeposit_sameRatio() public {
        // User1 首次存款
        vm.prank(user1);
        vault.deposit(1000e18);

        // User2 第二次存款
        vm.prank(user2);
        uint256 shares = vault.deposit(500e18);

        // 应该按比例获得 shares
        assertEq(shares, 500e18);
        assertEq(vaultToken.balanceOf(user2), 500e18);
        assertEq(vault.totalAssets(), 1500e18);
    }

    function test_deposit_RevertIf_ZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(MinimalVault.ZeroAmount.selector);
        vault.deposit(0);
    }

    function test_deposit_RevertIf_FirstDepositTooSmall() public {
        vm.prank(user1);
        vm.expectRevert(MinimalVault.FirstDepositTooSmall.selector);
        vault.deposit(100); // 小于 MINIMUM_SHARES (1000)
    }

    // ============ Redeem Tests ============

    function test_redeem() public {
        // User1 存款
        vm.prank(user1);
        vault.deposit(1000e18);

        uint256 sharesToRedeem = 300e18;
        uint256 balanceBefore = asset.balanceOf(user1);

        // User1 赎回
        vm.prank(user1);
        uint256 assetsReturned = vault.redeem(sharesToRedeem);

        assertEq(assetsReturned, 300e18);
        assertEq(vaultToken.balanceOf(user1), 700e18);
        assertEq(vault.totalAssets(), 700e18);
        assertEq(asset.balanceOf(user1), balanceBefore + 300e18);
    }

    function test_redeem_RevertIf_ZeroAmount() public {
        vm.prank(user1);
        vault.deposit(1000e18);

        vm.prank(user1);
        vm.expectRevert(MinimalVault.ZeroAmount.selector);
        vault.redeem(0);
    }

    function test_redeem_RevertIf_InsufficientShares() public {
        vm.prank(user1);
        vault.deposit(1000e18);

        vm.prank(user1);
        vm.expectRevert();
        vault.redeem(2000e18); // 超过持有量
    }

    // ============ Preview Functions Tests ============

    function test_previewDeposit_firstDeposit() public view {
        uint256 assets = 1000e18;
        uint256 expectedShares = vault.previewDeposit(assets);
        
        assertEq(expectedShares, assets); // 1:1
    }

    function test_previewDeposit_afterDeposit() public {
        vm.prank(user1);
        vault.deposit(1000e18);

        uint256 expectedShares = vault.previewDeposit(500e18);
        assertEq(expectedShares, 500e18); // 仍然 1:1，因为没有收益
    }

    function test_previewRedeem() public {
        vm.prank(user1);
        vault.deposit(1000e18);

        uint256 expectedAssets = vault.previewRedeem(300e18);
        assertEq(expectedAssets, 300e18);
    }

    // ============ View Functions Tests ============

    function test_sharePrice_initial() public view {
        uint256 price = vault.sharePrice();
        assertEq(price, 1e18); // 初始价格 1:1
    }

    function test_sharePrice_afterDeposit() public {
        vm.prank(user1);
        vault.deposit(1000e18);

        uint256 price = vault.sharePrice();
        assertEq(price, 1e18); // 没有收益，价格仍是 1:1
    }

    function test_balanceOfAssets() public {
        vm.prank(user1);
        vault.deposit(1000e18);

        uint256 userAssets = vault.balanceOfAssets(user1);
        assertEq(userAssets, 1000e18);
    }

    // ============ Multi-User Flow Tests ============

    function test_multiUser_depositAndRedeem() public {
        // User1 存 1000
        vm.prank(user1);
        vault.deposit(1000e18);

        // User2 存 500
        vm.prank(user2);
        vault.deposit(500e18);

        assertEq(vault.totalAssets(), 1500e18);
        assertEq(vaultToken.totalSupply(), 1500e18);

        // User1 赎回 300
        vm.prank(user1);
        vault.redeem(300e18);

        assertEq(vault.totalAssets(), 1200e18);
        assertEq(vaultToken.balanceOf(user1), 700e18);
        assertEq(vaultToken.balanceOf(user2), 500e18);

        // User2 赎回全部
        vm.prank(user2);
        vault.redeem(500e18);

        assertEq(vault.totalAssets(), 700e18);
        assertEq(vaultToken.balanceOf(user2), 0);
    }

    // ============ Edge Case Tests ============

    function test_deposit_roundingDown() public {
        // User1 存 1000
        vm.prank(user1);
        vault.deposit(1000e18);
        // User2 存入 1 wei
        vm.prank(user2);
        uint256 shares = vault.deposit(1);

        // 由于向下取整，可能得到 0 或 1 shares（这里接受两种情况）
        assertTrue(shares == 0 || shares == 1);
    }

    // ============ Fuzz Tests ============

    function testFuzz_deposit(uint256 amount) public {
        vm.assume(amount >= vault.MINIMUM_SHARES() && amount <= INITIAL_BALANCE);

        vm.prank(user1);
        uint256 shares = vault.deposit(amount);

        assertEq(shares, amount); // 首次存款 1:1
        assertEq(vault.totalAssets(), amount);
    }

    function testFuzz_depositAndRedeem(uint256 depositAmount, uint256 redeemAmount) public {
        vm.assume(depositAmount >= vault.MINIMUM_SHARES() && depositAmount <= INITIAL_BALANCE);
        vm.assume(redeemAmount > 0 && redeemAmount <= depositAmount);

        // Deposit
        vm.prank(user1);
        vault.deposit(depositAmount);

        // Redeem
        vm.prank(user1);
        uint256 assetsReturned = vault.redeem(redeemAmount);

        assertEq(assetsReturned, redeemAmount);
        assertEq(vault.totalAssets(), depositAmount - redeemAmount);
    }
}