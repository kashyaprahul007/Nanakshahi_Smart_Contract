// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;


import "./Storage.sol";

contract Getter is Storage  {

    
    constructor() {
  
    }

      // View functions
    function getUserInfo(uint _userId) external view returns (
        address account,
        uint id,
        uint sponsorId,
        uint uplineId,
        uint level,
        uint directTeam,
        uint totalMatrixTeam,
        uint totalDeposit
    ) {
        User storage user = users[_userId];
        return (
            user.account,
            user.id,
            user.sponsorId,
            user.uplineId,
            user.level,
            user.directTeam,
            user.totalMatrixTeam,
            user.totalDeposit
        );
    }

    function getDirectsUsersEssentialInfo(uint _userId) external view returns (
    uint[] memory ids,
    address[] memory accounts,
    uint[] memory levels,
    uint[] memory totalDeposits,
    uint[] memory registrationTimes
    ){
        uint[] memory directIds = directReferrals[_userId];
        uint length = directIds.length;
        
        ids = new uint[](length);
        accounts = new address[](length);
        levels = new uint[](length);
        totalDeposits = new uint[](length);
        registrationTimes = new uint[](length);
        
        for(uint i = 0; i < length; i++) {
            User storage user = users[directIds[i]];
            ids[i] = user.id;
            accounts[i] = user.account;
            levels[i] = user.level;
            totalDeposits[i] = user.totalDeposit;
            registrationTimes[i] = user.registrationTime;
        }
    }
    
    function getUserIncomeDetails(uint _userId) external view returns (
       UserIncome memory
        
    ) {
        return userIncomes[_userId];
       
    }
    
    function getMatrixUsers(uint _user, uint _layer) external view returns(User[] memory) {
        User[] memory teamUsers = new User[](teams[_user][_layer].length);

        for(uint i=0; i<teams[_user][_layer].length; i++) {
            teamUsers[i] = users[teams[_user][_layer][i]];
        }
        return teamUsers;
    }
    
    function getUserTeam(uint _userId) external view returns (uint[][] memory) {
        uint[][] memory result = new uint[][](maxLayers);
        for (uint i = 0; i < maxLayers; i++) {
            result[i] = teams[_userId][i];
        }
        return result;
    }
    
    // function getUserIncomeHistory(uint _userId) external view returns (Income[] memory) {
    //     return incomeHistory[_userId];
    // }
    
    
    // Combined view function for complete user data (if needed)
    function getCompleteUserInfo(uint _userId) external view returns (User memory) {
        return  users[_userId];
       
    }

    function getUserPackage(uint _userId)external view returns (UserPackage[] memory packagesdtl)
    {
        User storage user = users[_userId];
        require(user.id != 0, "User not found");

        // Create a memory array with known length
        packagesdtl = new UserPackage[](user.level);

        for (uint i = 0; i < user.level; i++) {
            uint packagePrice = packages[i]; // assumes you have a global packages array
            packagesdtl[i] = userPackage[_userId][packagePrice];
        }

        return packagesdtl;
    }
    
    function getMatrixDirect(uint _userId) external view returns (uint) {
        return matrixDirect[_userId];
    }


    /* Pool and Booster Getters*/

    function getUserPoolIds(uint _poolId, uint _userId)external view returns ( uint[] memory)   
    {
        return userIdPerPool[_poolId][_userId];
    }


    function getPoolDetails(uint _poolId, uint _userId)external view returns (UserPool memory)   
    {
        return userPooldtl[_poolId][_userId];
    }

    function getPoolChild(uint _poolId, uint _userId)external view returns ( uint[] memory)   
    {
        return userChildren[_poolId][_userId];
    }

    function getPoolTopup(uint _poolId, uint _userId)external view returns ( UserPoolTopup memory)   
    {       
        return userPooltopup[_poolId][_userId];
    }

    /* booster details*/

    function getBoosterDetails(uint _poolId, uint _userId)external view returns (UserBooster memory)   
    {
        return userBoosterdtl[_poolId][_userId];
    }

    function getBoosterChild(uint _poolId, uint _userId)external view returns ( uint[] memory)   
    {
        return userBoosterChildren[_poolId][_userId];
    }

    /*weekly contest*/

    function getCurrrentContestDetails()external view returns (uint[] memory, uint[] memory, uint[] memory)   
    {
        uint[] memory _currentWeeklyContest = new uint[](4);
        uint[] memory _currentMonthlyRoyalty = new uint[](4);
        uint[] memory _currentTopRoyalty = new uint[](4);

        _currentWeeklyContest[0] = currentWeeklyRound;
        _currentWeeklyContest[1] = WeeklyTotalReward;
        _currentWeeklyContest[2] = weeklyQualifiedUsers[currentWeeklyRound].length;
        _currentWeeklyContest[3] = currentWeeklyStartTime;

        _currentMonthlyRoyalty[0] = currentMonthlyRound;
        _currentMonthlyRoyalty[1] = monthlyTotalReward;
        _currentMonthlyRoyalty[2] = monthlyQualifiedUsers.length;
        _currentMonthlyRoyalty[3] = currentMonthlyStartTime;

        _currentTopRoyalty[0] = topRoyaltyRound;
        _currentTopRoyalty[1] = topRoyaltyReward;
        _currentTopRoyalty[2] = topRoyaltyQualifiedUsers.length;
        _currentTopRoyalty[3] = topRoyaltyStartTime;

        return (_currentWeeklyContest,
                _currentMonthlyRoyalty,
                _currentTopRoyalty
        );
    }

    function getWeeklyContestDetails(uint _roundId)external view returns (WeeklyContest memory)   
    {
        require(_roundId <= currentWeeklyRound && _roundId > 0, "Invalid or not closed");
        return weeklyContestdtl[_roundId];
    }

    function getWeeklyUserDetails(uint _roundId, uint _userId)external view returns (weeklyUser memory)   
    {
        require(_roundId <= currentWeeklyRound && _roundId > 0, "Invalid or not closed");       
        return weeklyUserdtl[_roundId][_userId];
    }

    function getWeeklyUserDirects(uint _roundId, uint _userId) external view returns (uint [] memory)
    {
        return  weeklyUserDirects[_roundId][_userId];
    }

     function getMonthlyRoyaltyDetails(uint _roundId)external view returns (monthlyRoyalty memory)   
    {
        require(_roundId <= currentMonthlyRound && _roundId > 0, "Invalid or not closed");
        return monthlyRoyaltydtl[_roundId];
    }   



    function getUserMonthlyRoyaltyDetails(uint _roundId, uint _userId) external view returns (uint joinTime, uint qualifiedRoundId, uint claimTime, bool isQualified)
    {
        require(_roundId <= currentMonthlyRound && _roundId > 0, "Invalid or not closed");

        monthlyRoyaltyUser storage u = monthlyRoyaltyUserdtl[_userId];
        return (u.joinTime, u.qualifiedRoundId, u.claimTime, u.isQualified);
    }

    function isUserClaimedMonthlyRoyalty(uint _roundId, uint _userId) external view returns (bool)
    {
        require(monthlyRoyaltyUserdtl[_userId].qualifiedRoundId >= _roundId && _roundId > 0, "Not qualified");
        return monthlyRoyaltyUserdtl[_userId].isClaimed[_roundId];
    }

    function getMonthlyRoyaltyUserDirects( uint _userId) external view returns (uint [] memory)
    {
        return monthlyUserDirects[_userId];
    }



    function getTopRoyaltyDetails(uint _roundId)external view returns (topRoyalty memory)   
    {
        require(_roundId <= topRoyaltyRound && _roundId > 0, "Invalid or not closed");
        return topRoyaltydtl[_roundId];
    }   

    function getUserTopRoyaltyDetails(uint _roundId, uint _userId) external view returns (uint joinTime, uint qualifiedRoundId, uint claimTime, bool isQualified)
    {
        require(_roundId <= currentMonthlyRound && _roundId > 0, "Invalid or not closed");

        topRoyaltyUser storage u = topRoyaltyUserdtl[_userId];
        return (u.joinTime, u.qualifiedRoundId, u.claimTime, u.isQualified);
    }

    function isUserClaimedTopRoyalty(uint _roundId, uint _userId) external view returns (bool)
    {
        require(topRoyaltyUserdtl[_userId].qualifiedRoundId >= _roundId && _roundId > 0, "Not qualified");
        return topRoyaltyUserdtl[_userId].isClaimed[_roundId];
    }

    function getTopRoyaltyUserDirects( uint _userId) external view returns (uint [] memory)
    {
        return topRoyaltyUserDirects[_userId];
    }

}