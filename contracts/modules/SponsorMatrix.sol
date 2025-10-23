// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
//import "../interfaces/IERC20.sol";
import "./Storage.sol";

contract Nanakshahi is Storage{
   
    
    constructor() {
       
    }

    
   
     function register(uint _sponsorId) external {
        require(addressToId[msg.sender] == 0, "Already registered");
        require(users[_sponsorId].id > 0, "Invalid sponsor");
        
        // Transfer USDT for the first package
        usdt.transferFrom(msg.sender, address(this), packages[0]);
        
        
        // Create new user
        uint newUserId = defaultRefId + totalUsers ;
        totalUsers += 1;
        addressToId[msg.sender] = newUserId;
        
        uint nowTime = block.timestamp;      
        uint packagePrice = packages[0];

        User storage user = users[newUserId];
        user.account = msg.sender;
        user.checkpoint = nowTime;
        user.id = newUserId;
        user.sponsorId = _sponsorId;
        user.level = 1;
        user.totalDeposit = packagePrice;
        user.registrationTime = nowTime;
        user.roiCap = 15;
        
        // Update sponsor direct team count
        users[_sponsorId].directTeam += 1;
        directReferrals[_sponsorId].push(newUserId);
       // registeredUserIds.push(newUserId);
        
        userPackage[newUserId][packagePrice].qualified = true; 
        packageQualifiedUsers[packagePrice] += 1;

        //communityDebt[newUserId] = communityAccPerUser;
         communityDebt[packagePrice][newUserId] = communityAccPerPackage[packagePrice];
        // Find placement in 2x2 matrix
        _placeInMatrix(newUserId, _sponsorId);

        // add in Deposit 
        // user.deposits.push(Deposit({
        //     amount: packages[0],
        //     withdrawn: 0,
        //     start: block.timestamp,
        //     depositType:1
        // }));
        // Distribute income
       
        uint creatorShare = packagePrice * 5 / 100; // 5% to creator
        uint remainingAmount = packagePrice * 60 / 100;    // 60% distributable
        /*5 %  for weekly Contest and Roaylty */

        WeeklyTotalReward +=  packagePrice * 5 / 100;
        monthlyTotalReward +=  packagePrice * 35 / 1000;
        topRoyaltyReward +=  packagePrice * 15 / 1000;
      
        uint communityShare = packagePrice * 25 / 100;
            // 9) accrue community bonus (no O(N) loop; users claim via claimCommunity)
        _accrueCommunityBonus(communityShare, packagePrice);

          
        // Send creator share
        _sendToCreator(creatorShare);
        
        // 60% to sponsor as first level income
        _distributeSponsorIncome(user.sponsorId, newUserId, remainingAmount, 1);
        
      
        emit Upgrade(msg.sender, newUserId,  1, packagePrice, "Sponsorship Structure", nowTime);
        emit Registration(msg.sender, users[_sponsorId].account, newUserId, user.uplineId);
    }
    
    function upgrade(uint _userId) external {
        User storage user = users[_userId];
        require(user.account == msg.sender, "Not your account");
        require(user.level < 15, "Already at max level");
        
        uint nextLevel = user.level;
        uint packagePrice = packages[nextLevel];
        uint nowTime = block.timestamp;
        
        // Transfer USDT for the next package
        usdt.transferFrom(msg.sender, address(this), packagePrice);
        
        user.level += 1;
        user.totalDeposit += packagePrice;
        userPackage[_userId][packagePrice].qualified = true;    
        // Distribute income
        uint creatorShare = packagePrice * 5 / 100; // 5% to creator
      
         uint communityShare = packagePrice * 25 / 100;
        _accrueCommunityBonus(communityShare, packagePrice);

        communityDebt[packagePrice][_userId] = communityAccPerPackage[packagePrice];
        // Send creator share
        _sendToCreator(creatorShare);
        packageQualifiedUsers[packagePrice] += 1;
        // sponsor income 15% for all package so call it once
        // nextLevel is package, when 1 then its mean 2nd package
        uint sponsorIncome = packagePrice * 20 / 100;
        _distributeSponsorIncome(user.sponsorId, _userId, sponsorIncome, nextLevel + 1);

        uint uplineIncome = packagePrice * 20 / 100;
        _distributeMatrixIncome(user.uplineId, _userId, uplineIncome, nextLevel + 1);

        uint boosterIncome = packagePrice * 20 / 100;
        _distributeLevelBoosterIncome(user.uplineId, _userId, boosterIncome, nextLevel + 1, nextLevel);

        WeeklyTotalReward +=  packagePrice * 5 / 100;
        monthlyTotalReward +=  packagePrice * 35 / 1000;
        topRoyaltyReward +=  packagePrice * 15 / 1000;
       // check for monthly royalty
        if((nextLevel+1) == MONTHLY_ROYALTY_LEVEL){
            
            user.level10Time = nowTime;
            User storage _user = users[_userId];
           // monthlyUserDirects[_user.sponsorId].push(_userId);

            User storage _sponsor = users[user.sponsorId];
            _sponsor.monthlyUserDirectCount +=1;
            if((_sponsor.monthlyUserDirectCount >= MONTHLY_ROYALTY_DIRECT) && (nowTime <= _sponsor.registrationTime + MONTHLY_ROYALTY_TIME) && (_sponsor.level >= MONTHLY_ROYALTY_LEVEL)){
                _tryMonthlyRoyaltyQualify( _user.sponsorId, currentMonthlyRound);
            }


            if((_user.monthlyUserDirectCount >= MONTHLY_ROYALTY_DIRECT) && (_user.level10Time <= _user.registrationTime + MONTHLY_ROYALTY_TIME) && (_user.level == MONTHLY_ROYALTY_LEVEL)  ){
                _tryMonthlyRoyaltyQualify( _userId, currentMonthlyRound);            
            }
        }


        // check for top royalty
        if((nextLevel+1) == TOP_ROYALTY_LEVEL){
            
            user.level15Time = nowTime;
            User storage _user = users[_userId];
           // monthlyUserDirects[_user.sponsorId].push(_userId);

            User storage _sponsor = users[user.sponsorId];
            _sponsor.topRoyaltyDirectCount +=1;
            if((_sponsor.topRoyaltyDirectCount >= TOP_ROYALTY_DIRECT) && (nowTime <= _sponsor.registrationTime + TOP_ROYALTY_TIME) && (_sponsor.level >= TOP_ROYALTY_LEVEL)){
                _tryTopRoyaltyQualify( _user.sponsorId, topRoyaltyRound);
            }


            if((_user.topRoyaltyDirectCount >= TOP_ROYALTY_DIRECT) &&(_user.level15Time <= _user.registrationTime + TOP_ROYALTY_TIME) && (_user.level == TOP_ROYALTY_LEVEL)  ){
                _tryTopRoyaltyQualify( _userId, topRoyaltyRound);            
            }
        }
        
        emit Upgrade(msg.sender, _userId, nextLevel + 1, packagePrice,    "Sponsorship Structure", nowTime);
    }
    
    function _applyGlobalCapping(uint _userId, uint _amount) internal view returns (uint) {
        User storage user = users[_userId];
        UserIncome storage income = userIncomes[_userId];
       
        uint _ROI_CAP_MULTIPLIER =   user.roiCap;
        uint maxIncome = (user.totalDeposit * _ROI_CAP_MULTIPLIER) / ROI_CAP_DIVIDER;

        if (income.totalIncome >= maxIncome) return 0;

        uint remaining = maxIncome - income.totalIncome;
        return (_amount > remaining) ? remaining : _amount;
    }

    function _accrueCommunityBonus(uint _totalAmount, uint package) internal {
        uint n = packageQualifiedUsers[package]; //registeredUserIds.length;
        if (n == 0 || _totalAmount == 0) {
            if (_totalAmount > 0) { _sendToCreator(_totalAmount); }
            return;
        }
        communityAccPerUser += (_totalAmount * ACC_PRECISION) / n;
    }



    // update package-based accumulator
    //     communityAccPerPackage[package] += (_totalAmount * ACC_PRECISION) / n;
    // }   


    // function claimCommunity(uint _userId) external {
    //         User storage u = users[_userId];
    //         require(u.id != 0, "User not found");
    //         require(u.account == msg.sender, "Not your account");

    //         // pending = (accumulator delta) scaled down
    //         uint256 accumulated = communityAccPerUser;
    //         uint256 debt = communityDebt[_userId];

    //         if (accumulated == debt) {
    //             return; // nothing to claim
    //         }

    //         uint256 accrued = (accumulated - debt) / ACC_PRECISION;
    //         if (accrued == 0) {
    //             communityDebt[_userId] = accumulated; // still sync debt
    //             return;
    //         }

    //         // apply global cap at claim time
    //         uint256 pay = _applyGlobalCapping(_userId, accrued);

    //         // effects (update debt first: checks-effects-interactions)
    //         communityDebt[_userId] = accumulated;

    //         if (pay > 0) {
    //             UserIncome storage inc = userIncomes[_userId];
    //             inc.totalIncome += pay;
    //             inc.communityIncome += pay;  // track claimed community bonus
    //             incomeHistory[_userId].push(Income({
    //                 fromUserId: _userId,
    //                 amount: pay,
    //                 packageLevel: 1,
    //                 timestamp: block.timestamp,
    //                 incomeType: 9 // Community Bonus
    //             }));

    //             // interaction
    //             require(usdt.transfer(u.account, pay), "USDT transfer failed");
    //         }

    //         // route any capped-away remainder to creator
    //         if (accrued > pay) {
    //             _sendToCreator(accrued - pay);
    //         }
    //     }

    function claimCommunity(uint _userId, uint packagePrice) external {
        User storage u = users[_userId];
        require(u.id != 0, "User not found");
        require(u.account == msg.sender, "Not your account");
        
        require(userPackage[_userId][packagePrice].qualified, "Invalid package");
        require(!userPackage[_userId][packagePrice].closed, "Package Closed");
   

        uint256 accumulated = communityAccPerPackage[packagePrice];
        uint256 debt = communityDebt[packagePrice][_userId];

        if (accumulated == debt) return;

        uint256 accrued = (accumulated - debt) / ACC_PRECISION;
        if (accrued == 0) {
            communityDebt[packagePrice][_userId] = accumulated;
            return;
        }

        uint256 pay = _applyGlobalCapping(_userId, accrued);

        communityDebt[packagePrice][_userId] = accumulated;

        if (pay > 0) {
            // UserIncome storage inc = userIncomes[_userId];
            // inc.totalIncome += pay;
            // inc.communityIncome += pay;
            // incomeHistory[_userId].push(Income({
            //     fromUserId: _userId,
            //     amount: pay,
            //     packageLevel: packageLevel,
            //     timestamp: block.timestamp,
            //     incomeType: 9
            // }));

            _distributeIncome(_userId, _userId, pay, packagePrice, IncomeType.Community);
            //require(usdt.transfer(u.account, pay), "USDT transfer failed");
        }

        if (accrued > pay) {
            _sendToCreator(accrued - pay);
        }
    }



    function pendingCommunity(uint _userId, uint _packagePrice) external view returns (uint pendingGross, uint pendingAfterCap) {
        if (users[_userId].id == 0) return (0, 0);
        uint256 acc =communityAccPerPackage[_packagePrice];// communityAccPerUser;
        uint256 debt = communityDebt[_packagePrice][_userId];// communityDebt[_userId];
        if (acc <= debt) return (0, 0);
        uint gross = (acc - debt) / ACC_PRECISION;
        uint net = _applyGlobalCapping(_userId, gross);
        return (gross, net);
    }


    function _placeInMatrix(uint _newUserId, uint _sponsorId) private {
        bool isFound;
        uint uplineId;

        // First check if sponsor has less than 2 matrix direct referrals
        if(matrixDirect[_sponsorId] < 2) {
            users[_newUserId].uplineId = _sponsorId;
            matrixDirect[_sponsorId] += 1;
            uplineId = _sponsorId;
        } else {
            // If sponsor already has 2 direct referrals, find a place in the team
            for(uint i=0; i<maxLayers; i++) { // Use a reasonable max depth for 2x2 matrix
                if(isFound) break;
                if(teams[_sponsorId][i+1].length < 2 ** (i+2)) {
                    for(uint j=0; j<teams[_sponsorId][i].length; j++) {
                      if(isFound) break;
                        uint temp = teams[_sponsorId][i][j];
                        if(matrixDirect[temp] < 2) {
                            users[_newUserId].uplineId = temp;
                            matrixDirect[temp] += 1;
                            uplineId = temp;
                            isFound = true;
                        } 
                    }
                }
            }
        }

        // Update team structure for all uplines
        for(uint k=0; k<maxLayers; k++) {
            if(uplineId == 0) break;
            users[uplineId].totalMatrixTeam += 1;
            teams[uplineId][k].push(_newUserId);
            uplineId = users[uplineId].uplineId;
        }
    }
    
    function _distributeSponsorIncome(uint _sponsorId, uint _fromId, uint _amount, uint _packageLevel) private {
        if (_sponsorId == 0 || _sponsorId == defaultRefId) {
            _sendToCreator(_amount);
            return;
        }
        
       
        
      
        // Update income in separate mapping
        // UserIncome storage sponsorIncome = userIncomes[_sponsorId];
        // sponsorIncome.totalIncome += _amount;
        // sponsorIncome.sponsorIncome += _amount;

        _distributeIncome(_sponsorId, _fromId, _amount, _packageLevel, IncomeType.Sponsor);   

        //User storage sponsor = users[_sponsorId];
       // usdt.transfer(sponsor.account, _amount);

        // Record income
        // incomeHistory[_sponsorId].push(Income({
        //     fromUserId: _fromId,
        //     amount: _amount,
        //     packageLevel: _packageLevel,
        //     timestamp: block.timestamp,
        //     incomeType: 1 // Sponsor income
        // }));
        
        // emit IncomeDistributed(sponsor.account, users[_fromId].account, _amount, _packageLevel, 1);
       
    }
    

    function _distributeMatrixIncome(uint _uplineId,uint _fromId,uint _amount, uint _packageLevel) private {
        // walk up the matrix chain looking for the first eligible ancestor

        // first need to get correct upline
   
        //)
        //uint depth = 1;
        if(_uplineId == defaultRefId || _uplineId == 0)
        {
            _sendToCreator(_amount);
            return;
        }       
        uint targetId = _uplineId;
        for (uint i = 1; i < _packageLevel; ++i) {
            targetId = users[targetId].uplineId;
            if (targetId == 0 || targetId == defaultRefId) {
                // No ancestor at that depth
                _sendToCreator(_amount);
                return;
            }
        }
        uint currentId = targetId;
        uint layer = 0;
        while (currentId != 0 && currentId != defaultRefId && layer < maxLayers) {
            User storage up = users[currentId];

            // eligibility: at least 2 directs AND level >= purchased level
            if (up.level >= _packageLevel) // up.directTeam >= 2 && 
            {
                // pay and record as Matrix income (type 2)

                _distributeIncome(currentId, _fromId, _amount, _packageLevel, IncomeType.Matrix);   

                // usdt.transfer(up.account, _amount);

                // UserIncome storage inc = userIncomes[currentId];
                // inc.totalIncome += _amount;
                // inc.matrixIncome += _amount;

                // incomeHistory[currentId].push(Income({
                //     fromUserId: _fromId,
                //     amount: _amount,
                //     packageLevel: _packageLevel,
                //     timestamp: block.timestamp,
                //     incomeType: 2 // matrix income
                // }));

                // emit IncomeDistributed(up.account, users[_fromId].account, _amount, _packageLevel, 2);
                return;
            }

            // move up one level in the matrix
            currentId = up.uplineId;
            layer++;
        }
        // nobody in the matrix chain qualified → send to creator/fees
        _sendToCreator(_amount);
    }
        
   

    
    function _distributeLevelBoosterIncome(uint _startId, uint _fromId, uint _amount,uint _packageLevel,uint _maxLevel) private {
        if (_startId == 0 || _startId == defaultRefId || _maxLevel == 0) {
            _sendToCreator(_amount);
            return;
        }

        //uint levelsToDistribute = _maxLevel; 
        uint amountPerLevel = _amount / _maxLevel;
        uint remainder = _amount - (amountPerLevel * _maxLevel);
        //uint spillover = 1;
       // uint baselineId = _startId;

        uint currentId = _startId;
        uint totalDistributed = 0;
        uint PaidCount = 0;
        uint accumulatedShares = 1; // starts with 1x share

        for (uint i = 0; i < 30; i++) // _maxLevel
        {
              // If we run out of uplines
            if (currentId == 0 || currentId == defaultRefId) {
                // Send any undistributed shares to creator
                uint remaining = _amount - totalDistributed;
                if (remaining > 0) _sendToCreator(remaining);
                return;
            }

            User storage up = users[currentId];

            if (up.level >= _packageLevel) {
                // Qualified: give all accumulated shares to this person
                uint payout = amountPerLevel * accumulatedShares;

                //_payLevelBooster(currentId, _fromId, payout, _packageLevel);
                _distributeIncome(currentId, _fromId, payout, _packageLevel, IncomeType.LevelBooster);   

                totalDistributed += payout;
                PaidCount += accumulatedShares;
                accumulatedShares = 1; // reset spillover
            } else {
                // Not qualified → roll share upward
                if(accumulatedShares<_maxLevel){
                     accumulatedShares++;
                }
               
            }
             // If we distributed all _maxLevel shares, stop
            if (PaidCount >= _maxLevel) break;
           
            //if (totalDistributed >= (_amount - remainder)) break;
           

            // Move to next upline
            currentId = up.uplineId;
        }

        // If loop finished but still some unassigned shares, send to creator
        uint remainingAfterLoop = _amount - totalDistributed;
        if (remainingAfterLoop > 0) {
            _sendToCreator(remainingAfterLoop);
        }

        // Add remainder (due to division rounding)
        if (remainder > 0) {
            _sendToCreator(remainder);
        }
       
    }
   
   // Pay a booster slice and record bookkeeping.
    function _payLevelBooster(uint receiverId, uint fromId, uint amount, uint packageLevel) private {

        _distributeIncome(receiverId, fromId, amount, packageLevel, IncomeType.LevelBooster);   
        // address to = users[receiverId].account;
        // usdt.transfer(to, amount);

        // UserIncome storage inc = userIncomes[receiverId];
        // inc.totalIncome += amount;
        // inc.levelBoosterIncome += amount;

        // incomeHistory[receiverId].push(Income({
        //     fromUserId: fromId,
        //     amount: amount,
        //     packageLevel: packageLevel,
        //     timestamp: block.timestamp,
        //     incomeType: 4 // Level booster income
        // }));

        // emit IncomeDistributed(to, users[fromId].account, amount, packageLevel, 4);
    }

    function _findEligibleSponsor(uint startId, uint packageLevel) private view returns (uint) {
        uint searchId = startId;
        uint hops = 0;
        while (searchId != 0 && searchId != defaultRefId && hops < maxLayers) {
            User storage u = users[searchId];
            if ( u.level >= packageLevel) // u.directTeam >= 2 &&
            {
                return searchId;
            }
            searchId = u.uplineId;
            hops++;
        }
        return 0;
    }


}