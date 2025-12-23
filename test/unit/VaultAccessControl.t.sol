// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/access/VaultAccessControl.sol";

/**
 * @title VaultAccessControlTest
 * @notice 模块5 单元测试：VaultAccessControl
 */
contract VaultAccessControlTest is Test {
    VaultAccessControl public accessControl;
    
    address public owner = address(1);
    address public strategist = address(2);
    address public guardian = address(3);
    address public keeper = address(4);
    address public user = address(5);

    function setUp() public {
        vm.prank(owner);
        accessControl = new VaultAccessControl(strategist, guardian, keeper);
    }

    // ============ Constructor Tests ============

    function test_constructor() public view {
        assertEq(accessControl.owner(), owner);
        assertEq(accessControl.strategist(), strategist);
        assertEq(accessControl.guardian(), guardian);
        assertEq(accessControl.keeper(), keeper);
        assertTrue(accessControl.publicDepositsEnabled());
        assertFalse(accessControl.paused());
    }

    function test_constructor_RevertIf_ZeroStrategist() public {
        vm.prank(owner);
        vm.expectRevert(VaultAccessControl.ZeroAddress.selector);
        new VaultAccessControl(address(0), guardian, keeper);
    }

    function test_constructor_RevertIf_ZeroGuardian() public {
        vm.prank(owner);
        vm.expectRevert(VaultAccessControl.ZeroAddress.selector);
        new VaultAccessControl(strategist, address(0), keeper);
    }

    function test_constructor_RevertIf_ZeroKeeper() public {
        vm.prank(owner);
        vm.expectRevert(VaultAccessControl.ZeroAddress.selector);
        new VaultAccessControl(strategist, guardian, address(0));
    }

    // ============ Role Management Tests ============

    function test_setStrategist() public {
        address newStrategist = address(10);

        vm.prank(owner);
        accessControl.setStrategist(newStrategist);

        assertEq(accessControl.strategist(), newStrategist);
    }

    function test_setStrategist_RevertIf_NotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        accessControl.setStrategist(address(10));
    }

    function test_setGuardian() public {
        address newGuardian = address(10);

        vm.prank(owner);
        accessControl.setGuardian(newGuardian);

        assertEq(accessControl.guardian(), newGuardian);
    }

    function test_setKeeper() public {
        address newKeeper = address(10);

        vm.prank(owner);
        accessControl.setKeeper(newKeeper);

        assertEq(accessControl.keeper(), newKeeper);
    }

    // ============ Whitelist Tests ============

    function test_setWhitelist() public {
        vm.prank(owner);
        accessControl.setWhitelist(user, true);

        assertTrue(accessControl.whitelisted(user));
    }

    function test_setWhitelist_Remove() public {
        vm.prank(owner);
        accessControl.setWhitelist(user, true);

        vm.prank(owner);
        accessControl.setWhitelist(user, false);

        assertFalse(accessControl.whitelisted(user));
    }

    function test_setWhitelistBatch() public {
        address[] memory users = new address[](3);
        users[0] = address(10);
        users[1] = address(11);
        users[2] = address(12);

        vm.prank(owner);
        accessControl.setWhitelistBatch(users, true);

        for (uint256 i = 0; i < users.length; i++) {
            assertTrue(accessControl.whitelisted(users[i]));
        }
    }

    // ============ Public Deposits Tests ============

    function test_togglePublicDeposits() public {
        vm.prank(owner);
        accessControl.togglePublicDeposits(false);
        assertFalse(accessControl.publicDepositsEnabled());

        vm.prank(owner);
        accessControl.togglePublicDeposits(true);
        assertTrue(accessControl.publicDepositsEnabled());
    }

    function test_canDeposit_PublicEnabled() public view {
        assertTrue(accessControl.canDeposit(user));
    }

    function test_canDeposit_PublicDisabled_NotWhitelisted() public {
        vm.prank(owner);
        accessControl.togglePublicDeposits(false);

        assertFalse(accessControl.canDeposit(user));
    }

    function test_canDeposit_PublicDisabled_Whitelisted() public {
        vm.startPrank(owner);
        accessControl.togglePublicDeposits(false);
        accessControl.setWhitelist(user, true);
        vm.stopPrank();

        assertTrue(accessControl.canDeposit(user));
    }

    // ============ Pause Tests ============

    function test_pause_ByOwner() public {
        vm.prank(owner);
        accessControl.pause();

        assertTrue(accessControl.paused());
    }

    function test_pause_ByGuardian() public {
        vm.prank(guardian);
        accessControl.pause();

        assertTrue(accessControl.paused());
    }

    function test_pause_RevertIf_NotAuthorized() public {
        vm.prank(user);
        vm.expectRevert(VaultAccessControl.OnlyGuardianOrOwner.selector);
        accessControl.pause();
    }

    function test_unpause() public {
        vm.prank(owner);
        accessControl.pause();

        vm.prank(owner);
        accessControl.unpause();

        assertFalse(accessControl.paused());
    }

    function test_unpause_RevertIf_NotOwner() public {
        vm.prank(owner);
        accessControl.pause();

        vm.prank(guardian);
        vm.expectRevert();
        accessControl.unpause();
    }

    // ============ Emergency Shutdown Tests ============

    function test_emergencyShutdown_ByOwner() public {
        vm.prank(owner);
        accessControl.emergencyShutdown();

        assertTrue(accessControl.paused());
    }

    function test_emergencyShutdown_ByGuardian() public {
        vm.prank(guardian);
        accessControl.emergencyShutdown();

        assertTrue(accessControl.paused());
    }

    function test_emergencyShutdown_RevertIf_NotAuthorized() public {
        vm.prank(strategist);
        vm.expectRevert(VaultAccessControl.OnlyGuardianOrOwner.selector);
        accessControl.emergencyShutdown();
    }

    // ============ View Functions Tests ============

    function test_getRoles() public view {
        (
            address owner_,
            address strategist_,
            address guardian_,
            address keeper_
        ) = accessControl.getRoles();

        assertEq(owner_, owner);
        assertEq(strategist_, strategist);
        assertEq(guardian_, guardian);
        assertEq(keeper_, keeper);
    }

    function test_getAccessControlState() public view {
        (
            bool isPaused,
            bool publicDeposits,
            address strategist_,
            address guardian_,
            address keeper_
        ) = accessControl.getAccessControlState();

        assertFalse(isPaused);
        assertTrue(publicDeposits);
        assertEq(strategist_, strategist);
        assertEq(guardian_, guardian);
        assertEq(keeper_, keeper);
    }

    function test_getAccessControlState_WhenPaused() public {
        vm.prank(owner);
        accessControl.pause();

        (bool isPaused,,,,) = accessControl.getAccessControlState();
        assertTrue(isPaused);
    }

    // ============ Integration Tests ============

    function test_fullAccessControlFlow() public {
        // 1. 关闭公开存款
        vm.prank(owner);
        accessControl.togglePublicDeposits(false);

        // 2. 添加白名单
        vm.prank(owner);
        accessControl.setWhitelist(user, true);

        // 3. 验证用户可以存款
        assertTrue(accessControl.canDeposit(user));

        // 4. Guardian 暂停合约
        vm.prank(guardian);
        accessControl.pause();
        assertTrue(accessControl.paused());

        // 5. Owner 恢复合约
        vm.prank(owner);
        accessControl.unpause();
        assertFalse(accessControl.paused());
    }
}