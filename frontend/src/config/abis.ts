// A more complete ABI for `MinimalVault` (keep in sync with contracts/src/core/MinimalVault.sol)
export const VAULT_ABI = [
  // View functions
  { inputs: [], name: 'totalAssets', outputs: [{ type: 'uint256' }], stateMutability: 'view', type: 'function' },
  { inputs: [], name: 'sharePrice', outputs: [{ type: 'uint256' }], stateMutability: 'view', type: 'function' },
  { inputs: [{ name: 'assets', type: 'uint256' }], name: 'previewDeposit', outputs: [{ type: 'uint256' }], stateMutability: 'view', type: 'function' },
  { inputs: [{ name: 'shares', type: 'uint256' }], name: 'previewRedeem', outputs: [{ type: 'uint256' }], stateMutability: 'view', type: 'function' },
  { inputs: [{ name: 'user', type: 'address' }], name: 'balanceOfAssets', outputs: [{ type: 'uint256' }], stateMutability: 'view', type: 'function' },
  { inputs: [], name: 'initialized', outputs: [{ type: 'bool' }], stateMutability: 'view', type: 'function' },
  { inputs: [], name: 'investRatioBps', outputs: [{ type: 'uint256' }], stateMutability: 'view', type: 'function' },
  {
    inputs: [],
    name: 'getStrategyInfo',
    outputs: [
      { name: 'strategyAddress', type: 'address' },
      { name: 'isStrategyActive', type: 'bool' },
      { name: 'investedAmount', type: 'uint256' },
      { name: 'strategyTotalAssets', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },

  // State-changing functions
  { inputs: [{ name: 'assets', type: 'uint256' }], name: 'deposit', outputs: [{ type: 'uint256' }], stateMutability: 'nonpayable', type: 'function' },
  { inputs: [{ name: 'shares', type: 'uint256' }], name: 'redeem', outputs: [{ type: 'uint256' }], stateMutability: 'nonpayable', type: 'function' },
  { inputs: [], name: 'invest', outputs: [], stateMutability: 'nonpayable', type: 'function' },
  { inputs: [], name: 'harvest', outputs: [], stateMutability: 'nonpayable', type: 'function' },
  { inputs: [{ name: '_strategy', type: 'address' }], name: 'setStrategy', outputs: [], stateMutability: 'nonpayable', type: 'function' },
  { inputs: [{ name: '_investRatioBps', type: 'uint256' }], name: 'setInvestRatio', outputs: [], stateMutability: 'nonpayable', type: 'function' },

  // Events (kept minimal)
  { anonymous: false, inputs: [ { indexed: true, name: 'user', type: 'address' }, { indexed: false, name: 'assets', type: 'uint256' }, { indexed: false, name: 'shares', type: 'uint256' } ], name: 'Deposit', type: 'event' },
  { anonymous: false, inputs: [ { indexed: true, name: 'user', type: 'address' }, { indexed: false, name: 'shares', type: 'uint256' }, { indexed: false, name: 'assets', type: 'uint256' } ], name: 'Redeem', type: 'event' },
] as const;

export const ERC20_ABI = [
  {
    inputs: [{ name: 'account', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    name: 'approve',
    outputs: [{ type: 'bool' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
    ],
    name: 'allowance',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'decimals',
    outputs: [{ type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'symbol',
    outputs: [{ type: 'string' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const;