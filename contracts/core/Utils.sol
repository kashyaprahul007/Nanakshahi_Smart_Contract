// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library Utils {
    function percent(uint amount, uint pct) internal pure returns (uint) {
        return (amount * pct) / 100;
    }
}
