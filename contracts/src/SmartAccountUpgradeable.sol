// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./interfaces/ISmartAccount.sol";
import "./interfaces/UserOperation.sol";

/**
 * @title SmartAccountUpgradeable
 * @dev ERC-4337 compatible smart account with UUPS upgradeability and social recovery
 */
contract SmartAccountUpgradeable is ISmartAccount, Initializable, OwnableUpgradeable, ReentrancyGuard, UUPSUpgradeable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // ERC-4337 Entry Point
    address public ENTRY_POINT;

    // Account nonce for user operations
    uint256 private _nonce;

    // Social Recovery Configuration
    struct SocialRecovery {
        address[] guardians;
        mapping(address => bool) isGuardian;
        uint256 threshold;
        uint256 recoveryDelay;
        bool recoveryActive;
        address pendingOwner;
        uint256 recoveryInitiated;
        mapping(address => bool) recoveryApprovals;
        uint256 approvalCount;
    }

    SocialRecovery private _socialRecovery;

    // Custom errors
    error OnlyEntryPoint();
    error OnlyOwnerOrEntryPoint();
    error InvalidSignature();
    error ExecutionFailed();
    error ArrayLengthMismatch();
    error InvalidGuardian();
    error GuardianAlreadyExists();
    error GuardianNotFound();
    error InvalidThreshold();
    error RecoveryNotActive();
    error RecoveryAlreadyActive();
    error RecoveryDelayNotPassed();
    error InsufficientApprovals();
    error NotGuardian();
    error AlreadyApproved();
    error InvalidRecoveryDelay();

    // Events
    event GuardianAdded(address indexed guardian);
    event GuardianRemoved(address indexed guardian);
    event ThresholdChanged(uint256 newThreshold);
    event RecoveryDelayChanged(uint256 newDelay);
    event RecoveryInitiated(address indexed newOwner, uint256 delay);
    event RecoveryApproved(address indexed guardian, address indexed newOwner);
    event RecoveryExecuted(address indexed oldOwner, address indexed newOwner);
    event RecoveryCancelled();

    /**
     * @dev Modifier to ensure only entry point can call
     */
    modifier onlyEntryPoint() {
        if (msg.sender != ENTRY_POINT) revert OnlyEntryPoint();
        _;
    }

    /**
     * @dev Modifier to ensure only owner or entry point can call
     */
    modifier onlyOwnerOrEntryPoint() {
        if (msg.sender != owner() && msg.sender != ENTRY_POINT) {
            revert OnlyOwnerOrEntryPoint();
        }
        _;
    }

    /**
     * @dev Modifier to ensure only guardians can call
     */
    modifier onlyGuardian() {
        if (!_socialRecovery.isGuardian[msg.sender]) revert NotGuardian();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the account with owner and entry point
     * @param owner_ The owner address
     * @param entryPointAddr The ERC-4337 entry point address
     */
    function initialize(address owner_, address entryPointAddr) external initializer {
        __Ownable_init(owner_);

        ENTRY_POINT = entryPointAddr;

        emit AccountInitialized(owner_);
    }

    /**
     * @dev Initialize the account with owner (for compatibility)
     * @param owner_ The owner address
     */
    function initialize(address owner_) external override {
        // This function is kept for interface compatibility but should not be used
        // The two-parameter initialize function should be used instead
        revert("Use initialize(address,address) instead");
    }

    /**
     * @dev Validate user operation signature and nonce
     * @param userOp The user operation to validate
     * @param userOpHash Hash of the user operation
     * @param missingAccountFunds Missing funds to pay
     * @return validationData Packed validation data
     */
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override onlyEntryPoint returns (uint256 validationData) {
        // Validate nonce
        if (userOp.nonce != _nonce) {
            return 1; // Invalid nonce
        }

        // Validate signature
        if (userOp.signature.length != 65) {
            return 1; // Invalid signature length
        }

        address signer = userOpHash.recover(userOp.signature);

        if (signer != owner()) {
            return 1; // Invalid signature
        }

        // Increment nonce
        _nonce++;

        // Pay missing account funds if needed
        if (missingAccountFunds > 0) {
            (bool success, ) = payable(msg.sender).call{value: missingAccountFunds}("");
            if (!success) {
                return 1; // Payment failed
            }
        }

        return 0; // Valid
    }

    /**
     * @dev Execute a single transaction
     * @param dest Target contract address
     * @param value ETH value to send
     * @param func Encoded function call data
     */
    function execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) external override onlyOwnerOrEntryPoint nonReentrant {
        _execute(dest, value, func);
        emit TransactionExecuted(dest, value, func);
    }

    /**
     * @dev Execute multiple transactions in batch
     * @param dest Array of target contract addresses
     * @param value Array of ETH values to send
     * @param func Array of encoded function call data
     */
    function executeBatch(
        address[] calldata dest,
        uint256[] calldata value,
        bytes[] calldata func
    ) external override onlyOwnerOrEntryPoint nonReentrant {
        if (dest.length != value.length || dest.length != func.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < dest.length; i++) {
            _execute(dest[i], value[i], func[i]);
        }

        emit BatchTransactionExecuted(dest, value);
    }

    /**
     * @dev Execute a delegate call
     * @param dest Target contract address
     * @param func Encoded function call data
     */
    function executeDelegate(
        address dest,
        bytes calldata func
    ) external override onlyOwnerOrEntryPoint nonReentrant returns (bytes memory) {
        (bool success, bytes memory result) = dest.delegatecall(func);
        if (!success) {
            revert ExecutionFailed();
        }
        return result;
    }

    // Social Recovery Functions

    /**
     * @dev Add a guardian for social recovery
     * @param guardian The guardian address to add
     */
    function addGuardian(address guardian) external onlyOwner {
        if (guardian == address(0) || guardian == owner()) revert InvalidGuardian();
        if (_socialRecovery.isGuardian[guardian]) revert GuardianAlreadyExists();

        _socialRecovery.guardians.push(guardian);
        _socialRecovery.isGuardian[guardian] = true;

        emit GuardianAdded(guardian);
    }

    /**
     * @dev Remove a guardian from social recovery
     * @param guardian The guardian address to remove
     */
    function removeGuardian(address guardian) external onlyOwner {
        if (!_socialRecovery.isGuardian[guardian]) revert GuardianNotFound();

        // Remove from guardians array
        for (uint256 i = 0; i < _socialRecovery.guardians.length; i++) {
            if (_socialRecovery.guardians[i] == guardian) {
                _socialRecovery.guardians[i] = _socialRecovery.guardians[_socialRecovery.guardians.length - 1];
                _socialRecovery.guardians.pop();
                break;
            }
        }

        _socialRecovery.isGuardian[guardian] = false;

        // Adjust threshold if necessary
        if (_socialRecovery.threshold > _socialRecovery.guardians.length) {
            _socialRecovery.threshold = _socialRecovery.guardians.length;
            emit ThresholdChanged(_socialRecovery.threshold);
        }

        emit GuardianRemoved(guardian);
    }

    /**
     * @dev Set the threshold for social recovery
     * @param threshold The minimum number of guardian approvals needed
     */
    function setThreshold(uint256 threshold) external onlyOwner {
        if (threshold == 0 || threshold > _socialRecovery.guardians.length) {
            revert InvalidThreshold();
        }

        _socialRecovery.threshold = threshold;
        emit ThresholdChanged(threshold);
    }

    /**
     * @dev Set the recovery delay period
     * @param delay The delay in seconds before recovery can be executed
     */
    function setRecoveryDelay(uint256 delay) external onlyOwner {
        if (delay < 1 days || delay > 30 days) revert InvalidRecoveryDelay();

        _socialRecovery.recoveryDelay = delay;
        emit RecoveryDelayChanged(delay);
    }

    /**
     * @dev Initiate social recovery process
     * @param newOwner The proposed new owner address
     */
    function initiateRecovery(address newOwner) external onlyGuardian {
        if (_socialRecovery.recoveryActive) revert RecoveryAlreadyActive();
        if (newOwner == address(0) || newOwner == owner()) revert InvalidGuardian();

        _socialRecovery.recoveryActive = true;
        _socialRecovery.pendingOwner = newOwner;
        _socialRecovery.recoveryInitiated = block.timestamp;
        _socialRecovery.approvalCount = 0;

        // Clear previous approvals
        for (uint256 i = 0; i < _socialRecovery.guardians.length; i++) {
            _socialRecovery.recoveryApprovals[_socialRecovery.guardians[i]] = false;
        }

        emit RecoveryInitiated(newOwner, _socialRecovery.recoveryDelay);
    }

    /**
     * @dev Approve the pending recovery
     */
    function approveRecovery() external onlyGuardian {
        if (!_socialRecovery.recoveryActive) revert RecoveryNotActive();
        if (_socialRecovery.recoveryApprovals[msg.sender]) revert AlreadyApproved();

        _socialRecovery.recoveryApprovals[msg.sender] = true;
        _socialRecovery.approvalCount++;

        emit RecoveryApproved(msg.sender, _socialRecovery.pendingOwner);
    }

    /**
     * @dev Execute the recovery after delay and sufficient approvals
     */
    function executeRecovery() external {
        if (!_socialRecovery.recoveryActive) revert RecoveryNotActive();
        if (block.timestamp < _socialRecovery.recoveryInitiated + _socialRecovery.recoveryDelay) {
            revert RecoveryDelayNotPassed();
        }
        if (_socialRecovery.approvalCount < _socialRecovery.threshold) {
            revert InsufficientApprovals();
        }

        address oldOwner = owner();
        address newOwner = _socialRecovery.pendingOwner;

        // Reset recovery state
        _socialRecovery.recoveryActive = false;
        _socialRecovery.pendingOwner = address(0);
        _socialRecovery.recoveryInitiated = 0;
        _socialRecovery.approvalCount = 0;

        // Transfer ownership
        _transferOwnership(newOwner);

        emit RecoveryExecuted(oldOwner, newOwner);
    }

    /**
     * @dev Cancel ongoing recovery (only owner can cancel)
     */
    function cancelRecovery() external onlyOwner {
        if (!_socialRecovery.recoveryActive) revert RecoveryNotActive();

        _socialRecovery.recoveryActive = false;
        _socialRecovery.pendingOwner = address(0);
        _socialRecovery.recoveryInitiated = 0;
        _socialRecovery.approvalCount = 0;

        emit RecoveryCancelled();
    }

    // View Functions

    /**
     * @dev Get all guardians
     * @return Array of guardian addresses
     */
    function getGuardians() external view returns (address[] memory) {
        return _socialRecovery.guardians;
    }

    /**
     * @dev Check if an address is a guardian
     * @param guardian The address to check
     * @return True if the address is a guardian
     */
    function isGuardian(address guardian) external view returns (bool) {
        return _socialRecovery.isGuardian[guardian];
    }

    /**
     * @dev Get the recovery threshold
     * @return The minimum number of guardian approvals needed
     */
    function getThreshold() external view returns (uint256) {
        return _socialRecovery.threshold;
    }

    /**
     * @dev Get the recovery delay
     * @return The delay in seconds before recovery can be executed
     */
    function getRecoveryDelay() external view returns (uint256) {
        return _socialRecovery.recoveryDelay;
    }

    /**
     * @dev Get recovery status
     * @return active True if recovery is active
     * @return pendingOwner The proposed new owner
     * @return initiatedAt When recovery was initiated
     * @return approvalCount Current number of approvals
     */
    function getRecoveryStatus()
        external
        view
        returns (bool active, address pendingOwner, uint256 initiatedAt, uint256 approvalCount)
    {
        return (
            _socialRecovery.recoveryActive,
            _socialRecovery.pendingOwner,
            _socialRecovery.recoveryInitiated,
            _socialRecovery.approvalCount
        );
    }

    /**
     * @dev Check if a guardian has approved the current recovery
     * @param guardian The guardian address to check
     * @return True if the guardian has approved
     */
    function hasApprovedRecovery(address guardian) external view returns (bool) {
        return _socialRecovery.recoveryApprovals[guardian];
    }

    /**
     * @dev Internal function to execute a transaction
     * @param dest Target contract address
     * @param value ETH value to send
     * @param func Encoded function call data
     */
    function _execute(address dest, uint256 value, bytes calldata func) internal {
        (bool success, ) = dest.call{value: value}(func);
        if (!success) {
            revert ExecutionFailed();
        }
    }

    /**
     * @dev Get the current nonce for user operations
     * @return The current nonce
     */
    function getNonce() external view override returns (uint256) {
        return _nonce;
    }

    /**
     * @dev Get the entry point contract address
     * @return The entry point address
     */
    function entryPoint() external view override returns (address) {
        return ENTRY_POINT;
    }

    /**
     * @dev Check if the account is initialized
     * @return True if initialized, false otherwise
     */
    function isInitialized() external view override returns (bool) {
        // Check if initialized but not disabled (disabled means type(uint64).max)
        uint64 version = _getInitializedVersion();
        return version > 0 && version < type(uint64).max;
    }

    /**
     * @dev Get the owner of the account (override from Ownable)
     * @return The owner address
     */
    function owner() public view override(OwnableUpgradeable, ISmartAccount) returns (address) {
        return OwnableUpgradeable.owner();
    }

    /**
     * @dev Authorize upgrade (only owner can upgrade)
     * @param newImplementation The new implementation address
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev Receive ETH
     */
    receive() external payable {}

    /**
     * @dev Fallback function
     */
    fallback() external payable {}
}
