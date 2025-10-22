// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;


import "./Storage.sol";

contract ContestRoyalty is Storage  {

    
    constructor() {
  
    }

    function _closeTopRoyalty() internal {
        
        if (block.timestamp < topRoyaltyStartTime + MONTH_DURATION) return;
        uint currentRound = topRoyaltyRound;
        topRoyalty storage curentTopRoyalty = topRoyaltydtl[currentRound];

        // Prevent double closing
        // if (curentMonthRoyalty.endTime > 0 && block.timestamp < curentMonthRoyalty.endTime) {
        //     return;
        // }
        if (curentTopRoyalty.closed) return;
        uint qualifiedCount = topRoyaltyQualifiedUsers.length;
        uint perUserReward;
        uint distributedAmount;
        uint leftover;

        if (qualifiedCount > 0) {
            // Calculate reward distribution              
            
            perUserReward = topRoyaltyReward / qualifiedCount;
            distributedAmount = perUserReward * qualifiedCount;
            leftover = topRoyaltyReward - distributedAmount;
        } else {
            // No qualified users → carry forward all
            leftover = topRoyaltyReward;
            distributedAmount = 0;
            perUserReward = 0;
        }

        // Store round data
        curentTopRoyalty.roundId = currentRound;
        curentTopRoyalty.perUserReward = perUserReward;
        curentTopRoyalty.totalUsers = qualifiedCount;
        curentTopRoyalty.totalReward = topRoyaltyReward;//distributedAmount;
        curentTopRoyalty.carryForward = leftover;
        curentTopRoyalty.endTime = topRoyaltyStartTime + MONTH_DURATION;
        curentTopRoyalty.closed = true;

        // Prepare next round
        topRoyaltyStartTime = curentTopRoyalty.endTime;
        topRoyaltyRound = currentRound + 1;
        topRoyaltyReward = leftover; // carry forward

        emit TopRoyaltyClosed(currentRound, qualifiedCount, perUserReward,  distributedAmount+leftover, distributedAmount, leftover, curentTopRoyalty.endTime);
        
    }


    function claimTopRoyaltyReward(uint _userId, uint _roundId) external nonReentrant {
        
        User storage user = users[_userId];
        address userAddress = user.account ;
        require(userAddress == msg.sender, "Not your account");
        require(userAddress != address(0), "Invalid account");

        require(_userId > 0 && _roundId > 0 && topRoyaltydtl[_roundId].closed == true && _roundId < topRoyaltyRound, "Invalid userId or roundId or round or not closed");
        topRoyaltyUser storage userRoyalty  = topRoyaltyUserdtl[_userId];
        topRoyalty storage currentTopRoyalty = topRoyaltydtl[_roundId];

        require(userRoyalty.isQualified == true, "Not qualified ");
        require(!userRoyalty.isClaimed[_roundId], "Already claimed for this round");
        require(currentTopRoyalty.perUserReward > 0, "No reward to claim");
        require(currentTopRoyalty.claimedCount < currentTopRoyalty.totalUsers, "All users claimed");
        require(userRoyalty.qualifiedRoundId <= _roundId, "Not eligible to claim");
        uint amount = currentTopRoyalty.perUserReward;
  
        currentTopRoyalty.claimedCount += 1;
        userRoyalty.isClaimed[_roundId] = true;
        
        _distributeIncome(_userId, _userId, amount, 0, IncomeType.TopRoyalty);       
       
        emit TopRoyaltyRewardClaim(_roundId, _userId, amount,  block.timestamp);
    } 

    function canClaimMonthlyReward(uint _userId, uint _roundId) external view returns (bool) {
        monthlyRoyaltyUser storage userRoyalty = monthlyRoyaltyUserdtl[_userId];
        monthlyRoyalty storage royalty = monthlyRoyaltydtl[_roundId];

        if (
            !royalty.closed ||
            _roundId >= currentMonthlyRound ||
            !userRoyalty.isQualified ||
            userRoyalty.qualifiedRoundId > _roundId ||
            userRoyalty.isClaimed[_roundId] ||
            royalty.perUserReward == 0
        ) {
            return false;
        }
        return true;
    }

    
    function _closeMonthlyRoyalty() internal {
        
        if (block.timestamp >= (currentMonthlyStartTime + MONTH_DURATION)) {
            uint currentRound = currentMonthlyRound;
            monthlyRoyalty storage curentMonthRoyalty = monthlyRoyaltydtl[currentRound];

            // Prevent double closing
            // if (curentMonthRoyalty.endTime > 0 && block.timestamp < curentMonthRoyalty.endTime) {
            //     return;
            // }
            if (curentMonthRoyalty.closed) return;
            uint qualifiedCount = monthlyQualifiedUsers.length;
            uint perUserReward;
            uint distributedAmount;
            uint leftover;

            if (qualifiedCount > 0) {
                // Calculate reward distribution
                uint rawReward = monthlyTotalReward / qualifiedCount;
                perUserReward = (rawReward > monthlyCapping) ? monthlyCapping : rawReward;
                distributedAmount = perUserReward * qualifiedCount;
                leftover = (monthlyTotalReward > distributedAmount) ? monthlyTotalReward - distributedAmount : 0;
            } else {
                // No qualified users → carry forward all
                leftover = monthlyTotalReward;
                distributedAmount = 0;
                perUserReward = 0;
            }

            // Store round data
            curentMonthRoyalty.roundId = currentRound;
            curentMonthRoyalty.perUserReward = perUserReward;
            curentMonthRoyalty.totalUsers = qualifiedCount;
            curentMonthRoyalty.totalReward = monthlyTotalReward;//distributedAmount;
            curentMonthRoyalty.carryForward = leftover;
            curentMonthRoyalty.endTime = currentMonthlyStartTime + MONTH_DURATION;
            curentMonthRoyalty.closed = true;

            // Prepare next round
            currentMonthlyStartTime = curentMonthRoyalty.endTime;
            currentMonthlyRound = currentRound + 1;
            monthlyTotalReward = leftover; // carry forward

            emit MonthlyClosed(currentRound, qualifiedCount, perUserReward,  distributedAmount+leftover, distributedAmount, leftover, curentMonthRoyalty.endTime);
        }
    } 

    function claimMonthlyCRoyaltyReward(uint _userId, uint _roundId) external nonReentrant {
        
        User storage user = users[_userId];
        address userAddress = user.account ;
        require(userAddress == msg.sender, "Not your account");
        require(_userId > 0 && _roundId > 0 && monthlyRoyaltydtl[_roundId].closed == true && _roundId < currentMonthlyRound, "Invalid userId or roundId or round or not closed");
        monthlyRoyaltyUser storage userRoyalty  = monthlyRoyaltyUserdtl[_userId];
        monthlyRoyalty storage currentMonthRoyalty = monthlyRoyaltydtl[_roundId];

        require(userRoyalty.isQualified == true, "Not qualified ");
        require(!userRoyalty.isClaimed[_roundId], "Already claimed for this round");
        require(currentMonthRoyalty.perUserReward > 0, "No reward to claim");
        require(currentMonthRoyalty.claimedCount < currentMonthRoyalty.totalUsers, "All users claimed");
        require(userRoyalty.qualifiedRoundId <= _roundId, "Not eligible to claim");
        uint amount = currentMonthRoyalty.perUserReward;
  
        currentMonthRoyalty.claimedCount += 1;
        userRoyalty.isClaimed[_roundId] = true;
        
        _distributeIncome(_userId, _userId, amount, 0, IncomeType.MonthlyRoyalty);       
       
        emit MonthlyRewardClaim(_roundId, _userId, amount,  block.timestamp);
    } 

    function _closeWeeklyContest() internal {
        
        if (block.timestamp >= (currentWeeklyStartTime + WEEK_DURATION)) {
            uint currentRound = currentWeeklyRound;
            WeeklyContest storage curentWeekContest = weeklyContestdtl[currentRound];

            // Prevent double closing
            // if (curentWeekContest.endTime > 0 && block.timestamp < curentWeekContest.endTime) {
            //     return;
            // }
            if (curentWeekContest.closed) return;

            uint qualifiedCount = weeklyQualifiedUsers[currentRound].length;
            uint perUserReward;
            uint distributedAmount;
            uint leftover;

            if (qualifiedCount > 0) {
                // Calculate reward distribution
                uint rawReward = WeeklyTotalReward / qualifiedCount;
                perUserReward = (rawReward > WeeklyCapping) ? WeeklyCapping : rawReward;
                distributedAmount = perUserReward * qualifiedCount;
                leftover = (WeeklyTotalReward > distributedAmount) ? WeeklyTotalReward - distributedAmount : 0;
            } else {
                // No qualified users → carry forward all
                leftover = WeeklyTotalReward;
                distributedAmount = 0;
                perUserReward = 0;
            }

            // Store round data
            curentWeekContest.roundId = currentRound;
            curentWeekContest.perUserReward = perUserReward;
            curentWeekContest.totalUsers = qualifiedCount;
            curentWeekContest.totalReward = WeeklyTotalReward;//distributedAmount;
            curentWeekContest.carryForward = leftover;
            curentWeekContest.endTime = currentWeeklyStartTime + WEEK_DURATION;
            curentWeekContest.closed = true;

            // Prepare next round
            currentWeeklyStartTime = curentWeekContest.endTime;
            currentWeeklyRound = currentRound + 1;
            WeeklyTotalReward = leftover; // carry forward

             emit WeeklyClosed(currentRound, qualifiedCount, perUserReward,  distributedAmount+leftover, distributedAmount, leftover, curentWeekContest.endTime);
        }
    }   

    function claimWeeklyContestReward(uint _userId, uint _roundId) external nonReentrant {
        
        User storage user = users[_userId];
        address userAddress = user.account ;
        require(userAddress == msg.sender, "Not your account");
        require(_userId > 0 && _roundId > 0 && weeklyContestdtl[_roundId].closed == true && _roundId < currentWeeklyRound, "Invalid userId or roundId or round or not closed");
        weeklyUser storage weeklyuserdtl = weeklyUserdtl[_roundId][_userId];
        WeeklyContest storage curentWeekContest = weeklyContestdtl[_roundId];
        require(weeklyuserdtl.isQualified == true && weeklyuserdtl.isClaimed == false, "Not qualified or already claimed");
        require(curentWeekContest.perUserReward > 0, "No reward to claim");
        require(curentWeekContest.claimedCount < curentWeekContest.totalUsers, "All users claimed");

        uint amount = curentWeekContest.perUserReward;
  
        curentWeekContest.claimedCount += 1;
        weeklyuserdtl.isClaimed = true;
        
        _distributeIncome(_userId, _userId, amount, 0, IncomeType.WeeklyContest);       
       
        emit WeeklyRewardClaim(_roundId, _userId, amount,  block.timestamp);
    }   

    





    // --- View helper (for frontend) ---
    

    // Deposit funds
   // receive() external payable {}
}
