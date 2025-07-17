// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

contract ABITest is Test {
    struct Foo {
        uint256 x;
        uint256[] a;
    }

    function transfer(uint256[] memory amount, address to) external pure {
        for (uint256 i = 0; i < amount.length; i++) {
            console2.log("amount:", amount[i], "to:", to);
        }
    }

    function play(string[] memory str) external pure {
        for (uint256 i = 0; i < str.length; i++) {
            console2.log("str:", str[i]);
        }
    }

    function foo(Foo[] calldata f) external pure {
        for (uint256 i = 0; i < f.length; i++) {
            console2.log("foo.x:", f[i].x);
            for (uint256 j = 0; j < f[i].a.length; j++) {
                console2.log("foo.a:", f[i].a[j]);
            }
        }
    }

    function test_DynamicArrayEncoding() public {
        console2.log("\n--- Testing Dynamic uint256[] Encoding ---");
        uint256[3] memory staticAmount = [uint256(1), uint256(2), uint256(3)];
        address addr = makeAddr("recipient");

        // For external calls, static arrays must be converted to dynamic memory arrays
        // to match the function signature and ensure correct ABI encoding.
        uint256[] memory dynamicAmount = new uint256[](staticAmount.length);
        for (uint256 i = 0; i < staticAmount.length; i++) {
            dynamicAmount[i] = staticAmount[i];
        }

        bytes memory encodedData = abi.encodeWithSelector(
            ABITest.transfer.selector,
            dynamicAmount,
            addr
        );
        console2.logBytes(encodedData);

        (bool success, ) = address(this).call(encodedData);
        assertTrue(success, "Call with dynamic uint256[] failed");
    }

    function test_StringArrayEncoding() public {
        console2.log("\n--- Testing Dynamic string[] Encoding ---");
        string[] memory strArray = new string[](2);
        strArray[0] = "alice";
        strArray[1] = "bob";

        bytes memory encodedData = abi.encodeWithSelector(ABITest.play.selector, strArray);
        console2.logBytes(encodedData);

        (bool success, ) = address(this).call(encodedData);
        assertTrue(success, "Call with dynamic string[] failed");
    }

    function test_StructArrayEncoding() public {
        console2.log("\n--- Testing Dynamic Struct[] Encoding ---");
        Foo[] memory fooArr = new Foo[](2);

        uint256[] memory one = new uint256[](3);
        one[0] = 0x11; one[1] = 0x12; one[2] = 0x13;
        fooArr[0] = Foo({x: 0x41, a: one});

        uint256[] memory two = new uint256[](2);
        two[0] = 0x21; two[1] = 0x22;
        fooArr[1] = Foo({x: 0x42, a: two});

        bytes memory encodedData = abi.encodeWithSelector(ABITest.foo.selector, fooArr);
        console2.logBytes(encodedData);
        
        (bool success, ) = address(this).call(encodedData);
        assertTrue(success, "Call with dynamic struct[] failed");
    }

    // --- Internal Function with Fixed-Size Array ---

    function transferInternal(uint256[3] memory amount, address to) internal pure {
        for (uint256 i = 0; i < amount.length; i++) {
            console2.log("Internal call:", amount[i], "to:", to);
        }
    }

    function test_fixed_array_internal_call() public {
        console2.log("\n--- Testing Internal Call with Fixed-Size Array ---");
        uint256[3] memory amount = [uint256(10), uint256(20), uint256(30)];
        address addr = makeAddr("internal_recipient");

        // Direct internal calls do not involve ABI encoding, so fixed-size arrays are allowed.
        transferInternal(amount, addr);
    }
}
