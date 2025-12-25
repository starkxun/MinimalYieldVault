// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/core/VaultToken.sol";

/**
 * @title VaultTokenTest
 * @notice 模块1 单元测试：VaultToken
 */
contract VaultTokenTest is Test {
    VaultToken public vaultToken;

    address public owner = address(1);
    address public vault = address(2);
    address public user = address(3);

    function setUp() public {
        vm.startPrank(owner);
        vaultToken = new VaultToken("Vault Token", "vTKN");
        vm.stopPrank();
    }

    // ============ Constructor Tests ============

    function test_constructor() public view {
        assertEq(vaultToken.name(), "Vault Token");
        assertEq(vaultToken.symbol(), "vTKN");
        assertEq(vaultToken.decimals(), 18);
        assertEq(vaultToken.owner(), owner);
        assertFalse(vaultToken.vaultInitialized());
    }

    // ============ SetVault Tests ============

    function test_setVault() public {
        vm.prank(owner);
        vaultToken.setVault(vault);

        assertEq(vaultToken.vault(), vault);
        assertTrue(vaultToken.vaultInitialized());
    }

    function test_setVault_RevertIf_NotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        vaultToken.setVault(vault);
    }

    function test_setVault_RevertIf_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(VaultToken.ZeroAddress.selector);
        vaultToken.setVault(address(0));
    }

    function test_setVault_RevertIf_AlreadySet() public {
        vm.startPrank(owner);
        vaultToken.setVault(vault);

        vm.expectRevert(VaultToken.VaultAlreadySet.selector);
        vaultToken.setVault(address(4));
        vm.stopPrank();
    }

    // ============ Mint Tests ============

    function test_mint() public {
        // 先设置 vault
        vm.prank(owner);
        vaultToken.setVault(vault);

        // Vault mint 100 tokens 给 user
        vm.prank(vault);
        vaultToken.mint(user, 100e18);

        assertEq(vaultToken.balanceOf(user), 100e18);
        assertEq(vaultToken.totalSupply(), 100e18);
    }

    function test_mint_RevertIf_NotVault() public {
        vm.prank(owner);
        vaultToken.setVault(vault);

        vm.prank(user);
        vm.expectRevert(VaultToken.OnlyVault.selector);
        vaultToken.mint(user, 100e18);
    }

    function test_mint_RevertIf_VaultNotSet() public {
        vm.prank(vault);
        vm.expectRevert(VaultToken.OnlyVault.selector);
        vaultToken.mint(user, 100e18);
    }

    // ============ Burn Tests ============

    function test_burn() public {
        // 设置并 mint
        vm.prank(owner);
        vaultToken.setVault(vault);

        vm.prank(vault);
        vaultToken.mint(user, 100e18);

        // Burn 30 tokens
        vm.prank(vault);
        vaultToken.burn(user, 30e18);

        assertEq(vaultToken.balanceOf(user), 70e18);
        assertEq(vaultToken.totalSupply(), 70e18);
    }

    function test_burn_RevertIf_NotVault() public {
        vm.prank(owner);
        vaultToken.setVault(vault);

        vm.prank(vault);
        vaultToken.mint(user, 100e18);

        vm.prank(user);
        vm.expectRevert(VaultToken.OnlyVault.selector);
        vaultToken.burn(user, 30e18);
    }

    function test_burn_RevertIf_InsufficientBalance() public {
        vm.prank(owner);
        vaultToken.setVault(vault);

        vm.prank(vault);
        vaultToken.mint(user, 100e18);

        vm.prank(vault);
        vm.expectRevert();
        vaultToken.burn(user, 200e18);
    }

    // ============ Fuzz Tests ============

    function testFuzz_mint_burn(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint128).max);

        vm.prank(owner);
        vaultToken.setVault(vault);

        // Mint
        vm.prank(vault);
        vaultToken.mint(user, amount);
        assertEq(vaultToken.balanceOf(user), amount);

        // Burn
        vm.prank(vault);
        vaultToken.burn(user, amount);
        assertEq(vaultToken.balanceOf(user), 0);
    }
}
