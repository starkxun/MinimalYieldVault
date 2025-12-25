# 🏦 Minimal Yield Vault

一个安全、模块化、经过全面测试的 DeFi 收益聚合协议，使用 Solidity 构建并针对常见攻击向量进行了广泛测试。

![Solidity](https://img.shields.io/badge/Solidity-^0.8.20-blue)
![Foundry](https://img.shields.io/badge/Foundry-Testing-green)
![Tests](https://img.shields.io/badge/Tests-155+-success)
![License](https://img.shields.io/badge/License-MIT-yellow)

## 📋 目录

- [项目概述](#项目概述)
- [核心功能](#核心功能)
- [技术架构](#技术架构)
- [快速开始](#快速开始)
- [测试](#测试)
- [部署](#部署)
- [前端](#前端)
- [安全性](#安全性)
- [贡献指南](#贡献指南)
- [许可证](#许可证)

---

## 🎯 项目概述

Minimal Yield Vault 是一个生产就绪的 DeFi 协议，允许用户存入资产并通过自动化投资策略赚取优化收益。

### 为什么选择 Minimal Yield Vault？

- **🏗️ 模块化设计**: 5 个核心模块清晰分离，易于维护和升级
- **🛡️ 全面测试**: 155+ 个测试用例，包括单元测试、集成测试、模糊测试、不变量测试和攻击向量测试
- **⚡ Gas 优化**: 高效实现，最小化 gas 消耗
- **🔒 安全优先**: 全面防护常见 DeFi 攻击

---

## ✨ 核心功能

### 用户功能

- 💰 **存款与提款**: 简单直观的资产管理界面
- 📈 **收益优化**: 自动化策略执行，最大化投资回报
- 🎯 **ERC-4626 兼容**: 标准化的 Vault Token 实现
- 💸 **灵活费用**: 可配置的绩效费和提款费
- 🔐 **访问控制**: 多角色权限系统与紧急暂停机制

### 安全特性

- ✅ **防重入攻击**: 所有关键函数都有重入保护
- ✅ **防捐赠攻击**: 首存保护机制
- ✅ **防通胀攻击**: Share 价格操纵防护
- ✅ **防三明治攻击**: 滑点保护和最小存款限制
- ✅ **紧急暂停**: Guardian 可快速响应异常情况

---

## 🏗️ 技术架构

### 模块化设计

```
MinimalYieldVault/
│
├── src/
│   ├── core/
│   │   ├── VaultToken.sol           # 模块 1: ERC20 份额代币
│   │   └── MinimalVault.sol         # 模块 2: Vault 核心逻辑
│   │
│   ├── strategies/
│   │   ├── MockStrategy.sol         # 模块 3: 策略模拟
│   │   └── BaseStrategy.sol         # 策略基类
│   │
│   ├── fees/
│   │   └── FeeManager.sol           # 模块 4: 费用管理
│   │
│   └── access/
│       └── VaultAccessControl.sol   # 模块 5: 权限控制
│
├── test/
│   ├── unit/                        # 单元测试
│   ├── integration/                 # 集成测试
│   ├── fuzz/                        # 模糊测试
│   ├── invariant/                   # 不变量测试
│   └── security/                    # 攻击向量测试
│
├── script/
│   ├── Deploy.s.sol                 # 部署脚本
│   └── MockData.s.sol               # 测试数据生成
│
└── frontend/                        # React 前端
```

### 核心模块说明

#### 1. VaultToken (ERC20 份额代币)
- 符合 ERC-4626 标准
- 代表用户在 Vault 中的份额
- 可转让、可交易

#### 2. MinimalVault (核心 Vault)
- 处理存款和提款逻辑
- 管理策略分配
- 计算收益和份额价格

#### 3. MockStrategy (投资策略)
- 模拟投资策略
- 可扩展为真实 DeFi 协议集成
- 支持多策略组合

#### 4. FeeManager (费用管理)
- 绩效费: 最高 50%（默认 10%）
- 提款费: 最高 5%（默认 1%）
- 可动态调整

#### 5. VaultAccessControl (权限控制)
- Owner: 最高权限
- Strategist: 管理投资策略
- Guardian: 紧急暂停权限
- Keeper: 自动化操作

---

## 🚀 快速开始

### 前置要求

- [Git](https://git-scm.com/)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (v18+)
- [pnpm](https://pnpm.io/) 或 npm

### 安装

```bash
# 1. 克隆仓库
git clone https://github.com/your-username/minimal-yield-vault.git
cd minimal-yield-vault

# 2. 安装 Solidity 依赖
forge install

# 3. 安装前端依赖
cd frontend
pnpm install
cd ..
```

### 编译

```bash
# 编译智能合约
forge build

# 查看编译输出
ls out/
```

---

## 🧪 测试

我们的测试套件包含 **155+ 个测试用例**，覆盖所有关键功能和安全场景。

### 运行所有测试

```bash
# 运行全部测试
forge test

# 显示详细输出
forge test -vvv

# 显示 gas 报告
forge test --gas-report
```

### 分类测试

```bash
# 单元测试
forge test --match-path "test/unit/**/*.sol"

# 集成测试
forge test --match-path "test/integration/**/*.sol"

# 模糊测试
forge test --match-path "test/fuzz/**/*.sol"

# 不变量测试
forge test --match-path "test/invariant/**/*.sol"

# 安全测试（攻击向量）
forge test --match-path "test/security/**/*.sol"
```

### 测试覆盖率

```bash
# 生成覆盖率报告
forge coverage

# 生成详细的 HTML 报告
forge coverage --report lcov
genhtml lcov.info -o coverage
open coverage/index.html
```

### 测试统计

| 测试类型 | 数量 | 说明 |
|---------|------|------|
| 单元测试 | 50+ | 测试单个函数和组件 |
| 集成测试 | 30+ | 测试完整流程 |
| 模糊测试 | 20+ | 随机输入测试 |
| 不变量测试 | 10+ | 核心不变量验证 |
| 安全测试 | 45+ | 攻击向量防护 |
| **总计** | **155+** | **全面覆盖** |

---

## 📦 部署

### 本地部署 (Anvil)

```bash
# 1. 启动本地节点
anvil

# 2. 部署合约（新终端）
forge script script/Deploy.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast

# 3. 查看部署地址
cat broadcast/Deploy.s.sol/31337/run-latest.json
```

### 测试网部署 (Sepolia)

```bash
# 1. 设置环境变量
export SEPOLIA_RPC_URL=<your_rpc_url>
export PRIVATE_KEY=<your_private_key>
export ETHERSCAN_API_KEY=<your_api_key>

# 2. 部署并验证
forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### 生成测试数据

```bash
# 为测试创建模拟数据
export VAULT_ADDRESS=<deployed_vault_address>
export ASSET_ADDRESS=<deployed_asset_address>
export VAULT_TOKEN_ADDRESS=<deployed_token_address>

forge script script/MockData.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast
```

---

## 🎨 前端

### 技术栈

- **React 18**: 现代化的 UI 框架
- **TypeScript**: 类型安全
- **Vite**: 极速开发体验
- **wagmi**: React Hooks for Ethereum
- **RainbowKit**: 钱包连接 UI
- **TailwindCSS**: 实用优先的 CSS 框架

### 启动前端

```bash
# 1. 进入前端目录
cd frontend

# 2. 配置环境变量
cp .env.example .env
nano .env  # 填入合约地址

# 3. 启动开发服务器
pnpm dev

# 4. 访问
open http://localhost:5173
```

### 环境变量配置

```env
# WalletConnect Project ID (从 https://cloud.walletconnect.com/ 获取)
VITE_WALLETCONNECT_PROJECT_ID=your_project_id

# 本地 Anvil 网络
VITE_VAULT_ADDRESS_HARDHAT=0x...
VITE_VAULT_TOKEN_ADDRESS_HARDHAT=0x...
VITE_ASSET_ADDRESS_HARDHAT=0x...

# Sepolia 测试网
VITE_VAULT_ADDRESS_SEPOLIA=0x...
VITE_VAULT_TOKEN_ADDRESS_SEPOLIA=0x...
VITE_ASSET_ADDRESS_SEPOLIA=0x...
```

### 前端功能

- 🔗 **钱包连接**: 支持 MetaMask、WalletConnect 等
- 📊 **数据展示**: TVL、APY、Share Price、用户持仓
- 💰 **存款**: Approve + Deposit 完整流程
- 💸 **提款**: 提取资产和收益
- 🔄 **实时更新**: 自动刷新数据
- 🎨 **响应式设计**: 支持移动端

---

## 🔒 安全性

### 已实现的安全措施

#### 1. 防重入攻击
```solidity
// 使用 OpenZeppelin 的 ReentrancyGuard
function deposit(uint256 amount) external nonReentrant {
    // 安全的存款逻辑
}
```

#### 2. 防捐赠攻击
```solidity
// 首次存款时铸造虚拟份额
if (totalSupply == 0) {
    shares = amount - MINIMUM_LIQUIDITY;
    _mint(address(0), MINIMUM_LIQUIDITY);
}
```

#### 3. 防通胀攻击
```solidity
// 最小存款金额限制
require(amount >= MINIMUM_DEPOSIT, "Amount too small");
```

#### 4. 防三明治攻击
```solidity
// 用户可设置最小接收份额
function deposit(uint256 amount, uint256 minShares) external {
    require(shares >= minShares, "Slippage too high");
}
```

### 安全审计

- ✅ 所有测试通过（155+ 测试用例）
- ✅ 无已知高危漏洞
- ⚠️ 建议在主网部署前进行专业审计

### 漏洞报告

如果发现安全问题，请通过以下方式联系：
- Email: security@yourproject.com
- 或创建私有安全 Issue

---

## 📊 Gas 优化

### Gas 消耗对比

| 操作 | Gas 消耗 | 说明 |
|------|---------|------|
| Deposit (首次) | ~150k | 包含 Approve |
| Deposit (后续) | ~80k | 已 Approve |
| Withdraw | ~90k | 标准提款 |
| 策略分配 | ~50k | 管理员操作 |

### 优化技术

- ✅ 使用 `uint256` 而非 `uint8` (节省打包成本)
- ✅ 缓存 storage 变量到 memory
- ✅ 批量操作支持
- ✅ 事件优化

---

## 🛠️ 开发

### 项目结构

```
├── src/               # 智能合约源码
├── test/              # 测试文件
├── script/            # 部署脚本
├── frontend/          # React 前端
├── foundry.toml       # Foundry 配置
└── README.md          # 本文件
```

### 添加新策略

1. 继承 `BaseStrategy`
2. 实现必需函数
3. 编写测试
4. 部署并添加到 Vault

```solidity
contract MyStrategy is BaseStrategy {
    function invest(uint256 amount) external override {
        // 实现投资逻辑
    }
    
    function withdraw(uint256 amount) external override {
        // 实现提款逻辑
    }
}
```

### 本地开发工作流

```bash
# 1. 创建新分支
git checkout -b feature/my-feature

# 2. 编写代码
# ...

# 3. 运行测试
forge test

# 4. 格式化代码
forge fmt

# 5. 提交
git add .
git commit -m "feat: add new feature"

# 6. 推送
git push origin feature/my-feature
```

---

## 🤝 贡献指南

欢迎所有形式的贡献！

### 如何贡献

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 代码规范

- 遵循 Solidity 风格指南
- 所有函数必须有 NatSpec 注释
- 新功能必须包含测试
- 测试覆盖率不得低于 95%

### 提交规范

使用 [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` 新功能
- `fix:` 修复 bug
- `docs:` 文档更新
- `test:` 测试相关
- `refactor:` 重构
- `chore:` 其他改动

---

## 🗺️ 路线图

### ✅ Phase 1: 核心功能 (已完成)
- [x] 基础 Vault 实现
- [x] 费用管理系统
- [x] 访问控制
- [x] 完整测试套件
- [x] 前端界面

### 🚧 Phase 2: 增强功能 (进行中)
- [ ] 多策略支持
- [ ] 链上治理
- [ ] 自动复投
- [ ] 更多 DeFi 协议集成

### 📋 Phase 3: 优化与扩展 (计划中)
- [ ] L2 部署 (Arbitrum, Optimism)
- [ ] 跨链支持
- [ ] NFT 奖励系统
- [ ] DAO 治理代币

### 🔮 Phase 4: 高级功能 (未来)
- [ ] 机器学习策略优化
- [ ] 自动化做市商
- [ ] 衍生品支持
- [ ] 专业审计报告

---

## 🙏 致谢

- [OpenZeppelin](https://www.openzeppelin.com/) - 安全的智能合约库
- [Foundry](https://github.com/foundry-rs/foundry) - 快速的 Solidity 开发工具
- [wagmi](https://wagmi.sh/) - React Hooks for Ethereum
- [RainbowKit](https://www.rainbowkit.com/) - 钱包连接 UI

---

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

---

<div align="center">

**如果这个项目对你有帮助，请给我一个 ⭐️**

Made with ❤️ by Starkxun

</div>
