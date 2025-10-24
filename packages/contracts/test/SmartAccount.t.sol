// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SmartAccount.sol";
import "../src/SmartAccountFactory.sol";
import "../src/interfaces/UserOperation.sol";

contract MockEntryPoint {
    function handleOps(UserOperation[] calldata ops, address payable beneficiary) external {}
}

contract MockTarget {
    uint256 public value;
    bool public called;
    
    function setValue(uint256 _value) external {
        value = _value;
        called = true;
    }
    
    function revertFunction() external pure {
        revert("Mock revert");
    }
    
    receive() external payable {}
}

contract SmartAccountTest is Test {
    SmartAccount public account;
    SmartAccountFactory public factory;
    MockEntryPoint public entryPoint;
    MockTarget public target;
    
    address public owner = address(0x1);
    address public user = address(0x2);
    uint256 public salt = 12345;

    event AccountInitialized(address indexed owner);
    event TransactionExecuted(address indexed target, uint256 value, bytes data);
    event BatchTransactionExecuted(address[] targets, uint256[] values);

    function setUp() public {
        entryPoint = new MockEntryPoint();
        factory = new SmartAccountFactory(address(entryPoint));
        target = new MockTarget();
        
        // Create account through factory
        address accountAddr = factory.createAccount(owner, salt, "");
        account = SmartAccount(payable(accountAddr));
        
        // Fund the account
        vm.deal(accountAddr, 10 ether);
    }

    function testAccountInitialization() public {
        assertTrue(account.isInitialized());
        assertEq(account.owner(), owner);
        assertEq(account.entryPoint(), address(entryPoint));
        assertEq(account.getNonce(), 0);
    }

    function testCannotReinitialize() public {
        vm.expectRevert(SmartAccount.AlreadyInitialized.selector);
        account.initialize(user);
    }

    function testExecuteAsOwner() public {
        vm.prank(owner);
        
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        
        vm.expectEmit(true, true, true, true);
        emit TransactionExecuted(address(target), 0, data);
        
        account.execute(address(target), 0, data);
        
        assertEq(target.value(), 42);
        assertTrue(target.called());
    }

    function testExecuteAsEntryPoint() public {
        vm.prank(address(entryPoint));
        
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 100);
        account.execute(address(target), 0, data);
        
        assertEq(target.value(), 100);
    }

    function testExecuteFailsForUnauthorized() public {
        vm.prank(user);
        
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        
        vm.expectRevert(SmartAccount.OnlyOwnerOrEntryPoint.selector);
        account.execute(address(target), 0, data);
    }

    function testExecuteWithValue() public {
        vm.prank(owner);
        
        uint256 initialBalance = address(target).balance;
        account.execute(address(target), 1 ether, "");
        
        assertEq(address(target).balance, initialBalance + 1 ether);
    }

    function testExecuteFailsOnRevert() public {
        vm.prank(owner);
        
        bytes memory data = abi.encodeWithSelector(MockTarget.revertFunction.selector);
        
        vm.expectRevert(SmartAccount.ExecutionFailed.selector);
        account.execute(address(target), 0, data);
    }

    function testBatchExecute() public {
        vm.prank(owner);
        
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory calls = new bytes[](2);
        
        targets[0] = address(target);
        targets[1] = address(target);
        values[0] = 0;
        values[1] = 0.5 ether;
        calls[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 123);
        calls[1] = "";
        
        vm.expectEmit(true, true, true, true);
        emit BatchTransactionExecuted(targets, values);
        
        account.executeBatch(targets, values, calls);
        
        assertEq(target.value(), 123);
        assertEq(address(target).balance, 0.5 ether);
    }

    function testBatchExecuteArrayLengthMismatch() public {
        vm.prank(owner);
        
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](1); // Mismatched length
        bytes[] memory calls = new bytes[](2);
        
        vm.expectRevert(SmartAccount.ArrayLengthMismatch.selector);
        account.executeBatch(targets, values, calls);
    }

    function testExecuteDelegate() public {
        vm.prank(owner);
        
        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, 999);
        bytes memory result = account.executeDelegate(address(target), data);
        
        // Delegate call should execute in account's context
        assertEq(result.length, 0); // setValue returns nothing
    }

    function testValidateUserOpSuccess() public {
        UserOperation memory userOp = UserOperation({
            sender: address(account),
            nonce: 0,
            initCode: "",
            callData: "",
            callGasLimit: 100000,
            verificationGasLimit: 100000,
            preVerificationGas: 21000,
            maxFeePerGas: 1e9,
            maxPriorityFeePerGas: 1e9,
            paymasterAndData: "",
            signature: ""
        });
        
        bytes32 userOpHash = keccak256("test");
        
        // Sign the hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, userOpHash); // private key 1 for owner
        userOp.signature = abi.encodePacked(r, s, v);
        
        vm.prank(address(entryPoint));
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        
        assertEq(validationData, 0); // Valid
        assertEq(account.getNonce(), 1); // Nonce incremented
    }

    function testValidateUserOpInvalidNonce() public {
        UserOperation memory userOp = UserOperation({
            sender: address(account),
            nonce: 5, // Wrong nonce
            initCode: "",
            callData: "",
            callGasLimit: 100000,
            verificationGasLimit: 100000,
            preVerificationGas: 21000,
            maxFeePerGas: 1e9,
            maxPriorityFeePerGas: 1e9,
            paymasterAndData: "",
            signature: ""
        });
        
        bytes32 userOpHash = keccak256("test");
        
        vm.prank(address(entryPoint));
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        
        assertEq(validationData, 1); // Invalid
    }

    function testValidateUserOpInvalidSignature() public {
        UserOperation memory userOp = UserOperation({
            sender: address(account),
            nonce: 0,
            initCode: "",
            callData: "",
            callGasLimit: 100000,
            verificationGasLimit: 100000,
            preVerificationGas: 21000,
            maxFeePerGas: 1e9,
            maxPriorityFeePerGas: 1e9,
            paymasterAndData: "",
            signature: abi.encodePacked(bytes32(0), bytes32(0), uint8(27)) // Invalid signature
        });
        
        bytes32 userOpHash = keccak256("test");
        
        vm.prank(address(entryPoint));
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        
        assertEq(validationData, 1); // Invalid
    }

    function testValidateUserOpWithMissingFunds() public {
        UserOperation memory userOp = UserOperation({
            sender: address(account),
            nonce: 0,
            initCode: "",
            callData: "",
            callGasLimit: 100000,
            verificationGasLimit: 100000,
            preVerificationGas: 21000,
            maxFeePerGas: 1e9,
            maxPriorityFeePerGas: 1e9,
            paymasterAndData: "",
            signature: ""
        });
        
        bytes32 userOpHash = keccak256("test");
        
        // Sign the hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, userOpHash);
        userOp.signature = abi.encodePacked(r, s, v);
        
        uint256 initialBalance = address(entryPoint).balance;
        
        vm.prank(address(entryPoint));
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 1 ether);
        
        assertEq(validationData, 0); // Valid
        assertEq(address(entryPoint).balance, initialBalance + 1 ether);
    }

    function testOnlyEntryPointCanValidate() public {
        UserOperation memory userOp;
        bytes32 userOpHash = keccak256("test");
        
        vm.prank(user);
        vm.expectRevert(SmartAccount.OnlyEntryPoint.selector);
        account.validateUserOp(userOp, userOpHash, 0);
    }

    function testReceiveEther() public {
        uint256 initialBalance = address(account).balance;
        
        vm.prank(user);
        (bool success,) = payable(address(account)).call{value: 1 ether}("");
        
        assertTrue(success);
        assertEq(address(account).balance, initialBalance + 1 ether);
    }

    function testUpgradeability() public {
        // Deploy new implementation
        SmartAccount newImpl = new SmartAccount(address(entryPoint));
        
        vm.prank(owner);
        account.upgradeTo(address(newImpl));
        
        // Account should still work after upgrade
        assertTrue(account.isInitialized());
        assertEq(account.owner(), owner);
    }

    function testUpgradeFailsForNonOwner() public {
        SmartAccount newImpl = new SmartAccount(address(entryPoint));
        
        vm.prank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        account.upgradeTo(address(newImpl));
    }

    // Fuzz testing
    function testFuzzExecute(address target_, uint256 value_, bytes calldata data_) public {
        vm.assume(target_ != address(0));
        vm.assume(value_ <= address(account).balance);
        
        vm.prank(owner);
        
        if (target_.code.length == 0) {
            // EOA target - should succeed
            account.execute(target_, value_, data_);
        } else {
            // Contract target - may succeed or fail
            try account.execute(target_, value_, data_) {
                // Success case
            } catch {
                // Failure case - expected for some inputs
            }
        }
    }

    function testFuzzValidateUserOp(uint256 nonce_, bytes32 hash_) public {
        UserOperation memory userOp = UserOperation({
            sender: address(account),
            nonce: nonce_,
            initCode: "",
            callData: "",
            callGasLimit: 100000,
            verificationGasLimit: 100000,
            preVerificationGas: 21000,
            maxFeePerGas: 1e9,
            maxPriorityFeePerGas: 1e9,
            paymasterAndData: "",
            signature: ""
        });
        
        // Sign with owner's key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, hash_);
        userOp.signature = abi.encodePacked(r, s, v);
        
        vm.prank(address(entryPoint));
        uint256 validationData = account.validateUserOp(userOp, hash_, 0);
        
        if (nonce_ == account.getNonce()) {
            assertEq(validationData, 0); // Should be valid
        } else {
            assertEq(validationData, 1); // Should be invalid
        }
    }
}