// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

contract ABITest is Test {
    struct Foo {
        uint256 x;
        uint256[] a;
    }

    function setUp() public {}

    function transfer(uint256[] memory amount, address to) external {
        for (uint256 i = 0; i < amount.length; i++) {
            console2.log(amount[i], to);
        }
    }

    function play(string[] memory str) external {
        for (uint256 i = 0; i < str.length; i++) {
            console2.log(str[i]);
        }
    }

    function foo(Foo[] calldata f) external pure {
        for (uint256 i = 0; i < f.length; i++) {
            console2.log(f[i].x);
        }
    }

    /// @dev Compares manual ABI encoding with `abi.encodeWithSelector` for a function
    /// that takes a dynamic array (`uint256[]`) and an address.
    function test_abi_encoding_comparison_transfer() public {
        // --- Test Data ---
        uint256[3] memory amount = [uint256(1), uint256(2), uint256(3)];
        address addr = makeAddr("addr");

        // `transfer` expects `uint256[]`, so we must convert the fixed-size array to a dynamic one.
        uint256[] memory dynamicAmount = new uint256[](amount.length);
        for (uint256 i = 0; i < amount.length; i++) {
            dynamicAmount[i] = amount[i];
        }

        // --- Encoding ---
        // 1. Standard encoding using `encodeWithSelector`
        bytes memory dataWithSelector = abi.encodeWithSelector(
            ABITest.transfer.selector,
            dynamicAmount,
            addr
        );

        // 2. Manual encoding (equivalent to `encodeWithSelector`)
        bytes memory manualData = abi.encodePacked(
            ABITest.transfer.selector,
            abi.encode(dynamicAmount, addr)
        );

        // --- Verification ---
        console2.log("--- Calldata for transfer(uint256[],address) ---");
        console2.logBytes(dataWithSelector);
        assertEq(dataWithSelector, manualData, "Manual encoding should match `encodeWithSelector`");

        (bool success, ) = address(this).call(dataWithSelector);
        assertTrue(success, "Call to transfer should succeed");
    }

    /// @dev Compares manual ABI encoding with `abi.encodeWithSelector` for a function
    /// that takes a dynamic array of strings (`string[]`).
    function test_abi_encoding_comparison_play() public {
        // --- Test Data ---
        string[] memory str = new string[](2);
        str[0] = "alice";
        str[1] = "bob";

        // --- Encoding ---
        // 1. Standard encoding
        bytes memory dataWithSelector = abi.encodeWithSelector(ABITest.play.selector, str);

        // 2. Manual encoding
        bytes memory manualData = abi.encodePacked(ABITest.play.selector, abi.encode(str));

        // --- Verification ---
        console2.log("--- Calldata for play(string[]) ---");
        console2.logBytes(dataWithSelector);
        assertEq(dataWithSelector, manualData, "Manual encoding should match `encodeWithSelector`");

        (bool success, ) = address(this).call(dataWithSelector);
        assertTrue(success, "Call to play should succeed");
    }

    /// @dev Compares manual ABI encoding with `abi.encodeWithSelector` for a function
    /// that takes a dynamic array of structs (`Foo[]`).
    function test_abi_encoding_comparison_foo() public {
        // --- Test Data ---
        Foo[] memory fooArr = new Foo[](2);
        uint256[] memory one = new uint256[](3);
        one[0] = 0x11;
        one[1] = 0x12;
        one[2] = 0x13;
        fooArr[0] = Foo(0x41, one);

        uint256[] memory two = new uint256[](2);
        two[0] = 0x21;
        two[1] = 0x22;
        fooArr[1] = Foo(0x42, two);

        // --- Encoding ---
        // 1. Standard encoding
        bytes memory dataWithSelector = abi.encodeWithSelector(ABITest.foo.selector, fooArr);

        // 2. Manual encoding
        bytes memory manualData = abi.encodePacked(ABITest.foo.selector, abi.encode(fooArr));

        // --- Verification ---
        console2.log("--- Calldata for foo(Foo[]) ---");
        console2.logBytes(dataWithSelector);
        assertEq(dataWithSelector, manualData, "Manual encoding should match `encodeWithSelector`");

        (bool success, ) = address(this).call(dataWithSelector);
        assertTrue(success, "Call to foo should succeed");
    }

    // `internal` and `private` functions can accept fixed-size arrays as parameters
    // because they are not part of the contract's public ABI.
    function transferInternal(uint256[3] memory amount, address to) internal {
        for (uint256 i = 0; i < amount.length; i++) {
            console2.log("Internal call:", amount[i], to);
        }
    }

    /// @dev Demonstrates that fixed-size arrays can be passed to internal functions.
    function test_fixed_array_internal_call() public {
        uint256[3] memory amount = [uint256(10), uint256(20), uint256(30)];
        address addr = makeAddr("internal_addr");

        // A direct call to an internal function with a fixed-size array is allowed.
        // The ABI is not involved in internal function calls, so no encoding mismatch occurs.
        transferInternal(amount, addr);
    }
}
