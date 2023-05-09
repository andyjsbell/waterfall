// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./Tags.sol";

contract Provider is IProvider {

    mapping(address => bool) providers;

    function isProvider(address _providerAddress) public view returns (bool) {
        return providers[_providerAddress];
    }

    function registerProvider(address _providerAddress) public {
        providers[_providerAddress] = true;
    }
}