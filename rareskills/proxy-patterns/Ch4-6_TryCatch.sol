// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

contract TryCatchTest is Test {
    Revert r;

    function setUp() public {
        r = new Revert();
    }

    function test_tryCatch() public {
        (, bytes memory err) = address(r).call(
            abi.encodeWithSignature("revertWithoutLog()")
        );
        console2.logBytes(err);
        (, err) = address(r).call(abi.encodeWithSignature("revertWithMsg()"));
        console2.logBytes(err);
        bytes4 selector = bytes4(keccak256(abi.encodePacked("Error(string)")));
        bytes memory s = abi.encode("error!");
        bytes memory rr = abi.encodePacked(selector, s);
        console2.logBytes(rr);
        (, err) = address(r).call(abi.encodeWithSignature("requireWithMsg()"));
        console2.logBytes(err);
        (, err) = address(r).call(abi.encodeWithSignature("revertWithErr()"));
        console2.logBytes(err);
        selector = bytes4(keccak256(abi.encodePacked("CustomError(uint256)")));
        console2.logBytes4(selector);
        // --- Assert Test ---
        selector = bytes4(keccak256(abi.encodePacked("Panic(uint256)")));
        console2.logBytes4(selector);
        (, err) = address(r).call(abi.encodeWithSignature("assertBasic()"));
        console2.logBytes(err);
        (, err) = address(r).call(
            abi.encodeWithSignature("assertDivision(uint256,uint256)", 1, 0)
        );
        console2.logBytes(err);
        (, err) = address(r).call{gas: 2300}(
            abi.encodeWithSignature("revertOutOfGas()")
        );
        console2.logBytes(err);

        // --- Asm ---
        // revert(startingMemorySlot, totalMemorySize)
        console2.log("--- Test Assembly ---");
        (, err) = address(r).call(abi.encodeWithSignature("revertWithAsm()"));
        console2.logBytes(err);
        (, err) = address(r).call(
            abi.encodeWithSignature("revertWithAsmMsg()")
        );
        console2.logBytes(err);

        // --- Try-Catch ---
        console2.log("--- Try-Catch ---");
        address user = makeAddr("user");
        vm.startPrank(user);
        for (uint i = 0; i < 10; i++) {
            try r.revertAll() {
                console2.log("%s - success!", r.counter());
            } catch Panic(uint256 errCode) {
                console2.log("%s - panic: %s", r.counter(), errCode);
            } catch Error(string memory reason) {
                console2.log("%s - string error: %s", r.counter(), reason);
            } catch (bytes memory lowData) {
                if (lowData.length == 0) {
                    console2.log("%s - revert without message", r.counter());
                } else if (
                    bytes4(lowData) ==
                    bytes4(keccak256(abi.encodePacked("CustomError(uint256)")))
                ) {
                    // this acts like "catch CustomError"
                    console2.log("%s - revert with custom error", r.counter());
                    console2.logBytes(lowData);
                } else if (bytes4(lowData) == bytes4(hex"8e4a23d6")) {
                    console2.log("%s - revert with Unauthorized", r.counter());
                    console2.logBytes(lowData);
                }
            }
            r.decreaseCounter();
        }
        vm.stopPrank();
    }
}

contract Revert {
    uint256 public counter = 10;
    error CustomError(uint256);
    error Unauthorized(address);

    constructor() {}

    function revertWithoutLog() external pure {
        revert();
    }

    function revertWithMsg() external pure {
        revert("error!");
    }

    function revertWithErr() external pure {
        revert CustomError(1);
    }

    function requireWithMsg() external pure {
        require(false, "error!");
    }

    function assertBasic() external pure {
        assert(false);
    }

    function assertDivision(
        uint256 a,
        uint256 b
    ) external pure returns (uint256) {
        return a / b;
    }

    function revertOutOfGas() external pure {
        while (true) {}
    }

    function revertWithAsm() external pure {
        assembly {
            revert(0, 0)
        }
    }

    function revertWithAsmMsg() external pure {
        bytes4 selector = bytes4(keccak256(abi.encodePacked("Error(string)")));
        assembly {
            mstore(0x00, selector)
            mstore(0x04, 0x20)
            mstore(0x24, 0x6)
            mstore(0x44, "error!")
            revert(0x00, 0x64)
        }
    }

    function revertAll() external view {
        if (counter == 10) {
            revert();
        }

        if (counter == 9) {
            uint256 a = 0;
            counter / a;
        }

        if (counter == 8) {
            revert("error!");
        }

        if (counter == 7) {
            assert(false);
        }

        if (counter == 6) {
            revert CustomError(counter);
        }

        if (counter == 5) {
            assembly {
                revert(0, 0)
            }
        }

        if (counter == 4) {
            bytes4 selector = bytes4(
                keccak256(abi.encodePacked("CustomError(uint256)"))
            );
            assembly {
                mstore(0x00, selector)
                mstore(0x04, 4)
                revert(0x00, 0x24)
            }
        }

        if (counter == 3) {
            // revert with Unauthorized: 0x8e4a23d6
            // using mstore8 + caller()
            assembly {
                mstore8(0x00, 0x8e)
                mstore8(0x01, 0x4a)
                mstore8(0x02, 0x23)
                mstore8(0x03, 0xd6)
                // make sure that address should be stored to memory with 32bytes, not 20bytes
                // memory(stack) should always be handled as ABI format
                // in contrast, storage stores more efficient way
                mstore(0x04, caller())
                revert(0x00, add(4, 32))
            }
        }
        if (counter == 2) {
            revert Unauthorized(msg.sender);
        }
    }

    function decreaseCounter() external {
        counter--;
    }
}
