// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;


//import "./core/Ownable.sol";
import "./modules/Storage.sol";

import "./modules/ContestRoyalty.sol";
import "./modules/SponsorMatrix.sol";
import "./modules/InfinityPool.sol";

contract MainSystem is Storage, ContestRoyalty, Nanakshahi {
    

     constructor(address _usdt, address _creatorWallet) {
       usdt = IERC20(_usdt);
        creatorWallet = _creatorWallet;
    
        defaultRefId = 1000;
        totalUsers = 1;
        
        // Initialize creator account
        User storage creator = users[defaultRefId];
        creator.account = _creatorWallet;
        creator.id = defaultRefId;
        creator.level = 15; // Creator starts at max level
        creator.registrationTime = block.timestamp;
        creator.poollevel = 7;
        creator.boosterlevel = 8;
        creator.directPoolQualified = 2;
        creator.roiCap = 20;
        
        // Set initial deposit for creator
        uint totalDeposit = 0;
        for(uint i = 0; i < 15; i++) {
            totalDeposit += packages[i];
        }
        creator.totalDeposit = totalDeposit;
        addressToId[_creatorWallet] = defaultRefId;

        totalDeposit = 0;
        for(uint j = 0; j < poolPackages.length; j++) {
            totalDeposit += poolPackages[j];
            userPooldtl[j][defaultRefId] = UserPool({
                id: defaultRefId,
                mainid: defaultRefId,
                poolId: j,
                parentId: 0,
                bonusCount: 0
            });
            poolUsers[j].push(defaultRefId);
            userIdPerPool[j][defaultRefId].push(defaultRefId);
        }
        creator.poolDeposit = totalDeposit;

        totalDeposit =0;
         for(uint k = 0; k < 8; k++) {
             totalDeposit += glbBoosterPackages[k];
            userBoosterdtl[k][defaultRefId] = UserBooster({
                id: defaultRefId,              
                poolId: k,
                parentId: 0,
                bonusCount: 0,
                joinTime: block.timestamp
            });
            boosterUsers[k].push(defaultRefId);
            
        }
       creator.boosterDeposit = totalDeposit;

        currentWeeklyStartTime = block.timestamp;
        currentMonthlyStartTime = block.timestamp;
        topRoyaltyStartTime = block.timestamp;

        WeeklyTotalReward = 0;
        currentWeeklyRound = 1;

        monthlyTotalReward = 0;
        currentMonthlyRound = 1;    

        topRoyaltyReward = 0;
        topRoyaltyRound = 1;

        weeklyUser storage weeklyuserdtl = weeklyUserdtl[currentWeeklyRound][defaultRefId];
        weeklyQualifiedUsers[currentWeeklyRound].push(defaultRefId);

        weeklyuserdtl.joinTime = block.timestamp;
        weeklyuserdtl.roundId = currentWeeklyRound;
        weeklyuserdtl.isQualified = true;
   
        emit WeeklyContestQualified(currentWeeklyRound, defaultRefId, block.timestamp);
    }
}
