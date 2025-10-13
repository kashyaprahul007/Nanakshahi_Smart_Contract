// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;



contract practice  {
   

    constructor() {
        // everything initializes
    }

    function getUser(uint len_) external view returns (uint parent1, uint parent2) 
    {      
      uint len = len_;
      return ((len -1 )/3, (len  )/3);
    }
}
