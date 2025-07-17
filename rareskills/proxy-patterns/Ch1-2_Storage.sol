// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

contract StorageTest is Test {
    MyStorage st;

    function setUp() public {
        st = new MyStorage();
    }

    function test_run() public {
        st.run();
    }
}

contract MyStorage {
    // SLOT 0
    mapping(address => uint256) private balances;
    // Immutable variables don't use storage slots; they are baked into the bytecode.
    address immutable alice;
    address immutable bob;

    // SLOT 1
    mapping(address => mapping(address => uint256)) private nestedBalances;
    // Constants don't use storage slots; they are replaced by the compiler.
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // SLOT 2, 3, 4: Statically-sized arrays store elements sequentially.
    uint256[3] private fArr = [11, 12, 13];

    // SLOT 5, 6: Elements are packed if they fit. `uint128` takes half a slot.
    // fArr2[0] and fArr2[1] are packed into slot 5.
    // fArr2[2] is in slot 6.
    uint128[3] private fArr2 = [21, 22, 23];

    // SLOT 7: For dynamic arrays, the slot stores the array length.
    // The data is at keccak256(slot).
    uint256[] private dArr = [31, 32, 33];

    // SLOT 8: Another dynamic array.
    uint128[] private dArr2 = [41, 42, 43];

    // SLOT 9: For short strings (<= 31 bytes), data is stored in the slot.
    // The last byte is `length * 2`.
    string private short = "short";

    // SLOT 10: For long strings (> 31 bytes), slot stores `length * 2 + 1`.
    // The data is at keccak256(slot).
    string private long =
        "aabbccddeeffgghhiijjkkllmmnnooppqqrrssttuuvvwwxxyyzz"; // 52 bytes

    // SLOT 11: For short bytes (<= 31 bytes), similar to short strings.
    bytes private fBytes = hex"ffeedd";

    // SLOT 12: Dynamic array of bytes1.
    bytes1[] private bBytes;

    constructor() {
        alice = address(0x1234);
        balances[alice] = 100e18;
        bob = address(0x2345);
        nestedBalances[alice][WETH] = 1000e18;

        bBytes.push(hex"ff");
        bBytes.push(hex"ee");
        bBytes.push(hex"dd");
    }

    function run() public {
        console2.log("--- Testing Simple Mapping (Slot 0) ---");
        bytes32 balanceBaseSlot;
        assembly {
            balanceBaseSlot := balances.slot
        }
        assert(balanceBaseSlot == 0);

        uint256 aliceBalanceSlot = getMappingSlot(balanceBaseSlot, alice);
        assert(getVal(aliceBalanceSlot) == 100e18);

        uint256 bobBalanceSlot = getMappingSlot(balanceBaseSlot, bob);
        setVal(bobBalanceSlot, 200e18);
        assert(getVal(bobBalanceSlot) == 200e18);

        console2.log("\n--- Testing Nested Mapping (Slot 1) ---");
        bytes32 nestedBalancesBaseSlot;
        assembly {
            nestedBalancesBaseSlot := nestedBalances.slot
        }
        bytes32 aliceLevel1Slot = keccak256(
            abi.encode(alice, nestedBalancesBaseSlot)
        );
        bytes32 aliceWethLevel2Slot = keccak256(
            abi.encode(WETH, aliceLevel1Slot)
        );

        uint256 aliceWethBalance;
        assembly {
            aliceWethBalance := sload(aliceWethLevel2Slot)
        }
        assert(nestedBalances[alice][WETH] == aliceWethBalance);
        console2.log("Nested balance for Alice:", aliceWethBalance);

        console2.log("\n--- Testing Fixed-Size Arrays (Slots 2-6) ---");
        for (uint8 i = 0; i < 3; i++) {
            assert(getVal(2 + i) == fArr[i]);
        }

        // Check packed array fArr2
        bytes32 packedSlot5 = getValAsBytes32(5);
        assert(uint128(uint256(packedSlot5)) == fArr2[0]);
        assert(uint128(uint256(packedSlot5) >> 128) == fArr2[1]);
        assert(uint128(getVal(6)) == fArr2[2]);

        console2.log("\n--- Testing Dynamic Arrays (Slots 7-8) ---");
        assert(getVal(7) == dArr.length); // Slot 7 stores length of dArr
        uint256 dArrBase = uint256(keccak256(abi.encode(7)));
        assert(getVal(dArrBase) == dArr[0]);
        assert(getVal(dArrBase + 1) == dArr[1]);

        assert(getVal(8) == dArr2.length); // Slot 8 stores length of dArr2

        console2.log("\n--- Testing Strings (Slots 9-10) ---");
        bytes32 shortStrSlot = getValAsBytes32(9);
        // "short" is 5 bytes. Last byte of slot is 5 * 2 = 10 (0x0a).
        // For a short string, the last byte of the slot stores `length * 2`.
        // "short" has 5 characters, so the last byte should be 10.
        assert(uint8(bytes1(shortStrSlot << 248)) == 5 * 2);
        console2.logBytes32(shortStrSlot);

        // long is 52 bytes. Slot 10 stores 52 * 2 + 1 = 105.
        // "long" is 52 bytes. Slot 10 stores 52 * 2 + 1 = 105.
        assert(getVal(10) == 52 * 2 + 1);
        uint256 longStrBase = uint256(keccak256(abi.encode(10)));
        bytes32 longStrPart1 = getValAsBytes32(longStrBase);
        bytes32 longStrPart2 = getValAsBytes32(longStrBase + 1);
        console2.log(
            "Long string part 1:",
            string(abi.encodePacked(longStrPart1))
        );
        console2.log(
            "Long string part 2:",
            string(abi.encodePacked(longStrPart2))
        );
    }

    function getMappingSlot(
        bytes32 baseSlot,
        address key
    ) internal pure returns (uint256 slot) {
        slot = uint256(keccak256(abi.encode(key, baseSlot)));
    }

    function getVal(uint256 slot) internal view returns (uint256 val) {
        assembly {
            val := sload(slot)
        }
    }

    function getValAsBytes32(uint256 slot) internal view returns (bytes32 val) {
        assembly {
            val := sload(slot)
        }
    }

    function setVal(uint256 slot, uint256 value) internal {
        assembly {
            sstore(slot, value)
        }
    }
}
