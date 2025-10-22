/**
 * AbstractChain Automation SDK
 * 
 * A comprehensive TypeScript/Solidity toolkit that leverages ERC-4337 Account Abstraction
 * to enable gasless transactions, cross-chain DeFi automation, and social finance features.
 * 
 * @packageDocumentation
 */

export * from './sdk';
export * from './types';
export * from './errors';

// Re-export modules for convenience
export * from './modules/accounts';
export * from './modules/paymaster';
export * from './modules/nft';
export * from './modules/tipping';
export * from './modules/automation';
export * from './modules/abstract';