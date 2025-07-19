// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

contract ProxyTest is Test {
    function setUp() public {}

    function test_proxy_basic() public {
        Impl impl = new Impl();
        Proxy proxy = new Proxy();
        proxy.setImpl(address(impl));
        assertEq(address(impl), proxy.getImpl());
        // To call the fallback of the proxy, you need to make a call to the proxy
        // with a function signature that doesn't exist on the Proxy contract itself.
        // In this case, we will call the `add(uint256,uint256)` function from the Impl contract.

        // 1. Encode the function call for `add(2, 3)`
        bytes memory callData = abi.encodeWithSignature(
            "add(uint256,uint256)",
            2,
            3
        );

        // 2. Call the proxy, which will trigger the fallback and delegate the call to the implementation.
        (bool success, bytes memory res) = address(proxy).call(callData);
        assertTrue(success, "Proxy delegatecall failed");

        // 3. Decode the result and assert it's correct.
        uint256 result = abi.decode(res, (uint256));
        assertEq(result, 5, "Result of add(2, 3) should be 5");
        console2.log("Result from proxied call:", result);
    }

    function test_proxy_collsion() public {
        CollisionImpl impl = new CollisionImpl();
        Proxy proxy = new Proxy();
        proxy.setImpl(address(impl));
        assertEq(address(impl), proxy.getImpl());
        // increment call
        bytes memory callData = abi.encodeWithSignature("increment()");
        (bool success, ) = address(proxy).call(callData);
        assertTrue(success, "Proxy delegatecall failed");
        // proxy impl address manipulated (added 1)
        assertNotEq(address(impl), proxy.getImpl());
        console2.log("address:", address(impl));
        console2.log("address:", proxy.getImpl());
    }

    function test_proxy_EIP1967() public {
        address deployer = makeAddr("deployer");
        vm.startPrank(deployer);
        ImplV1 prevImpl = new ImplV1();
        EIP1967 proxy = new EIP1967();
        proxy.setImpl(address(prevImpl));
        assertEq(deployer, proxy.getOwner());
        assertEq(address(prevImpl), proxy.getImpl());
        // delegatecall v1 version()
        bytes memory dataForDelegateCall = abi.encodeWithSignature("version()");
        (bool success, bytes memory result) = address(proxy).call(
            dataForDelegateCall
        );
        assertTrue(success);
        assertEq(abi.encode("V1"), result);
        // upgrade to v2
        ImplV2 newImpl = new ImplV2();
        proxy.setImpl(address(newImpl));
        assertEq(address(newImpl), proxy.getImpl()); // addr check
        // delegatecall v1 version()
        (success, result) = address(proxy).call(dataForDelegateCall);
        assertTrue(success);
        assertEq(abi.encode("V2"), result);
        vm.stopPrank();

        // non-owner upgrade fails
        vm.expectRevert("should be admin");
        proxy.setImpl(address(prevImpl));
    }
}

contract Impl {
    event Result(uint256 value);

    function add(uint256 a, uint256 b) public returns (uint256 result) {
        result = a + b;
        emit Result(result);
    }
}

contract CollisionImpl {
    uint256 counter; // this refers "address impl"

    function increment() public {
        counter++;
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

contract Proxy {
    address private impl;

    function setImpl(address _impl) public {
        impl = _impl;
    }

    function getImpl() public view returns (address) {
        return impl;
    }

    fallback(bytes calldata data) external returns (bytes memory) {
        (bool success, bytes memory res) = address(impl).delegatecall(data);
        require(success, "Delegatecall failed");
        return res;
    }
}

contract EIP1967 {
    bytes32 private constant _IMPL_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 private constant _ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    constructor() {
        bytes32 _implSlot = bytes32(
            uint256(keccak256("eip1967.proxy.implementation")) - 1
        );
        bytes32 _adminSlot = bytes32(
            uint256(keccak256("eip1967.proxy.admin")) - 1
        );
        require(_IMPL_SLOT == _implSlot, "impl slot error");
        require(_ADMIN_SLOT == _adminSlot, "admin slot error");
        address owner = msg.sender;
        assembly {
            // although can update with caller()
            // this works same but no-gas advantage, so use high-level msg.sender
            sstore(_ADMIN_SLOT, owner)
        }
    }

    modifier onlyOwner() {
        address admin;
        assembly {
            admin := sload(_ADMIN_SLOT)
        }
        require(admin == msg.sender, "should be admin");
        _;
    }

    function setImpl(address _impl) public onlyOwner {
        assembly {
            sstore(_IMPL_SLOT, _impl)
        }
    }

    function getImpl() public view returns (address impl) {
        assembly {
            impl := sload(_IMPL_SLOT)
        }
    }

    function getOwner() public view returns (address owner) {
        assembly {
            owner := sload(_ADMIN_SLOT)
        }
    }

    fallback(bytes calldata data) external returns (bytes memory result) {
        (bool success, bytes memory _result) = getImpl().delegatecall(data);
        require(success, "delegate call failed!");
        result = _result;
    }
}
