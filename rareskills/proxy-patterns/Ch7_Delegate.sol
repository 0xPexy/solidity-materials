// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

contract DelegatecallTest is Test {
    Called calledContract;
    Caller callerContract;

    function setUp() public {
        calledContract = new Called();
        callerContract = new Caller();
    }

    /// @dev Demonstrates that `delegatecall` preserves the original `msg.data` of the calling context.
    function test_delegatecall_preserves_msg_data() public {
        console2.log("--- Testing msg.data preservation in delegatecall ---");

        bytes memory calldataPayload = abi.encodeWithSignature(
            "delegatecallAndReturnMsgData(address)",
            address(calledContract)
        );
        console2.log("Original calldata to Caller:");
        console2.logBytes(calldataPayload);

        (bool success, ) = address(callerContract).call(calldataPayload);
        assertTrue(success, "Call to callerContract should succeed");
    }

    /// @dev Differentiates CODESIZE and EXTCODESIZE opcodes within a delegatecall.
    /// This test proves the core concept of execution context vs. environment.
    function test_codesize_vs_extcodesize_in_delegatecall() public {
        console2.log("--- CODESIZE vs. EXTCODESIZE in delegatecall ---");

        uint callerCodeSize = address(callerContract).code.length;
        uint calledCodeSize = address(calledContract).code.length;
        console2.log("Caller Contract Code Size (via EXTCODESIZE):", callerCodeSize);
        console2.log("Called Contract Code Size (via EXTCODESIZE):", calledCodeSize);

        // This call will execute `getBothCodeSizes()` from `Called` in the context of `Caller`.
        (uint from_codesize_opcode, uint from_address_this_code_length) =
            callerContract.delegatecallAndGetBothCodeSizes(
                address(calledContract)
            );

        console2.log("Result from `codesize()` opcode:", from_codesize_opcode);
        console2.log("Result from `address(this).code.length` (EXTCODESIZE):", from_address_this_code_length);

        // Key Assertion 1: `codesize()` returns the size of the code being executed (the CALLEE).
        assertEq(
            from_codesize_opcode,
            calledCodeSize,
            "FAIL: `codesize()` should return the CALLEE's code size."
        );

        // Key Assertion 2: `address(this)` is the CALLER's address. `address(this).code.length`
        // uses EXTCODESIZE on the caller's address, returning the CALLER's code size.
        assertEq(
            from_address_this_code_length,
            callerCodeSize,
            "FAIL: `address(this).code.length` should return the CALLER's code size."
        );
    }
    
    /// @dev Shows that EXTCODESIZE (called via assembly) is unaffected by delegatecall context.
    function test_extcodesize_is_unaffected_by_delegatecall() public {
        console2.log("--- EXTCODESIZE (asm) unaffected by delegatecall context ---");

        uint callerCodeSize = address(callerContract).code.length;
        uint calledCodeSize = address(calledContract).code.length;

        // 1. Get the caller's code size by passing its address to EXTCODESIZE within the delegatecall.
        uint returnedCallerSize = callerContract.delegatecallAndGetExtCodeSizeWithAsm(
            address(calledContract),
            address(callerContract)
        );
        console2.log("Probing caller's address via delegatecall'd EXTCODESIZE:", returnedCallerSize);
        assertEq(returnedCallerSize, callerCodeSize, "Should return caller's size");

        // 2. Get the callee's code size by passing its address.
        uint returnedCalledSize = callerContract.delegatecallAndGetExtCodeSizeWithAsm(
            address(calledContract),
            address(calledContract)
        );
        console2.log("Probing callee's address via delegatecall'd EXTCODESIZE:", returnedCalledSize);
        assertEq(returnedCalledSize, calledCodeSize, "Should return callee's size");
    }

    /// @dev Demonstrates making a `delegatecall` using Yul (inline assembly).
    function test_delegatecall_with_yul() public {
        console2.log("--- Testing delegatecall with Yul ---");

        uint result = callerContract.delegatecallWithYul(address(calledContract));
        console2.log("Result from Yul delegatecall:", result);

        assertEq(result, 1, "Yul delegatecall should return 1");
    }
}

/// @title Called
/// @notice This contract contains the logic that will be executed via delegatecall.
contract Called {
    function returnMsgData() public pure returns (bytes memory) {
        console2.log("==> Executing in Called.returnMsgData <==");
        console2.log("msg.data in Called's context:");
        console2.logBytes(msg.data);
        return msg.data;
    }

    function getBothCodeSizes()
        public
        view
        returns (uint from_codesize_opcode, uint from_address_this_code_length)
    {
        assembly {
            from_codesize_opcode := codesize()
        }
        from_address_this_code_length = address(this).code.length;
    }

    function getExtCodeSizeWithAsm(address _addr) public view returns (uint size) {
        assembly {
            size := extcodesize(_addr)
        }
    }

    function one() public pure returns (uint) {
        return 1;
    }
}

/// @title Caller
/// @notice This contract makes delegatecalls to the `Called` contract.
contract Caller {
    function delegatecallAndReturnMsgData(
        address _target
    ) public returns (bytes memory data) {
        console2.log("==> Executing in Caller.delegatecallAndReturnMsgData <==");
        console2.log("msg.data in Caller's context:");
        console2.logBytes(msg.data);

        (bool success, bytes memory returnData) = _target.delegatecall(
            abi.encodeWithSignature("returnMsgData()")
        );
        require(success, "Delegatecall failed");
        data = returnData;
    }

    function delegatecallAndGetBothCodeSizes(
        address _target
    ) public returns (uint, uint) {
        (bool success, bytes memory returnData) = _target.delegatecall(
            abi.encodeWithSignature("getBothCodeSizes()")
        );
        require(success, "Delegatecall failed");
        return abi.decode(returnData, (uint, uint));
    }

    function delegatecallAndGetExtCodeSizeWithAsm(address _target, address _addrToProbe) public returns (uint) {
        (bool success, bytes memory returnData) = _target.delegatecall(
            abi.encodeWithSignature("getExtCodeSizeWithAsm(address)", _addrToProbe)
        );
        require(success, "Delegatecall failed");
        return abi.decode(returnData, (uint));
    }

    function delegatecallWithYul(address _target) public returns (uint data) {
        assembly {
            let selector := 0x901717d100000000000000000000000000000000000000000000000000000000
            mstore(0x00, selector)

            let result := delegatecall(gas(), _target, 0x00, 0x04, 0x00, 0x20)

            if eq(result, 0) {
                revert(0, 0)
            }
            data := mload(0x00)
        }
    }
}
