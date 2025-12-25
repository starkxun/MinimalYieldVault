import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount } from 'wagmi';
import VaultStats from './VaultStats';
import DepositWithdraw from './DepositWithdraw';
import UserPosition from './UserPosition';
import { Wallet, TrendingUp, Shield } from 'lucide-react';

export default function Dashboard() {
  const { isConnected } = useAccount();

  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="border-b border-white/10 bg-black/20 backdrop-blur-sm">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <div className="rounded-lg bg-gradient-to-br from-purple-500 to-pink-500 p-2">
                <TrendingUp className="h-6 w-6 text-white" />
              </div>
              <div>
                <h1 className="text-2xl font-bold text-white">Yield Vault</h1>
                <p className="text-sm text-gray-400">Maximize your DeFi returns</p>
              </div>
            </div>
            <ConnectButton />
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container mx-auto px-4 py-8">
        {!isConnected ? (
          <div className="flex min-h-[60vh] flex-col items-center justify-center space-y-6">
            <div className="rounded-full bg-purple-500/10 p-6">
              <Wallet className="h-16 w-16 text-purple-400" />
            </div>
            <div className="text-center">
              <h2 className="text-3xl font-bold text-white mb-2">
                Welcome to Yield Vault
              </h2>
              <p className="text-gray-400 text-lg max-w-md">
                Connect your wallet to start earning optimized yields on your crypto assets
              </p>
            </div>
            <div className="flex items-center space-x-2 text-sm text-gray-500">
              <Shield className="h-4 w-4" />
              <span>Audited & Secure</span>
            </div>
          </div>
        ) : (
          <div className="space-y-6">
            {/* Vault Statistics */}
            <VaultStats />

            {/* Main Grid */}
            <div className="grid gap-6 lg:grid-cols-3">
              {/* Left Column - User Position */}
              <div className="lg:col-span-1">
                <UserPosition />
              </div>

              {/* Right Column - Deposit/Withdraw */}
              <div className="lg:col-span-2">
                <DepositWithdraw />
              </div>
            </div>
          </div>
        )}
      </main>

      {/* Footer */}
      <footer className="border-t border-white/10 bg-black/20 backdrop-blur-sm mt-12">
        <div className="container mx-auto px-4 py-6">
          <div className="flex flex-col md:flex-row items-center justify-between text-sm text-gray-400">
            <p>&copy; 2024 Yield Vault. All rights reserved.</p>
            <div className="flex space-x-6 mt-4 md:mt-0">
              <a href="#" className="hover:text-white transition-colors">Docs</a>
              <a href="https://github.com/starkxun" className="hover:text-white transition-colors">GitHub</a>
              <a href="https://x.com/starkxun" className="hover:text-white transition-colors">Twitter</a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}