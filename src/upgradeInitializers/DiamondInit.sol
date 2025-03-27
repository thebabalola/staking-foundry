// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAppStorage, AppStorage} from "../libraries/LibAppStorage.sol"; // Added AppStorage import
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IERC173} from "../interfaces/IERC173.sol";
import {IERC165} from "../interfaces/IERC165.sol";

contract DiamondInit {
    function init() external {
        // Initialize Diamond storage
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        // Initialize AppStorage
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.name = "Diamond Reward Token";
        s.symbol = "DRT";
        s.decimals = 18;
        
        // Initialize staking parameters
        s.rewardRate = 1e16; // 0.01 tokens per second per staked token
        s.decayRate = 1e14; // 0.01% decay per second
        s.lastUpdateTime = block.timestamp;
    }
}