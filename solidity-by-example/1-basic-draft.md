# Solidity by Example - 1. Basic
This is a personal draft intended for review and content reinforcement.
## Primitives and Types
### Keywords
- `immutable` is like to `constants`, but can be set in `construtor` & cannot be modified after.
- `mapping` is not iterable. (q. to iterate, use with array to save key? - yes. push each new key into an array and iterate the array.)
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


