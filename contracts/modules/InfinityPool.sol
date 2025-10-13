// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CompanyMultiMatrixConstants
 * @dev 3× company-wide matrices (5 levels) with constant reward percentages
 * Author: Rahul + GPT-5 team
 */
contract CompanyMultiMatrixConstants {
    uint8 public constant MAX_CHILDREN = 3;
    uint32 public constant START_ID = 1000;

    // === CONFIGURATION ===

    // Fixed matrix entry prices (in wei)
    //uint256[5] public constant MATRIX_PRICES = [100e18,200e18, 500e18,1000e18,2000e18];
      uint256[5] public immutable MATRIX_PRICES;

    // Reward percentages (in whole numbers)
    // [Level1, Level2, Level3, Company]
    uint8[4] public immutable REWARD_PCT = [40, 30, 20, 10];

    // === DATA STRUCTURES ===

    struct User {
        uint32 id;                // user ID starting from 1000
        address userAddress;      // wallet address
        uint32 parentId;          // parent ID (also starts from 1000)
        uint32[] children;        // list of child IDs
    }

    // matrixId => array of users (index 0 = company root)
    mapping(uint8 => User[]) public matrices;

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

    // === CONSTRUCTOR ===

    constructor() {

           MATRIX_PRICES[0] = 100e18;
        MATRIX_PRICES[1] = 200e18;
        MATRIX_PRICES[2] = 500e18;
        MATRIX_PRICES[3] = 1000e18;
        MATRIX_PRICES[4] = 2000e18;
        // Initialize company root for all matrices
        for (uint8 i = 0; i < MATRIX_PRICES.length; i++) {
            User memory root = User({
                id: START_ID,
                userAddress: msg.sender,
                parentId: 0,
                children: new uint32 
            });
            matrices[i].push(root);
        }
    }

    // === MAIN JOIN FUNCTION ===

    function joinMatrix(uint8 matrixId) external payable {
        require(matrixId < MATRIX_PRICES.length, "Invalid matrix");
        require(msg.value == MATRIX_PRICES[matrixId], "Incorrect amount");

        User[] storage users = matrices[matrixId];
        uint256 index = users.length;               // current index for new user
        uint32 newUserId = START_ID + uint32(index);

        // parent by formula
        uint256 parentIndex = (index - 1) / MAX_CHILDREN;
        User storage parent = users[parentIndex];

        // create user
        User memory newUser = User({
            id: newUserId,
            userAddress: msg.sender,
            parentId: parent.id,
            children: new uint32 
        });

        users.push(newUser);
        users[parentIndex].children.push(newUserId);

        emit UserJoined(
            matrixId,
            newUserId,
            msg.sender,
            parent.id,
            parent.userAddress,
            uint8(users[parentIndex].children.length)
        );

        _distributeRewards(matrixId, parentIndex, msg.value);
    }

    // === INTERNAL REWARD DISTRIBUTION ===

    function _distributeRewards(uint8 matrixId, uint256 parentIndex, uint256 amount) internal {
        User[] storage users = matrices[matrixId];
        uint256 remaining = amount;

        // Level 1
        address level1 = users[parentIndex].userAddress;
        uint256 lvl1Amt = (amount * REWARD_PCT[0]) / 100;
        _safeSend(level1, lvl1Amt, "Level1");
        remaining -= lvl1Amt;

        // Level 2
        uint256 parent2Index = _getParentIndexById(matrixId, users[parentIndex].parentId);
        if (parent2Index < users.length) {
            address level2 = users[parent2Index].userAddress;
            uint256 lvl2Amt = (amount * REWARD_PCT[1]) / 100;
            _safeSend(level2, lvl2Amt, "Level2");
            remaining -= lvl2Amt;

            // Level 3
            uint256 parent3Index = _getParentIndexById(matrixId, users[parent2Index].parentId);
            if (parent3Index < users.length) {
                address level3 = users[parent3Index].userAddress;
                uint256 lvl3Amt = (amount * REWARD_PCT[2]) / 100;
                _safeSend(level3, lvl3Amt, "Level3");
                remaining -= lvl3Amt;
            }
        }

        // Remaining to company
        address company = users[0].userAddress;
        if (remaining > 0) _safeSend(company, remaining, "Company");
    }

    function _getParentIndexById(uint8 matrixId, uint32 parentId) internal view returns (uint256) {
        if (parentId < START_ID) return type(uint256).max;
        uint256 index = parentId - START_ID;
        return index < matrices[matrixId].length ? index : type(uint256).max;
    }

    function _safeSend(address to, uint256 amount, string memory level) internal {
        if (to == address(0) || amount == 0) return;
        (bool ok, ) = payable(to).call{value: amount}("");
        if (ok) emit RewardSent(to, amount, level);
    }

    // === VIEW HELPERS ===

    function getUser(uint8 matrixId, uint256 index)
        external
        view
        returns (uint32 id, address userAddr, uint32 parentId, uint32[] memory children)
    {
        User storage u = matrices[matrixId][index];
        return (u.id, u.userAddress, u.parentId, u.children);
    }

    function getMatrixSize(uint8 matrixId) external view returns (uint256) {
        return matrices[matrixId].length;
    }

    receive() external payable {}
}
