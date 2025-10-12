// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../core/Ownable.sol";

contract ContestRoyalty is Ownable {

    uint public constant WEEK_DURATION = 7 days;
    uint public constant MONTH_DURATION = 30 days;

    uint public currentWeeklyRound = 1;
    uint public currentMonthlyRound = 1;
    uint public lastWeeklyReset;
    uint public lastMonthlyReset;

    address[] public qualifiedWeekly;
    address[] public qualifiedMonthly;

    struct RoundInfo {
        uint id;
        uint totalUsers;
        uint totalReward;
        uint perUserReward;
        uint startTime;
        uint endTime;
        bool closed;
    }

    mapping(uint => RoundInfo) public weeklyRounds;
    mapping(uint => RoundInfo) public monthlyRounds;

    event RoundEnded(string period, uint roundId, uint users, uint perUser);
    event UserQualified(address indexed user, string period, uint roundId);

    constructor() {
        lastWeeklyReset = block.timestamp;
        lastMonthlyReset = block.timestamp;
        weeklyRounds[currentWeeklyRound].startTime = block.timestamp;
        monthlyRounds[currentMonthlyRound].startTime = block.timestamp;
    }

    // --- User qualification ---
    function qualifyWeekly() external payable {
        _checkWeeklyRound();
        qualifiedWeekly.push(msg.sender);
        emit UserQualified(msg.sender, "Weekly", currentWeeklyRound);
    }

    function qualifyMonthly() external payable {
        _checkMonthlyRound();
        qualifiedMonthly.push(msg.sender);
        emit UserQualified(msg.sender, "Monthly", currentMonthlyRound);
    }

    // --- Internal checkers ---
    function _checkWeeklyRound() internal {
        if (block.timestamp >= lastWeeklyReset + WEEK_DURATION) {
            _endWeeklyRound();
        }
    }

    function _checkMonthlyRound() internal {
        if (block.timestamp >= lastMonthlyReset + MONTH_DURATION) {
            _endMonthlyRound();
        }
    }

    // --- Round enders ---
    function _endWeeklyRound() internal {
        uint users = qualifiedWeekly.length;
        uint total = address(this).balance / 2;
        uint perUser = users > 0 ? total / users : 0;

        weeklyRounds[currentWeeklyRound] = RoundInfo({
            id: currentWeeklyRound,
            totalUsers: users,
            totalReward: total,
            perUserReward: perUser,
            startTime: lastWeeklyReset,
            endTime: block.timestamp,
            closed: true
        });

        emit RoundEnded("Weekly", currentWeeklyRound, users, perUser);

        currentWeeklyRound++;
        lastWeeklyReset = block.timestamp;
        delete qualifiedWeekly;
    }

    function _endMonthlyRound() internal {
        uint users = qualifiedMonthly.length;
        uint total = address(this).balance / 2;
        uint perUser = users > 0 ? total / users : 0;

        monthlyRounds[currentMonthlyRound] = RoundInfo({
            id: currentMonthlyRound,
            totalUsers: users,
            totalReward: total,
            perUserReward: perUser,
            startTime: lastMonthlyReset,
            endTime: block.timestamp,
            closed: true
        });

        emit RoundEnded("Monthly", currentMonthlyRound, users, perUser);

        currentMonthlyRound++;
        lastMonthlyReset = block.timestamp;
        delete qualifiedMonthly;
    }

    // Deposit funds
    receive() external payable {}
}
