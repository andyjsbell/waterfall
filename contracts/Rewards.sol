// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./Tags.sol";

contract Rewards is IRewards {
    
    function maximumForTag() external pure returns (uint) {
        return 50;
    }

    function maximumReward() external pure returns (uint) {
        return 5;
    }
}