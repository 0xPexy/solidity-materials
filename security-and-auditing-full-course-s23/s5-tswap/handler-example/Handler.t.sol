// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {HandlerStatefulFuzzCatches} from "../../../src/invariant-break/HandlerStatefulFuzzCatches.sol";
import {YieldERC20} from "../../mocks/YieldERC20.sol";
import {MockUSDC} from "../../mocks/MockUSDC.sol";
import {console} from "forge-std/console.sol";

contract MyHandler is Test {
    address user;
    YieldERC20 yerc;
    MockUSDC usdc;
    HandlerStatefulFuzzCatches hsfc;

    modifier useUser() {
        vm.startPrank(user);
        _;
        vm.stopPrank();
    }

    constructor(
        address _user,
        YieldERC20 _yerc,
        MockUSDC _usdc,
        HandlerStatefulFuzzCatches _hsfc
    ) {
        user = _user;
        yerc = _yerc;
        usdc = _usdc;
        hsfc = _hsfc;
    }

    function depositYERC(uint _amount) public useUser {
        uint amount = bound(_amount, 0, yerc.balanceOf(user));
        yerc.approve(address(hsfc), amount);
        hsfc.depositToken(yerc, amount);
        // can do function-level assertions also in handler
        // assertEq(asset.balanceOf(address(this)), beforeBalance - assets);
    }

    function withdrawYERC() public useUser {
        hsfc.withdrawToken(yerc);
    }

    function depositUSDC(uint _amount) public useUser {
        uint amount = bound(_amount, 0, usdc.balanceOf(user));
        usdc.approve(address(hsfc), amount);
        hsfc.depositToken(usdc, amount);
    }

    function withdrawUSDC() public useUser {
        hsfc.withdrawToken(usdc);
    }
}
