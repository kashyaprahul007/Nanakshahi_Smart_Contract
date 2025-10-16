// SPDX-License-Identifier: MIT
    pragma solidity ^0.8.30;


    import "./Storage.sol";

    contract InfinityPool is Storage {
   
    
    constructor() { 
       
    }

    function canBuyNextPool(uint userId) public view returns (bool eligible, string memory reason) {
        User storage user = users[userId];
        uint nextPool = user.poollevel;
        if (nextPool >= poolPackages.length) {
            return (false, "You are already at the highest pool");
        }

        uint requiredLevel = minLevelForPool[nextPool];

        if (user.level < requiredLevel) {
            return (false, "You need to reach a higher level first");
        }

        if (nextPool > 0 && user.poollevel < nextPool) {
            return (false, "Buy previous pool first");
        }

        return (true, "Eligible to buy next pool");
    }


    function RetopPoolByEarning(uint _userId, uint _poolId) external {
   
        User storage user = users[_userId];
        require(user.account == msg.sender, "Not your account");
        require(user.poollevel < 7, "At max pool");
        //require(_upgradeType == 1 || _upgradeType == 2, "Invalid upgrade type");

        uint256 packagePrice;

        packagePrice = poolPackages[_poolId];
    
        UserPoolTopup storage top = userPooltopup[_poolId][_userId];
        require(top.reTopupAmt >= packagePrice, "Not enough reTopup balance");

        // Deduct balance
        top.reTopupAmt -= packagePrice;

        // Record deposit
        user.poolDeposit += packagePrice;

        // Place new entry in same pool
        _placeInPool(_poolId, _userId, packagePrice);

        // Log
        user.deposits.push(Deposit({
            amount: packagePrice,
            withdrawn: 0,
            start: block.timestamp,
            depositType: 10 // Retopup via earning
        }));

        emit Upgrade(msg.sender, _userId, _poolId, "Pool ReTopup (Earning)");
    

   
    }
    function upgradePoolByEarning(uint32 _userId, uint _poolId) external {
        // _upgradeType = 1 → Retopup (same pool)
        // _upgradeType = 2 → Upgrade to next pool

        User storage user = users[_userId];
        require(user.account == msg.sender, "Not your account");
        require(user.poollevel < 7, "At max pool");
    

        uint256 packagePrice;
        uint256 targetPool;

    
    
        require(_poolId + 1 < poolPackages.length, "No higher pool");
        packagePrice = poolPackages[_poolId + 1];
        targetPool = _poolId + 1;

        //uint requiredLevel = minLevelForPool[_poolId]; 
       // require(user.level >= requiredLevel, "Upgrade your level first");

        // Check internal funds
        UserPoolTopup storage top = userPooltopup[_poolId][_userId];
        require(top.nextPoolAmt >= packagePrice, "Not enough next pool balance");
        require(!userHasPool[_userId][targetPool], "Already purchased next pool");

        // Deduct funds
        top.nextPoolAmt -= packagePrice;

        // Update user info
        user.poollevel += 1;
    
        user.poolDeposit += packagePrice;
        userHasPool[_userId][targetPool] = true;

        // Place in next pool
        _placeInPool(targetPool, _userId, packagePrice);

        // Record deposit
        user.deposits.push(Deposit({
            amount: packagePrice,
            withdrawn: 0,
            start: block.timestamp,
            depositType: 11 // Upgrade via earning
        }));

        emit Upgrade(msg.sender, _userId, targetPool + 1, "Pool Upgrade (Earning)");
    
    }

    function upgradePool(uint _userId) external {
        User storage user = users[_userId];
        require(user.account == msg.sender, "Not your account");
        require(user.poollevel < 7, "At max level");
        
        uint nextLevel = user.poollevel;

        uint nextPool = user.poollevel; // next pool to buy (0-based index)
        uint requiredLevel = minLevelForPool[nextPool]; // required main level for this pool

        //  Check 1: Ensure user has required main level
        require(user.level >= requiredLevel, "Upgrade your level first");

        //  Check 2: Must buy sequentially (can't skip pools)
        if (nextPool > 0) {
            require(user.poollevel == nextPool, "Buy previous pool first");
        }
        require(!userHasPool[_userId][nextPool], "Pool already purchased");
 
       

        uint packagePrice = poolPackages[nextPool];
        
        // Transfer USDT for the next package
        usdt.transferFrom(msg.sender, address(this), packagePrice);
        
        if(nextPool == 0){
            uint _sponsorId = user.sponsorId;
            if(users[_sponsorId].registrationTime + 172800 <= block.timestamp){
                 users[_sponsorId].directPoolQualified += 1;
            }
        }
        user.poollevel += 1;
        userHasPool[_userId][nextPool] = true;
        user.poolDeposit += packagePrice;
        _placeInPool(nextLevel, _userId, packagePrice);
            // add in Deposit 
        user.deposits.push(Deposit({
            amount: packagePrice,
            withdrawn: 0,
            start: block.timestamp,
            depositType:10
        }));

        emit Upgrade(msg.sender, _userId, nextPool + 1, "Pool");
    }

    
    function _placeInPool(uint256 poolId, uint userMainId, uint packagePrice) private {
        require(poolId < poolPackages.length, "Invalid");
        require(msg.value == poolPackages[poolId], "Incorrect amount");

        //uint [] memory usersLen = poolUsers[poolId];
       
        uint index = poolUsers[poolId].length;// usersLen.length;               // current index for new user
        uint newUserId = defaultRefId + uint(index);
        poolUsers[poolId].push(newUserId);
        // parent by formula
        uint256 parentIndex = (index - 1) / 3;
        uint parentId = poolUsers[poolId][parentIndex]; //usersLen[parentIndex];

         userPooldtl[poolId][newUserId] = UserPool({
                id: newUserId,
                mainid: userMainId,
                poolId: poolId,
                parentId: parentId,
                bonusCount: 0
            });
           
        userIdPerPool[poolId][userMainId].push(newUserId);
        userChildren[poolId][parentId].push(newUserId);
        _distributePoolIncome( parentId, poolId, userMainId, packagePrice);
    }

    function _distributePoolIncome( uint _parentId, uint _poolId, uint _userMainId, uint _amount) private {
       
        uint currentParent = _parentId;       
        uint amountPerLevel = _amount / 3;  
        uint totalDistributed = 0;

        for(uint i=0; i<3; i++){
           
            if (currentParent == 0 || currentParent == defaultRefId) {
            // Send *remaining* amount to creator, not just one share
                uint remaining = _amount - totalDistributed;
                if (remaining > 0) {
                    _sendToCreator(remaining);
                }
                break;
            }

            UserPool storage userp = userPooldtl[_poolId][currentParent];
            uint parentMainId = userp.mainid; //parent main id
            if (userp.bonusCount < 39) {
                userp.bonusCount += 1;

                if (userp.bonusCount <= 24) {
                    _payPoolIncome(parentMainId, _userMainId, amountPerLevel, 1, 10);
                } else if (userp.bonusCount <= 36) {
                    userPooltopup[_poolId][parentMainId].nextPoolAmt += amountPerLevel;
                } else {
                    userPooltopup[_poolId][parentMainId].reTopupAmt += amountPerLevel;
                }

            }         
            totalDistributed += amountPerLevel; // Track amount given so far
            currentParent = userp.parentId;
        }     
         // If we finished all 3 levels normally but still have rounding dust
        uint _remaining = _amount - totalDistributed;
        if (_remaining > 0) {
            _sendToCreator(_remaining);
        }  
    }
    function _payPoolIncome(uint receiverId, uint fromId, uint amount, uint packageLevel, uint _incomeType) private {
       

        UserIncome storage inc = userIncomes[receiverId];
        inc.totalIncome += amount;
        if(_incomeType == 10){
             inc.poolIncome += amount;
        }
        if(_incomeType == 11){
             inc.boosterIncome += amount;
        }
        
       

        incomeHistory[receiverId].push(Income({
            fromUserId: fromId,
            amount: amount,
            packageLevel: packageLevel,
            timestamp: block.timestamp,
            incomeType: _incomeType // infintiy pool income
        }));

        address to = users[receiverId].account;
        uint netamount = (amount* 95 )/100;
        usdt.transfer(to, netamount);
        _sendToCreator((amount*5) / 100);

        emit IncomeDistributed(to, users[fromId].account, amount, packageLevel, _incomeType);
    }
   
   
    function upgradeBooster(uint _userId) external {
        User storage user = users[_userId];
        require(user.account == msg.sender, "Not your account");
        require(user.boosterlevel < 8, "At max level");
        
        //uint nextLevel = user.boosterlevel;

        uint nextPool = user.boosterlevel; // next pool to buy (0-based index)
        uint requiredLevel = minLevelForGlbBooster[nextPool]; // required main level for this pool
        uint requiredPool = minPoolForGlbBooster[nextPool]; // required main level for this pool
        //  Check 1: Ensure user has required main level
        require(user.level >= requiredLevel && user.poollevel >= requiredPool, "Upgrade Slot and Pool");

        //  Check 2: Must buy sequentially (can't skip pools)
        if (nextPool > 0) {
            require(user.boosterlevel == nextPool, "Buy previous pool first");
        }
        require(!userHasbooster[_userId][nextPool], "Pool already purchased");

        uint packagePrice = glbBoosterPackages[nextPool];
        
        // Transfer USDT for the next package
        usdt.transferFrom(msg.sender, address(this), packagePrice);
        
        user.boosterlevel += 1;
        userHasbooster[_userId][nextPool] = true;
        user.boosterDeposit += packagePrice;
        _placeInBooster(nextPool, _userId, packagePrice);
            // add in Deposit 
        user.deposits.push(Deposit({
            amount: packagePrice,
            withdrawn: 0,
            start: block.timestamp,
            depositType:11
        }));

        emit Upgrade(msg.sender, _userId, nextPool + 1, "Booster");
    }

    
    function _placeInBooster(uint256 poolId, uint userMainId, uint packagePrice) private {
        require(poolId < glbBoosterPackages.length, "Invalid");
        require(msg.value == glbBoosterPackages[poolId], "Incorrect amount");

        //uint [] memory usersLen = boosterUsers[poolId];
       
        uint index = boosterUsers[poolId].length; //usersLen.length;               // current index for new user
        //uint newUserId = userMainId;//defaultRefId + uint(index);
        boosterUsers[poolId].push(userMainId);
        // parent by formula
        uint256 parentIndex = (index - 1) / 3;
        uint parentId = boosterUsers[poolId][parentIndex]; //usersLen[parentIndex];

        userBoosterdtl[poolId][userMainId] = UserBooster({
                id: userMainId,               
                poolId: poolId,
                parentId: parentId,
                bonusCount: 0
            });
        userBoosterChildren[poolId][parentId].push(userMainId);

        if (parentId == 0 || parentId == defaultRefId) {
            _sendToCreator(packagePrice);
            return;
        }  
        UserBooster storage userB = userBoosterdtl[poolId][parentId];
        if( userB.bonusCount<3)
        {
            userB.bonusCount +=1; 
            _payPoolIncome(parentId, userMainId, packagePrice, 1, 11);  
        }
        else{
            _sendToCreator(packagePrice);
            return;
        }
       
           // _distributePoolIncome( parentId, poolId, userMainId, packagePrice);
    }
    // function _distributeBoosterlIncome( uint _parentId, uint _poolId, uint _userMainId, uint _amount) private {
    //     if (_parentId == 0 || _parentId == defaultRefId) {
    //         _sendToCreator(_amount);
    //         return;
    //     }        
    //     uint _amountPerLevel = _amount / 3;  

    //     for(uint i=0; i<3; i++){
           
    //         UserPool storage userp = userPooldtl[_poolId][_parentId];
    //         uint parentMainId = userp.mainid; //parent main id
    //         if(userp.bonusCount<39)
    //         {
    //             if(userp.bonusCount<24){
    //                userp.bonusCount +=1;   
    //                _payPoolIncome(parentMainId, _userMainId, _amountPerLevel, 1, 10);
    //             }
    //             if(userp.bonusCount>=24 && userp.bonusCount<36){
    //                 userp.bonusCount +=1;
    //                 userPooltopup[_poolId][parentMainId].nextPoolAmt += _amountPerLevel;
    //                // userp.nextPoolAmt += _amountPerLevel;
    //             }
    //             if(userp.bonusCount>=36 ){
    //                 userp.bonusCount +=1;
    //                  userPooltopup[_poolId][parentMainId].reTopupAmt += _amountPerLevel;
    //                // userp.reTopupAmt += _amountPerLevel;
    //             }
    //         }
    //     }     
  
    // }
   
}
