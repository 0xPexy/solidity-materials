### [M-1] Missing a deadline check in `deposit` allows transactions after deadline
**Description:** 
`TSwapPool::deposit` has `deadline` parameter, intended to reject transactions after the deadline. However, `deadline` is unused anywhere, results to missing a deadline check.

**Impact:** 
Transactions 

**Proof of Concept:**
Run `make build` to see a compilation warning.
```bash
Warning (5667): Unused function parameter. Remove or comment out the variable name to silence this warning.
   --> src/TSwapPool.sol:105:9:
    |
105 |         uint64 deadline
    |         ^^^^^^^^^^^^^^^
```

**Recommended Mitigation:** 
Add a deadline check in `deposit`.
```diff
function deposit(...) external
    revertIfZero(wethToDeposit)
+   revertIfDeadlinePassed(deadline)
```


### [I-1] Unused statements
Remove unused statements.
- `error PoolFactory__PoolDoesNotExist(address tokenAddress);` in `PoolFactory`
- `uint256 poolTokenReserves = i_poolToken.balanceOf(address(this));` in `TSwapPool::deposit`

### [I-2] Lacking zero-address checks
Add zero-address checks in below parts.
- `PoolFactory::constructor`: `address wethToken`
- `TSwapPool::constructor`: `address poolToken` and `address wethToken`
```diff
// PoolFactory.t.sol
constructor(address wethToken) {
+   require(wethToken != address(0));    
    i_wethToken = wethToken;
}

// TSwapPool.t.sol
constructor(
    address poolToken,
    address wethToken,
    ...
)
{
+    require(wethToken != address(0));
+    require(poolToken != address(0));
    i_wethToken = IERC20(wethToken);
    i_poolToken = IERC20(poolToken);
}
```

### [I-3] Function usage
In `PoolFactory::createPool`, consider using `IERC20::symbol` to represent LP token symbol.
```diff
- string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).name());
+ string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).symbol());
```

### [I-4] Unnecessary visibility
The `public` function `TSwapPool::swapExactInput` is not internally referenced, use `external`.

### [I-5] Unnamed numeric constants
Use named numeric constants for arithmetic operations.
```diff
+   uint256 private constant WITHOUT_FEE = 997;
+   uint256 private constant SCALE = 1000;
-   uint256 inputAmountMinusFee = inputAmount * 997;
-   uint256 denominator = (inputReserves * 1000) + inputAmountMinusFee;
+   uint256 inputAmountMinusFee = inputAmount * WITHOUT_FEE;
+   uint256 denominator = (inputReserves * SCALE) + inputAmountMinusFee;
-   return ((inputReserves * outputAmount) * 10000) / ((outputReserves - outputAmount) * 997);
+   return ((inputReserves * outputAmount) * SCALE) / ((outputReserves - outputAmount) * WITHOUT_FEE);

```
