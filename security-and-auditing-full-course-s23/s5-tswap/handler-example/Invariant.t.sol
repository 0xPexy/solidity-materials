// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {HandlerStatefulFuzzCatches} from "../../src/invariant-break/HandlerStatefulFuzzCatches.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {YieldERC20} from "../mocks/WeirdERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Handler} from "./Handler.t.sol";

contract HandlerCatchesTest is StdInvariant, Test {
    HandlerStatefulFuzzCatches sfc;
    MockUSDC musdc;
    YieldERC20 yerc;
    address user = makeAddr("user");
    IERC20[] public supportedTokens;
    uint256 public initAmount;
    Handler h;

    function setUp() public {
        vm.startPrank(user);
        yerc = new YieldERC20();
        initAmount = yerc.INITIAL_SUPPLY();
        musdc = new MockUSDC();
        musdc.mint(user, initAmount);

        supportedTokens.push(musdc);
        supportedTokens.push(yerc);
        sfc = new HandlerStatefulFuzzCatches(supportedTokens);
        vm.stopPrank();
        // targetContract(address(sfc));
        h = new Handler(sfc, musdc, yerc, user);
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = h.depositMUSDC.selector;
        selectors[1] = h.depositYERC20.selector;
        selectors[2] = h.withdrawMUSDC.selector;
        selectors[3] = h.withdrawYERC20.selector;

        targetSelector(FuzzSelector({addr: address(h), selectors: selectors}));
        targetContract(address(h));
    }

    function testTokenAmount() public {
        assert(initAmount == yerc.balanceOf(user));
        assert(initAmount == musdc.balanceOf(user));
    }

    function statefulFuzz_withdraw_fixed() public {
        vm.startPrank(user);
        // sfc.withdrawToken(usdc);
        h.withdrawMUSDC();
        h.withdrawYERC20();
        vm.stopPrank();

        assert(initAmount == yerc.balanceOf(user));
        assert(initAmount == musdc.balanceOf(user));

        assert(yerc.balanceOf(address(sfc))==0);
        assert(musdc.balanceOf(address(sfc))==0);
    }
}
//
