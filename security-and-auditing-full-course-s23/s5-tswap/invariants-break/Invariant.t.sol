// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

import {TSwapPool} from "../../src/TSwapPool.sol";
import {PoolFactory} from "../../src/PoolFactory.sol";
import {Handler} from "./Handler.t.sol";

contract Invariant is StdInvariant, Test {
    // PT, weth
    ERC20Mock pt;
    ERC20Mock weth;
    // PoolFactory, TswapPool
    TSwapPool pool;
    // constants: INIT AMOUNT of weth, PT
    uint256 constant INIT_PT = 100e18;
    uint256 constant INIT_WETH = 50e18;

    Handler h;

    // setUp:
    function setUp() public {
        // init memebers
        pt = new ERC20Mock();
        weth = new ERC20Mock();
        pool = new TSwapPool(address(pt), address(weth), "LP", "LP");
        // mint weth, pooltoken
        address user = makeAddr("user");
        vm.startPrank(user);
        pt.mint(user, INIT_PT);
        weth.mint(user, INIT_WETH);
        // approve poolToken, weth to pool, max
        pt.approve(address(pool), UINT256_MAX);
        weth.approve(address(pool), UINT256_MAX);

        // Pool Deposit
        pool.deposit(INIT_WETH, 1, INIT_PT, uint64(block.timestamp));

        vm.stopPrank();

        // set handler
        h = new Handler(pool);
        bytes4[] memory s = new bytes4[](2);
        s[0] = h.deposit.selector;
        s[1] = h.swap.selector;
        targetContract(address(h));
        targetSelector(FuzzSelector({addr: address(h), selectors: s}));
        // set selectors
        // set targets
    }

    function test_pool_initialized() public view {
        int256 x;
        int256 y;
        (x, y) = h.getPoolReserves();
        assertEq(INIT_PT, uint256(x));
        assertEq(INIT_WETH, uint256(y));
    }

    
    // invariant testing
    // delta must be keeped in deposits, swaps
    function invariant_delta() public view {
        assertEq(h.expectedDeltaX(), h.actualDeltaX());
        assertEq(h.expectedDeltaY(), h.actualDeltaY());
    }
}
