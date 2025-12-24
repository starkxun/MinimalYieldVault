import { useReadContract, useChainId } from 'wagmi';
import { formatUnits } from 'viem';
import { VAULT_ABI } from '../config/abis';
import { getContractAddresses } from '../config/wagmi';
import { TrendingUp, DollarSign, Percent, Users } from 'lucide-react';

export default function VaultStats() {
  const chainId = useChainId();
  const addresses = getContractAddresses(chainId);

  // Read total assets
  const { data: totalAssets } = useReadContract({
    address: addresses.vault as `0x${string}`,
    abi: VAULT_ABI,
    functionName: 'totalAssets',
  });

  // Read share price
  const { data: sharePrice } = useReadContract({
    address: addresses.vault as `0x${string}`,
    abi: VAULT_ABI,
    functionName: 'sharePrice',
  });

  // Mock data for demo (replace with real data later)
  const stats = [
    {
      label: 'Total Value Locked',
      value: totalAssets ? `$${formatUnits(totalAssets, 18)}` : '$0',
      icon: DollarSign,
      change: '+12.5%',
      changeType: 'positive' as const,
    },
    {
      label: 'Current APY',
      value: '18.5%',
      icon: Percent,
      change: '+2.3%',
      changeType: 'positive' as const,
    },
    {
      label: 'Share Price',
      value: sharePrice ? `$${Number(formatUnits(sharePrice, 18)).toFixed(4)}` : '$1.0000',
      icon: TrendingUp,
      change: '+5.2%',
      changeType: 'positive' as const,
    },
    {
      label: 'Total Depositors',
      value: '1,234',
      icon: Users,
      change: '+156',
      changeType: 'positive' as const,
    },
  ];

  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
      {stats.map((stat) => {
        const Icon = stat.icon;
        return (
          <div
            key={stat.label}
            className="rounded-xl border border-white/10 bg-white/5 backdrop-blur-sm p-6 hover:bg-white/10 transition-colors"
          >
            <div className="flex items-center justify-between mb-4">
              <div className="rounded-lg bg-purple-500/10 p-2">
                <Icon className="h-5 w-5 text-purple-400" />
              </div>
              <span
                className={`text-sm font-medium ${
                  stat.changeType === 'positive' ? 'text-green-400' : 'text-red-400'
                }`}
              >
                {stat.change}
              </span>
            </div>
            <div>
              <p className="text-sm text-gray-400 mb-1">{stat.label}</p>
              <p className="text-2xl font-bold text-white">{stat.value}</p>
            </div>
          </div>
        );
      })}
    </div>
  );
}