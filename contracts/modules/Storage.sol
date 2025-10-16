// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../interfaces/IERC20.sol";

contract Storage {
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
    uint256 public constant ROI_CAP_MULTIPLIER = 15; // 1.5x
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
    uint[] public poolPackages = [75e18, 300e18, 1200e18, 4800e18, 19200e18, 76800e18, 307200e18];
    uint[] public glbBoosterPackages = [ 100e18, 200e18, 400e18, 800e18, 1600e18, 3200e18, 6400e18, 12800e18];
    uint[7] public minLevelForPool = [3, 5, 7, 9, 11, 13, 15];
    uint[8] public minLevelForGlbBooster = [4, 5, 6, 7, 8, 9, 10,11];
    uint[8] public minPoolForGlbBooster = [0, 1, 1, 1, 1, 1, 1,1];
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
        uint directPoolQualified; // Direct referrals count in infinity pool
        uint totalMatrixTeam; // Total users in matrix
        uint totalDeposit;
        uint poollevel;
        uint poolDeposit;
        uint boosterlevel;
        uint boosterDeposit;
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
        uint poolIncome;        // <-- Infinity Pool Income
        uint boosterIncome;        // <-- Infinity Pool Income
    }

    struct Income {
        uint fromUserId;
        uint amount;
        uint packageLevel;
        uint timestamp;
        uint incomeType; // 1: Sponsor, 2: Matrix, 3: Level, 4: Level Booster, 5: Creator, 6: Royalty , 7 Lottery  , 8 Roi Income, 10 Infintiy Pool, 11 Booster Income
    }

    // Infinity Pool
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

    // === EVENTS ===

    event UserJoined(uint8 indexed matrixId, uint32 indexed userId, address indexed user, uint32 parentId, address parentAddr, uint8 position);

    event RewardSent(address indexed to, uint256 amount, string level);

    mapping(address => uint) internal addressToId;
    mapping(uint => User) internal users;
    mapping(uint => UserIncome) internal userIncomes; // New mapping for income data
    mapping(uint => Income[]) internal incomeHistory;
    mapping(uint => mapping(uint => uint[])) internal teams; // Matrix team structure by level
    mapping(uint => uint) internal matrixDirect; // Count of direct matrix referrals
    mapping(uint => uint[]) internal directReferrals;

   
    // --- Community bonus accrual (pull-based) ---
    uint256 public constant ACC_PRECISION = 1e18;
    uint256 public communityAccPerUser;                 // global accumulator
    mapping(uint => uint256) internal communityDebt;      // user snapshot

  //  uint public lotteryPool;
    //address public lastLotteryWinner;
   // uint public lastLotteryRun;
   // uint public lotteryInterval = 1 days;
    uint[] public registeredUserIds;
    uint private nonce; // add this at the top of your contract
    //uint private lastWinnerId;

    // Events
    event Registration(address indexed user, address indexed sponsor, uint indexed userId, uint uplineId);
    event Upgrade(address indexed user, uint indexed userId, uint packageLevel, string depositType);
    event IncomeDistributed(address indexed to, address indexed from, uint amount, uint packageLevel, uint incomeType);
    event LotteryReward(address indexed winner, uint indexed fromUserId, uint amount, uint timestamp);
    event CommunityBonusDistributed(uint amount, uint usersCount, uint perUser);

       constructor() {
       
    }

    function _sendToCreator(uint _amount) internal {
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
}