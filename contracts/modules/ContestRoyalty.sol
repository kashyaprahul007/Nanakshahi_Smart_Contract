// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;


import "./Storage.sol";

contract ContestRoyalty is Storage  {

    
    constructor() {
  
    }



    function claimTopRoyaltyReward(uint _userId, uint _roundId) external nonReentrant {
        
        _closeContestRoyalty();
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

  
    function claimMonthlyCRoyaltyReward(uint _userId, uint _roundId) external nonReentrant {
        
        _closeContestRoyalty();
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



    function claimWeeklyContestReward(uint _userId, uint _roundId) external nonReentrant {
        
        _closeContestRoyalty();
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
