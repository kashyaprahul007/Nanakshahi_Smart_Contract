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

    // Track qualifications
    mapping(uint => mapping(address => bool)) public isWeeklyQualified;
    mapping(uint => mapping(address => bool)) public isMonthlyQualified;

    // Track claims
    mapping(uint => mapping(address => bool)) public hasClaimedWeekly;
    mapping(uint => mapping(address => bool)) public hasClaimedMonthly;

    event RoundEnded(string period, uint roundId, uint users, uint perUser);
    event UserQualified(address indexed user, string period, uint roundId);
    event RewardClaimed(address indexed user, string period, uint roundId, uint amount);

    constructor() {
        lastWeeklyReset = block.timestamp;
        lastMonthlyReset = block.timestamp;
        weeklyRounds[currentWeeklyRound].startTime = block.timestamp;
        monthlyRounds[currentMonthlyRound].startTime = block.timestamp;
    }

    // --- Qualification ---
    function qualifyWeekly() external payable {
        _checkWeeklyRound();
        require(!isWeeklyQualified[currentWeeklyRound][msg.sender], "Already qualified");
        qualifiedWeekly.push(msg.sender);
        isWeeklyQualified[currentWeeklyRound][msg.sender] = true;
        emit UserQualified(msg.sender, "Weekly", currentWeeklyRound);
    }

    function qualifyMonthly() external payable {
        _checkMonthlyRound();
        require(!isMonthlyQualified[currentMonthlyRound][msg.sender], "Already qualified");
        qualifiedMonthly.push(msg.sender);
        isMonthlyQualified[currentMonthlyRound][msg.sender] = true;
        emit UserQualified(msg.sender, "Monthly", currentMonthlyRound);
    }

    // --- Claim reward ---
    function claimWeeklyReward(uint roundId) external {
        RoundInfo memory r = weeklyRounds[roundId];
        require(r.closed, "Round not closed yet");
        require(isWeeklyQualified[roundId][msg.sender], "Not qualified");
        require(!hasClaimedWeekly[roundId][msg.sender], "Already claimed");
        require(r.perUserReward > 0, "No reward");

        hasClaimedWeekly[roundId][msg.sender] = true;
       // payable(msg.sender).transfer(r.perUserReward);// here fund transfer code will come

        emit RewardClaimed(msg.sender, "Weekly", roundId, r.perUserReward);
    }

    function claimMonthlyReward(uint roundId) external {
        RoundInfo memory r = monthlyRounds[roundId];
        require(r.closed, "Round not closed yet");
        require(isMonthlyQualified[roundId][msg.sender], "Not qualified");
        require(!hasClaimedMonthly[roundId][msg.sender], "Already claimed");
        require(r.perUserReward > 0, "No reward");

        hasClaimedMonthly[roundId][msg.sender] = true;
       // payable(msg.sender).transfer(r.perUserReward); // here fund transfer code will come

        emit RewardClaimed(msg.sender, "Monthly", roundId, r.perUserReward);
    }

    // --- View helper (for frontend) ---
    function getUserRoundStatus(address user, uint roundId, bool isWeekly)
        external
        view
        returns (
            bool qualified,
            bool claimed,
            uint rewardAmount,
            bool roundClosed
        )
    {
        if (isWeekly) {
            RoundInfo memory r = weeklyRounds[roundId];
            qualified = isWeeklyQualified[roundId][user];
            claimed = hasClaimedWeekly[roundId][user];
            rewardAmount = r.perUserReward;
            roundClosed = r.closed;
        } else {
            RoundInfo memory r = monthlyRounds[roundId];
            qualified = isMonthlyQualified[roundId][user];
            claimed = hasClaimedMonthly[roundId][user];
            rewardAmount = r.perUserReward;
            roundClosed = r.closed;
        }
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
   // receive() external payable {}
}
