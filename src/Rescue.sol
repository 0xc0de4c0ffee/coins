// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;
abstract contract Rescue {
    address rescuer;
    constructor(address _rescuer){
        rescuer = _rescuer;
    }
} 