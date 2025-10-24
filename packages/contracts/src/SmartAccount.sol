// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./interfaces/ISmartAccount.sol";
import "./interfaces/UserOperation.sol";

/**
 * @title SmartAccount
 * @dev ERC-4337 compatible smart account with batch execution and upgradeability
 */
contract SmartAccount is 
    ISmartAccount,
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // ERC-4337 Entry Point
    address public immutable ENTRY_POINT;
    
    // Account nonce for user operations
    uint256 private _nonce;
    
    // Account initialization status
    bool private _initialized;

    // Custom errors
    error OnlyEntryPoint();
    error OnlyOwnerOrEntryPoint();
    error InvalidSignature();
    error ExecutionFailed();
    error ArrayLengthMismatch();
    error AlreadyInitialized();

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
     * @dev Constructor sets the entry point address
     * @param entryPoint The ERC-4337 entry point address
     */
    constructor(address entryPoint) {
        ENTRY_POINT = entryPoint;
        _disableInitializers();
    }

    /**
     * @dev Initialize the account with owner
     * @param owner_ The owner address
     */
    function initialize(address owner_) external initializer {
        if (_initialized) revert AlreadyInitialized();
        
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        
        _transferOwnership(owner_);
        _initialized = true;
        
        emit AccountInitialized(owner_);
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
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        address signer = hash.recover(userOp.signature);
        
        if (signer != owner()) {
            return 1; // Invalid signature
        }

        // Increment nonce
        _nonce++;

        // Pay missing account funds if needed
        if (missingAccountFunds > 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds}("");
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

    /**
     * @dev Internal function to execute a transaction
     * @param dest Target contract address
     * @param value ETH value to send
     * @param func Encoded function call data
     */
    function _execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) internal {
        (bool success,) = dest.call{value: value}(func);
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
        return _initialized;
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