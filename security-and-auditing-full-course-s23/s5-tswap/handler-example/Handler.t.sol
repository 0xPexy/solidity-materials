// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {HandlerStatefulFuzzCatches} from "../../src/invariant-break/HandlerStatefulFuzzCatches.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
// This is for weird erc20
import {YieldERC20} from "../mocks/WeirdERC20.sol";

contract Handler is Test {
    HandlerStatefulFuzzCatches hsfc;
    MockUSDC musdc;
    YieldERC20 yerc20;
    address user;

    constructor(
        HandlerStatefulFuzzCatches _hsfc,
        MockUSDC _musdc,
        YieldERC20 _yerc20,
        address _user
    ) {
        hsfc = _hsfc;
        musdc = _musdc;
        yerc20 = _yerc20;
        user = _user;
    }

    function depositYERC20(uint256 _amount) public {
        uint amount = bound(_amount, 0, yerc20.balanceOf(user));
        vm.startPrank(user);
        yerc20.approve(address(hsfc), amount);
        hsfc.depositToken(yerc20, amount);
        vm.stopPrank();
    }

    function depositMUSDC(uint256 _amount) public {
        uint amount = bound(_amount, 0, musdc.balanceOf(user));
        vm.startPrank(user);
        musdc.approve(address(hsfc), amount);
        hsfc.depositToken(musdc, amount);
        vm.stopPrank();
    }

    function withdrawYERC20() public {
        vm.startPrank(user);
        hsfc.withdrawToken(yerc20);
        vm.stopPrank();
    }

    function withdrawMUSDC() public {
        vm.startPrank(user);
        hsfc.withdrawToken(musdc);
        vm.stopPrank();
    }
}
