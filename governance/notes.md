# Governance Study

## Init

Use [OZ Contracts Wizard]("https://wizard.openzeppelin.com/#governor").

## Governance Contract

Governor Ext. Contracts:
- GovernorVotes: which IVotes token & clock mode(ERC-6372)
- GovernorVotesQuorumFraction: quorom ratio (% of total supply)
- GovernorCountingSimple: For / Against / Abstain. For + Abstain => Quorum 

Core Params: votingDelay, votingPeriod, proposalThreashold(restrict proposer)

## Governance Token Contract

Should implement ERC20Votes extension. 
- `_update(address from, address to, uint256 amount)`: ERC20 hook in OZ v5.
- `nonces(address owner)`: signature replay

IVotes(ERC20Votes/ERC721Votes):
- Snapshot(checkpoint)-based VP: proposal timing
- Delegated voting
- ERC-6372: Standard for "clock"-BN vs TS

## Timelock
- TimelockController + GovernorTimelockControl Combination
- TimelockController should be owner of funds/roles, not Governor
  ex) TimelockController owns tokens-assets sent to Governor cannot be used
```solidity
    // TimelockController.sol
    /**
     * @dev Execute an operation's call.
     */
    function _execute(address target, uint256 value, bytes calldata data) internal virtual {
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        Address.verifyCallResult(success, returndata);
    }
```

RBAC:
- Proposer: only Governor, push to queue
- Executor: anyone or Governor, execute after timelock
- Admin: give or remove role

## Proposal Lifecycle
1. propose
2. castVote/castVoteWithReason
3. validate if success(quorum)
4. queue(if timelock)
5. execute

## ERC-6372

- Standard for "clock"-BN vs TS
- Default: BN, override `clock()/CLOCK_MODE()` for timestamp
- Automatically detected by Governor

## Questions
1. Why For+Abstain => Quorum?
    - Abstain is for quorum calculation, not for adoption. 
    - Quorum: For + Abstain(기권/중립)
    - Adoption: For > Against (Abstain excluded)


## References

- https://docs.openzeppelin.com/contracts/5.x/governance