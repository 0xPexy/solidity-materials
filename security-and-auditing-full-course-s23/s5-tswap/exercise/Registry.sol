// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Registry {
    error PaymentNotEnough(uint256 expected, uint256 actual);

    uint256 public constant PRICE = 1 ether;

    mapping(address account => bool registered) private registry;

    function register() external payable {
        if (msg.value < PRICE) {
            revert PaymentNotEnough(PRICE, msg.value);
        }

        registry[msg.sender] = true;
    }

    function isRegistered(address account) external view returns (bool) {
        return registry[account];
    }
}

contract RegistryFixed {
    error PaymentNotEnough(uint256 expected, uint256 actual);

    event Registered(address addr);
    uint256 public constant PRICE = 1 ether;

    mapping(address account => bool registered) private registry;

    function register() external payable {
        if (msg.value < PRICE) {
            revert PaymentNotEnough(PRICE, msg.value);
        }

        registry[msg.sender] = true;
        emit Registered(msg.sender);
        (bool success, ) = msg.sender.call{value: msg.value - PRICE}("");
        require(success, "Registry: failed to transfer change");
    }

    function isRegistered(address account) external view returns (bool) {
        return registry[account];
    }
}
