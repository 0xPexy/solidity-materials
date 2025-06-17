# Findings in Puppy Raffle
## [M-#] Unbounded for-loop checking duplicates in `PuppyRaffle::enterRaffle` is a potential DoS attack, incrementing gas costs for future entrants

### Description
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

### Impact 
This can cause **Denial-of-Service(DoS)** attack. If malicious users call `enterRaffle` with large `newPlayers` or call `enterRaffle` repeatedly, gas cost to run new `enterRaffle` become gradually expensive. Then new late users have to pay more gas to enter, or even cannot enter the raffle and malicious users will get all rewards.

### Proof of Concept
The first `enterRaffle` call pushs 1000 addresses, which cost `440181896` gas. However, the second call pushs only one address, it costs `417774202` gas, which is even more than first call. That gas amount is really huge amount itself, the worst is the more calls accumulated, the more gas needed, end with `revert`.
<details>
<summary><b>Proof of Code</b></summary>

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


### Recommnedation
1. Consider allowing duplicates. Users can make new wallet address anyways, so duplicates check does not prevent the same person from entering multiple times, only the same wallet address.
1. Use **mappings** to remove unbouded for-loop checking duplicates, which cost only O(1) time-complexity.
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

1. If any additional for-loop traversal in `players` is needed, consider to make limitations of users in one raffle round and check before pushing new user.
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

1. Use EnumerableSet in OpenZeppelin. Follow [link](https://docs.openzeppelin.com/contracts/5.x/api/utils#EnumerableSet).