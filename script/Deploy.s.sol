// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";
import {MinimalVault} from "../src/core/MinimalVault.sol";
import {VaultToken} from "../src/core/VaultToken.sol";
import {MockStrategy} from "../src/strategies/MockStrategy.sol";
import {FeeManager} from "../src/fees/FeeManager.sol";
import {VaultAccessControl} from "../src/access/VaultAccessControl.sol";

// 我们需要一个 Mock ERC20，检查是否存在
// 如果不存在，我们在脚本中创建一个简单的
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

/**
 * @title Deploy Script
 * @notice 完整的部署脚本，用于部署模块化 Vault 系统到任何网络
 * @dev 使用方法:
 *      本地 Anvil: forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
 *      Sepolia: forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
 */
contract Deploy is Script {
    // 部署的合约实例
    MinimalVault public vault;
    VaultToken public vaultToken;
    MockERC20 public asset;
    MockStrategy public strategy;
    FeeManager public feeManager;
    VaultAccessControl public accessControl;

    // 配置参数
    uint256 constant INITIAL_MINT = 1_000_000 * 1e18; // 给部署者 100 万测试代币
    uint256 constant PERFORMANCE_FEE = 1000; // 10% (1000 basis points)
    uint256 constant WITHDRAWAL_FEE = 100;   // 1% (100 basis points)

    function run() external {
        // 获取部署者私钥（从环境变量或使用默认的 Anvil 账户）
        uint256 deployerPrivateKey = getDeployerPrivateKey();
        address deployer = vm.addr(deployerPrivateKey);

        console.log("===========================================");
        console.log("Deploying Modular Yield Vault System");
        console.log("===========================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 Mock 资产代币（测试网/本地用）
        console.log("1. Deploying Mock Asset (USDC)...");
        asset = new MockERC20("Mock USDC", "USDC", 18);
        console.log("   Mock Asset deployed at:", address(asset));

        // 2. 部署 VaultAccessControl
        console.log("");
        console.log("2. Deploying VaultAccessControl...");
        // VaultAccessControl 需要 3 个参数: strategist, guardian, keeper
        accessControl = new VaultAccessControl(
            deployer,  // strategist (策略管理者)
            deployer,  // guardian (紧急守护者)
            deployer   // keeper (自动化管理者)
        );
        console.log("   VaultAccessControl deployed at:", address(accessControl));

        // 3. 部署 FeeManager
        console.log("");
        console.log("3. Deploying FeeManager...");
        // FeeManager 需要 3 个参数: feeRecipient, performanceFeeBps, withdrawalFeeBps
        feeManager = new FeeManager(
            deployer,         // fee recipient (费用接收地址)
            PERFORMANCE_FEE,  // performance fee (10% = 1000 bps)
            100               // withdrawal fee (1% = 100 bps)
        );
        console.log("   FeeManager deployed at:", address(feeManager));
        console.log("   Performance Fee: %s bps (%s%%)", PERFORMANCE_FEE, PERFORMANCE_FEE / 100);
        console.log("   Withdrawal Fee: 100 bps (1%)");

        // 4. 部署 Vault Token
        console.log("");
        console.log("4. Deploying Vault Token...");
        vaultToken = new VaultToken("Vault Token", "VLT");
        console.log("   Vault Token deployed at:", address(vaultToken));

        // 5. 部署 MinimalVault
        console.log("");
        console.log("5. Deploying MinimalVault...");
        // MinimalVault 构造函数参数: (asset, shares, investRatioBps)
        vault = new MinimalVault(
            address(asset),
            address(vaultToken),
            9500 // 初始投资比例 95% (满足 MinimalVault 的 MAX_INVEST_RATIO)
        );
        console.log("   MinimalVault deployed at:", address(vault));

        // 6. 设置 Vault Token 的 vault 地址
        console.log("");
        console.log("6. Setting up Vault Token permissions...");
        vaultToken.setVault(address(vault));
        console.log("   Vault Token vault set to:", address(vault));

        // 7. 配置 VaultAccessControl
        console.log("");
        console.log("7. Configuring VaultAccessControl...");
        // VaultAccessControl 使用 Ownable 和角色系统
        // 默认 deployer 已经是 owner、strategist、guardian、keeper
        // 如果需要，可以启用公开存款
        console.log("   Owner:", deployer);
        console.log("   Strategist:", deployer);
        console.log("   Guardian:", deployer);
        console.log("   Keeper:", deployer);
        console.log("   Public Deposits: enabled");

        // 8. 部署 MockStrategy
        console.log("");
        console.log("8. Deploying MockStrategy...");
        // MockStrategy 构造: (vault, asset, apyBps)
        strategy = new MockStrategy(address(vault), address(asset), 1000); // 10% APY
        console.log("   MockStrategy deployed at:", address(strategy));

        // 9. 将策略添加到 Vault
        console.log("");
        console.log("9. Adding strategy to Vault...");
        // MinimalVault 提供 setStrategy 接口
        vault.setStrategy(address(strategy));
        console.log("   Strategy set on Vault:", address(strategy));

        // 10. 给部署者 mint 一些测试代币（仅测试网/本地）
        if (block.chainid == 31337 || block.chainid == 11155111) {
            console.log("");
            console.log("10. Minting test tokens to deployer...");
            asset.mint(deployer, INITIAL_MINT);
            console.log("   Minted %s tokens to deployer", INITIAL_MINT / 1e18);
        }

        vm.stopBroadcast();

        // 打印部署摘要
        printDeploymentSummary(deployer);
    }

    /**
     * @notice 获取部署者私钥
     * @dev 优先使用环境变量，否则使用 Anvil 默认账户
     */
    function getDeployerPrivateKey() internal view returns (uint256) {
        // 尝试从环境变量读取
        try vm.envUint("PRIVATE_KEY") returns (uint256 privateKey) {
            return privateKey;
        } catch {
            // 使用 Anvil 第一个默认账户的私钥
            console.log("No PRIVATE_KEY found, using Anvil default account");
            return 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }
    }

    /**
     * @notice 打印部署摘要
     */
    function printDeploymentSummary(address deployer) internal view {
        console.log("");
        console.log("===========================================");
        console.log("Deployment Summary");
        console.log("===========================================");
        console.log("Network: Chain ID", block.chainid);
        console.log("Deployer:", deployer);
        console.log("");
        console.log("Contracts:");
        console.log("  Mock Asset (USDC):", address(asset));
        console.log("  Vault Token:", address(vaultToken));
        console.log("  MinimalVault:", address(vault));
        console.log("  MockStrategy:", address(strategy));
        console.log("  FeeManager:", address(feeManager));
        console.log("  AccessControl:", address(accessControl));
        console.log("");
        console.log("Configuration:");
        console.log("  Fee Recipient:", deployer);
        console.log("  Performance Fee:", PERFORMANCE_FEE, "bps");
        console.log("  Withdrawal Fee:", WITHDRAWAL_FEE, "bps");
        console.log("  Strategy Allocation: 100%");
        console.log("  Roles (All set to deployer):");
        console.log("    - Owner");
        console.log("    - Strategist");
        console.log("    - Guardian");
        console.log("    - Keeper");
        if (block.chainid == 31337 || block.chainid == 11155111) {
            console.log("  Initial Mint: %s tokens", INITIAL_MINT / 1e18);
        }
        console.log("");
        console.log("Next Steps:");
        console.log("1. Update frontend .env with these addresses:");
        console.log("   VITE_VAULT_ADDRESS=%s", address(vault));
        console.log("   VITE_VAULT_TOKEN_ADDRESS=%s", address(vaultToken));
        console.log("   VITE_ASSET_ADDRESS=%s", address(asset));
        console.log("");
        console.log("2. Start Anvil (if not running):");
        console.log("   anvil");
        console.log("");
        console.log("3. (Optional) Run MockData script to create test scenarios:");
        console.log("   forge script script/MockData.s.sol --rpc-url http://localhost:8545 --broadcast");
        console.log("===========================================");
    }
}
