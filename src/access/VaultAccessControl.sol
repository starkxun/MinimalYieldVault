// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title VaultAccessControl
 * @notice 模块5: 访问控制与暂停机制
 * @dev 管理 Vault 的多角色权限和紧急暂停
 */
contract VaultAccessControl is Ownable, Pausable {
    
    // ============ State Variables ============
    
    /// @notice Strategist 地址（管理投资策略）
    address public strategist;
    
    /// @notice Guardian 地址（紧急暂停权限）
    address public guardian;
    
    /// @notice Keeper 地址（自动化操作）
    address public keeper;
    
    /// @notice 是否允许公开 deposit（任何人都能存款）
    bool public publicDepositsEnabled;
    
    /// @notice 白名单用户（当 publicDeposits 关闭时）
    mapping(address => bool) public whitelisted;

    // ============ Events ============
    event StrategistUpdated(address indexed oldStrategist, address indexed newStrategist);
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);
    event KeeperUpdated(address indexed oldKeeper, address indexed newKeeper);
    event UserWhitelisted(address indexed user, bool status);
    event PublicDepositsToggled(bool enabled);
    event EmergencyShutdown(address indexed caller);

    // ============ Errors ============
    error OnlyStrategist();
    error OnlyGuardian();
    error OnlyKeeper();
    error OnlyStrategistOrOwner();
    error OnlyGuardianOrOwner();
    error NotWhitelisted();
    error ZeroAddress();

    // ============ Modifiers ============
    
    modifier onlyStrategist() {
        if (msg.sender != strategist) revert OnlyStrategist();
        _;
    }

    modifier onlyGuardian() {
        if (msg.sender != guardian) revert OnlyGuardian();
        _;
    }

    modifier onlyKeeper() {
        if (msg.sender != keeper) revert OnlyKeeper();
        _;
    }

    modifier onlyStrategistOrOwner() {
        if (msg.sender != strategist && msg.sender != owner()) {
            revert OnlyStrategistOrOwner();
        }
        _;
    }

    modifier onlyGuardianOrOwner() {
        if (msg.sender != guardian && msg.sender != owner()) {
            revert OnlyGuardianOrOwner();
        }
        _;
    }

    modifier onlyWhitelistedOrPublic() {
        if (!publicDepositsEnabled && !whitelisted[msg.sender]) {
            revert NotWhitelisted();
        }
        _;
    }

    // ============ Constructor ============
    constructor(
        address _strategist,
        address _guardian,
        address _keeper
    ) Ownable(msg.sender) {
        if (_strategist == address(0)) revert ZeroAddress();
        if (_guardian == address(0)) revert ZeroAddress();
        if (_keeper == address(0)) revert ZeroAddress();
        
        strategist = _strategist;
        guardian = _guardian;
        keeper = _keeper;
        publicDepositsEnabled = true; // 默认开启公开存款
    }

    // ============ External Functions ============

    /**
     * @notice 设置 Strategist
     * @param _strategist 新的 Strategist 地址
     */
    function setStrategist(address _strategist) external onlyOwner {
        if (_strategist == address(0)) revert ZeroAddress();
        
        address oldStrategist = strategist;
        strategist = _strategist;
        
        emit StrategistUpdated(oldStrategist, _strategist);
    }

    /**
     * @notice 设置 Guardian
     * @param _guardian 新的 Guardian 地址
     */
    function setGuardian(address _guardian) external onlyOwner {
        if (_guardian == address(0)) revert ZeroAddress();
        
        address oldGuardian = guardian;
        guardian = _guardian;
        
        emit GuardianUpdated(oldGuardian, _guardian);
    }

    /**
     * @notice 设置 Keeper
     * @param _keeper 新的 Keeper 地址
     */
    function setKeeper(address _keeper) external onlyOwner {
        if (_keeper == address(0)) revert ZeroAddress();
        
        address oldKeeper = keeper;
        keeper = _keeper;
        
        emit KeeperUpdated(oldKeeper, _keeper);
    }

    /**
     * @notice 添加/移除白名单用户
     * @param user 用户地址
     * @param status 白名单状态
     */
    function setWhitelist(address user, bool status) external onlyOwner {
        whitelisted[user] = status;
        emit UserWhitelisted(user, status);
    }

    /**
     * @notice 批量设置白名单
     * @param users 用户地址数组
     * @param status 白名单状态
     */
    function setWhitelistBatch(address[] calldata users, bool status) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            whitelisted[users[i]] = status;
            emit UserWhitelisted(users[i], status);
        }
    }

    /**
     * @notice 切换公开存款开关
     * @param enabled 是否启用
     */
    function togglePublicDeposits(bool enabled) external onlyOwner {
        publicDepositsEnabled = enabled;
        emit PublicDepositsToggled(enabled);
    }

    /**
     * @notice 暂停合约（Guardian 或 Owner）
     */
    function pause() external onlyGuardianOrOwner {
        _pause();
    }

    /**
     * @notice 恢复合约（仅 Owner）
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice 紧急关闭（仅 Guardian 或 Owner）
     */
    function emergencyShutdown() external onlyGuardianOrOwner {
        _pause();
        emit EmergencyShutdown(msg.sender);
    }

    // ============ View Functions ============

    /**
     * @notice 检查用户是否能存款
     * @param user 用户地址
     */
    function canDeposit(address user) external view returns (bool) {
        return publicDepositsEnabled || whitelisted[user];
    }

    /**
     * @notice 获取所有角色地址
     */
    function getRoles() external view returns (
        address owner_,
        address strategist_,
        address guardian_,
        address keeper_
    ) {
        return (owner(), strategist, guardian, keeper);
    }

    /**
     * @notice 获取访问控制状态
     */
    function getAccessControlState() external view returns (
        bool isPaused,
        bool publicDeposits,
        address strategist_,
        address guardian_,
        address keeper_
    ) {
        return (
            paused(),
            publicDepositsEnabled,
            strategist,
            guardian,
            keeper
        );
    }
}