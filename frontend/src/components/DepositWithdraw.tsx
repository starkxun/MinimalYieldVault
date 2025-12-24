import { useState } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt, useChainId } from 'wagmi';
import { parseUnits, formatUnits } from 'viem';
import { VAULT_ABI, ERC20_ABI } from '../config/abis';
import { getContractAddresses } from '../config/wagmi';
import { ArrowDownCircle, ArrowUpCircle, Loader2, CheckCircle2, AlertCircle } from 'lucide-react';

type Tab = 'deposit' | 'withdraw';

export default function DepositWithdraw() {
  const [activeTab, setActiveTab] = useState<Tab>('deposit');
  const [amount, setAmount] = useState('');
  const [isApproving, setIsApproving] = useState(false);

  const { address } = useAccount();
  const chainId = useChainId();
  const addresses = getContractAddresses(chainId);

  // 检查合约地址是否为占位符或未设置
  const isPlaceholderAddress = (addr?: string) => {
    if (!addr) return true;
    const a = addr.toLowerCase();
    return a === '0x...' || a === '0x0' || /^0x0+$/.test(a);
  };
  // Read contracts
  const { data: assetBalance } = useReadContract({
    address: addresses.asset as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  const { data: shareBalance } = useReadContract({
    address: addresses.vaultToken as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  const { data: allowance } = useReadContract({
    address: addresses.asset as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: address ? [address, addresses.vault] : undefined,
  });

  const { data: previewShares } = useReadContract({
    address: addresses.vault as `0x${string}`,
    abi: VAULT_ABI,
    functionName: 'previewDeposit',
    args: amount ? [parseUnits(amount, 18)] : undefined,
  });

  const { data: previewAssets } = useReadContract({
    address: addresses.vault as `0x${string}`,
    abi: VAULT_ABI,
    functionName: 'previewRedeem',
    args: amount ? [parseUnits(amount, 18)] : undefined,
  });

  // Write contracts
  const { writeContract: approve, data: approveHash } = useWriteContract();
  const { writeContract: deposit, data: depositHash } = useWriteContract();
  const { writeContract: withdraw, data: withdrawHash } = useWriteContract();

  // Wait for transactions
  const { isLoading: isApproveLoading, isSuccess: isApproveSuccess } = useWaitForTransactionReceipt({
    hash: approveHash,
  });

  const { isLoading: isDepositLoading, isSuccess: isDepositSuccess } = useWaitForTransactionReceipt({
    hash: depositHash,
  });

  const { isLoading: isWithdrawLoading, isSuccess: isWithdrawSuccess } = useWaitForTransactionReceipt({
    hash: withdrawHash,
  });

  // Handlers
  const handleApprove = async () => {
    if (!amount) return;
    setIsApproving(true);
    try {
      approve({
        address: addresses.asset as `0x${string}`,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [addresses.vault, parseUnits(amount, 18)],
      });
    } finally {
      setIsApproving(false);
    }
  };

  const handleDeposit = () => {
    if (!amount) return;
    deposit({
      address: addresses.vault as `0x${string}`,
      abi: VAULT_ABI,
      functionName: 'deposit',
      args: [parseUnits(amount, 18)],
    });
  };

  const handleWithdraw = () => {
    if (!amount) return;
    withdraw({
      address: addresses.vault as `0x${string}`,
      abi: VAULT_ABI,
      functionName: 'redeem',
      args: [parseUnits(amount, 18)],
    });
  };

  const needsApproval = activeTab === 'deposit' && allowance && amount
    ? parseUnits(amount, 18) > allowance
    : false;

  const maxBalance = activeTab === 'deposit'
    ? assetBalance ? formatUnits(assetBalance, 18) : '0'
    : shareBalance ? formatUnits(shareBalance, 18) : '0';

  return (
    <div className="rounded-xl border border-white/10 bg-white/5 backdrop-blur-sm p-6">
      {/* Tab Switcher */}
      <div className="flex space-x-2 mb-6 bg-black/20 p-1 rounded-lg">
        <button
          onClick={() => setActiveTab('deposit')}
          className={`flex-1 flex items-center justify-center space-x-2 py-3 px-4 rounded-lg font-medium transition-all ${
            activeTab === 'deposit'
              ? 'bg-purple-500 text-white'
              : 'text-gray-400 hover:text-white'
          }`}
        >
          <ArrowDownCircle className="h-5 w-5" />
          <span>Deposit</span>
        </button>
        <button
          onClick={() => setActiveTab('withdraw')}
          className={`flex-1 flex items-center justify-center space-x-2 py-3 px-4 rounded-lg font-medium transition-all ${
            activeTab === 'withdraw'
              ? 'bg-purple-500 text-white'
              : 'text-gray-400 hover:text-white'
          }`}
        >
          <ArrowUpCircle className="h-5 w-5" />
          <span>Withdraw</span>
        </button>
      </div>

      {/* 配置警告：当合约地址为占位符时显示 */}
      {(isPlaceholderAddress(addresses.vault) || isPlaceholderAddress(addresses.vaultToken) || isPlaceholderAddress(addresses.asset)) && (
        <div className="mb-4 flex items-start space-x-2 text-sm text-yellow-400 bg-yellow-500/10 border border-yellow-500/20 rounded-lg p-3">
          <AlertCircle className="h-4 w-4 text-yellow-400 mt-0.5 flex-shrink-0" />
          <p>
            合约地址未正确配置。请在 `frontend/.env` 中设置 `VITE_VAULT_ADDRESS_SEPOLIA`、
            `VITE_VAULT_TOKEN_ADDRESS_SEPOLIA` 和 `VITE_ASSET_ADDRESS_SEPOLIA`，然后重启前端，或切换到本地网络进行测试。
          </p>
        </div>
      )}

      {/* Input Section */}
      <div className="space-y-4">
        <div>
          <div className="flex items-center justify-between mb-2">
            <label className="text-sm text-gray-400">
              {activeTab === 'deposit' ? 'Deposit Amount' : 'Withdraw Shares'}
            </label>
            <button
              onClick={() => setAmount(maxBalance)}
              className="text-sm text-purple-400 hover:text-purple-300"
            >
              Max: {Number(maxBalance).toFixed(4)}
            </button>
          </div>
          <div className="relative">
            <input
              type="number"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.00"
              className="w-full bg-black/20 border border-white/10 rounded-lg px-4 py-4 text-white text-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
            />
            <div className="absolute right-4 top-1/2 -translate-y-1/2">
              <span className="text-gray-400 text-sm">
                {activeTab === 'deposit' ? 'USDC' : 'vUSDC'}
              </span>
            </div>
          </div>
        </div>

        {/* Preview */}
        {amount && (
          <div className="rounded-lg bg-white/5 p-4 space-y-2">
            <div className="flex items-center justify-between text-sm">
              <span className="text-gray-400">You will receive</span>
              <span className="text-white font-medium">
                {activeTab === 'deposit'
                  ? `${previewShares ? formatUnits(previewShares, 18) : '0'} vUSDC`
                  : `${previewAssets ? formatUnits(previewAssets, 18) : '0'} USDC`}
              </span>
            </div>
            <div className="flex items-center justify-between text-sm">
              <span className="text-gray-400">Exchange Rate</span>
              <span className="text-white font-medium">1 vUSDC = 1.0234 USDC</span>
            </div>
          </div>
        )}

        {/* Action Buttons */}
        <div className="space-y-3">
          {needsApproval && (
            <button
              onClick={handleApprove}
              disabled={isApproveLoading || isApproving}
              className="w-full bg-yellow-500 hover:bg-yellow-600 disabled:bg-gray-600 disabled:cursor-not-allowed text-white font-medium py-4 px-6 rounded-lg transition-colors flex items-center justify-center space-x-2"
            >
              {isApproveLoading || isApproving ? (
                <>
                  <Loader2 className="h-5 w-5 animate-spin" />
                  <span>Approving...</span>
                </>
              ) : isApproveSuccess ? (
                <>
                  <CheckCircle2 className="h-5 w-5" />
                  <span>Approved!</span>
                </>
              ) : (
                <span>Approve USDC</span>
              )}
            </button>
          )}

          <button
            onClick={activeTab === 'deposit' ? handleDeposit : handleWithdraw}
            disabled={!amount || needsApproval || isDepositLoading || isWithdrawLoading}
            className="w-full bg-gradient-to-r from-purple-500 to-pink-500 hover:from-purple-600 hover:to-pink-600 disabled:from-gray-600 disabled:to-gray-700 disabled:cursor-not-allowed text-white font-medium py-4 px-6 rounded-lg transition-all flex items-center justify-center space-x-2"
          >
            {(isDepositLoading || isWithdrawLoading) ? (
              <>
                <Loader2 className="h-5 w-5 animate-spin" />
                <span>Processing...</span>
              </>
            ) : (isDepositSuccess || isWithdrawSuccess) ? (
              <>
                <CheckCircle2 className="h-5 w-5" />
                <span>Success!</span>
              </>
            ) : (
              <span>{activeTab === 'deposit' ? 'Deposit' : 'Withdraw'}</span>
            )}
          </button>
        </div>

        {/* Info */}
        <div className="flex items-start space-x-2 text-sm text-gray-400 bg-blue-500/10 border border-blue-500/20 rounded-lg p-3">
          <AlertCircle className="h-4 w-4 text-blue-400 mt-0.5 flex-shrink-0" />
          <p>
            {activeTab === 'deposit'
              ? 'Your assets will be automatically invested in the best yield strategies.'
              : 'You can withdraw your funds at any time. Withdrawal may take up to 1 block to process.'}
          </p>
        </div>
      </div>
    </div>
  );
}