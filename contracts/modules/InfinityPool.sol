// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "../core/Ownable.sol";

contract CompanyMatrix is Ownable {

    uint public constant MAX_CHILDREN = 3;

    struct User {
        uint id;
        address userAddress;
        uint parentId; // who placed above them
        uint[] children;
    }

    // For 5 different matrix levels
    mapping(uint => mapping(uint => User)) public matrixUsers; // matrixId => userId => User
    mapping(uint => uint) public lastUserId; // matrixId => lastUserId
    mapping(uint => uint[]) public matrixQueue; // matrixId => queue of parentIds   
    mapping(uint => mapping(uint => uint[])) public UsersIds; // matrixId => userId (main user id) => matrixid (id alloted to user in matrix

    uint256[] public matrixPrices = [75e18, 300e18, 1200e18, 4800e18, 19200e18, 76800e18, 307200e18];

    event UserPlaced(address indexed user, uint indexed matrixId, uint userId, uint parentId, uint position);

    constructor() {
        // Initialize root (company) for all matrices
        for (uint i = 0; i < matrixPrices.length; i++) {
            lastUserId[i] = 1;

            User storage root = matrixUsers[i][1];
            root.id = 1;
            root.userAddress = msg.sender;
            root.parentId = 0;

            // Add root to queue as available parent
            matrixQueue[i].push(1);
        }
    }

    function joinMatrix(uint matrixId) external payable {
        require(matrixId < matrixPrices.length, "Invalid matrix");
        require(msg.value == matrixPrices[matrixId], "Invalid amount");

        lastUserId[matrixId]++;
        uint newId = lastUserId[matrixId];

        // Find parent from queue
        uint parentId = _findNextAvailableParent(matrixId);

        // Register user
        User storage u = matrixUsers[matrixId][newId];
        u.id = newId;
        u.userAddress = msg.sender;
        u.parentId = parentId;

        // Attach child
        matrixUsers[matrixId][parentId].children.push(newId);

        emit UserPlaced(msg.sender, matrixId, newId, parentId, matrixUsers[matrixId][parentId].children.length);

        // Add this new user to queue as potential parent
        matrixQueue[matrixId].push(newId);
    }

    function _findNextAvailableParent(uint matrixId) internal returns (uint parentId) {
        uint[] storage queue = matrixQueue[matrixId];

        for (uint i = 0; i < queue.length; i++) {
            uint candidate = queue[i];
            if (matrixUsers[matrixId][candidate].children.length < MAX_CHILDREN) {
                return candidate;
            }
        }

        revert("No available parent found");
    }

    // View helpers
    function getUser(uint matrixId, uint userId) external view returns (
        uint id,
        address userAddress,
        uint parentId,
        uint[] memory children
    ) {
        User storage u = matrixUsers[matrixId][userId];
        return (u.id, u.userAddress, u.parentId, u.children);
    }

    function getChildren(uint matrixId, uint userId) external view returns (uint[] memory) {
        return matrixUsers[matrixId][userId].children;
    }

    function getQueue(uint matrixId) external view returns (uint[] memory) {
        return matrixQueue[matrixId];
    }

    receive() external payable {}
}
