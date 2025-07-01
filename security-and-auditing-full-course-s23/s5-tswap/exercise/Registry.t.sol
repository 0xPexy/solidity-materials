// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Registry, RegistryFixed} from "./Registry.sol";

contract RegistryTest is Test {
    Registry registry;
    address alice;

    function setUp() public {
        alice = makeAddr("alice");

        registry = new Registry();
    }

    function test_register() public {
        uint256 amountToPay = registry.PRICE();

        vm.deal(alice, amountToPay);
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = address(alice).balance;

        registry.register{value: amountToPay}();

        uint256 aliceBalanceAfter = address(alice).balance;

        assertTrue(registry.isRegistered(alice), "Did not register user");
        assertEq(
            address(registry).balance,
            registry.PRICE(),
            "Unexpected registry balance"
        );
        assertEq(
            aliceBalanceAfter,
            aliceBalanceBefore - registry.PRICE(),
            "Unexpected user balance"
        );
    }

    /** Code your fuzz test here */
    function test_register_fuzzing_amount(uint256 _amount) public {
        uint256 amountToPay = bound(_amount, 1e17, 10e18);
        vm.deal(alice, amountToPay);
        vm.startPrank(alice);
        uint256 price = registry.PRICE();
        uint256 aliceBalanceBefore = address(alice).balance;

        if (aliceBalanceBefore < price) {
            vm.expectPartialRevert(Registry.PaymentNotEnough.selector);
        }
        registry.register{value: amountToPay}();

        if (aliceBalanceBefore < price) {
            return;
        }

        uint256 aliceBalanceAfter = address(alice).balance;

        assertTrue(registry.isRegistered(alice), "Did not register user");
        assertEq(
            address(registry).balance,
            price,
            "Unexpected registry balance"
        );
        assertEq(
            aliceBalanceAfter,
            aliceBalanceBefore - registry.PRICE(),
            "Unexpected user balance"
        );
    }
}

contract RegistryFixedTest is Test {
    RegistryFixed registry;
    address alice;

    function setUp() public {
        alice = makeAddr("alice");

        registry = new RegistryFixed();
    }

    function test_register_fixed() public {
        uint256 amountToPay = registry.PRICE();

        vm.deal(alice, amountToPay);
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = address(alice).balance;

        registry.register{value: amountToPay}();

        uint256 aliceBalanceAfter = address(alice).balance;

        assertTrue(registry.isRegistered(alice), "Did not register user");
        assertEq(
            address(registry).balance,
            registry.PRICE(),
            "Unexpected registry balance"
        );
        assertEq(
            aliceBalanceAfter,
            aliceBalanceBefore - registry.PRICE(),
            "Unexpected user balance"
        );
    }

    /** Code your fuzz test here */
    function test_register_fuzzing_amount_fixed(uint256 _amount) public {
        uint256 amountToPay = bound(_amount, 1e17, 10e18);
        vm.deal(alice, amountToPay);
        vm.startPrank(alice);
        uint256 price = registry.PRICE();
        uint256 aliceBalanceBefore = address(alice).balance;

        if (aliceBalanceBefore < price) {
            vm.expectPartialRevert(RegistryFixed.PaymentNotEnough.selector);
        }
        registry.register{value: amountToPay}();

        if (aliceBalanceBefore < price) {
            return;
        }

        uint256 aliceBalanceAfter = address(alice).balance;

        assertTrue(registry.isRegistered(alice), "Did not register user");
        assertEq(
            address(registry).balance,
            price,
            "Unexpected registry balance"
        );
        assertEq(
            aliceBalanceAfter,
            aliceBalanceBefore - registry.PRICE(),
            "Unexpected user balance"
        );
    }
}
