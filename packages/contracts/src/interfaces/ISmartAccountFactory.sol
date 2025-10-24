// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title ISmartAccountFactory
 * @dev Interface for Smart Account Factory with CREATE2 deterministic deployment
 */
interface ISmartAccountFactory {
    /**
     * @dev Create a new smart account
     * @param owner The owner of the account
     * @param salt Salt for CREATE2 deployment
     * @param initData Additional initialization data
     * @return account The address of the created account
     */
    function createAccount(
        address owner,
        uint256 salt,
        bytes calldata initData
    ) external returns (address account);

    /**
     * @dev Get the deterministic address of an account
     * @param owner The owner of the account
     * @param salt Salt for CREATE2 deployment
     * @return The predicted account address
     */
    function getAddress(
        address owner,
        uint256 salt
    ) external view returns (address);

    /**
     * @dev Get the account implementation address
     * @return The implementation address
     */
    function accountImplementation() external view returns (address);

    /**
     * @dev Get the entry point contract address
     * @return The entry point address
     */
    function entryPoint() external view returns (address);

    /**
     * @dev Emitted when a new account is created
     * @param account The address of the created account
     * @param owner The owner of the account
     * @param salt The salt used for deployment
     */
    event AccountCreated(address indexed account, address indexed owner, uint256 salt);
}