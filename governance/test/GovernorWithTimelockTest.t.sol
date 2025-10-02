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
    address proposer;

    function setUp() public {
        govToken = new GovToken();

        // 1. setup Timelock
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0); // anyone can run

        // constructor: minDelay, proposers, executors, admin(address(this) as temp admin)
        timelock = new TimelockController(2 days, proposers, executors, address(this));

        // 2. setup Governor
        governor = new GovernorWithTimelock(govToken, timelock);

        // 3. grant role to Governor
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        // 4. remove admin role from Timelock
        assertTrue(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(this)));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), address(this));

        // 5. setup Counter -> owner should be Timelock, not Governor
        counter = new Counter(address(timelock));
    }

    function test_initialized() public {
        assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(this)));
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(governor)));
        assertTrue(timelock.hasRole(timelock.CANCELLER_ROLE(), address(governor)));
        assertEq(counter.owner(), address(timelock));

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

        uint256 proposalId = governor.hashProposal(targets, values, calldatas, descriptionHash);

        // uint256 voteStart = block.timestamp + VOTING_DELAY;
        // uint256 voteEnd = voteStart + VOTING_PERIOD;

        // vm.expectEmit(true, true, true, true);
        // emit IGovernor.ProposalCreated(
        //     proposalId, proposer, targets, values, new string[](1), calldatas, voteStart, voteEnd, description
        // );

        // vm.prank(proposer);
        // governor.propose(targets, values, calldatas, description);

        // assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));
        // assertEq(governor.proposalProposer(proposalId), proposer);
        // assertEq(governor.proposalSnapshot(proposalId), voteStart);
        // assertEq(governor.proposalDeadline(proposalId), voteEnd);
    }
}
