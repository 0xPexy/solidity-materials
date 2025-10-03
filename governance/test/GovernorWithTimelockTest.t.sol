// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {GovernorWithTimelock} from "src/GovernorWithTimelock.sol";
import {GovToken} from "src/GovToken.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {Counter} from "src/Counter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract GovernorWithTimelockTest is Test {
    TimelockController private timelock;
    GovernorWithTimelock private governor;
    GovToken private govToken;
    Counter private counter;

    uint256 VOTING_DELAY;
    uint256 VOTING_PERIOD;
    uint256 constant MIN_DELAY = 2 days;
    address proposer;
    address voter;

    function setUp() public {
        govToken = new GovToken();

        // 1. setup Timelock
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0); // anyone can run

        // constructor: minDelay, proposers, executors, admin(address(this) as temp admin)
        timelock = new TimelockController(MIN_DELAY, proposers, executors, address(this));

        // 2. setup Governor
        governor = new GovernorWithTimelock(govToken, timelock);
        VOTING_DELAY = governor.votingDelay();
        VOTING_PERIOD = governor.votingPeriod();

        // 3. grant role to Governor
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        // 4. remove admin role from Timelock
        assertTrue(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(this)));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), address(this));

        // 5. setup Counter -> owner should be Timelock, not Governor
        counter = new Counter(address(timelock));

        // 6. proposer GovToken Setting: mint -> delegate
        // Don't use deal (deal changes storage without totalSupply)
        proposer = makeAddr("proposer");
        govToken.mint(proposer, 1000e18);
        vm.prank(proposer);
        govToken.delegate(proposer);

        voter = makeAddr("voter");
        govToken.mint(voter, 1000e18);
        vm.prank(voter);
        govToken.delegate(voter);

        // 7. skip 1 hour to activate votes (bc we're using timestamp in GovToken)
        skip(3600);
    }

    function test_initialized() public {
        assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(this)));
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(governor)));
        assertTrue(timelock.hasRole(timelock.CANCELLER_ROLE(), address(governor)));
        assertEq(counter.owner(), address(timelock));

        // Governor should not be able to execute
        vm.prank(address(governor));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(governor)));
        counter.increment();
    }

    function test_lifecycle() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Increment counter";

        targets[0] = address(counter);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("increment()");

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));

        // 1. propose
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, descriptionHash);

        uint256 voteStart = block.timestamp + VOTING_DELAY;
        uint256 voteEnd = voteStart + VOTING_PERIOD;

        vm.prank(proposer);
        governor.propose(targets, values, calldatas, description);

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));
        assertEq(governor.proposalProposer(proposalId), proposer);
        assertEq(governor.proposalSnapshot(proposalId), voteStart);
        assertEq(governor.proposalDeadline(proposalId), voteEnd);

        // 2. castVote
        vm.startPrank(voter);

        // revert bc not in voting period
        vm.expectRevert();
        governor.castVote(proposalId, 1);

        // skip voting delay, make sure to add 1(should exceed)
        skip(VOTING_DELAY + 1);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Active));
        governor.castVote(proposalId, 1);

        vm.stopPrank();

        skip(VOTING_PERIOD + 1 days);

        // 3. queue operation
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));
        governor.queue(targets, values, calldatas, descriptionHash);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Queued));

        // 4. execute
        // revert before minDelay
        vm.expectRevert();
        governor.execute(targets, values, calldatas, descriptionHash);

        skip(MIN_DELAY + 1);
        governor.execute(targets, values, calldatas, descriptionHash);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
        assertEq(counter.count(), 1);
    }
}
