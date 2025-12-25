// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VaultToken
 * @notice ERC20 Share Token - 代表用户在 Vault 中的份额
 * @dev 模块1: 只有 Vault 合约可以 mint/burn shares
 */
contract VaultToken is ERC20, Ownable {
    /// @notice 记录 Vault 地址（只有它能 mint/burn）
    address public vault;

    /// @notice 是否已初始化 Vault
    bool public vaultInitialized;

    // ============ Events ============
    event VaultSet(address indexed vault);

    // ============ Errors ============
    error OnlyVault();
    error VaultAlreadySet();
    error ZeroAddress();

    // ============ Constructor ============
    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender) {}

    // ============ Modifiers ============
    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    // ============ External Functions ============

    /**
     * @notice 设置 Vault 地址（只能设置一次）
     * @param _vault Vault 合约地址
     */
    function setVault(address _vault) external onlyOwner {
        if (vaultInitialized) revert VaultAlreadySet();
        if (_vault == address(0)) revert ZeroAddress();

        vault = _vault;
        vaultInitialized = true;

        emit VaultSet(_vault);
    }

    /**
     * @notice 铸造 shares（仅 Vault 可调用）
     * @param to 接收地址
     * @param amount 数量
     */
    function mint(address to, uint256 amount) external onlyVault {
        _mint(to, amount);
    }

    /**
     * @notice 销毁 shares（仅 Vault 可调用）
     * @param from 销毁地址
     * @param amount 数量
     */
    function burn(address from, uint256 amount) external onlyVault {
        _burn(from, amount);
    }
}
