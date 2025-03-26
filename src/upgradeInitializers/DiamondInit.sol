// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, LibAppStorage} from "../libraries/LibAppStorage.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IERC173} from "../interfaces/IERC173.sol";
import {IERC165} from "../interfaces/IERC165.sol";

contract DiamondInit {
    AppStorage internal s;

    struct Args {
        string name;
        string symbol;
        uint8 decimals;
        uint256 baseRewardRate;
        uint256 erc20RewardMultiplier;
        uint256 erc721RewardMultiplier;
        uint256 erc1155RewardMultiplier;
        uint256 decayRate;
        uint256 minStakingPeriod;
    }

    function init(Args memory _args) external {
        // Initialize ERC20 token parameters
        s.name = _args.name;
        s.symbol = _args.symbol;
        s.decimals = _args.decimals;
        
        // Initialize staking parameters
        s.baseRewardRate = _args.baseRewardRate;
        s.erc20RewardMultiplier = _args.erc20RewardMultiplier;
        s.erc721RewardMultiplier = _args.erc721RewardMultiplier;
        s.erc1155RewardMultiplier = _args.erc1155RewardMultiplier;
        s.decayRate = _args.decayRate;
        s.minStakingPeriod = _args.minStakingPeriod;
        
        // Add ERC165 data
        s.supportedInterfaces[type(IERC165).interfaceId] = true;
        s.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        s.supportedInterfaces[type(IERC173).interfaceId] = true;
    }
}

