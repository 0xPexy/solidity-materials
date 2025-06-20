# Solidity by Example - 2. Applications
This is a personal draft intended for review and content reinforcement.

### Multisig wallet
- Submit tx to get sigs
- Owners accept or reject
- Multiple signature accepted, call other contract with tx.data
- q. no replay attack? a. Set a nonce in signed digest

### Merkle Tree
```solidity
contract MerkleProof {
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf,
        uint256 index
    ) public pure returns (bool) {
        bytes32 hash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (index % 2 == 0) {
                hash = keccak256(abi.encodePacked(hash, proofElement));
            } else {
                hash = keccak256(abi.encodePacked(proofElement, hash));
            }

            index = index / 2;
        }

        return hash == root;
    }
}
```
- q. Is index full? no unbalance per height? 
- a. Balanced vs unbalanced trees don’t matter—the index traces the path. The index is sufficient even for uneven heights, because path direction is unambiguous per level.
  

