// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;


interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
contract Nanakshahi {
    IERC20 public usdt;
    address public owner;
    address public creatorWallet;   
    address public systemMaintance;
    address public teamDevelopment;
    uint public defaultRefId;
    uint public totalUsers;
    uint private constant maxLayers = 15;

    uint256 public constant PERCENTS_DIVIDER = 10000;
    uint256 public constant TIME_STEP = 1 days;
    uint256 public constant ROI_CAP_MULTIPLIER = 25; // 2.5x
    uint256 public constant ROI_CAP_DIVIDER = 10;
    // Package prices in USDT (with 18 decimals)


    uint[] public packages = [
        15 * 1e18,      // 15$
        25 * 1e18,      // 25$
        50 * 1e18,      // 50$
        100 * 1e18,     // 100$
        200 * 1e18,     // 200$
        400 * 1e18,     // 400$
        800 * 1e18,     // 800$
        1600 * 1e18,    // 1600$
        3200 * 1e18,    // 3200$
        6400 * 1e18,    // 6400$
        12800 * 1e18,   // 12800$
        25600 * 1e18,   // 25600$
        51200 * 1e18,   // 51200$
        102400 * 1e18,  // 102400$
        204800 * 1e18   // 204800$
    ];

        //  User struct into basic info and relationships
    struct Deposit {
        uint256 amount;
        uint256 withdrawn;
        uint256 start; 
        uint8 depositType;  
    }

    struct User {
        address account;
        Deposit[] deposits;
        uint256 checkpoint;
        uint id;
        uint sponsorId;  // Referrer
        uint uplineId;   // Placement in matrix
        uint level;      // Current package level (1-15)
        uint directTeam; // Direct referrals count
        uint totalMatrixTeam; // Total users in matrix
        uint totalDeposit;
        uint poollevel;
        uint poolDeposit;
        uint registrationTime;

    }
     // struct for bonus calc
    struct UserIncome {
        uint totalIncome;
        uint sponsorIncome;
        uint matrixIncome;
        uint levelBoosterIncome;
        uint levelIncome;
        uint royaltyIncome;
        uint royaltyIncomeClaimed; // Track claimed royalty for capping
        uint communityIncome;        // <-- NEW: total community bonus claimed
        uint poolIncome;        // <-- NEW: total community bonus claimed
    }

    struct Income {
        uint fromUserId;
        uint amount;
        uint packageLevel;
        uint timestamp;
        uint incomeType; // 1: Sponsor, 2: Matrix, 3: Level, 4: Level Booster, 5: Creator, 6: Royalty , 7 Lottery  , 8 Roi Income
    }

        struct UserPool {
        uint id;               
        uint mainid;
        uint poolId;
        uint parentId;  
        uint bonusCount;
        uint nextPoolAmt;       
        uint reTopupAmt;          
    }

    mapping(uint =>  mapping(uint => UserPool)) public userPooldtl;

    mapping(uint => mapping(uint => uint[])) public userChildren;// in each pool id wise
    mapping(uint => mapping(uint => uint[])) public userIdPerPool;// will store user ids pool wise

 
    uint[] public poolPackages = [25e18, 100e18, 400e18, 1600e18, 6400e18, 25600e18, 102400e18];
    mapping(uint => uint[]) public poolUsers; // store all users  pool wise

    // === EVENTS ===

    event UserJoined(
        uint8 indexed matrixId,
        uint32 indexed userId,
        address indexed user,
        uint32 parentId,
        address parentAddr,
        uint8 position
    );

    event RewardSent(address indexed to, uint256 amount, string level);

    mapping(address => uint) public addressToId;
    mapping(uint => User) public users;
    mapping(uint => UserIncome) public userIncomes; // New mapping for income data
    mapping(uint => Income[]) public incomeHistory;
    mapping(uint => mapping(uint => uint[])) public teams; // Matrix team structure by level
    mapping(uint => uint) public matrixDirect; // Count of direct matrix referrals
    mapping(uint => uint[]) public directReferrals;

   
    // --- Community bonus accrual (pull-based) ---
    uint256 public constant ACC_PRECISION = 1e18;
    uint256 public communityAccPerUser;                 // global accumulator
    mapping(uint => uint256) public communityDebt;      // user snapshot

    uint public lotteryPool;
    address public lastLotteryWinner;
    uint public lastLotteryRun;
    uint public lotteryInterval = 1 days;
    uint[] public registeredUserIds;
    uint private nonce; // add this at the top of your contract
    uint private lastWinnerId;

    // Events
    event Registration(address indexed user, address indexed sponsor, uint indexed userId, uint uplineId);
    event Upgrade(address indexed user, uint indexed userId, uint packageLevel, string depositType);
    event IncomeDistributed(address indexed to, address indexed from, uint amount, uint packageLevel, uint incomeType);
    event LotteryReward(address indexed winner, uint indexed fromUserId, uint amount, uint timestamp);
    event CommunityBonusDistributed(uint amount, uint usersCount, uint perUser);
    
    constructor(address _usdt,address _creatorWallet, address _systemMaintance , address _teamDevelopment) {
        usdt = IERC20(_usdt);
        creatorWallet = _creatorWallet;
        systemMaintance = _systemMaintance;
        teamDevelopment = _teamDevelopment;
        defaultRefId = 1000;
        totalUsers = 1;
        
        // Initialize creator account
        User storage creator = users[defaultRefId];
        creator.account = _creatorWallet;
        creator.id = defaultRefId;
        creator.level = 15; // Creator starts at max level
        creator.registrationTime = block.timestamp;
        
        // Set initial deposit for creator
        uint totalDeposit = 0;
        for(uint i = 0; i < 15; i++) {
            totalDeposit += packages[i];
        }
        creator.totalDeposit = totalDeposit;
        addressToId[_creatorWallet] = defaultRefId;

         for(uint j = 0; j < poolPackages.length; j++) {
            userPooldtl[j][defaultRefId] = UserPool({
                id: defaultRefId,
                mainid: defaultRefId,
                poolId: j,
                parentId: 0,

                bonusCount: 0,
                nextPoolAmt: 0,
                reTopupAmt: 0
            });
            poolUsers[j].push(defaultRefId);
            userIdPerPool[j][defaultRefId].push(defaultRefId);
        }
        
    }


     function upgradePool(uint32 _userId) external {
        User storage user = users[_userId];
        require(user.account == msg.sender, "Not your account");
        require(user.poollevel < 7, "At max level");
        
        uint nextLevel = user.poollevel;
        uint packagePrice = poolPackages[nextLevel];
        
        // Transfer USDT for the next package
        usdt.transferFrom(msg.sender, address(this), packagePrice);
        
        user.poollevel += 1;
       
        user.poolDeposit += packagePrice;
         _placeInPool(nextLevel, _userId, packagePrice);
            // add in Deposit 
          user.deposits.push(Deposit({
            amount: packagePrice,
            withdrawn: 0,
            start: block.timestamp,
            depositType:2
        }));

        emit Upgrade(msg.sender, _userId, nextLevel + 1, "Pool");
    }

    
    function _placeInPool(uint256 poolId, uint32 userMainId, uint packagePrice) private {
        require(poolId < poolPackages.length, "Invalid");
        require(msg.value == poolPackages[poolId], "Incorrect amount");

        uint [] memory usersLen = poolUsers[poolId];
       
        uint index = usersLen.length;               // current index for new user
        uint newUserId = defaultRefId + uint(index);
        poolUsers[poolId].push(newUserId);
        // parent by formula
        uint256 parentIndex = (index - 1) / 3;
        uint parentId = usersLen[parentIndex];

         userPooldtl[poolId][newUserId] = UserPool({
                id: newUserId,
                mainid: userMainId,
                poolId: poolId,
                parentId: parentId,
                bonusCount: 0,
                nextPoolAmt: 0,
                reTopupAmt: 0
            });
            poolUsers[poolId].push(newUserId);
            userIdPerPool[poolId][userMainId].push(newUserId);
            userChildren[poolId][parentId].push(newUserId);
            _distributePoolIncome( parentId, poolId, userMainId, packagePrice);
    }
    

        function _distributePoolIncome( uint _parentId, uint _poolId, uint _userMainId, uint _amount) private {
          if (_parentId == 0 || _parentId == defaultRefId) {
            _sendToCreator(_amount);
            return;
        }
        uint _amountPerLevel = _amount / 3;  

        for(uint i=0; i<3; i++){
           
            UserPool storage userp = userPooldtl[_poolId][_parentId];
            uint parentMainId = userp.mainid; //parent main id
            if(userp.bonusCount<39)
            {
                if(userp.bonusCount<24){
                   userp.bonusCount +=1;
                   _payPoolIncome(parentMainId, _userMainId, _amountPerLevel, 1);
                }
                if(userp.bonusCount>=24 && userp.bonusCount<36){
                    userp.bonusCount +=1;
                    userp.nextPoolAmt += _amountPerLevel;
                }
                if(userp.bonusCount>=36 ){
                    userp.bonusCount +=1;
                    userp.reTopupAmt += _amountPerLevel;
                }
            }
        }     
  
    }
   
   // Pay a booster slice and record bookkeeping.
    function _payPoolIncome(uint receiverId, uint fromId, uint amount, uint packageLevel) private {
        address to = users[receiverId].account;
        usdt.transfer(to, amount);

        UserIncome storage inc = userIncomes[receiverId];
        inc.totalIncome += amount;
        inc.poolIncome += amount;

        incomeHistory[receiverId].push(Income({
            fromUserId: fromId,
            amount: amount,
            packageLevel: packageLevel,
            timestamp: block.timestamp,
            incomeType: 10 // infintiy pool income
        }));

        emit IncomeDistributed(to, users[fromId].account, amount, packageLevel, 10);
    }


    function _sendToCreator(uint _amount) private {
    require(creatorWallet != address(0),"fee addrs not set");
    // 100% split to creator
    
    // Send dust to creator (you can pick any bucket)
    usdt.transfer(creatorWallet, _amount);
  

    // Bookkeeping for the full routed amount
    UserIncome storage creatorIncome = userIncomes[defaultRefId];
    creatorIncome.totalIncome += _amount;

    incomeHistory[defaultRefId].push(Income({
        fromUserId: 0,
        amount: _amount,
        packageLevel: 0,
        timestamp: block.timestamp,
        incomeType: 5
    }));
}
   
     function register(uint _sponsorId) external {
        require(addressToId[msg.sender] == 0, "Already registered");
        require(users[_sponsorId].id > 0, "Invalid sponsor");
        
        // Transfer USDT for the first package
        usdt.transferFrom(msg.sender, address(this), packages[0]);
        
        // Create new user
        uint newUserId = defaultRefId + (totalUsers * 5);
        addressToId[msg.sender] = newUserId;
        
        User storage user = users[newUserId];
        user.account = msg.sender;
        user.checkpoint = block.timestamp;
        user.id = newUserId;
        user.sponsorId = _sponsorId;
        user.level = 1;
        user.totalDeposit = packages[0];
        user.registrationTime = block.timestamp;
        
        // Update sponsor direct team count
        users[_sponsorId].directTeam += 1;
        directReferrals[_sponsorId].push(newUserId);
        registeredUserIds.push(newUserId);
        communityDebt[newUserId] = communityAccPerUser;
        // Find placement in 2x2 matrix
        _placeInMatrix(newUserId, _sponsorId);
        // add in Deposit 
        user.deposits.push(Deposit({
            amount: packages[0],
            withdrawn: 0,
            start: block.timestamp,
            depositType:1
        }));
        // Distribute income
        uint totalPackagePrice = packages[0];
        uint creatorShare = totalPackagePrice * 10 / 100; // 10% to creator
        uint remainingAmount = totalPackagePrice * 35 / 100;    // 35% distributable
        lotteryPool += totalPackagePrice * 5 / 100;
        //_autoTriggerLottery();
        uint communityShare = totalPackagePrice * 50 / 100;
            // 9) accrue community bonus (no O(N) loop; users claim via claimCommunity)
        _accrueCommunityBonus(communityShare);
          
        // Send creator share
        _sendToCreator(creatorShare);
        
        // 30% to sponsor as first level income
        _distributeSponsorIncome(user.sponsorId, newUserId, remainingAmount, 1);
        
        totalUsers += 1;
        
        emit Registration(msg.sender, users[_sponsorId].account, newUserId, user.uplineId);
    }
    
    function upgrade(uint _userId) external {
        User storage user = users[_userId];
        require(user.account == msg.sender, "Not your account");
        require(user.level < 15, "Already at max level");
        
        uint nextLevel = user.level;
        uint packagePrice = packages[nextLevel];
        
        // Transfer USDT for the next package
        usdt.transferFrom(msg.sender, address(this), packagePrice);
        
        user.level += 1;
        user.totalDeposit += packagePrice;
            // add in Deposit 
          user.deposits.push(Deposit({
            amount: packagePrice,
            withdrawn: 0,
            start: block.timestamp,
            depositType:1
        }));
   
        // Distribute income
        uint creatorShare = packagePrice * 5 / 100; // 5% to creator
        // lotteryPool += packagePrice * 5 / 100;
        //_autoTriggerLottery();

         uint communityShare = packagePrice * 35 / 100;
        _accrueCommunityBonus(communityShare);

        // Send creator share
        _sendToCreator(creatorShare);

        // sponsor income 15% for all package so call it once
        // nextLevel is package, when 1 then its mean 2nd package
        uint sponsorIncome = packagePrice * 15 / 100;
        _distributeSponsorIncome(user.sponsorId, _userId, sponsorIncome, nextLevel + 1);

        uint uplineIncome = packagePrice * 15 / 100;
        _distributeMatrixIncome(user.uplineId, _userId, uplineIncome, nextLevel + 1);

        uint boosterIncome = packagePrice * 15 / 100;
        _distributeLevelBoosterIncome(user.uplineId, _userId, boosterIncome, nextLevel + 1, nextLevel);

       
        
        emit Upgrade(msg.sender, _userId, nextLevel + 1, "Slot");
    }
    
    function _applyGlobalCapping(uint _userId, uint _amount) internal view returns (uint) {
    User storage user = users[_userId];
    UserIncome storage income = userIncomes[_userId];

    // If user has last package, allow unlimited non-ROI income
    if (user.level == packages.length) {
        return _amount;
    }

   uint maxIncome = (user.totalDeposit * ROI_CAP_MULTIPLIER) / ROI_CAP_DIVIDER;

    if (income.totalIncome >= maxIncome) return 0;

    uint remaining = maxIncome - income.totalIncome;
    return (_amount > remaining) ? remaining : _amount;
}

    function _accrueCommunityBonus(uint _totalAmount) internal {
        uint n = registeredUserIds.length;
        if (n == 0 || _totalAmount == 0) {
            if (_totalAmount > 0) { _sendToCreator(_totalAmount); }
            return;
        }
        communityAccPerUser += (_totalAmount * ACC_PRECISION) / n;
    }


    function claimCommunity(uint _userId) external {
            User storage u = users[_userId];
            require(u.id != 0, "User not found");
            require(u.account == msg.sender, "Not your account");

            // pending = (accumulator delta) scaled down
            uint256 accumulated = communityAccPerUser;
            uint256 debt = communityDebt[_userId];

            if (accumulated == debt) {
                return; // nothing to claim
            }

            uint256 accrued = (accumulated - debt) / ACC_PRECISION;
            if (accrued == 0) {
                communityDebt[_userId] = accumulated; // still sync debt
                return;
            }

            // apply global cap at claim time
            uint256 pay = _applyGlobalCapping(_userId, accrued);

            // effects (update debt first: checks-effects-interactions)
            communityDebt[_userId] = accumulated;

            if (pay > 0) {
                UserIncome storage inc = userIncomes[_userId];
                inc.totalIncome += pay;
                inc.communityIncome += pay;  // track claimed community bonus
                incomeHistory[_userId].push(Income({
                    fromUserId: _userId,
                    amount: pay,
                    packageLevel: 1,
                    timestamp: block.timestamp,
                    incomeType: 9 // Community Bonus
                }));

                // interaction
                require(usdt.transfer(u.account, pay), "USDT transfer failed");
            }

            // route any capped-away remainder to creator
            if (accrued > pay) {
                _sendToCreator(accrued - pay);
            }
        }


    function pendingCommunity(uint _userId) external view returns (uint pendingGross, uint pendingAfterCap) {
        if (users[_userId].id == 0) return (0, 0);
        uint256 acc = communityAccPerUser;
        uint256 debt = communityDebt[_userId];
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
        
        User storage sponsor = users[_sponsorId];
        
        if (_packageLevel != 1)
        {
            if(sponsor.directTeam < 2)
            {
                    _sendToCreator(_amount);
                    return;
            }
        }
    

            usdt.transfer(sponsor.account, _amount);
            
            // Update income in separate mapping
            UserIncome storage sponsorIncome = userIncomes[_sponsorId];
            sponsorIncome.totalIncome += _amount;
            sponsorIncome.sponsorIncome += _amount;
            
            // Record income
            incomeHistory[_sponsorId].push(Income({
                fromUserId: _fromId,
                amount: _amount,
                packageLevel: _packageLevel,
                timestamp: block.timestamp,
                incomeType: 1 // Sponsor income
            }));
            
            emit IncomeDistributed(sponsor.account, users[_fromId].account, _amount, _packageLevel, 1);
       
    }
    

    function _distributeMatrixIncome(uint _uplineId,uint _fromId,uint _amount, uint _packageLevel) private {
        // walk up the matrix chain looking for the first eligible ancestor

        // first need to get correct upline
   
        //)
        uint depth = 1;
        if(_uplineId == defaultRefId || _uplineId == 0)
        {
            _sendToCreator(_amount);
            return;
        }
        uint uplineId_ = _uplineId;
        while(depth < _packageLevel)
        {
            depth++;
            uplineId_ = users[uplineId_].uplineId;

            if(uplineId_ == defaultRefId || uplineId_ == 0)
            {   
                depth = _packageLevel;
                _sendToCreator(_amount);
              
                return;
            }
        }
        uint currentId = uplineId_;
        depth = 0;
        while (currentId != 0 && currentId != defaultRefId && depth < maxLayers) {
            User storage up = users[currentId];

            // eligibility: at least 2 directs AND level >= purchased level
            if (up.level >= _packageLevel) // up.directTeam >= 2 && 
            {
                // pay and record as Matrix income (type 2)
                usdt.transfer(up.account, _amount);

                UserIncome storage inc = userIncomes[currentId];
                inc.totalIncome += _amount;
                inc.matrixIncome += _amount;

                incomeHistory[currentId].push(Income({
                    fromUserId: _fromId,
                    amount: _amount,
                    packageLevel: _packageLevel,
                    timestamp: block.timestamp,
                    incomeType: 2 // matrix income
                }));

                emit IncomeDistributed(up.account, users[_fromId].account, _amount, _packageLevel, 2);
                return;
            }

            // move up one level in the matrix
            currentId = up.uplineId;
            depth++;
        }
        // nobody in the matrix chain qualified → send to creator/fees
        _sendToCreator(_amount);
    }
        
    function _distributeLevelIncome(uint _startId,uint _fromId,uint _amount,uint _packageLevel,uint _targetLevel) private {
        if (_startId == 0 || _startId == defaultRefId) {
            _sendToCreator(_amount);
            return;
        }

        // Step 1: move up to the target (n-th) upline
        uint currentId = _startId;
        uint hops = 1;
        while (hops < _targetLevel) {
            currentId = users[currentId].uplineId;
            hops++;
            if (currentId == 0 || currentId == defaultRefId) {
                _sendToCreator(_amount);
                return;
            }
        }

        // Step 2: from the target upline, roll upward until someone qualifies
        uint depth = 0;
        while (currentId != 0 && currentId != defaultRefId && depth < maxLayers) {
            User storage u = users[currentId];

            // eligibility: at least 2 directs AND level >= purchased level
            if (u.level >= _packageLevel) //u.directTeam >= 2 && 
            {
                usdt.transfer(u.account, _amount);
                // bookkeeping
                UserIncome storage inc = userIncomes[currentId];
                inc.totalIncome += _amount;
                inc.levelIncome += _amount;

                incomeHistory[currentId].push(Income({
                    fromUserId: _fromId,
                    amount: _amount,
                    packageLevel: _packageLevel,
                    timestamp: block.timestamp,
                    incomeType: 3 // Level income
                }));

                emit IncomeDistributed(u.account, users[_fromId].account, _amount, _packageLevel, 3);
                return;
            }

            // not eligible → try the next sponsor up
            currentId = u.uplineId;
            depth++;
        }

        // nobody eligible up the chain
        _sendToCreator(_amount);
    }

    
    function _distributeLevelBoosterIncome(
        uint _startId,
        uint _fromId,
        uint _amount,
        uint _packageLevel,
        uint _maxLevel
    ) private {
        if (_startId == 0 || _startId == defaultRefId) {
            _sendToCreator(_amount);
            return;
        }

        uint levelsToDistribute = _maxLevel; // or cap to 4 if desired
        if (levelsToDistribute == 0) {
            _sendToCreator(_amount);
            return;
        }

        uint amountPerLevel = _amount / levelsToDistribute;
        uint remainder = _amount - (amountPerLevel * levelsToDistribute);
        uint spilover = 1;
        uint baselineId = _startId;

        for (uint i = 0; i < levelsToDistribute; i++) 
        {
            //uint receiverId = baselineId;// _findEligibleSponsor(baselineId, _packageLevel);
            //User storage u = users[baselineId];
            if (baselineId != 0 && baselineId != defaultRefId) 
            {
                if(users[baselineId].level >= _packageLevel)
                {   
                    for(uint j=0; j<spilover; j++)
                    {
                        _payLevelBooster(baselineId, _fromId, amountPerLevel , _packageLevel); 
                        
                    }
                    baselineId = users[baselineId].uplineId;
                    spilover = 1;
                }
                else 
                {
                    baselineId = users[baselineId].uplineId;
                    spilover++;
                }
    
            }
           
           
            if (baselineId == 0 || baselineId == defaultRefId) {
                _sendToCreator(amountPerLevel);
            } 
       
        }

        if (remainder > 0) {
            _sendToCreator(remainder);
        }
    }
   
   // Pay a booster slice and record bookkeeping.
    function _payLevelBooster(uint receiverId, uint fromId, uint amount, uint packageLevel) private {
        address to = users[receiverId].account;
        usdt.transfer(to, amount);

        UserIncome storage inc = userIncomes[receiverId];
        inc.totalIncome += amount;
        inc.levelBoosterIncome += amount;

        incomeHistory[receiverId].push(Income({
            fromUserId: fromId,
            amount: amount,
            packageLevel: packageLevel,
            timestamp: block.timestamp,
            incomeType: 4 // Level booster income
        }));

        emit IncomeDistributed(to, users[fromId].account, amount, packageLevel, 4);
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