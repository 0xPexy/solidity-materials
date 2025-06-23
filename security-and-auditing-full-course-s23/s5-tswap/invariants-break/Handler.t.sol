// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import {Test, console2} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

import {TSwapPool} from "../../src/TSwapPool.sol";
import {PoolFactory} from "../../src/PoolFactory.sol";

contract Handler is Test {
    TSwapPool pool;
    // X-poolToken, Y-WETH
    ERC20Mock poolToken;
    ERC20Mock weth;

    //addresses: lp, swapper
    address lp = makeAddr("lp");
    address swapper = makeAddr("swapper");

    // set ghost vars
    // startingX,Y,
    int256 startingX;
    int256 startingY;
    // expectedDeltaX,Y
    int256 public expectedDeltaX;
    int256 public expectedDeltaY;
    // actualDelta X,Y
    int256 public actualDeltaX;
    int256 public actualDeltaY;

    modifier useLP() {
        vm.startPrank(lp);
        _;
        vm.stopPrank();
    }

    modifier useSwapper() {
        vm.startPrank(swapper);
        _;
        vm.stopPrank();
    }

    constructor(TSwapPool _pool) {
        pool = _pool;
        // weth, pt addr from pool.func()
        poolToken = ERC20Mock(pool.getPoolToken());
        weth = ERC20Mock(pool.getWeth());
    }

    // func deposit(WETHamount)
    function depositByWETH(uint256 amountWETH) public useLP {
        // set reasonable WETHamount 1~ 64.max
        uint amountMinWETH = pool.getMinimumWethDepositAmount();
        amountWETH = bound(amountWETH, amountMinWETH, type(uint64).max);
        // get PT amount to deposit by pool func
        uint256 amountPT = pool.getPoolTokensToDepositBasedOnWeth(amountWETH);

        // set ghost vars
        (startingX, startingY) = _getPoolBalances();
        expectedDeltaX = int256(amountPT);
        expectedDeltaY = int256(amountWETH);

        // deposit part
        // mint weth, PT
        uint lpWETHBalance = weth.balanceOf(lp);
        if (lpWETHBalance < amountWETH) {
            weth.mint(lp, amountWETH - lpWETHBalance);
        }
        uint lpPTBalance = poolToken.balanceOf(lp);
        if (lpPTBalance < amountPT) {
            poolToken.mint(lp, amountPT - lpPTBalance);
        }
        // approve to pool
        weth.approve(address(pool), amountWETH);
        poolToken.approve(address(pool), amountPT);
        // do deposit
        pool.deposit(amountWETH, 1, amountPT, uint64(block.timestamp));

        // calc actual DeltaX, DeltaY
        (int256 endX, int256 endY) = _getPoolBalances();
        actualDeltaX = endX - startingX;
        actualDeltaY = endY - startingY;
    }

    function _getPoolBalances() internal view returns (int256, int256) {
        return (
            int256(poolToken.balanceOf(address(pool))),
            int256(weth.balanceOf(address(pool)))
        );
    }

    // TODO: start from here
    // func swapPT->Weth, amountOutput(WETH)fixed
    // bound output WETH 1~pool balance
    // calc pTAmount by pool func
    // return if ptAmount > balance
    // set ghost vars

    // if user insufficient PT, mint

    // prank swapper
    // pt approve
    // pool.swap
    // stop prank

    // calc actual
}
