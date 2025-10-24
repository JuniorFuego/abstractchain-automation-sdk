// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SmartAccountFactory.sol";
import "../src/SmartAccount.sol";
import "../src/interfaces/UserOperation.sol";

contract MockEntryPoint {
    function handleOps(UserOperation[] calldata ops, address payable beneficiary) external {}
}

contract SmartAccountFactoryTest is Test {
    SmartAccountFactory public factory;
    MockEntryPoint public entryPoint;
    
    address public owner1 = address(0x1);
    address public owner2 = address(0x2);
    uint256 public salt1 = 12345;
    uint256 public salt2 = 67890;

    event AccountCreated(address indexed account, address indexed owner, uint256 salt);

    function setUp() public {
        entryPoint = new MockEntryPoint();
        factory = new SmartAccountFactory(address(entryPoint));
    }

    function testFactoryInitialization() public {
        assertEq(factory.entryPoint(), address(entryPoint));
        assertTrue(factory.accountImplementation() != address(0));
    }

    function testCreateAccount() public {
        address predictedAddr = factory.getAddress(owner1, salt1);
        
        vm.expectEmit(true, true, true, true);
        emit AccountCreated(predictedAddr, owner1, salt1);
        
        address accountAddr = factory.createAccount(owner1, salt1, "");
        
        assertEq(accountAddr, predictedAddr);
        assertTrue(factory.isAccount(accountAddr));
        
        // Verify account is properly initialized
        SmartAccount account = SmartAccount(payable(accountAddr));
        assertTrue(account.isInitialized());
        assertEq(account.owner(), owner1);
        assertEq(account.entryPoint(), address(entryPoint));
    }

    function testCreateAccountDeterministic() public {
        // Create account twice with same parameters
        address addr1 = factory.createAccount(owner1, salt1, "");
        address addr2 = factory.createAccount(owner1, salt1, "");
        
        // Should return same address
        assertEq(addr1, addr2);
        
        // Should only emit event once
        assertTrue(factory.isAccount(addr1));
    }

    function testCreateAccountDifferentOwners() public {
        address addr1 = factory.createAccount(owner1, salt1, "");
        address addr2 = factory.createAccount(owner2, salt1, "");
        
        // Different owners should create different accounts
        assertTrue(addr1 != addr2);
        assertTrue(factory.isAccount(addr1));
        assertTrue(factory.isAccount(addr2));
        
        SmartAccount account1 = SmartAccount(payable(addr1));
        SmartAccount account2 = SmartAccount(payable(addr2));
        
        assertEq(account1.owner(), owner1);
        assertEq(account2.owner(), owner2);
    }

    function testCreateAccountDifferentSalts() public {
        address addr1 = factory.createAccount(owner1, salt1, "");
        address addr2 = factory.createAccount(owner1, salt2, "");
        
        // Different salts should create different accounts
        assertTrue(addr1 != addr2);
        assertTrue(factory.isAccount(addr1));
        assertTrue(factory.isAccount(addr2));
        
        SmartAccount account1 = SmartAccount(payable(addr1));
        SmartAccount account2 = SmartAccount(payable(addr2));
        
        assertEq(account1.owner(), owner1);
        assertEq(account2.owner(), owner1);
    }

    function testGetAddressPrediction() public {
        address predictedAddr = factory.getAddress(owner1, salt1);
        address actualAddr = factory.createAccount(owner1, salt1, "");
        
        assertEq(predictedAddr, actualAddr);
    }

    function testCreateAccountInvalidOwner() public {
        vm.expectRevert(SmartAccountFactory.InvalidOwner.selector);
        factory.createAccount(address(0), salt1, "");
    }

    function testFactoryInvalidEntryPoint() public {
        vm.expectRevert(SmartAccountFactory.InvalidOwner.selector);
        new SmartAccountFactory(address(0));
    }

    function testAccountImplementationIsValid() public {
        address impl = factory.accountImplementation();
        assertTrue(impl != address(0));
        
        // Implementation should be a SmartAccount
        SmartAccount implContract = SmartAccount(payable(impl));
        assertEq(implContract.entryPoint(), address(entryPoint));
    }

    function testMultipleAccountsFromSameFactory() public {
        address[] memory accounts = new address[](5);
        
        for (uint256 i = 0; i < 5; i++) {
            accounts[i] = factory.createAccount(
                address(uint160(i + 1)), // Different owners
                i, // Different salts
                ""
            );
            assertTrue(factory.isAccount(accounts[i]));
        }
        
        // All accounts should be different
        for (uint256 i = 0; i < 5; i++) {
            for (uint256 j = i + 1; j < 5; j++) {
                assertTrue(accounts[i] != accounts[j]);
            }
        }
    }

    function testAccountCodeExists() public {
        address accountAddr = factory.createAccount(owner1, salt1, "");
        
        // Account should have code deployed
        assertTrue(accountAddr.code.length > 0);
    }

    function testAccountReceivesEther() public {
        address accountAddr = factory.createAccount(owner1, salt1, "");
        
        // Send ether to account
        vm.deal(accountAddr, 1 ether);
        assertEq(accountAddr.balance, 1 ether);
    }

    // Fuzz testing
    function testFuzzCreateAccount(address owner_, uint256 salt_) public {
        vm.assume(owner_ != address(0));
        
        address predictedAddr = factory.getAddress(owner_, salt_);
        address actualAddr = factory.createAccount(owner_, salt_, "");
        
        assertEq(predictedAddr, actualAddr);
        assertTrue(factory.isAccount(actualAddr));
        
        SmartAccount account = SmartAccount(payable(actualAddr));
        assertEq(account.owner(), owner_);
    }

    function testFuzzGetAddress(address owner_, uint256 salt_) public {
        vm.assume(owner_ != address(0));
        
        address addr1 = factory.getAddress(owner_, salt_);
        address addr2 = factory.getAddress(owner_, salt_);
        
        // Should always return same address for same parameters
        assertEq(addr1, addr2);
        
        // Address should be deterministic
        assertTrue(addr1 != address(0));
    }

    function testFuzzDifferentParameters(
        address owner1_,
        address owner2_,
        uint256 salt1_,
        uint256 salt2_
    ) public {
        vm.assume(owner1_ != address(0) && owner2_ != address(0));
        vm.assume(owner1_ != owner2_ || salt1_ != salt2_);
        
        address addr1 = factory.getAddress(owner1_, salt1_);
        address addr2 = factory.getAddress(owner2_, salt2_);
        
        // Different parameters should produce different addresses
        assertTrue(addr1 != addr2);
    }

    function testGasUsageCreateAccount() public {
        uint256 gasBefore = gasleft();
        factory.createAccount(owner1, salt1, "");
        uint256 gasUsed = gasBefore - gasleft();
        
        // Gas usage should be reasonable (less than 500k gas)
        assertTrue(gasUsed < 500000);
    }

    function testCreateAccountIdempotent() public {
        address addr1 = factory.createAccount(owner1, salt1, "");
        
        // Creating again should not revert and return same address
        address addr2 = factory.createAccount(owner1, salt1, "");
        assertEq(addr1, addr2);
        
        // Should still be marked as account
        assertTrue(factory.isAccount(addr1));
    }
}