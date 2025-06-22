// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {HandlerStatefulFuzzCatches} from "../../../src/invariant-break/HandlerStatefulFuzzCatches.sol";
import {YieldERC20} from "../../mocks/YieldERC20.sol";
import {MockUSDC} from "../../mocks/MockUSDC.sol";
import {MyHandler} from "./MyHandler.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyInvariant is StdInvariant, Test {
    address user = makeAddr("user");
    address owner = makeAddr("owner");
    YieldERC20 yerc;
    MockUSDC usdc;
    uint initAmount;
    IERC20[] supportedTokens;
    HandlerStatefulFuzzCatches hsfc;
    MyHandler handler;

    function setUp() public {
        vm.startPrank(owner);
        yerc = new YieldERC20();
        initAmount = yerc.balanceOf(owner);
        yerc.transfer(user, initAmount);
        usdc = new MockUSDC();
        usdc.mint(user, initAmount);
        supportedTokens.push(yerc);
        supportedTokens.push(usdc);
        hsfc = new HandlerStatefulFuzzCatches(supportedTokens);

        handler = new MyHandler({
            _user: user,
            _yerc: yerc,
            _usdc: usdc,
            _hsfc: hsfc
        });

        vm.stopPrank();

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = handler.depositYERC.selector;
        selectors[1] = handler.depositUSDC.selector;
        selectors[2] = handler.withdrawYERC.selector;
        selectors[3] = handler.withdrawUSDC.selector;
        targetContract(address(handler));
        targetSelector(
            FuzzSelector({addr: address(handler), selectors: selectors})
        );
        // i: good for excluding SUT contract itself 
        excludeContract(address(hsfc));
    }

    function test_just_balance() public {
        assert(yerc.balanceOf(owner) == 0);
        assert(usdc.balanceOf(owner) == 0);
        assert(initAmount == yerc.balanceOf(user));
        assert(initAmount == usdc.balanceOf(user));
    }

    // sum of user and pool balance should be totalsupply
    // assertion error if 'fail_on_revert = false'
    // owner address got some ERC20
    function invariant_balance() public {
        address pool = address(hsfc);
        uint yercPool = yerc.balanceOf(pool);
        uint yercUser = yerc.balanceOf(user);
        uint usdcPool = usdc.balanceOf(pool);
        uint usdcUser = usdc.balanceOf(user);
        assertEq(yercPool + yercUser, yerc.totalSupply());
        assertEq(usdcPool + usdcUser, usdc.totalSupply());
    }
}
