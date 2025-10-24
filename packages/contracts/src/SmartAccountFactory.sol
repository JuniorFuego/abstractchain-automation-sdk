// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISmartAccountFactory.sol";
import "./SmartAccount.sol";

/**
 * @title SmartAccountFactory
 * @dev Factory contract for creating smart accounts with CREATE2 deterministic deployment
 */
contract SmartAccountFactory is ISmartAccountFactory, Ownable {
    // Smart account implementation address
    address public immutable ACCOUNT_IMPLEMENTATION;
    
    // Entry point address
    address public immutable ENTRY_POINT;

    // Mapping to track created accounts
    mapping(address => bool) public isAccount;

    // Custom errors
    error AccountAlreadyExists();
    error InvalidOwner();

    /**
     * @dev Constructor
     * @param entryPoint The ERC-4337 entry point address
     */
    constructor(address entryPoint) {
        if (entryPoint == address(0)) revert InvalidOwner();
        
        ENTRY_POINT = entryPoint;
        ACCOUNT_IMPLEMENTATION = address(new SmartAccount(entryPoint));
    }

    /**
     * @dev Create a new smart account using CREATE2
     * @param owner The owner of the account
     * @param salt Salt for CREATE2 deployment
     * @param initData Additional initialization data (unused for now)
     * @return account The address of the created account
     */
    function createAccount(
        address owner,
        uint256 salt,
        bytes calldata initData
    ) external override returns (address account) {
        if (owner == address(0)) revert InvalidOwner();

        // Calculate deterministic address
        account = getAddress(owner, salt);

        // Check if account already exists
        if (isAccount[account] || account.code.length > 0) {
            return account; // Return existing account
        }

        // Create proxy with CREATE2
        bytes memory bytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(
                ACCOUNT_IMPLEMENTATION,
                abi.encodeWithSelector(SmartAccount.initialize.selector, owner)
            )
        );

        bytes32 saltHash = keccak256(abi.encodePacked(owner, salt));
        
        assembly {
            account := create2(0, add(bytecode, 0x20), mload(bytecode), saltHash)
        }

        if (account == address(0)) {
            revert AccountAlreadyExists();
        }

        // Mark as created account
        isAccount[account] = true;

        emit AccountCreated(account, owner, salt);
        return account;
    }

    /**
     * @dev Get the deterministic address of an account
     * @param owner The owner of the account
     * @param salt Salt for CREATE2 deployment
     * @return The predicted account address
     */
    function getAddress(
        address owner,
        uint256 salt
    ) public view override returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(
                ACCOUNT_IMPLEMENTATION,
                abi.encodeWithSelector(SmartAccount.initialize.selector, owner)
            )
        );

        bytes32 saltHash = keccak256(abi.encodePacked(owner, salt));
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                saltHash,
                keccak256(bytecode)
            )
        );

        return address(uint160(uint256(hash)));
    }

    /**
     * @dev Get the account implementation address
     * @return The implementation address
     */
    function accountImplementation() external view override returns (address) {
        return ACCOUNT_IMPLEMENTATION;
    }

    /**
     * @dev Get the entry point contract address
     * @return The entry point address
     */
    function entryPoint() external view override returns (address) {
        return ENTRY_POINT;
    }
}