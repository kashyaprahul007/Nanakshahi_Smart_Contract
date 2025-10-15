// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title Constants
 * @dev Centralized configuration for all modules (rewards, matrix, timing)
 */
library Constants {

    uint256 public constant PERCENTS_DIVIDER = 10000;
    uint256 public constant TIME_STEP = 1 days;
    uint256 public constant ROI_CAP_MULTIPLIER = 25; // 2.5x
    uint256 public constant ROI_CAP_DIVIDER = 10;
    
    // Reward percentages
    // uint256[7] internal  constant Pools = [75e18, 300e18, 1200e18, 4800e18, 19200e18, 76800e18, 307200e18 ];

    // uint256[7] public constant IP_Total_Amt = [25e18, 100e18, 400e18, 1600e18, 6400e18, 25600e18, 102400e18 ];// pool wise total amount
    // uint256[7] public constant IP_Net_Amt = [2375e16, 95e18, 380e18, 1520e18, 6080e18, 24320e18, 97280e18 ]; // pool wise net amount
    // uint256[7] public constant IP_Admin_Amt = [375e16, 15e18, 60e18, 240e18, 960e18, 3840e18, 15360e18 ]; //pool wise admin amount
    //  uint256[7] public constant IP_Admin_Amt_PU = [125e16, 5e18, 20e18, 80e18, 320e18, 1280e18, 5120e18 ]; //pool wise admin amount per user




    /* Infinity Pool Reward Amount Pool Wise    */

    // // Pool 1 75$
    // uint256 public constant IP_Total_Amt_1 = 25e18; // infinity pool 1 total amount for user is 25
    // uint256 public constant IP_Net_Amt_1 = 2375e16; // infinity pool 1 net amount for user is 23.75
    // uint256 public constant IP_Admin_Amt_1 = 375e16; // infinity pool 1 Admin amount  is 3.75
    // uint256 public constant IP_Admin_Amt_PU_1 = 125e16; // infinity pool 1 Admin amount for per user is 1.25

    // // Pool 2 300$
    // uint256 public constant IP_Total_Amt_2 = 100e18; 
    // uint256 public constant IP_Net_Amt_2 = 95e18;
    // uint256 public constant IP_Admin_Amt_2 = 15e18; 
    // uint256 public constant IP_Admin_Amt_PU_2 = 5e18; 


    //  //Pool 3 1200$
    // uint256 public constant IP_Total_Amt_3 = 400e18; 
    // uint256 public constant IP_Net_Amt_3 = 380e18; 
    // uint256 public constant IP_Admin_Amt_3 = 60e18;
    // uint256 public constant IP_Admin_Amt_PU_3 = 20e18; 

    
    //  //Pool 4 4800$
    // uint256 public constant IP_Total_Amt_4 = 1600e18; 
    // uint256 public constant IP_Net_Amt_4 = 1520e18; 
    // uint256 public constant IP_Admin_Amt_4 = 240e18; 
    // uint256 public constant IP_Admin_Amt_PU_4 = 80e18; 

    // //Pool 5 19200$
    // uint256 public constant IP_Total_Amt_5 = 6400e18; 
    // uint256 public constant IP_Net_Amt_5 = 6080e18; 
    // uint256 public constant IP_Admin_Amt_5 = 960e18; 
    // uint256 public constant IP_Admin_Amt_PU_5 = 320e18; 

    // //Pool 6 76800$
    // uint256 public constant IP_Total_Amt_6 = 25600e18; 
    // uint256 public constant IP_Net_Amt_6 =  24320e18; 
    // uint256 public constant IP_Admin_Amt_6 = 3840e18; 
    // uint256 public constant IP_Admin_Amt_PU_6 = 1280e18; 

    // //Pool 7 307200$
    // uint256 public constant IP_Total_Amt_7 = 102400e18; 
    // uint256 public constant IP_Net_Amt_7 =  97280e18; 
    // uint256 public constant IP_Admin_Amt_7 = 15360e18; 
    // uint256 public constant IP_Admin_Amt_PU_7 = 5120e18; 


    // // Time durations
    // uint256 public constant WEEK_DURATION = 7 days;
    // uint256 public constant MONTH_DURATION = 30 days;

    // // Tree structure
    // uint8 public constant MAX_CHILDREN = 3;
    // uint32 public constant START_USER_ID = 1000;


    // function getPoolAmounts() internal pure returns (uint256[7] memory) {
    //     return [
    //         uint256(75e18),
    //         uint256(300e18),
    //         uint256(1200e18),
    //         uint256(4800e18),
    //         uint256(19200e18),
    //         uint256(76800e18),
    //         uint256(307200e18)
    //     ];
    // }

    // function getPool(uint8 index) internal pure returns (uint256) {
    //     uint256[7] memory arr = getPoolAmounts();
    //     require(index < arr.length, "Invalid pool index");
    //     return arr[index];
    // }
}

