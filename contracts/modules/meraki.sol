/**
 *Submitted for verification at BscScan.com on 2025-10-14
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

interface BEP20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function transfer(address to, uint tokens) external returns (bool success);
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}
 
contract Meraki{
    
    uint[] pkgs = [0,10e18,20e18,40e18,80e18,160e18,320e18,640e18,1280e18,2560e18,5120e18];    
    uint public totalUsers;
    BEP20 public depositToken;   
    address payable public owner;
    address payable public rewardAddress;
    address payable public CommunityAddress;
    address payable public CreatorAddress;

    event UserRegistered(
        address user,
        uint referrer,
        uint uniqueId
    );
    event PackageBought(
        uint user,
        uint pkg
    );
    event PoolCreated(
        uint poolId,
        uint user,
        uint parent,
        uint pkg
    );

    struct userInfo{
        uint id;
        address sponsor;
        uint directs;        
        uint pkg;
        uint time;
        uint totalInvestment; 
        uint isfr; // 1 for free user
        uint directInvest;
    }
    event poolIncomeEv(
        uint poolId,        
        uint user,
        uint from,
        uint level,
        uint income,
        uint pkg
    );
    event poolMissingIncomeEv(
        uint poolId,        
        uint user,
        uint from,
        uint level,
        uint income,
        uint pkg
    );
 
 
    mapping (address => userInfo) public users;
    mapping (uint => address) public idToAddress;
    mapping (address => bool) private owners;
    mapping (address => mapping (uint => address[])) public myPoolDirects;
    
    uint public packageMnt = 1;
    uint private intid = 1009;
     constructor(address rew,address community,address creatorAddress){
        totalUsers++;
        owner = payable(msg.sender);
        owners[msg.sender] = true;//payable(msg.sender);
        rewardAddress = payable(rew);
        CommunityAddress = payable(community);
        CreatorAddress = payable(creatorAddress);
        users[msg.sender].id = intid;
        idToAddress[intid] = msg.sender; 
        users[msg.sender].pkg = pkgs.length-1;     
        users[msg.sender].totalInvestment = pkgs[pkgs.length-1]; 
        for(uint i=1; i<=pkgs.length; i++){
            poolUsers[i]++;
            myPoolId[msg.sender][i] = poolUsers[i];
            
            pool[i][poolUsers[i]].id = poolUsers[i];
            pool[i][poolUsers[i]].user_id = intid;
            pool[i][poolUsers[i]].parent = 0;
            pool[i][poolUsers[i]].pkg = i;
            pool[i][poolUsers[i]].time = block.timestamp;
            emit PoolCreated(poolUsers[i], intid, 0, i);

            communityUsersCount[i] = 1;
        }         
    }
    receive() external payable {}
    modifier onlyOwner() {
        require(owners[msg.sender] == true, "Only owner can call this function");
        _;
    }

    function setToken(address _dp) public onlyOwner {
        depositToken = BEP20(_dp);       
    }
    
    function changeOwner(address newOwner,bool st) public onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");        
        if(st==false){
            owners[newOwner] = false; // Remove old owner            
        }
        if(st==true){
            owner = payable(newOwner);
            owners[newOwner] = true; // Add new owner
        }        
    }
    function setFeesr(address _dp,address fs,address creatorAddress) public onlyOwner {
        rewardAddress = payable(_dp);   
        CommunityAddress = payable(fs);
        CreatorAddress = payable(creatorAddress);
    }
    function setPkgAmnt(uint amnt) public onlyOwner {
        packageMnt = amnt;   
    }

    
    function register(uint spid,address useraddress) public {
        require(users[useraddress].id == 0, "User already registered");
        require(idToAddress[spid] != useraddress, "Sponsor cannot be the same as user");
        require(idToAddress[spid] != address(0), "Sponsor must be registered");
        address sp = idToAddress[spid];
        totalUsers++;
        intid += 5;
        users[useraddress].id = intid;
        users[useraddress].sponsor = sp;
        if(packageMnt==0){
            users[useraddress].isfr = 1;
        }
        users[sp].directs++;
        idToAddress[intid] = useraddress;
        emit UserRegistered(useraddress, users[sp].id, intid);
        buyPackage(1,useraddress);
    }
 
    event directIncomeEv(address usr, address frm,uint amnt);
    function buyPackage(uint _pkg,address useraddress) public {
        // if(packageMnt!=0){
        //     require(_pkg==1 || getPoolDirects(msg.sender,_pkg-1).length>=3 ,"3 Directs Required.");
        // }
        require(users[useraddress].id != 0, "User not registered");
        require(users[useraddress].pkg == _pkg-1, "Invalid package");
        require(_pkg > 0 && _pkg < 11, "Invalid package");
        if(packageMnt!=0){
            require(depositToken.balanceOf(msg.sender) >= pkgs[_pkg], "Insufficient balance");
            //PhonemixApprove(approveAddress).transferFrom(msg.sender, address(this), pkgs[_pkg], tokenIn);
            depositToken.transferFrom(msg.sender, address(this), pkgs[_pkg]+(_pkg*1e18));
        }
        address sp = users[useraddress].sponsor;
        users[sp].directInvest += pkgs[_pkg];
        incomes[users[sp].id].direct += pkgs[_pkg]*15/100;
        emit directIncomeEv(sp, useraddress, pkgs[_pkg]*15/100);
        if(packageMnt!=0){
            depositToken.transfer(sp, pkgs[_pkg]*15/100);
        }
        

        // myPoolDirects[sp][_pkg].push(msg.sender);
        users[useraddress].pkg = _pkg;
        users[useraddress].time = block.timestamp;
        users[useraddress].totalInvestment += pkgs[_pkg];

        setCommunityStatus(useraddress);
        setCommunityStatus(sp);

        emit PackageBought(users[useraddress].id, _pkg);

        placeAutopool(useraddress, _pkg);
        
        disCom(pkgs[_pkg]*40/100);
    }

    struct poolDetials{
        uint id;
        uint user_id;
        uint parent;
        uint downlineCount;
        uint pkg;
        uint time;        
    }

    struct incomeDetails{
        uint totalIncome;
        uint level;
        uint missing;
        uint direct;
        uint community;
        uint reward;
    }
    mapping (uint => mapping (uint => poolDetials)) public pool;
    mapping (uint => uint) public poolUsers;
    mapping (uint => incomeDetails) public incomes;

    event MissingDirect(uint user_address,uint missing_address,uint pkg);

    function placeAutopool(address usr,uint pkg) internal {
        require(users[usr].id != 0, "User not registered");
        require(pkg > 0 && pkg < 11, "Invalid package");
        
        uint idd = myPoolId[usr][1];
        if(idd>0){
            distributeIncome(idd,idd, pkg,1);
        }else{
            poolUsers[pkg]++;         
            uint newpoolid = poolUsers[pkg];
            uint getp = getActiveParent(usr,pkg);
            uint parent = findSpilloverReferrer1(getp,pkg);
            myPoolId[usr][pkg] = newpoolid;
            downlines[pkg][parent].push(newpoolid);
            pool[pkg][newpoolid].id = newpoolid;
            pool[pkg][newpoolid].user_id = users[usr].id;
            pool[pkg][newpoolid].parent = parent;
            pool[pkg][newpoolid].pkg = pkg;
            pool[pkg][newpoolid].time = block.timestamp;
            pool[pkg][parent].downlineCount++;        
            emit PoolCreated(newpoolid, users[usr].id, parent, pkg);
            distributeIncome(newpoolid,newpoolid, pkg,1);
        }  
        depositToken.transfer(rewardAddress,pkgs[pkg]*10/100);              
        depositToken.transfer(CommunityAddress,pkgs[pkg]*40/100);              
        depositToken.transfer(CommunityAddress,pkg*1e18); 
        remsend();             
    }

    mapping (address => mapping(uint => uint)) public MissingIncome;
    // now we will distribute the income to the users upto 20 levels
    function distributeIncome(uint prnt,uint poolid, uint pkg,uint lvl) internal {
        uint parent = pool[1][poolid].parent;
        // uint parent = pool[pkg][poolid].parent;
        if(parent==0){            
            return;
        }
        if(pkg==1){
            address user_address = idToAddress[pool[1][poolid].user_id];
            address gparent_address = users[user_address].sponsor;
            emit poolIncomeEv(poolid,users[gparent_address].id, pool[1][poolid].user_id, 1, pkgs[pkg]*25/100, pkg);
            incomes[users[gparent_address].id].level += pkgs[pkg]*25/100;
            depositToken.transfer(gparent_address,pkgs[pkg]*25/100);
        }else{
            uint parent1 = prnt;
            for(uint i=1;i<=pkg;i++){
                lvl++;
                if(parent1>0){ 
                    parent1 = pool[1][parent1].parent;
                }                
            }
            address parent_address = idToAddress[pool[1][parent1].user_id];

            if(users[parent_address].pkg>=pkg && users[parent_address].directs>=2){
                
                emit poolIncomeEv(poolid,pool[1][parent1].user_id, pool[1][poolid].user_id, lvl, pkgs[pkg]*25/100, pkg);
                incomes[pool[1][parent1].user_id].level += pkgs[pkg]*25/100;
                depositToken.transfer(parent_address,pkgs[pkg]*25/100);
            }else{
                //distributeIncome
                if(parent1!=0){
                    MissingIncome[parent_address][pkg]+=pkgs[pkg]*25/100;
                    emit MissingDirect(users[parent_address].id, pool[1][poolid].user_id, pkg);
                    return distributeIncome(parent1,poolid,pkg,lvl);
                }
            }
        }        
    }
    function getPoolDirects(address usr,uint pkg)public view returns(address[] memory){
        return myPoolDirects[usr][pkg];
    }
    function getActiveParent(address usr,uint pkg) public view returns(uint){
        address sp = users[usr].sponsor;
        if(users[sp].pkg>= pkg){
            return myPoolId[sp][pkg];
        }else{
            return getActiveParent(sp,pkg);
        }
    }

    function getParentId(uint memberId) public pure returns (uint) {
        // Calculate parent based on position in a 1x2 matrix
       
        if (memberId == 1) {
            return 0; // Top ID has no parent
        }
        uint parentId = (memberId - 2) / 2 + 1;
        return parentId;
    }

    uint[] public communityPer = [0,150,150,150,150,75,75,75,75,50,50];
    uint[] public communityCapp = [0,15,15,15,15,20,20,20,20,25,25];     
    
    function disCom(uint amnt) internal {
        for(uint i=1;i<=10;i++){
            uint incm = (amnt*communityPer[i])/1000;
            communityAmount[i] += incm;
        }        
    }
    function weeklyUpdate() public onlyOwner {
        for(uint i=1;i<=10;i++){
            // devide currect week to all users
            uint currentweekBusiness = communityAmount[i]-communityTillLastWeek[i];
            if(communityUsersCount[i]>0 && currentweekBusiness>0){
                uint peruser = currentweekBusiness/communityUsersCount[i];
                communityIncomeTillLastWeek[i] += peruser;
            }
            communityTillLastWeek[i] = communityAmount[i];
        }
    }
    mapping (uint => uint) public communityAmount;
    mapping (uint => uint) public communityTillLastWeek;
    mapping (uint => uint) public communityIncomeTillLastWeek;
    mapping (uint => uint) public communityUsersCount;
    struct communityDetails{
        uint user_id;
        uint enterAmount; 
        uint claimedAmount;
        bool status;      
    }
    mapping (address => mapping (uint => communityDetails)) public communityDetail;
    
    struct communityUser{
        uint user_id;
        uint claimedAmount;       
    }    
    mapping (address => communityUser) public communityUsers;
    function setCommunityStatus(address usr)internal {        
        if(users[usr].directs>=2){
            for(uint i=1;i<=users[usr].pkg;i++){
                if(communityDetail[usr][i].status==false){
                    communityDetail[usr][i].status = true;
                    communityDetail[usr][i].user_id = users[usr].id;
                    communityDetail[usr][i].enterAmount = communityIncomeTillLastWeek[i];
                    communityUsersCount[i]++;
                }
            }
        }        
    }
    function getMyCommunity(address usr,uint i) public view returns(uint) {
        uint ret = 0;
        //for(uint i=1;i<=users[usr].pkg;i++){
            if(communityDetail[usr][i].status==true){
                // uint pndg = communityDetail[usr][i].enterAmount>0 ? communityIncomeTillLastWeek[i] - communityDetail[usr][i].enterAmount : 0;
                uint pndg =   communityIncomeTillLastWeek[i] - communityDetail[usr][i].enterAmount ;
                uint incmc = pndg;
                if(pndg >= (pkgs[i]*communityCapp[i])/10){
                    incmc =  ((pkgs[i]*communityCapp[i])/10) - communityDetail[usr][i].claimedAmount;
                }else{
                    incmc =  pndg - communityDetail[usr][i].claimedAmount;
                }
                ret = incmc;
            }
        //}
        return ret;
    }

    event communityClaimed(address user,uint userid,uint pkg,uint amnt);
    function claimCommunity(uint pkg) public {
        uint ret = getMyCommunity(msg.sender,pkg);
        require(ret>0,"No Income");
        
        //for(uint i=1;i<=users[msg.sender].pkg;i++){
        uint i = pkg;
            if(communityDetail[msg.sender][i].status==true){
                
                //communityDetail[msg.sender][i].enterAmount>0 ? communityIncomeTillLastWeek[i] - communityDetail[msg.sender][i].enterAmount : 0;
                                

                communityDetail[msg.sender][i].claimedAmount += ret;
                communityUsers[msg.sender].claimedAmount += ret;
                incomes[users[msg.sender].id].community += ret;
                emit communityClaimed(msg.sender,users[msg.sender].id,pkg,ret);
                depositToken.transferFrom(CommunityAddress,msg.sender,ret);
            }
        //}        
    }

    mapping (address => mapping (uint => uint)) public myPoolId;

    mapping (uint => mapping (uint => uint[])) public downlines;


    function findSpilloverReferrer1(uint poolid, uint pkg) internal view returns (uint) {
        // Breadth-first search for the next available spot in the matrix
        uint[1000] memory queue;
        uint front = 0;
        uint back = 0;
        queue[back++] = poolid;
        bool find = false;
        while (front < back) {
            uint current = queue[front++];
            if (downlines[pkg][current].length < 2) {
                find = true;
                return current;
            }
            for (uint i = 0; i < downlines[pkg][current].length; i++) {
                queue[back++] = downlines[pkg][current][i];
                // Prevent overflow for very deep trees
                if (back >= 1000) break;
            }
            if (back >= 1000) break;
        }
        if(find==false){
            return findSpilloverReferrerPre(poolid,pkg);
        }
        return 0; // Should not happen
    }


    
    function findSpilloverReferrerPre(uint poolid,uint pkg) internal view returns (uint) {
        // Find the next available spot in the matrix
        
        if (downlines[pkg][poolid].length < 2) {
            return poolid;
        }

        for (uint i = 0; i < downlines[pkg][poolid].length; i++) {
            uint candidate = downlines[pkg][poolid][i];
            if (downlines[pkg][candidate].length < 2) {
                return candidate;
            }
        }
        // If all direct referrals are full, find deeper
        for (uint i = 0; i < downlines[pkg][poolid].length; i++) {
            uint candidate = downlines[pkg][poolid][i];
            uint result = findSpilloverReferrer1(candidate,pkg);
            if (result != 0) {
                return result;
            }
        }
        return 0; // In case no spillover spot is found, which should not happen
    }

    uint[] public rewardReq = [0,150e18,500e18,1000e18,2000e18,5000e18,10000e18,20000e18,50000e18,100000e18,200000e18];
    uint[] public rewardIncome = [0,15e18,35e18,50e18,100e18,300e18,500e18,1000e18,3000e18,5000e18,10000e18];
    mapping (address => mapping (uint => bool)) public rewardStatus;

    
    event RewardClaimed(address user,uint userid,uint pkg,uint amnt);
    function claimReward(uint pkg) public {
        require(users[msg.sender].id != 0, "User not registered");
        require(pkg > 0 && pkg < 11, "Invalid package");
        require(rewardStatus[msg.sender][pkg]==false,"Already Claimed");
        require(users[msg.sender].directInvest >= rewardReq[pkg],"Insufficient Investment");
        rewardStatus[msg.sender][pkg] = true;
        incomes[users[msg.sender].id].reward += rewardIncome[pkg];
        depositToken.transferFrom(rewardAddress,msg.sender,rewardIncome[pkg]);
        emit RewardClaimed(msg.sender,users[msg.sender].id,pkg,rewardIncome[pkg]);
    }

    function remsend()internal {
        depositToken.transfer(CreatorAddress,depositToken.balanceOf(address(this)));
    }
    
    function withdraw(uint amnt,address rcv,address tkn)external onlyOwner(){
        BEP20(tkn).transfer(rcv,amnt);
    }
}