# Solidity by Example - 1. Basic
This is a personal draft intended for review and content reinforcement.
## Primitives and Types
### Keywords
- `immutable` is like to `constants`, but can be set in `construtor` & cannot be modified after.
- `mapping` is not iterable. (q. to iterate, use with array to save key? - yes. push each new key into an array and iterate the array.)
- Iterable map can be impled with struct
  ```solidity
    struct Map {
        address[] keys;
        mapping(address => uint256) values;
        mapping(address => uint256) indexOf;
        mapping(address => bool) inserted;
    }
  ```

- (q. `array` is like C++ vector? can use `push` in fixed size array? resizing in dynamic array acts like vector, like extending 2x? - You cannot push to fixed-size. Dynamic arrays let you .push() but there is no doubling heuristic—each push writes a new storage slot at constant cost.)
- `enum`, `struct` exists like other langs
- To use type alias: `type Duration is uint64`
### Transient Storage(EIP-1153)
Temporary cheap storage variable during transaction, cleaned up tx end. 
- usage: lock in `ReentrancyGuard` (much cheaper), flash accounting in UniswapV4(temp storage to partial settlement while multi-hops)
- impl: `tload` & `tstore` opcode (q. does it only can be implemented by assembly in solidity? - Yes—today you use assembly { tstore(slot, value) } / tload(slot); high-level language support is on the roadmap but not yet released.)
### Functions
- named parameters: you can call params in `({key1:value1, key2:value2})` form regardless of declaration order.
- `pure` cannot do even reading state
- (q. passing `storage` keyword arg to func means like passing pointer? ex: `MyStruct storage _myStruct` - Yes—it creates an alias to the on-chain storage location rather than copying into memory.)
### Events
- Like cheap storage
- `indexed` needs much gas so use carefully, typically use `address`, not like `amount`
- do not emit duplicated events already in dependencies
  
## Inheritance
### Constructor
How to call parent constructor with params
- use inheritance list: `contract B is X("Input to X"), Y("Input to Y") {}`
- use like C++ initializer list
    ```solidity
    contract C is X, Y {
        constructor(string memory _name, string memory _text) X(_name) Y(_text) {}
    }
    ```
Note that constructor call order is `X->Y->C`, only affected by order after `is`
### Multiple Inheritance
(q. why solidity support this? - For flexible composition of behaviors (e.g. Ownable, ERC20, security mixins) without boilerplate. C3 linearization ensures each base is initialized once and super calls follow a single, predictable chain.
)
Must inherit from MOST BASE-LIKE to MOST DERIVED after `is`.
`super` called from right-most parent.
```solidity
/* Graph of inheritance
    A
   / \
  B   C
 / \ /
F  D,E

*/
```
- `contract D is B,C`: `super` starts from `C`.
- `contract E is C, B`: `super` starts from `B`.
- `contract F is A, B` is OK, `contract F is B, A` compile error
- supports **C3 linearization** to prevent 'diamond problem': `D->C->B->A` order
### Others
- `virtual`: must be overriden vs `override`: can be overriden
- Shadowing: can overwrite state var of parent, not by re-declaring but just access(q. in below, we overwrite in constructor, it can be only done in there? - No—any function in the child contract can assign to name. It isn’t limited to the constructor.)
    ```solidity
    contract A {
        string public name = "Contract A";
    }
    contract C is A {
        constructor() {
            name = "Contract C";
        }
    }
    ```

## Interactions
### Function Keywords
- `interface`: can be inherited & all funcs must be `external`
- `payable`: is for function & address to receive ETH
- q. why external needed compared to public? is it for interacting with other contracts? other langs dont have it.
- a. external saves ~20–40 gas when the caller is another contract or an EOA, because the ABI-encoded calldata is used as-is; public first copies arguments into memory.

### Sending ETH 
- `transfer`: max 2300 gas, throws `error`, deprecated
- `send`: max 2300 gas, returns `bool`, legacy
- `call`: max gas customizable, returns `bool`, recommended 
- q. recommended if sending to EOA?
- a. Preferred, both to EOAs and contracts—always check success and use re-entrancy guard. 

### Receving ETH 
- `receive`: no `msg.data`. just receives.
- `fallback`: `msg.data` exists or no `receive`. Can get `bytes calldata` param and return `bytes memory` output.
- q: why two functions seperated? other methods cannnot receive ETH even set to `payable`? If then, sending ETH and other tokens in one tx needs two way call?
- a: Separate paths for empty vs non-empty `calldata`. Any other payable function can accept ETH, but a plain ETH transfer without data will not select it—so you need `receive` for minimal-data transfers. Tokens + ETH in the same tx call a normal payable function with encoded params.
  
### Interacting between Contracts
- `call`: use to call `fallback` of another contract, not recommend to interact with other contracts directly; hard to check revert, function existence, param types.
- To call another contract general method, get callee instance in caller and use method directly. 
- q. putting callee instance does not cost much? why interface not used?
- a: Passing an interface type is zero-cost at runtime; it’s just an address. Interfaces improve type-safety and readability.
- `staticcall`: for only view, pure func. cannot change state
- `delegatecall`: willing to use stoarge of A, function of B. B must have same storage layout with A.
- `new`: keyword to create another contract, in Sol >= `0.8.0`, can use `salt` works like in `create2`. 
    ```solidity
    function create2AndSendEther(
        address _owner,
        string memory _model,
        bytes32 _salt
    ) public payable {
        // can use optional `value` and `salt` parameter
        Car car = (new Car){value: msg.value, salt: _salt}(_owner, _model);
        cars.push(car);
    }
    ```

### Try-catch
- Can catch detailed error in external call(`call, staticcall, delegatecall`) or creation of other contract(`new`)
- Caller catch error in callee, not to catch caller itself error.
- `catch Panic(uint256)`(0.8.4): catch low-level `panic`(arithmetic error, invalid access) and `assert` error
- `catch Error(string memory)`: catch `revert` or `require` with `string` error
- `catch (bytes memory)`: catch any uncaught error
- Custom `Error`(0.8.0): like `Event`, can caught in `bytes` catch. Can only identified by selector, not like `catch CustomError` in other langs.
- empty data(0x) returned: if no reason in `revert` or `require`, caller out-of-gas(63/64), caller reverts with assembly `revert(0,0)`
```solidity
function callerFunction() external view {
    try functionFromAnotherContract() {
        //<-- Handle the success case if needed
    } catch Panic(uint256 errorCode) {
        //<-- handle Panic errors
    } catch Error(string memory reason) {
        //<-- handle revert with a reason
    } catch (bytes memory reason) {
        //<-- handle every other errors apart from Panic and Error with a reason
        bytes4 expectedSelector = PathRegistry.InsufficientAmountOut.selector;
        bytes4 receivedSelector = bytes4(reason);
        
        //<-- these errors will not be handled in this try-catch
        assertEq(expectedSelector, receivedSelector);
        revert("caller error");
    }
}
```

### Imports
- `import` from github can be directly done by `import "https://github.com/..."`
- `library`: no state vars, no receving ETH. If all methods `internal`, can be embedded into contract, otherwise should be deployed and linked before caller deployed.
    ```solidity
    library Array { function remove(uint256[] storage arr, uint256 index) public{} }
    contract TestArray {
        using Array for uint256[]; 
    }
    ```

### Encodings
- `abi.encodeCall(func, (args...))`: able to typo & type error check which cannot in `abi.encodeWithSignature`, `abi.encodeWithSelector`. Can use interface.
- `abi.encodePacked(string)` vs `bytes(string)`: `encodePacked` creates new bytes and copy to memory(deep copy), `bytes` is just copy address like pointer(shallow copy)
```solidity
// Typo and type errors will not compile
return abi.encodeCall(IERC20.transfer, (to, amount));

// decode (bytes-> data)
(x, addr, arr, myStruct) =
abi.decode(data, (uint256, address, uint256[], MyStruct));
```

## Cryptography
### Hash
- `keccack256`: used in UUID, commmit-reveal, gen sigs. `encodePacked` is efficient for compress inputs for hash, it make hash collision so need seperator like `|`

### Signature 
- gen: `messageHash(inputs)` -> `web3.sign(hash, account)` output is hash of `x19Etherem ~~`(EIP-191) + hashed message
- verify: `messageHash(inputs)` -> `ethSignedMessageHash(messageHash)` -> `ecrecover(signedHash, v, r, s)`
- q. what is difference between EIP-191 vs 712?
- a. EIP-712: extends 191; Typed-structured data; more secure & human-readable, but heavier to implement.



## Miscs
### Gas Optimizations 
- `memory` -> `calldata` (q. how it reduce costs? -> zero copy; memory copies data, costing 3 gas/byte + dynamic cost. )
- cache state variables: `array.length`, array elements
- `i++`-> `++i` & `unchecked` (q. why ++i is better? prefix avoids saving the old value, so the compiler emits one fewer stack operation (~3–5 gas inside tight loops).)
  
### Low-level Operations
- Bitwise operation supported
- yul: assembly language, use `assembly` keyword
- q. in sol, assembly and bitwise ops are frequently used in 2025? 
- a. Yul/inline-assembly is still widely used for gas-critical libs (e.g., Uniswap v4 hooks, 4626 math), but most business logic stays in high-level Solidity; developers lean on libraries and compiler optimisations. Bitwise ops remain common for packing metadata/flags.






