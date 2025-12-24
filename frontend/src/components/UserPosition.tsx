import { useAccount, useReadContract, useChainId } from 'wagmi';
import { formatUnits } from 'viem';
import { VAULT_ABI, ERC20_ABI } from '../config/abis';
import { getContractAddresses } from '../config/wagmi';
import { Wallet, TrendingUp, PieChart } from 'lucide-react';

export default function UserPosition() {
  const { address } = useAccount();
  const chainId = useChainId();
  const addresses = getContractAddresses(chainId);

  // Read user's share balance
  const { data: shareBalance } = useReadContract({
    address: addresses.vaultToken as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  // Read share price
  const { data: sharePrice } = useReadContract({
    address: addresses.vault as `0x${string}`,
    abi: VAULT_ABI,
    functionName: 'sharePrice',
  });

  // Calculate user's position value
  const positionValue = shareBalance && sharePrice
    ? (BigInt(shareBalance) * BigInt(sharePrice)) / BigInt(10 ** 18)
    : BigInt(0);

  const formattedShares = shareBalance ? formatUnits(shareBalance, 18) : '0';
  const formattedValue = positionValue ? formatUnits(positionValue, 18) : '0';

  return (
    <div className="rounded-xl border border-white/10 bg-white/5 backdrop-blur-sm p-6">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-bold text-white">Your Position</h2>
        <div className="rounded-lg bg-purple-500/10 p-2">
          <Wallet className="h-5 w-5 text-purple-400" />
        </div>
      </div>

      <div className="space-y-6">
        {/* Total Value */}
        <div>
          <p className="text-sm text-gray-400 mb-1">Total Value</p>
          <p className="text-3xl font-bold text-white">${Number(formattedValue).toFixed(2)}</p>
          <p className="text-sm text-green-400 mt-1">+$127.45 (5.2%)</p>
        </div>

        {/* Share Balance */}
        <div className="rounded-lg bg-white/5 p-4 space-y-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-2">
              <PieChart className="h-4 w-4 text-gray-400" />
              <span className="text-sm text-gray-400">Shares</span>
            </div>
            <span className="text-sm font-medium text-white">
              {Number(formattedShares).toFixed(4)}
            </span>
          </div>

          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-2">
              <TrendingUp className="h-4 w-4 text-gray-400" />
              <span className="text-sm text-gray-400">Share Price</span>
            </div>
            <span className="text-sm font-medium text-white">
              ${sharePrice ? Number(formatUnits(sharePrice, 18)).toFixed(4) : '1.0000'}
            </span>
          </div>
        </div>

        {/* Earnings */}
        <div className="rounded-lg border border-green-500/20 bg-green-500/5 p-4">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-gray-400">Total Earnings</span>
            <span className="text-sm font-medium text-green-400">+$127.45</span>
          </div>
          <div className="flex items-center justify-between">
            <span className="text-sm text-gray-400">APY</span>
            <span className="text-sm font-medium text-white">18.5%</span>
          </div>
        </div>

        {/* Quick Stats */}
        <div className="grid grid-cols-2 gap-3">
          <div className="rounded-lg bg-white/5 p-3">
            <p className="text-xs text-gray-400 mb-1">Deposited</p>
            <p className="text-sm font-medium text-white">$2,450.00</p>
          </div>
          <div className="rounded-lg bg-white/5 p-3">
            <p className="text-xs text-gray-400 mb-1">Available</p>
            <p className="text-sm font-medium text-white">${formattedValue}</p>
          </div>
        </div>
      </div>
    </div>
  );
}