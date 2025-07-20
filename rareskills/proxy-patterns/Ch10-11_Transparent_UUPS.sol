// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

contract ProxyTest2 is Test {
    address owner = makeAddr("owner");

    function setUp() public {}

    function test_transparent() public {
        vm.startPrank(owner);
        ImplV1 v1 = new ImplV1();
        ImplV2 v2 = new ImplV2();
        Transparent tp = new Transparent(owner, address(v1));
        (bool success, bytes memory v) = address(tp).call(
            abi.encodeWithSignature("version()")
        );
        assertTrue(success);
        assertEq(v, abi.encode("V1"));

        AdminProxy ap = AdminProxy(tp.ADMIN_PROXY());
        ap.upgradeToAndCall(ITransparent(address(tp)), address(v2), "");
        (success, v) = address(tp).call(abi.encodeWithSignature("version()"));
        // successfully migrated to V2
        assertTrue(success);
        assertEq(v, abi.encode("V2"));
        vm.stopPrank();
    }
}

contract AdminProxy {
    address public owner;

    constructor(address _owner) {
        owner = _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function upgradeToAndCall(
        ITransparent _tp,
        address _newImpl,
        bytes calldata _data
    ) public onlyOwner {
        _tp.upgradeToAndCall(_newImpl, _data);
    }
}

interface ITransparent {
    function upgradeToAndCall(address impl, bytes calldata data) external;
}

contract EIP1967 {
    bytes32 private constant _IMPL_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor(address _impl) {
        bytes32 _implSlot = bytes32(
            uint256(keccak256("eip1967.proxy.implementation")) - 1
        );
        require(_IMPL_SLOT == _implSlot, "impl slot error");
        assembly {
            sstore(_IMPL_SLOT, _impl)
        }
    }

    // funcs in proxy should not be public
    function _getImpl() internal virtual returns (address impl) {
        assembly {
            impl := sload(_IMPL_SLOT)
        }
    }

    // delegate call should be part of the base abstract contract 'proxy'
    // in this ex, treat EIP1967 doing that
    function _fallback(
        bytes memory data
    ) internal virtual returns (bytes memory result) {
        (bool success, bytes memory _result) = _getImpl().delegatecall(data);
        require(success, "delegate call failed!");
        result = _result;
    }

    // This might not be part of original EIP 1967, but for easy impl
    function _upgradeToAndCall(
        address _newImpl,
        bytes memory data
    ) internal virtual {
        assembly {
            sstore(_IMPL_SLOT, _newImpl)
        }
        if (data.length > 0) {
            _fallback(data);
        }
        console2.log("upgraded to:", _newImpl);
    }
}

contract Transparent is EIP1967 {
    address public immutable ADMIN_PROXY;

    constructor(address _owner, address _impl) EIP1967(_impl) {
        ADMIN_PROXY = address(new AdminProxy(_owner));
    }

    fallback(bytes calldata _data) external returns (bytes memory result) {
        console2.log("Fallback called, caller:", msg.sender);
        if (msg.sender == ADMIN_PROXY) {
            if (msg.sig == ITransparent.upgradeToAndCall.selector) {
                (address newImpl, bytes memory data) = abi.decode(
                    _data[4:],
                    (address, bytes)
                );
                _upgradeToAndCall(newImpl, data);
            } else {
                revert("admin should call upgradeToAndCall");
            }
        } else {
            result = _fallback(_data);
        }
    }
}

contract ImplV1 {
    string private constant VERSION = "V1";

    function version() public pure returns (string memory) {
        return VERSION;
    }
}

contract ImplV2 {
    string private constant VERSION = "V2";

    function version() public pure returns (string memory) {
        return VERSION;
    }
}
