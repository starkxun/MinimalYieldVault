// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";
import {MinimalVault} from "../src/core/MinimalVault.sol";
import {VaultToken} from "../src/core/VaultToken.sol";

// 简单的 MockERC20 接口
interface IERC20 {
    function mint(address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title MockData Script
 * @notice 创建测试数据和场景，方便前端测试
 * @dev 使用方法:
 *      forge script script/MockData.s.sol --rpc-url http://localhost:8545 --broadcast
 * 
 * 这个脚本会:
 * 1. 给多个测试账户 mint 代币
 * 2. 模拟一些用户存款
 * 3. 模拟收益产生
 * 4. 创建不同的测试场景
 */
contract MockData is Script {
    // 从环境变量或命令行读取合约地址
    address vaultAddress;
    address vaultTokenAddress;
    address assetAddress;

    MinimalVault vault;
    VaultToken vaultToken;
    IERC20 asset;

    // Anvil 默认账户（用于测试）
    address constant DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address constant USER1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant USER2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address constant USER3 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    uint256 constant DEPLOYER_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() external {
        // 读取合约地址
        loadContractAddresses();

        console.log("===========================================");
        console.log("Creating Mock Data for Testing");
        console.log("===========================================");
        console.log("Vault:", vaultAddress);
        console.log("Asset:", assetAddress);
        console.log("");

        vm.startBroadcast(DEPLOYER_KEY);

        // 场景 1: 给测试账户 mint 代币
        console.log("Scenario 1: Minting tokens to test accounts...");
        mintToTestAccounts();

        // 场景 2: 模拟多个用户存款
        console.log("");
        console.log("Scenario 2: Simulating user deposits...");
        simulateUserDeposits();

        // 场景 3: 模拟收益产生
        console.log("");
        console.log("Scenario 3: Simulating yield generation...");
        simulateYieldGeneration();

        vm.stopBroadcast();

        // 打印测试账户信息
        printTestAccountsInfo();
    }

    /**
     * @notice 读取合约地址
     */
    function loadContractAddresses() internal {
        // 尝试从环境变量读取
        try vm.envAddress("VAULT_ADDRESS") returns (address _vault) {
            vaultAddress = _vault;
        } catch {
            revert("Please set VAULT_ADDRESS environment variable or deploy first");
        }

        assetAddress = vm.envOr("ASSET_ADDRESS", address(0));
        vaultTokenAddress = vm.envOr("VAULT_TOKEN_ADDRESS", address(0));

        require(assetAddress != address(0), "ASSET_ADDRESS not set");
        require(vaultTokenAddress != address(0), "VAULT_TOKEN_ADDRESS not set");

        vault = MinimalVault(vaultAddress);
        vaultToken = VaultToken(vaultTokenAddress);
        asset = IERC20(assetAddress);
    }

    /**
     * @notice 给测试账户 mint 代币
     */
    function mintToTestAccounts() internal {
        uint256 amount = 10000 * 1e18; // 每个账户 10,000 代币

        address[] memory accounts = new address[](4);
        accounts[0] = DEPLOYER;
        accounts[1] = USER1;
        accounts[2] = USER2;
        accounts[3] = USER3;

        for (uint256 i = 0; i < accounts.length; i++) {
            asset.mint(accounts[i], amount);
            console.log("  Minted %s tokens to %s", amount / 1e18, accounts[i]);
        }
    }

    /**
     * @notice 模拟用户存款
     */
    function simulateUserDeposits() internal {
        // USER1 存 1000
        depositAs(USER1, 1000 * 1e18);
        
        // USER2 存 2500
        depositAs(USER2, 2500 * 1e18);
        
        // USER3 存 500
        depositAs(USER3, 500 * 1e18);

        console.log("  Total deposited: %s tokens", uint256(1000 + 2500 + 500));
        console.log("  Total TVL: %s", vault.totalAssets() / 1e18);
    }

    /**
     * @notice 模拟指定用户存款
     */
    function depositAs(address user, uint256 amount) internal {
        // 获取用户的私钥（仅用于测试）
        uint256 userKey = getUserPrivateKey(user);
        
        vm.stopBroadcast();
        vm.startBroadcast(userKey);

        // Approve
        asset.approve(address(vault), amount);
        
        // Deposit
        vault.deposit(amount);

        console.log("  %s deposited %s tokens", user, amount / 1e18);

        vm.stopBroadcast();
        vm.startBroadcast(DEPLOYER_KEY);
    }

    /**
     * @notice 获取测试用户的私钥
     */
    function getUserPrivateKey(address user) internal pure returns (uint256) {
        if (user == DEPLOYER) return 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if (user == USER1) return 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
        if (user == USER2) return 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
        if (user == USER3) return 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;
        revert("Unknown user");
    }

    /**
     * @notice 模拟收益产生
     * @dev 直接给 Vault 转一些代币来模拟收益
     */
    function simulateYieldGeneration() internal {
        uint256 yieldAmount = 200 * 1e18; // 200 代币收益（5% APY）
        
        asset.mint(address(vault), yieldAmount);
        
        console.log("  Generated yield: %s tokens", yieldAmount / 1e18);
        console.log("  New TVL: %s tokens", vault.totalAssets() / 1e18);
        console.log("  Share price: %s", vault.sharePrice() / 1e18);
    }

    /**
     * @notice 打印测试账户信息
     */
    function printTestAccountsInfo() internal view {
        console.log("");
        console.log("===========================================");
        console.log("Test Accounts Information");
        console.log("===========================================");
        
        printAccountInfo("Deployer", DEPLOYER);
        printAccountInfo("User 1", USER1);
        printAccountInfo("User 2", USER2);
        printAccountInfo("User 3", USER3);

        console.log("");
        console.log("Vault Statistics:");
        console.log("  Total Assets: %s", vault.totalAssets() / 1e18);
        console.log("  Share Price: %s", vault.sharePrice() / 1e18);
        console.log("  Total Supply: %s", vaultToken.totalSupply() / 1e18);
        console.log("===========================================");
        console.log("");
        console.log("Frontend Testing:");
        console.log("1. Use these accounts in MetaMask:");
        console.log("   Account #0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");
        console.log("   Account #1: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8");
        console.log("   Account #2: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC");
        console.log("");
        console.log("2. Each account has:");
        console.log("   - Asset balance for depositing");
        console.log("   - Some have existing vault positions");
        console.log("===========================================");
    }

    /**
     * @notice 打印单个账户信息
     */
    function printAccountInfo(string memory name, address account) internal view {
        uint256 assetBalance = asset.balanceOf(account);
        uint256 shareBalance = vaultToken.balanceOf(account);
        uint256 positionValue = shareBalance > 0 
            ? (shareBalance * vault.sharePrice()) / 1e18 
            : 0;

        console.log("");
        console.log("%s (%s):", name, account);
        console.log("  Asset Balance: %s", assetBalance / 1e18);
        console.log("  Share Balance: %s", shareBalance / 1e18);
        console.log("  Position Value: %s", positionValue / 1e18);
    }
}
