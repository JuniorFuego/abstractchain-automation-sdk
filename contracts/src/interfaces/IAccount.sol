// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./UserOperation.sol";

/**
 * @title IAccount
 * @dev Basic ERC-4337 account interface
 */
interface IAccount {
    /**
     * @dev Validate user's signature and nonce
     * @param userOp The user operation to validate
     * @param userOpHash Hash of the user operation
     * @param missingAccountFunds Missing funds that the account needs to pay
     * @return validationData Packed validation data (authorizer, validUntil, validAfter)
     */
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData);
}