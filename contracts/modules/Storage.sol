// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

//import "../interfaces/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Storage is ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 public usdt;
    //address public owner;
    address public creatorWallet;   
    address public systemMaintance;
    address public teamDevelopment;
    uint public defaultRefId;
    uint public totalUsers;
    uint internal constant maxLayers = 15;

    uint256 public constant PERCENTS_DIVIDER = 10000;
    uint256 public constant TIME_STEP = 1 days;
    uint256 public constant MONTHLY_ROYALTY_TIME = 100 days;
    uint256 public constant TOP_ROYALTY_TIME = 450 days;
    uint256 public constant ROI_CAP_MULTIPLIER = 15; // 1.5x
    uint256 public constant ROI_CAP_DIVIDER = 10;
    uint256 public constant MONTHLY_ROYALTY_LEVEL = 10;
    uint256 public constant TOP_ROYALTY_LEVEL = 15;
    uint256 public constant MONTHLY_ROYALTY_DIRECT = 5;
    uint256 public constant TOP_ROYALTY_DIRECT = 2;



 
    uint[] public registeredUserIds;
    uint private nonce; // add this at the top of your contract
  
    // Package prices in USDT (with 18 decimals)

        // --- Community bonus accrual (pull-based) ---
    uint256 public constant ACC_PRECISION = 1e18;
    uint256 public communityAccPerUser;                 // global accumulator
    mapping(uint => uint256) internal communityDebt;      // user snapshot

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

        /*User main struct and mappings*/
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
        uint directPoolQualified; // Direct referrals count in infinity pool
        uint totalMatrixTeam; // Total users in matrix
        uint totalDeposit;
        uint poollevel;
        uint poolDeposit;
        uint boosterlevel;
        uint boosterDeposit;
        uint registrationTime;
        uint level10Time;
        uint level15Time;
        uint monthlyUserDirectCount; // at 10 th level in 100 days
        uint topRoyaltyDirectCount; // // at 15 th level in 450 days
    }
     // struct for bonus calc
    struct UserIncome {
        uint totalIncome;
        uint sponsorIncome;
        uint matrixIncome;
        uint levelBoosterIncome;
        //uint levelIncome;
        uint royaltyIncome;
        uint royaltyIncomeClaimed; // Track claimed royalty for capping
        uint communityIncome;        // <-- NEW: total community bonus claimed
        uint poolIncome;        // <-- Infinity Pool Income
        uint boosterIncome;        // <-- booster Income
        uint weeklyContestIncome;        // <-- weekly contest Income
        uint monthlyRoyalty;        // <-- weekly contest Income
        uint topRoyalty;        // <-- weekly contest Income
    }

    struct Income {
        uint fromUserId;
        uint amount;
        uint packageLevel;
        uint timestamp;
        uint incomeType; // 1: Sponsor, 2: Matrix, 3: Level, 4: Level Booster, 5: Creator, 6: Royalty , 7 Lottery  , 8 Roi Income, 10 Infintiy Pool, 11 Booster Income,12 weekly contest
    }
    enum IncomeType {
        Creator,            // 0
        Sponsor,            // 1
        Matrix,             // 2
        LevelBooster,       // 3        
        Community,          // 4
        Pool,               // 5
        Booster,            // 6
        WeeklyContest,      // 7
        MonthlyRoyalty,     // 8
        TopRoyalty   // 9
    }



    mapping(address => uint) internal addressToId;
    mapping(uint => User) internal users;
    mapping(uint => UserIncome) internal userIncomes; // New mapping for income data
    mapping(uint => Income[]) internal incomeHistory;
    mapping(uint => mapping(uint => uint[])) internal teams; // Matrix team structure by level
    mapping(uint => uint) internal matrixDirect; // Count of direct matrix referrals
    mapping(uint => uint[]) internal directReferrals;

    event UserJoined(uint8 indexed matrixId, uint32 indexed userId, address indexed user, uint32 parentId, address parentAddr, uint8 position);
    event RewardSent(address indexed to, uint256 amount, string level);


     // Events
    event Registration(address indexed user, address indexed sponsor, uint indexed userId, uint uplineId);
    event Upgrade(address indexed user, uint indexed userId, uint packageLevel, string depositType, uint upgradeTime);
    event IncomeDistributed(address indexed to, address indexed from, uint amount, uint packageLevel, uint incomeType);
    event LotteryReward(address indexed winner, uint indexed fromUserId, uint amount, uint timestamp);
    event CommunityBonusDistributed(uint amount, uint usersCount, uint perUser);
    event IncomeDistribution(address indexed to,address indexed from,uint256 amount,uint256 packageLevel,IncomeType incomeType,uint256 timestamp);
  
    // Infinity Pool and booster bonus 


    uint[] public poolPackages = [75e18, 300e18, 1200e18, 4800e18, 19200e18, 76800e18, 307200e18];
    uint[] public glbBoosterPackages = [ 100e18, 200e18, 400e18, 800e18, 1600e18, 3200e18, 6400e18, 12800e18];
    uint[7] public minLevelForPool = [3, 5, 7, 9, 11, 13, 15];
    uint[8] public minLevelForGlbBooster = [4, 5, 6, 7, 8, 9, 10,11];
    uint[8] public minPoolForGlbBooster = [0, 1, 1, 1, 1, 1, 1,1];


    struct UserPool {
        uint id;               
        uint mainid;
        uint poolId;
        uint parentId;  
        uint bonusCount;            
    }
    
    struct UserPoolTopup{
         uint nextPoolAmt;       
        uint reTopupAmt;     
    }

      // Golbal Booster
    struct UserBooster {
        uint id; 
        uint poolId;
        uint parentId;  
        uint bonusCount;
         uint joinTime;            
    }

    /* mapping for Infinity Pool*/
    mapping(uint =>  mapping(uint => UserPoolTopup)) internal userPooltopup;

    mapping(uint =>  mapping(uint => UserPool)) internal userPooldtl;
    mapping(uint => mapping(uint => uint[])) internal userChildren;// in each pool id wise
    mapping(uint => mapping(uint => uint[])) internal userIdPerPool;// will store user ids pool wise
    mapping(uint => uint[]) internal poolUsers; // store all users  pool wise
    mapping(uint => mapping(uint => bool)) internal userHasPool; 

    /* mapping for Global Booster */
    mapping(uint =>  mapping(uint => UserBooster)) internal userBoosterdtl;
    mapping(uint =>  mapping(uint => uint[])) internal userBoosterChildren;
    mapping(uint => uint[]) internal boosterUsers;  // store all users booster wise
    mapping(uint => mapping(uint => bool)) internal userHasbooster; 

   
    // weekly contest

    uint public constant WEEK_DURATION = 7 days;   
    uint public constant WeeklyCapping = 1000e18;
 

    uint public currentWeeklyRound = 0;
    uint public currentWeeklyStartTime = 0;  
    uint public WeeklyTotalReward = 0;
   


    struct WeeklyContest {
        uint roundId;    
        uint totalReward;
        uint totalUsers;
        uint perUserReward;
        uint claimedCount;
        uint startTime;
        uint endTime;
        uint carryForward;
        bool closed;
    }
   
    struct weeklyUser{
      
        uint joinTime;
        uint roundId ;
        uint claimTime;
        bool isClaimed; 
        bool isQualified;
    }
    mapping (uint => WeeklyContest) internal weeklyContestdtl;// details of weekly contest
    mapping(uint=> uint[]) weeklyQualifiedUsers; // qualifieduserweekly
    mapping(uint => mapping(uint => weeklyUser)) internal weeklyUserdtl;// details of weekly user))
    mapping(uint => mapping(uint => uint[])) internal weeklyUserDirects;//details users direct in current weekly round
    event WeeklyClosed(uint roundId, uint totalUsers, uint perUserReward, uint totalReward, uint totalDistributed, uint leftoverReward, uint endTime);
    event WeeklyRewardClaim(uint roundId, uint userId, uint perUserReward,  uint claimTime);
    event WeeklyContestQualified(uint roundId, uint userId, uint joinTime);

    //, monthly royalty and top royalty

    
    uint public constant MONTH_DURATION = 30 days;
    uint public constant monthlyCapping = 10000e18;

  
    uint public currentMonthlyRound = 1;
    uint public currentMonthlyStartTime = 0;
    uint public monthlyTotalReward = 0;

    struct monthlyRoyalty {
        uint roundId;    
        uint totalReward;
        uint totalUsers;
        uint perUserReward;
        uint claimedCount;
        uint startTime;
        uint endTime;
        uint carryForward;
        bool closed;
    }

    struct monthlyRoyaltyUser{
      
        uint joinTime;
        uint qualifiedRoundId ;
        uint claimTime;
        mapping(uint => bool) isClaimed; 
        bool isQualified;
    }
    mapping (uint => monthlyRoyalty) internal monthlyRoyaltydtl;// details of monthly royalty
    uint[] monthlyQualifiedUsers; // qualified user monthly royalty
    mapping(uint => monthlyRoyaltyUser) internal monthlyRoyaltyUserdtl;
    mapping(uint => uint[]) internal monthlyUserDirects;//details users direct in monthly Royalty at 10th level

    event MonthlyClosed(uint roundId, uint totalUsers, uint perUserReward, uint totalReward, uint totalDistributed, uint leftoverReward, uint endTime);
    event MonthlyRewardClaim(uint roundId, uint userId, uint perUserReward,  uint claimTime);
    event MonthlyRoyaltyQualified(uint roundId, uint userId, uint joinTime);

      //, Top royalty
  
    uint public topRoyaltyRound = 1;
    uint public topRoyaltyStartTime = 0;
    uint public topRoyaltyReward = 0;

    struct topRoyalty {
        uint roundId;    
        uint totalReward;
        uint totalUsers;
        uint perUserReward;
        uint claimedCount;
        uint startTime;
        uint endTime;
        uint carryForward;
        bool closed;
    }

    struct topRoyaltyUser{
      
        uint joinTime;
        uint qualifiedRoundId ;
        uint claimTime;
        mapping(uint => bool) isClaimed; 
        bool isQualified;
    }
    mapping (uint => topRoyalty) internal topRoyaltydtl;// details of top royalty contest
    uint[] topRoyaltyQualifiedUsers; // qualified user top royalty
    mapping(uint => topRoyaltyUser) internal topRoyaltyUserdtl;
    mapping(uint => uint[]) internal topRoyaltyUserDirects;//details users direct in top Royalty at 15th level

    event TopRoyaltyClosed(uint roundId, uint totalUsers, uint perUserReward, uint totalReward, uint totalDistributed, uint leftoverReward, uint endTime);
    event TopRoyaltyRewardClaim(uint roundId, uint userId, uint perUserReward,  uint claimTime);
    event TopRoyaltyQualified(uint roundId, uint userId, uint joinTime);



   
    constructor() {
       
    }
      
    

    function _sendToCreator(uint _amount) internal {
    require(creatorWallet != address(0),"fee addrs not set");
    // 100% split to creator
    
    // Send dust to creator (you can pick any bucket)
    usdt.safeTransfer(creatorWallet, _amount);
  

    // Bookkeeping for the full routed amount
    UserIncome storage creatorIncome = userIncomes[defaultRefId];
    creatorIncome.totalIncome += _amount;

    // incomeHistory[defaultRefId].push(Income({
    //     fromUserId: 0,
    //     amount: _amount,
    //     packageLevel: 0,
    //     timestamp: block.timestamp,
    //     incomeType: 5
    // }));
    emit IncomeDistribution(creatorWallet, creatorWallet, _amount, 0, IncomeType.Creator, block.timestamp );
}


    function _distributeIncome(uint _userId,uint _fromUserId,uint _amount, uint _packageLevel, IncomeType _incomeType) internal {
        User storage user = users[_userId];
        address userAddress = user.account;
        require(userAddress != address(0), "Invalid user");
        require(_amount > 0, "Zero amount");


        // Transfer tokens
        //usdt.safeTransfer(userAddress, _amount);
    //( userAddress, _amount);

        UserIncome storage income = userIncomes[_userId];
        income.totalIncome += _amount;
            // --- Update specific income field based on type ---
        if      (_incomeType == IncomeType.Sponsor) income.sponsorIncome += _amount;
        else if (_incomeType == IncomeType.Matrix) income.matrixIncome += _amount;
        else if (_incomeType == IncomeType.LevelBooster) income.levelBoosterIncome += _amount;  
        else if (_incomeType == IncomeType.Community) income.communityIncome += _amount;   
        else if (_incomeType == IncomeType.Pool) income.poolIncome += _amount;
        else if (_incomeType == IncomeType.Booster) income.boosterIncome += _amount;
        else if (_incomeType == IncomeType.WeeklyContest) income.weeklyContestIncome += _amount;
        else if (_incomeType == IncomeType.MonthlyRoyalty) income.monthlyRoyalty += _amount;
        else if (_incomeType == IncomeType.TopRoyalty) income.topRoyalty += _amount;

        

        else revert("Unknown income type");
    
            // --- Update total income ---
        

        // Record income in user history
        // incomeHistory[_userId].push(Income({
        //     fromUserId: _fromUserId,
        //     amount: _amount,
        //     packageLevel: _packageLevel,
        //     timestamp: block.timestamp,
        //     incomeType: _incomeType
        // }));
        //usdt.transfer(userAddress, _amount);
    
        usdt.safeTransfer(userAddress, _amount);
        emit IncomeDistribution(userAddress, users[_fromUserId].account, _amount,_packageLevel, _incomeType, block.timestamp );
        //emit IncomeDistributed(userAddress, users[_fromUserId].account, _amount, _packageLevel, _incomeType);
    }

    function _tryWeeklyContestQualify(uint _userId, uint _roundId)internal {
            if (!weeklyUserdtl[_roundId][_userId].isQualified) {
                    _weeklyContestQualifier(_userId, _roundId);
            }
    }

    function _weeklyContestQualifier(uint _userId, uint _roundId)internal {
       
       // uint currentRound = currentWeeklyRound;        
        require(_roundId == currentWeeklyRound, "Invalid round");
        require(!weeklyContestdtl[_roundId].closed, "Round closed");
        UserBooster memory userBoosterJoinDtl = userBoosterdtl[1][_userId];

        bool hasEnoughDirects = weeklyUserDirects[_roundId][_userId].length >= 5;
        bool boosterEarlyJoin = (
            userBoosterJoinDtl.id == _userId && 
            userBoosterJoinDtl.joinTime <= users[_userId].registrationTime + TIME_STEP
        );
        require(hasEnoughDirects || boosterEarlyJoin, "Not eligible for weekly contest");
        //require(weeklyUserDirects[currentRound][_userId].length >=5 ||  (userBoosterJoinDtl.id == _userId && userBoosterJoinDtl.joinTime <= users[_userId].registrationTime + TIME_STEP), "not eligible"); // (userBoosterJoinDtl.id = _userId && userBoosterJoinDtl.joinTime <= users[_userId].registrationTime)
        
        weeklyUser storage weeklyuserdtl = weeklyUserdtl[_roundId][_userId];
        if (weeklyuserdtl.isQualified) return;
        require(!weeklyuserdtl.isQualified, "already Qualified");

        uint nowTime = block.timestamp;

        weeklyuserdtl.joinTime = nowTime;
        weeklyuserdtl.roundId = _roundId;
        weeklyuserdtl.isQualified = true;
   
        emit WeeklyContestQualified(_roundId, _userId, nowTime);
    }

    function _tryMonthlyRoyaltyQualify(uint _userId, uint _roundId)internal {
            if (!monthlyRoyaltyUserdtl[_userId].isQualified) {
                    _monthlyRoyaltyQualifier(_userId, _roundId);
            }
    }

    function _monthlyRoyaltyQualifier(uint _userId, uint _roundId)internal {      
       
        require(_roundId == currentMonthlyRound, "Invalid round");
        require(!monthlyRoyaltydtl[_roundId].closed, "Round closed");
       
        User storage user = users[_userId];        

        require(user.level10Time > 0, "User not level 10");
        bool withinTime = user.level10Time <= user.registrationTime + MONTHLY_ROYALTY_TIME;
        bool qualifiedByLevel = user.level >= MONTHLY_ROYALTY_LEVEL;
        bool qualifiedByDirects = user.monthlyUserDirectCount >= MONTHLY_ROYALTY_DIRECT;
        require(withinTime && qualifiedByLevel && qualifiedByDirects, "Not eligible");
        
        monthlyRoyaltyUser storage userRoyalty  = monthlyRoyaltyUserdtl[_userId];
       
        //if (userRoyalty.isQualified) return;
        require(!userRoyalty.isQualified, "already Qualified");

        uint nowTime = block.timestamp;
        //userRoyalty.id = _userId;
        userRoyalty.joinTime = nowTime;
        userRoyalty.qualifiedRoundId = _roundId;
        userRoyalty.isQualified = true;
   
        emit MonthlyRoyaltyQualified(_roundId, _userId, nowTime);
    }

    

    function _tryTopRoyaltyQualify(uint _userId, uint _roundId)internal {
            if (!topRoyaltyUserdtl[_userId].isQualified) {
                    _topRoyaltyQualifier(_userId, _roundId);
            }
    }

    function _topRoyaltyQualifier(uint _userId, uint _roundId)internal {      
       
        require(_roundId == topRoyaltyRound, "Invalid round");
        require(!topRoyaltydtl[_roundId].closed, "Round closed");
       
        User storage user = users[_userId];        

        require(user.level15Time > 0, "User not level 15");
        bool withinTime = user.level15Time <= user.registrationTime + TOP_ROYALTY_TIME;
        bool qualifiedByLevel = user.level >= TOP_ROYALTY_LEVEL;
        bool qualifiedByDirects = user.topRoyaltyDirectCount >= TOP_ROYALTY_DIRECT;
        require(withinTime && qualifiedByLevel && qualifiedByDirects, "Not eligible");
        
        topRoyaltyUser storage userRoyalty  = topRoyaltyUserdtl[_userId];
       
        //if (userRoyalty.isQualified) return;
        require(!userRoyalty.isQualified, "already Qualified");

        uint nowTime = block.timestamp;
        //userRoyalty.id = _userId;
        userRoyalty.joinTime = nowTime;
        userRoyalty.qualifiedRoundId = _roundId;
        userRoyalty.isQualified = true;
   
        emit MonthlyRoyaltyQualified(_roundId, _userId, nowTime);
    }

}