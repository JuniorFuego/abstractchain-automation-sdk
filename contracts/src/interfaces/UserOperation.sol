// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title UserOperation
 * @dev User Operation struct for ERC-4337 (simplified version for testing)
 */
struct UserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;
    bytes signature;
}