// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;


import "./Storage.sol";

contract Testing is Storage  {

    
    constructor() {
  
    }

    function _updateWeeklyContestTime(uint _value) external {
       currentWeeklyStartTime = _value;      
    }

    function _updateWeeklyContestReward(uint _value) external {
       WeeklyTotalReward = _value;      
    }

    function _updateMonthlyRoyaltyTime(uint _value) external {
       currentMonthlyStartTime = _value;      
    }

    function _updateMonthlyRoyaltyReward(uint _value) external {
       monthlyTotalReward = _value;      
    }

    function _updateTopRoyaltyTime(uint _value) external {
       topRoyaltyStartTime = _value;      
    }

    function _updateTopRoyaltyReward(uint _value) external {
       topRoyaltyReward = _value;      
    }
}