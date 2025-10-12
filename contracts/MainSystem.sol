// MainSystem.sol
pragma solidity ^0.8.20;

import "./core/Ownable.sol";
import "./core/Storage.sol";
import "./core/Utils.sol";
import "./modules/ContestRoyalty.sol";
import "./modules/SponsorMatrix.sol";
import "./modules/InfinityPool.sol";

contract MainSystem is Ownable, Storage, ContestRoyalty, SponsorMatrix2, PoolMatrix3 {
    using Utils for uint;  // now Utils functions available globally

    constructor() {
        // everything initializes
    }
}
