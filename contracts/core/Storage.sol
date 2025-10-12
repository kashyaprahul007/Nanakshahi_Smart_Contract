pragma solidity ^0.8.20;

contract Storage {
    struct User {
        uint id;
        address account;
        uint sponsorId;
        uint totalIncome;
        uint currentLevel;
        bool active;
    }

    mapping(uint => User) public users;
    mapping(address => uint) public userIds;

    uint public roundId;
}
