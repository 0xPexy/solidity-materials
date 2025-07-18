// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

contract TryCatchTest is Test {
    Revert revertContract;

    function setUp() public {
        revertContract = new Revert();
    }

    /// @dev Inspects the raw data returned by different types of reverts.
    function test_inspectRawRevertData() public {
        console2.log("--- Inspecting Raw Revert Data ---");
        (, bytes memory returnedData) = address(revertContract).call(
            abi.encodeWithSignature("revertWithEmptyData()")
        );
        console2.log("Revert with empty data:");
        console2.logBytes(returnedData);

        (, returnedData) = address(revertContract).call(
            abi.encodeWithSignature("revertWithString()")
        );
        console2.log("Revert with string:");
        console2.logBytes(returnedData);

        (, returnedData) = address(revertContract).call(
            abi.encodeWithSignature("requireWithString()")
        );
        console2.log("Require with string:");
        console2.logBytes(returnedData);

        (, returnedData) = address(revertContract).call(
            abi.encodeWithSignature("revertWithCustomError()")
        );
        console2.log("Revert with custom error:");
        console2.logBytes(returnedData);

        // --- Panic ---
        (, returnedData) = address(revertContract).call(
            abi.encodeWithSignature("assertWithFalse()")
        );
        console2.log("Panic from assert(false):");
        console2.logBytes(returnedData);

        (, returnedData) = address(revertContract).call(
            abi.encodeWithSignature(
                "triggerPanicViaDivisionByZero(uint256,uint256)",
                1,
                0
            )
        );
        console2.log("Panic from division by zero:");
        console2.logBytes(returnedData);

        // --- Assembly Reverts ---
        console2.log("--- Assembly Reverts ---");
        (, returnedData) = address(revertContract).call(
            abi.encodeWithSignature("revertWithAsmEmptyData()")
        );
        console2.log("Assembly revert with empty data:");
        console2.logBytes(returnedData);

        (, returnedData) = address(revertContract).call(
            abi.encodeWithSignature("revertWithAsmString()")
        );
        console2.log("Assembly revert with string:");
        console2.logBytes(returnedData);
    }

    /// @dev Demonstrates handling various error types using try/catch.
    function test_handleErrorsWithTryCatch() public {
        console2.log("--- Handling Errors with Try/Catch ---");
        address user = makeAddr("user");
        vm.startPrank(user);

        // Loop to trigger each revert case in `revertAll`
        for (uint i = 0; i < 10; i++) {
            uint256 counterBefore = revertContract.counter();
            try revertContract.revertAll() {
                // This block should not be reached as `revertAll` always reverts or panics
                // if counter > 1.
                console2.log("Counter %s: Success (should not happen if counter > 1)", counterBefore);
            } catch Panic(uint256 panicCode) {
                console2.log("Counter %s: Caught Panic with code: %s", counterBefore, panicCode);
            } catch Error(string memory errorMessage) {
                console2.log("Counter %s: Caught Error with message: '%s'", counterBefore, errorMessage);
            } catch (bytes memory lowLevelData) {
                // This is a general-purpose catch block for other errors.
                if (lowLevelData.length == 0) {
                    console2.log("Counter %s: Caught revert with no data", counterBefore);
                } else if (bytes4(lowLevelData) == Revert.CustomError.selector) {
                    uint256 val;
                    assembly {
                        val := mload(add(lowLevelData, 0x24))
                    }
                    console2.log("Counter %s: Caught CustomError(%s)", counterBefore, val);
                } else if (bytes4(lowLevelData) == Revert.Unauthorized.selector) {
                    address returnedAddr;
                    assembly {
                        returnedAddr := mload(add(lowLevelData, 0x24))
                    }
                    console2.log("Counter %s: Caught Unauthorized for address: %s", counterBefore, returnedAddr);
                } else {
                    console2.log("Counter %s: Caught unknown low-level data:", counterBefore);
                    console2.logBytes(lowLevelData);
                }
            }

            if (revertContract.counter() > 0) {
                revertContract.decreaseCounter();
            }
        }
        vm.stopPrank();
    }
}

contract Revert {
    uint256 public counter = 10;

    error CustomError(uint256 value);
    error Unauthorized(address user);

    constructor() {}

    function revertWithEmptyData() external pure {
        revert();
    }

    function revertWithString() external pure {
        revert("error!");
    }

    function revertWithCustomError() external pure {
        revert CustomError(1);
    }

    function requireWithString() external pure {
        require(false, "error!");
    }

    function assertWithFalse() external pure {
        assert(false); // Panics with 0x01 (Assert Error)
    }

    function triggerPanicViaDivisionByZero(
        uint256 a,
        uint256 b
    ) external pure returns (uint256) {
        return a / b; // Panics with 0x12 (Division by Zero) if b is 0
    }

    function triggerOutOfGas() external pure {
        // This will run out of gas and revert.
        // The try/catch block will not catch this as it's a transactional failure.
        while (true) {}
    }

    function revertWithAsmEmptyData() external pure {
        assembly {
            // revert(memory_offset, memory_size)
            revert(0, 0)
        }
    }

    function revertWithAsmString() external pure {
        // Manually craft the `Error(string)` revert message in memory.
        bytes4 selector = bytes4(keccak256(abi.encodePacked("Error(string)")));
        string memory message = "error!";
        assembly {
            // The final revert data will be: selector (4 bytes) + abi.encode(message)
            let free_mem_ptr := mload(0x40) // Get free memory pointer
            mstore(free_mem_ptr, selector) // Store the selector
            mstore(add(free_mem_ptr, 0x04), 0x20) // Store the offset to the string data (32 bytes from this point)
            mstore(add(free_mem_ptr, 0x24), mload(message)) // Store the length of the string
            mstore(add(free_mem_ptr, 0x44), message) // Store the string data itself
            revert(free_mem_ptr, 0x64) // Revert with the crafted data
        }
    }

    /// @dev A state machine that reverts differently based on the `counter` value.
    /// Used to test various catch blocks.
    function revertAll() external view {
        if (counter == 10) {
            revert(); // Caught by `catch (bytes memory lowLevelData)` with length 0
        }
        if (counter == 9) {
            uint256 a = 0;
            counter / a; // Caught by `catch Panic`
        }
        if (counter == 8) {
            revert("error!"); // Caught by `catch Error(string)`
        }
        if (counter == 7) {
            assert(false); // Caught by `catch Panic`
        }
        if (counter == 6) {
            revert CustomError(counter); // Caught by low-level catch and decoded
        }
        if (counter == 5) {
            assembly {
                revert(0, 0)
            }
        }
        if (counter == 4) {
            // Manually revert with CustomError selector and data
            bytes4 customErrorSelector = CustomError.selector;
            assembly {
                let free_mem_ptr := mload(0x40)
                mstore(free_mem_ptr, customErrorSelector)
                mstore(add(free_mem_ptr, 0x04), 4) // Store the value for the error
                revert(free_mem_ptr, 0x24) // Revert with 36 bytes of data
            }
        }
        if (counter == 3) {
            // Manually revert with Unauthorized selector and data
            bytes4 unauthorizedSelector = Unauthorized.selector;
            assembly {
                let free_mem_ptr := mload(0x40)
                mstore(free_mem_ptr, unauthorizedSelector)
                mstore(add(free_mem_ptr, 0x04), caller()) // Store the caller's address
                revert(free_mem_ptr, 0x24) // Revert with 36 bytes of data
            }
        }
        if (counter == 2) {
            revert Unauthorized(msg.sender); // Caught by low-level catch and decoded
        }
    }

    function decreaseCounter() external {
        if (counter > 0) {
            counter--;
        }
    }
}
