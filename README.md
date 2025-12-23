# MinimalYieldVault

> 一个最小但完整的 DeFi Vault 协议（带真实攻击面）

## 🎯 项目目标

基于五大核心模块构建：
1. ✅ **ERC20 Share Token** - 用户份额代币
2. ✅ **Vault 主逻辑** - 存取款核心功能
3. ⏳ **Strategy 模拟** - 收益生成
4. ⏳ **Fee 模型** - 协议费用
5. ⏳ **Access Control** - 权限与暂停

## 🚀 快速开始

### 环境要求
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Solidity ^0.8.20

### 安装与运行

```bash
# 1. 克隆项目
git clone <your-repo>
cd MinimalYieldVault

# 2. 运行安装脚本
chmod +x setup.sh
./setup.sh

# 或手动执行：
forge install
forge build
forge test
```

## 📁 项目结构

```
MinimalYieldVault/
├── src/
│   ├── core/
│   │   ├── VaultToken.sol           # 模块1: ERC20 Share Token
│   │   ├── MinimalVault.sol         # 模块2: Vault 主逻辑
│   │
│   ├── strategies/
│   │   ├── MockStrategy.sol         # 模块3: Strategy 模拟
│   │   └── BaseStrategy.sol         # Strategy 基类（可选）
│   │
│   ├── fees/
│   │   └── FeeManager.sol           # 模块4: Fee 模型
│   │
│   └── access/
│       └── AccessControl.sol        # 模块5: 权限 & Pause
│
├── test/
│   ├── unit/
│   │   ├── VaultToken.t.sol         # 模块1 单元测试
│   │   ├── MinimalVault.t.sol       # 模块2 单元测试
│   │   ├── MockStrategy.t.sol       # 模块3 单元测试
│   │   ├── FeeManager.t.sol         # 模块4 单元测试
│   │   └── VaultAccessControl.t.sol # 模块5 单元测试
│   │
│   ├── integration/
│   │   ├── VaultStrategyFlow.t.sol  # 完整流程测试
│   │
│   ├── fuzz/
│   │   └── VaultFuzz.t.sol
│   │
│   ├── invariant/
│   │   └── VaultInvariants.t.sol    # 核心不变量测试
│   │
│   ├── security/
│       ├── DonationAttack.t.sol     # 攻击测试：donation
│       ├── InflationAttack.t.sol    # 攻击测试：share inflation
│       ├── ReentrancyAttack.t.sol   # 攻击测试：reentrancy
│       └── SandwichAttack.t.sol     # 攻击测试：sandwich
│
├── script/
│   ├── Deploy.s.sol                 # 部署脚本
│   └── MockData.s.sol               # 生成 mock 数据（供前端用）
│
├── docs/
│   ├── architecture.md              # 架构文档
│   ├── security-analysis.md         # 安全分析
│   └── attack-vectors.md            # 已知攻击向量
│
├── frontend/                        # 前端可视化（后期开发）
│
├── foundry.toml
├── remappings.txt
└── README.md
```

### 📁 前端结构
```
frontend/
├── node_modules/          # ⚠️ 自动生成，不要手动修改
├── src/                   # 👈 源代码（你的代码在这里）
│   ├── components/        # React 组件
│   │   ├── Dashboard.tsx       # 主页面
│   │   ├── VaultStats.tsx      # 统计卡片
│   │   ├── UserPosition.tsx    # 用户持仓
│   │   └── DepositWithdraw.tsx # 存取款表单
│   ├── config/            # 配置文件
│   │   ├── wagmi.ts            # 🔧 Web3 配置（重要！）
│   │   └── abis.ts             # 合约接口定义
│   ├── App.tsx            # 应用入口
│   ├── main.tsx           # 程序启动点
│   ├── App.css            # 样式
│   └── index.css          # 全局样式
├── public/                # 静态资源
├── index.html             # HTML 模板
├── package.json           # 📦 依赖配置（重要！）
├── vite.config.ts         # Vite 构建配置
├── tailwind.config.js     # Tailwind CSS 配置
├── tsconfig.json          # TypeScript 配置
├── .env                   # 🔐 环境变量（需要创建！）
├── .env.example           # 环境变量示例
└── README.md              # 说明文档
```


## 🧪 测试

### 运行所有测试
```bash
forge test
```

### 详细输出
```bash
forge test -vvv
```

### 测试覆盖率
```bash
forge coverage
```

### Gas 报告
```bash
forge test --gas-report
```

### 监听模式（开发时使用）
```bash
forge test --watch
```

## 📊 当前进度

### ✅ 阶段一：最小可运行版本
- [x] VaultToken.sol - Share Token 实现
- [x] MinimalVault.sol - 基础存取款功能
- [x] 单元测试（VaultToken）
- [x] 单元测试（MinimalVault）

### ✅ 阶段二：添加 Strategy
- [x] BaseStrategy.sol - Strategy 基类
- [x] MockStrategy.sol - 模拟收益实现
- [x] MinimalVault v2 - 集成 Strategy
- [x] 单元测试（MockStrategy）
- [x] 集成测试（Vault + Strategy）

### ⏳ 阶段三：完善系统
- [x] FeeManager.sol
- [x] AccessControl.sol
- [x] Fuzzing 测试
- [x] Invariant 测试

### ⏳ 阶段四：安全测试
- [x] Donation Attack 测试
- [x] Inflation Attack 测试
- [x] Reentrancy Attack 测试
- [x] Sandwich Attack 测试

### ⏳ 阶段五：前端可视化
- [ ] React 仪表盘
- [ ] 五大模块可视化组件

## 🔑 核心功能

### VaultToken (模块1)
- 标准 ERC20 实现
- 只允许 Vault 合约 mint/burn
- 防止未授权的份额操作

### MinimalVault (模块2)
- `deposit(uint256 assets)` - 存入资产，获得 shares
- `redeem(uint256 shares)` - 赎回 shares，取回资产
- `previewDeposit(uint256)` - 预览存款能获得的 shares
- `previewRedeem(uint256)` - 预览赎回能获得的 assets
- `sharePrice()` - 当前 share 价格
- `balanceOfAssets(address)` - 用户的资产价值

### 安全特性
- ✅ 防止首次存款攻击（MINIMUM_SHARES）
- ✅ ReentrancyGuard 保护
- ✅ SafeERC20 安全转账
- ✅ 向下取整保护协议

## 📖 相关文档

- [架构设计](docs/architecture.md) - 待补充
- [安全分析](docs/security-analysis.md) - 待补充
- [攻击向量](docs/attack-vectors.md) - 待补充

## 🛠 开发命令

```bash
# 编译
forge build

# 测试
forge test

# 清理
forge clean

# 格式化代码
forge fmt

# 快照（gas 基准）
forge snapshot
```

## 📝 测试输出示例

运行 `forge test -vvv` 应该看到类似输出：

```
Running 20 tests for test/unit/VaultToken.t.sol:VaultTokenTest
[PASS] test_constructor() (gas: 12345)
[PASS] test_setVault() (gas: 23456)
[PASS] test_mint() (gas: 34567)
...

Running 15 tests for test/unit/MinimalVault.t.sol:MinimalVaultTest
[PASS] test_constructor() (gas: 12345)
[PASS] test_deposit_firstDeposit() (gas: 123456)
[PASS] test_redeem() (gas: 98765)
...

Test result: ok. 35 passed; 0 failed
```

## 🤝 贡献

这是一个学习项目，欢迎提出改进建议！

## 📄 License

MIT