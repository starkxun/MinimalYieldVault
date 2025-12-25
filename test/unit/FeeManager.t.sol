// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/fees/FeeManager.sol";

/**
 * @title FeeManagerTest
 * @notice 模块4 单元测试：FeeManager
 */
contract FeeManagerTest is Test {
    FeeManager public feeManager;

    address public owner = address(1);
    address public feeRecipient = address(2);
    address public user = address(3);

    uint256 constant PERFORMANCE_FEE = 2000; // 20%
    uint256 constant WITHDRAWAL_FEE = 100; // 1%

    function setUp() public {
        vm.prank(owner);
        feeManager = new FeeManager(feeRecipient, PERFORMANCE_FEE, WITHDRAWAL_FEE);
    }

    // ============ Constructor Tests ============

    function test_constructor() public view {
        assertEq(feeManager.owner(), owner);
        assertEq(feeManager.feeRecipient(), feeRecipient);
        assertEq(feeManager.performanceFeeBps(), PERFORMANCE_FEE);
        assertEq(feeManager.withdrawalFeeBps(), WITHDRAWAL_FEE);
        assertTrue(feeManager.performanceFeeEnabled());
        assertTrue(feeManager.withdrawalFeeEnabled());
    }

    function test_constructor_RevertIf_ZeroRecipient() public {
        vm.prank(owner);
        vm.expectRevert(FeeManager.ZeroAddress.selector);
        new FeeManager(address(0), PERFORMANCE_FEE, WITHDRAWAL_FEE);
    }

    function test_constructor_RevertIf_PerformanceFeeTooHigh() public {
        vm.prank(owner);
        vm.expectRevert(FeeManager.FeeTooHigh.selector);
        new FeeManager(feeRecipient, 6000, WITHDRAWAL_FEE); // > 50%
    }

    function test_constructor_RevertIf_WithdrawalFeeTooHigh() public {
        vm.prank(owner);
        vm.expectRevert(FeeManager.FeeTooHigh.selector);
        new FeeManager(feeRecipient, PERFORMANCE_FEE, 600); // > 5%
    }

    // ============ Performance Fee Tests ============

    function test_calculatePerformanceFee() public view {
        uint256 profit = 1000e18;
        uint256 fee = feeManager.calculatePerformanceFee(profit);

        // 20% of 1000 = 200
        assertEq(fee, 200e18);
    }

    function test_calculatePerformanceFee_WhenDisabled() public {
        vm.prank(owner);
        feeManager.togglePerformanceFee(false);

        uint256 fee = feeManager.calculatePerformanceFee(1000e18);
        assertEq(fee, 0);
    }

    function test_calculatePerformanceFee_ZeroProfit() public view {
        uint256 fee = feeManager.calculatePerformanceFee(0);
        assertEq(fee, 0);
    }

    function test_setPerformanceFee() public {
        uint256 newFee = 1000; // 10%

        vm.prank(owner);
        feeManager.setPerformanceFee(newFee);

        assertEq(feeManager.performanceFeeBps(), newFee);
    }

    function test_setPerformanceFee_RevertIf_TooHigh() public {
        vm.prank(owner);
        vm.expectRevert(FeeManager.FeeTooHigh.selector);
        feeManager.setPerformanceFee(6000);
    }

    function test_recordPerformanceFee() public {
        uint256 feeAmount = 200e18;
        uint256 profit = 1000e18;

        vm.prank(owner);
        feeManager.recordPerformanceFee(feeAmount, profit);

        assertEq(feeManager.totalPerformanceFeesCollected(), feeAmount);
    }

    function test_recordPerformanceFee_RevertIf_FeeExceedsProfit() public {
        vm.prank(owner);
        vm.expectRevert(FeeManager.InvalidFeeAmount.selector);
        feeManager.recordPerformanceFee(1100e18, 1000e18);
    }

    // ============ Withdrawal Fee Tests ============

    function test_calculateWithdrawalFee() public view {
        uint256 amount = 1000e18;
        uint256 fee = feeManager.calculateWithdrawalFee(amount);

        // 1% of 1000 = 10
        assertEq(fee, 10e18);
    }

    function test_calculateWithdrawalFee_WhenDisabled() public {
        vm.prank(owner);
        feeManager.toggleWithdrawalFee(false);

        uint256 fee = feeManager.calculateWithdrawalFee(1000e18);
        assertEq(fee, 0);
    }

    function test_setWithdrawalFee() public {
        uint256 newFee = 50; // 0.5%

        vm.prank(owner);
        feeManager.setWithdrawalFee(newFee);

        assertEq(feeManager.withdrawalFeeBps(), newFee);
    }

    function test_setWithdrawalFee_RevertIf_TooHigh() public {
        vm.prank(owner);
        vm.expectRevert(FeeManager.FeeTooHigh.selector);
        feeManager.setWithdrawalFee(600);
    }

    function test_recordWithdrawalFee() public {
        uint256 feeAmount = 10e18;
        uint256 withdrawn = 1000e18;

        vm.prank(owner);
        feeManager.recordWithdrawalFee(feeAmount, withdrawn);

        assertEq(feeManager.totalWithdrawalFeesCollected(), feeAmount);
    }

    // ============ Fee Recipient Tests ============

    function test_setFeeRecipient() public {
        address newRecipient = address(4);

        vm.prank(owner);
        feeManager.setFeeRecipient(newRecipient);

        assertEq(feeManager.feeRecipient(), newRecipient);
    }

    function test_setFeeRecipient_RevertIf_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(FeeManager.ZeroAddress.selector);
        feeManager.setFeeRecipient(address(0));
    }

    // ============ Toggle Tests ============

    function test_togglePerformanceFee() public {
        vm.prank(owner);
        feeManager.togglePerformanceFee(false);
        assertFalse(feeManager.performanceFeeEnabled());

        vm.prank(owner);
        feeManager.togglePerformanceFee(true);
        assertTrue(feeManager.performanceFeeEnabled());
    }

    function test_toggleWithdrawalFee() public {
        vm.prank(owner);
        feeManager.toggleWithdrawalFee(false);
        assertFalse(feeManager.withdrawalFeeEnabled());

        vm.prank(owner);
        feeManager.toggleWithdrawalFee(true);
        assertTrue(feeManager.withdrawalFeeEnabled());
    }

    // ============ View Functions Tests ============

    function test_getFeeConfiguration() public view {
        (uint256 perfFeeBps, uint256 withdrawFeeBps, address recipient, bool perfEnabled, bool withdrawEnabled) =
            feeManager.getFeeConfiguration();

        assertEq(perfFeeBps, PERFORMANCE_FEE);
        assertEq(withdrawFeeBps, WITHDRAWAL_FEE);
        assertEq(recipient, feeRecipient);
        assertTrue(perfEnabled);
        assertTrue(withdrawEnabled);
    }

    function test_getTotalFeesCollected() public {
        vm.startPrank(owner);
        feeManager.recordPerformanceFee(100e18, 500e18);
        feeManager.recordWithdrawalFee(10e18, 1000e18);
        vm.stopPrank();

        (uint256 performanceFees, uint256 withdrawalFees, uint256 totalFees) = feeManager.getTotalFeesCollected();

        assertEq(performanceFees, 100e18);
        assertEq(withdrawalFees, 10e18);
        assertEq(totalFees, 110e18);
    }

    // ============ Fuzz Tests ============

    function testFuzz_calculatePerformanceFee(uint256 profit) public view {
        profit = bound(profit, 0, type(uint128).max);

        uint256 fee = feeManager.calculatePerformanceFee(profit);

        // Fee 应该 <= profit * 50%
        assertLe(fee, profit / 2);
    }

    function testFuzz_calculateWithdrawalFee(uint256 amount) public view {
        amount = bound(amount, 0, type(uint128).max);

        uint256 fee = feeManager.calculateWithdrawalFee(amount);

        // Fee 应该 <= amount * 5%
        assertLe(fee, amount * 5 / 100);
    }
}
