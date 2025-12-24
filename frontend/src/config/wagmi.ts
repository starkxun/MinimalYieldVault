import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { sepolia, mainnet, hardhat } from 'wagmi/chains';
import type { Chain } from 'wagmi';

// 定义本地 Anvil 链（使其在钱包/网络选择中显示为 'Anvil'）
export const anvilChain: Chain = {
  id: 31337,
  name: 'Anvil',
  network: 'anvil',
  nativeCurrency: { name: 'Ethereum', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: ['http://127.0.0.1:8545'] },
    public: { http: ['http://127.0.0.1:8545'] },
  },
  blockExplorers: {
    default: { name: 'Etherscan', url: 'https://etherscan.io' },
  },
  testnet: true,
};

// 根据环境变量选择链，并按 chain.id 去重（避免 Anvil 与 Hardhat 同时显示）
const initialChains = [
  ...(import.meta.env.VITE_ENABLE_MAINNET === 'true' ? [mainnet] : []),
  sepolia,
  // 加入本地 Anvil 链和 Hardhat（两者链 id 相同，Anvil 提供可读名称）
  anvilChain,
  hardhat,
];

// 去重 helpers：保留首次出现的 chain（按 id）
const seen = new Set<number>();
const chains: typeof initialChains = initialChains.filter((c) => {
  if (seen.has(c.id)) return false;
  seen.add(c.id);
  return true;
});

export const config = getDefaultConfig({
  appName: 'Yield Vault',
  projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || 'YOUR_PROJECT_ID',
  chains,
  ssr: false,
});

// 合约地址配置
export const CONTRACT_ADDRESSES = {
  [sepolia.id]: {
    // 优先使用环境变量（VITE_*），未设置时回退到项目中当前示例地址
    vault: import.meta.env.VITE_VAULT_ADDRESS_SEPOLIA || '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9',
    vaultToken: import.meta.env.VITE_VAULT_TOKEN_ADDRESS_SEPOLIA || '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9',
    asset: import.meta.env.VITE_ASSET_ADDRESS_SEPOLIA || '0x5FbDB2315678afecb367f032d93F642f64180aa3',
  },
  [hardhat.id]: {
    // 本地默认地址（与 Foundry / Anvil 部署一致）
    vault: '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9',
    vaultToken: '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9',
    asset: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
  },
  // anvilChain 与 hardhat 使用相同链 id (31337)，我们也为 anvilChain 映射地址
  [anvilChain.id]: {
    vault: '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9',
    vaultToken: '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9',
    asset: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
  },
} as const;

// 获取当前链的合约地址
export function getContractAddresses(chainId: number) {
  return CONTRACT_ADDRESSES[chainId as keyof typeof CONTRACT_ADDRESSES] || CONTRACT_ADDRESSES[sepolia.id];
}