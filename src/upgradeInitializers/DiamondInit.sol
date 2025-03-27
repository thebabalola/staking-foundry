// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import "../libraries/LibDiamond.sol";
import "../interfaces/IDiamondLoupe.sol";
import "../interfaces/IERC173.sol";
import "../interfaces/IERC165.sol";

contract DiamondInit {
    AppStorage internal s;
    
    struct Args {
        string name;
        string symbol;
        uint8 decimals;
        uint256 initialSupply;
        address initialSupplyRecipient;
        uint256 rewardRate;
        uint256 decayRate;
        uint256 minimumStakingPeriod;
    }
    
    function init(Args memory _args) external {
        // Initialize ERC20 token properties
        s.name = _args.name;
        s.symbol = _args.symbol;
        s.decimals = _args.decimals;
        
        // Mint initial supply
        if (_args.initialSupply > 0) {
            address recipient = _args.initialSupplyRecipient;
            if (recipient == address(0)) {
                recipient = msg.sender;
            }
            s.totalSupply = _args.initialSupply;
            s.balances[recipient] = _args.initialSupply;
        }
        
        // Initialize staking properties
        s.rewardRate = _args.rewardRate;
        s.decayRate = _args.decayRate;
        s.minimumStakingPeriod = _args.minimumStakingPeriod;
        
        // Initialize contract owner
        s.contractOwner = msg.sender;
        
        // Add ERC165 data
        DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
    }
}

