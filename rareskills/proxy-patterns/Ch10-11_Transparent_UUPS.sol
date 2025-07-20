// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

contract ProxyTest2 is Test {
    address owner = makeAddr("owner");

    function setUp() public {}

    function test_transparentProxy() public {
        vm.startPrank(owner);
        ImplV1 v1 = new ImplV1();
        ImplV2 v2 = new ImplV2(); // The new implementation
        TransparentProxy proxy = new TransparentProxy(owner, address(v1));

        // 1. Check initial version is V1
        (bool success, bytes memory versionResult) = address(proxy).call(
            abi.encodeWithSignature("version()")
        );
        assertTrue(success, "Initial call to V1 failed");
        assertEq(versionResult, abi.encode("V1"));

        // 2. Upgrade to V2
        AdminProxy admin = AdminProxy(proxy.ADMIN_PROXY());
        admin.upgradeToAndCall(ITransparent(address(proxy)), address(v2), "");

        // 3. Check version is now V2
        (success, versionResult) = address(proxy).call(
            abi.encodeWithSignature("version()")
        );
        assertTrue(success, "Call to V2 failed");
        assertEq(versionResult, abi.encode("V2"));

        // 4. Fails to call non-existing func
        (success, ) = address(proxy).call(
            abi.encodeWithSignature("version1()")
        );
        assertFalse(success);
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
        ITransparent _proxy,
        address _newImpl,
        bytes calldata _data
    ) public onlyOwner {
        _proxy.upgradeToAndCall(_newImpl, _data);
    }
}

interface ITransparent {
    function upgradeToAndCall(address impl, bytes calldata data) external;
}

contract EIP1967Proxy {
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
    function _delegate(
        bytes memory data
    ) internal virtual returns (bytes memory result) {
        (bool success, bytes memory _result) = _getImpl().delegatecall(data);
        require(success, "delegate call failed!");
        result = _result;
    }

    // This upgrade function is a simplified helper for the pattern
    function _upgradeToAndCall(
        address _newImpl,
        bytes memory data
    ) internal virtual {
        assembly {
            sstore(_IMPL_SLOT, _newImpl)
        }
        if (data.length > 0) {
            _delegate(data);
        }
    }
}

contract TransparentProxy is EIP1967Proxy {
    address public immutable ADMIN_PROXY;

    constructor(address _owner, address _impl) EIP1967Proxy(_impl) {
        ADMIN_PROXY = address(new AdminProxy(_owner));
    }

    fallback(bytes calldata _calldata) external returns (bytes memory result) {
        if (msg.sender == ADMIN_PROXY) {
            if (msg.sig == ITransparent.upgradeToAndCall.selector) {
                // Admin is calling the upgrade function.
                (address newImpl, bytes memory initData) = abi.decode(
                    _calldata[4:],
                    (address, bytes)
                );
                _upgradeToAndCall(newImpl, initData);
            } else {
                revert("admin should call upgradeToAndCall");
            }
        } else {
            // All other calls are delegated to the implementation.
            result = _delegate(_calldata);
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
