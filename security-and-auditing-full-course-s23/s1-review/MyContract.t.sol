// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {MyContract} from "../../src/s1/MyContract.sol";
import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

contract MyContractTest is Test {
    MyContract exampleContract;

    function setUp() public {
        exampleContract = new MyContract();
    }

    // basic unit test
    function test_AlwaysReturnsZero() public {
        uint256 data = 0;
        exampleContract.doSomething(data);
        assert(exampleContract.shouldAlwaysBeZero() == 0);
    }

    // test with fuzzing
    function testFuzz_AlwaysReturnsZero(uint256 data) public {
        exampleContract.doSomething(data);
        assert(exampleContract.shouldAlwaysBeZero() == 0);
    }

    // function invariant_testAlwaysReturnZero() public {
    //     assert(exampleContract.shouldAlwaysBeZero() == 0);
    // }
}

contract MyContractTest2 is StdInvariant {
    MyContract exampleContract;

    function setUp() public {
        exampleContract = new MyContract();
        targetContract(address(exampleContract));
    }

    function invariant_testAlwaysReturnZero() public {
        assert(exampleContract.shouldAlwaysBeZero() == 0);
    }
}
