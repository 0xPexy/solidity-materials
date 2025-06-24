// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

import {TSwapPool} from "../../src/TSwapPool.sol";
import {PoolFactory} from "../../src/PoolFactory.sol";

contract Handler is Test {
    // pool
    TSwapPool pool;
    // weth, poolToken
    ERC20Mock pt;
    ERC20Mock weth;

    //addresses: lp, swapper
    address lp = makeAddr("lp");
    address swapper = makeAddr("swapper");
    uint256 constant INIT_BAL = type(uint128).max;

    // set ghost vars
    // startingX,Y,
    // expectedDeltaX,Y
    // actualDelta X,Y
    int256 public expectedDeltaX;
    int256 public expectedDeltaY;
    int256 public actualDeltaX;
    int256 public actualDeltaY;
    int256 beforeX;
    int256 beforeY;
    int256 afterX;
    int256 afterY;

    modifier useLP() {
        vm.startPrank(lp);
        _;
        vm.stopPrank();
    }

    modifier useSW() {
        vm.startPrank(swapper);
        _;
        vm.stopPrank();
    }

    // constructor(_pool)
    // set pool
    // weth, pt addr from pool.func()
    constructor(TSwapPool _pool) {
        pool = _pool;
        pt = ERC20Mock(pool.getPoolToken());
        weth = ERC20Mock(pool.getWeth());

        pt.mint(lp, INIT_BAL);
        weth.mint(lp, INIT_BAL);

        pt.mint(swapper, INIT_BAL);
        weth.mint(swapper, INIT_BAL);
    }

    // hook for testing
    function getPoolReserves() public view returns (int256, int256) {
        return (
            int256(pt.balanceOf(address(pool))),
            int256(weth.balanceOf(address(pool)))
        );
    }

    // deposit by WETH
    // 5-step handler layout: bound → set ghosts → pre-tx → main-tx → record
    function deposit(uint256 _amountWETH) external useLP {
        // 1. bound input; WETH & PT amount
        uint256 amountWETH = bound(
            _amountWETH,
            pool.getMinimumWethDepositAmount(),
            type(uint64).max
        );
        uint256 amountPT = pool.getPoolTokensToDepositBasedOnWeth(amountWETH);

        // 2. set invariants; ghost vars
        expectedDeltaX = int256(amountPT);
        expectedDeltaY = int256(amountWETH);
        (beforeX, beforeY) = getPoolReserves();

        // 3. run pre-cond. tx; approve
        pt.approve(address(pool), amountPT);
        weth.approve(address(pool), amountWETH);

        // 4. run tx; deposit
        pool.deposit(amountWETH, 1, amountPT, uint64(block.timestamp));

        // 5. update ghost vars
        (afterX, afterY) = getPoolReserves();
        actualDeltaX = int256(afterX - beforeX);
        actualDeltaY = int256(afterY - beforeY);
    }

    // swap PT->WETH by WETH amount
    function swap(uint256 _amountWETH) external useSW {
        // 1. bound input
        uint256 amountWETH = bound(
            _amountWETH,
            type(uint24).max,
            type(uint32).max
        );
        (beforeX, beforeY) = getPoolReserves();
        uint256 amountPT = pool.getInputAmountBasedOnOutput(
            amountWETH,
            uint256(beforeX),
            uint256(beforeY)
        );

        // 2. set invariants
        expectedDeltaX = int256(amountPT);
        expectedDeltaY = (-1) * int256(amountWETH);

        // 3. run pre-cond. tx
        pt.approve(address(pool), amountPT);

        // 4. run tx
        pool.swapExactOutput(pt, weth, amountWETH, uint64(block.timestamp));

        // 5. update ghost vars
        (afterX, afterY) = getPoolReserves();

        actualDeltaX = afterX - beforeX;
        actualDeltaY = afterY - beforeY;
    }
}
