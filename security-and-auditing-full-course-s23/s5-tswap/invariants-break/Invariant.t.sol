// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

import {TSwapPool} from "../../src/TSwapPool.sol";
import {PoolFactory} from "../../src/PoolFactory.sol";
import {Handler} from "./Handler.t.sol";

contract Invariant is StdInvariant, Test {
    // ERC20, weth
    ERC20Mock poolToken;
    ERC20Mock weth;

    // PoolFactory, TswapPool
    PoolFactory poolFactory;
    TSwapPool pool;

    // constants: INIT AMOUNT of weth, ERC20
    int256 constant INIT_X = 100e18; // poolToken
    int256 constant INIT_Y = 50e18; // weth

    // initLP address
    address initLP = makeAddr("initLP");

    // handler
    Handler handler;

    // setUp:
    function setUp() public {
        // init memebers
        poolToken = new ERC20Mock();
        weth = new ERC20Mock();
        poolFactory = new PoolFactory(address(weth));
        pool = new TSwapPool(
            address(poolToken),
            address(weth),
            "LPToken",
            "LP"
        );

        vm.startPrank(initLP);
        // mint erc20, weth, pooltoken
        poolToken.mint(initLP, uint256(INIT_X));
        weth.mint(initLP, uint256(INIT_Y));

        // approve poolToken, weth to pool, max
        poolToken.approve(address(pool), UINT256_MAX);
        weth.approve(address(pool), UINT256_MAX);

        // Pool Deposit
        // q: why minimumLiquidityTokensToMint is INIT_Y
        pool.deposit(
            uint256(INIT_Y),
            1,
            uint256(INIT_X),
            uint64(block.timestamp)
        );
        vm.stopPrank();
        // set handler
        handler = new Handler(pool);
        // set selectors
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = handler.depositByWETH.selector;
        // set targets
        targetContract(address(handler));
        targetSelector(
            FuzzSelector({addr: address(handler), selectors: selectors})
        );
    }

    // invariant_xy=k
    // change in pool size of WETH follow function
    // assert delta X == expected X, by handler
    function invariant_xyk() public {
        assertEq(handler.expectedDeltaX(), handler.actualDeltaX());
        assertEq(handler.expectedDeltaY(), handler.actualDeltaY());
    }
}
