// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IAccount.sol";

/**
 * @title ISmartAccount
 * @dev Interface for ERC-4337 compatible smart accounts with enhanced features
 */
interface ISmartAccount is IAccount {
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
    ) external;

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
    ) external;

    /**
     * @dev Execute a delegate call
     * @param dest Target contract address
     * @param func Encoded function call data
     */
    function executeDelegate(
        address dest,
        bytes calldata func
    ) external returns (bytes memory);

    /**
     * @dev Get the current nonce for user operations
     * @return The current nonce
     */
    function getNonce() external view returns (uint256);

    /**
     * @dev Get the entry point contract address
     * @return The entry point address
     */
    function entryPoint() external view returns (address);

    /**
     * @dev Check if the account is initialized
     * @return True if initialized, false otherwise
     */
    function isInitialized() external view returns (bool);

    /**
     * @dev Initialize the account with owner
     * @param owner The owner address
     */
    function initialize(address owner) external;

    /**
     * @dev Get the owner of the account
     * @return The owner address
     */
    function owner() external view returns (address);

    /**
     * @dev Emitted when the account is initialized
     * @param owner The owner address
     */
    event AccountInitialized(address indexed owner);

    /**
     * @dev Emitted when a transaction is executed
     * @param target The target contract address
     * @param value The ETH value sent
     * @param data The function call data
     */
    event TransactionExecuted(address indexed target, uint256 value, bytes data);

    /**
     * @dev Emitted when batch transactions are executed
     * @param targets Array of target contract addresses
     * @param values Array of ETH values sent
     */
    event BatchTransactionExecuted(address[] targets, uint256[] values);
}