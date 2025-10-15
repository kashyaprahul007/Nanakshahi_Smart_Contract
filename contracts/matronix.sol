// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.20;

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
    // Package prices in USDT (with 6 decimals)
    uint256 public constant PERCENTS_DIVIDER = 10000;
    uint256 public constant TIME_STEP = 1 days;
    uint256 public constant ROI_CAP_MULTIPLIER = 25; // 2.5x
    uint256 public constant ROI_CAP_DIVIDER = 10;

    uint[] public packages = [
        20 * 1e18,      // 20$
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
        51200 * 1e18,  // 51200$
        102400 * 1e18,  // 102400$
        204800 * 1e18  // 204800$
    ];

    // Split User struct into basic info and relationships
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
        uint registrationTime;

    }
    
    // Separate struct for income tracking
    struct UserIncome {
        uint totalIncome;
        uint sponsorIncome;
        uint matrixIncome;
        uint levelBoosterIncome;
        uint levelIncome;
        uint royaltyIncome;
        uint royaltyIncomeClaimed; // Track claimed royalty for capping
        uint communityIncome;        // <-- NEW: total community bonus claimed

    }
    
    struct Deposit {
        uint256 amount;
        uint256 withdrawn;
        uint256 start;
    }

    struct Income {
        uint fromUserId;
        uint amount;
        uint packageLevel;
        uint timestamp;
        uint incomeType; // 1: Sponsor, 2: Matrix, 3: Level, 4: Level Booster, 5: Creator, 6: Royalty , 7 Lottery  , 8 Roi Income
    }
    
    // Main mappings
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
    event Upgrade(address indexed user, uint indexed userId, uint packageLevel);
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
            start: block.timestamp
        }));
        // Distribute income
        uint totalPackagePrice = packages[0];
        uint creatorShare = totalPackagePrice * 10 / 100; // 10% to creator
        uint remainingAmount = totalPackagePrice * 35 / 100;    // 35% distributable
        lotteryPool += totalPackagePrice * 5 / 100;
        _autoTriggerLottery();
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
            start: block.timestamp
        }));
   
        // Distribute income
        uint creatorShare = packagePrice * 10 / 100; // 2% to creator
         lotteryPool += packagePrice * 5 / 100;
        _autoTriggerLottery();

         uint communityShare = packagePrice * 50 / 100;
        _accrueCommunityBonus(communityShare);

        // Send creator share
        _sendToCreator(creatorShare);
    
        if (nextLevel == 1) {
            // 2nd package:
            // 25% to sponsor
            uint sponsorIncome = packagePrice * 25 / 100;
            _distributeSponsorIncome(user.sponsorId, _userId, sponsorIncome, nextLevel + 1);
            // 10% to upline (matrix parent)
            uint uplineIncome = packagePrice * 10 / 100;
            _distributeMatrixIncome(user.uplineId, _userId, uplineIncome, nextLevel + 1);
        } else if (nextLevel == 2) {
            // 3rd package:
            // 25% to sponsor
            uint sponsorIncome = packagePrice * 25 / 100;
            _distributeSponsorIncome(user.sponsorId, _userId, sponsorIncome, nextLevel + 1);
            
            // 10% to upline (matrix parent)
            uint uplineIncome = packagePrice * 10 / 100;
            _distributeMatrixIncome(user.uplineId, _userId, uplineIncome, nextLevel + 1);
        } else {
            // 4th to 15th package:
            // 10% to sponsor
            uint sponsorIncome = packagePrice * 10 / 100;
            _distributeSponsorIncome(user.sponsorId, _userId, sponsorIncome, nextLevel + 1);
            
            // 5% to upper nth level user
            uint levelIncome = packagePrice * 5 / 100;
            _distributeLevelIncome(user.sponsorId, _userId, levelIncome, nextLevel + 1, nextLevel + 1);
            
            // 20% to all sponsors up to level n as booster income (10% each for first 4 or fewer)
            uint boosterIncome = packagePrice * 20 / 100;
            _distributeLevelBoosterIncome(user.sponsorId, _userId, boosterIncome, nextLevel + 1, nextLevel + 1);
        }
        
        emit Upgrade(msg.sender, _userId, nextLevel + 1);
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


    function _autoTriggerLottery() private {
        if (block.timestamp < lastLotteryRun + lotteryInterval) return;
        if (lotteryPool == 0 || registeredUserIds.length == 0) return;

        uint lotteryAmount = lotteryPool;
        uint randomUserId = _getRandomUserId();

        if (users[randomUserId].id == 0) {
            _sendToCreator(lotteryAmount);
            return;
        }

        address winner = users[randomUserId].account;
        usdt.transfer(winner, lotteryAmount);

        UserIncome storage inc = userIncomes[randomUserId];
        inc.totalIncome += lotteryAmount;

        incomeHistory[randomUserId].push(Income({
            fromUserId: randomUserId,
            amount: lotteryAmount,
            packageLevel: 0,
            timestamp: block.timestamp,
            incomeType: 7
        }));

        emit LotteryReward(winner, randomUserId, lotteryAmount, block.timestamp);

        lotteryPool = 0;
        lastLotteryRun = block.timestamp;
    }
    function getLastWinnerId() external view returns (uint) {
        return lastWinnerId;
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


   function _getRandomUserId() private returns (uint) {
        uint len = registeredUserIds.length;
        if (len == 0) return 0;

        uint candidateId;
        uint attempts = 0;

        do {
            nonce++;
            uint seed = uint(keccak256(abi.encodePacked(
                block.timestamp,
                block.prevrandao,
                block.number,
                msg.sender,
                gasleft(),
                nonce
            )));
            
            uint index = seed % len;
            candidateId = registeredUserIds[index];
            attempts++;
        } while (candidateId == lastWinnerId && attempts < 5);
        lastWinnerId = candidateId;
        return candidateId;
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
        for(uint i=0; i<maxLayers; i++) {
            if(uplineId == 0) break;
            users[uplineId].totalMatrixTeam += 1;
            teams[uplineId][i].push(_newUserId);
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
        uint currentId = _uplineId;
        uint depth = 0;
        while (currentId != 0 && currentId != defaultRefId && depth < maxLayers) {
            User storage up = users[currentId];

            // eligibility: at least 2 directs AND level >= purchased level
            if (up.directTeam >= 2 && up.level >= _packageLevel) {
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
                    incomeType: 2
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
        currentId = users[currentId].sponsorId;
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
        if (u.directTeam >= 2 && u.level >= _packageLevel) {
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
        currentId = u.sponsorId;
        depth++;
    }

    // nobody eligible up the chain
    _sendToCreator(_amount);
}
    

    // Find first eligible sponsor up the chain (bounded by maxLayers). Returns 0 if none.
function _findEligibleSponsor(uint startId, uint packageLevel) private view returns (uint) {
    uint searchId = startId;
    uint hops = 0;
    while (searchId != 0 && searchId != defaultRefId && hops < maxLayers) {
        User storage u = users[searchId];
        if (u.directTeam >= 2 && u.level >= packageLevel) {
            return searchId;
        }
        searchId = u.sponsorId;
        hops++;
    }
    return 0;
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

    uint baselineId = _startId;

    for (uint i = 0; i < levelsToDistribute; i++) {
        uint receiverId = _findEligibleSponsor(baselineId, _packageLevel);

        if (receiverId == 0) {
            _sendToCreator(amountPerLevel);
        } else {
            _payLevelBooster(receiverId, _fromId, amountPerLevel, _packageLevel);
        }

        // advance the baseline one hop for the next slice
        if (baselineId != 0 && baselineId != defaultRefId) {
            baselineId = users[baselineId].sponsorId;
        } else {
            baselineId = 0;
        }
    }

    if (remainder > 0) {
        _sendToCreator(remainder);
    }
}
    
  function _sendToCreator(uint _amount) private {
    require(
        creatorWallet != address(0) &&
        systemMaintance != address(0) &&
        teamDevelopment != address(0),
        "fee addrs not set"
    );
    // 30% / 50% / 20% split
    uint toCreator = (_amount * 30) / 100;
    uint toMaint   = (_amount * 50) / 100;
    uint toDev     = (_amount * 20) / 100;

    // Handle integer-division rounding so total sent == _amount
    uint sent = toCreator + toMaint + toDev;
    uint remainder = _amount - sent;

    // Send dust to creator (you can pick any bucket)
    usdt.transfer(creatorWallet, toCreator + remainder);
    usdt.transfer(systemMaintance, toMaint);
    usdt.transfer(teamDevelopment, toDev);

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
        uint totalIncome,
        uint sponsorIncome,
        uint matrixIncome,
        uint levelIncome,
        uint levelBoosterIncome,
        uint royaltyIncome,
        uint communityIncome
        
    ) {
        UserIncome storage income = userIncomes[_userId];
        return (
            income.totalIncome,
            income.sponsorIncome,
            income.matrixIncome,
            income.levelIncome, 
            income.levelBoosterIncome,
            income.royaltyIncome,
            income.communityIncome
        );
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
    
    function getUserIncomeHistory(uint _userId) external view returns (Income[] memory) {
        return incomeHistory[_userId];
    }
    
    
    // Combined view function for complete user data (if needed)
    function getCompleteUserInfo(uint _userId) external view returns (
        address account,
        uint id,
        uint sponsorId,
        uint uplineId,
        uint level,
        uint directTeam,
        uint totalMatrixTeam,
        uint totalDeposit,
        uint totalIncome
    ) {
        User storage user = users[_userId];
        UserIncome storage income = userIncomes[_userId];
        return (
            user.account,
            user.id,
            user.sponsorId,
            user.uplineId,
            user.level,
            user.directTeam,
            user.totalMatrixTeam,
            user.totalDeposit,
            income.totalIncome
        );
    }
    
    function getMatrixDirect(uint _userId) external view returns (uint) {
        return matrixDirect[_userId];
    }
}