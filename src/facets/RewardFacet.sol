// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC20.sol";
import "../libraries/LibAppStorage.sol";
import "../libraries/LibDiamond.sol";
import {AppStorage} from "../libraries/LibAppStorage.sol"; // Added explicit import
import "./StakingFacet.sol";
import "../interfaces/IStaking.sol";
import "./ERC20Facet.sol"; // Added import for ERC20Facet

contract RewardFacet {
    AppStorage internal s;
    
    event RewardClaimed(address indexed user, uint256 amount);
    
    function claimReward() external {
        IStaking(address(this)).updateReward(msg.sender);
        uint256 reward = s.rewards[msg.sender];
        require(reward > 0, "No rewards to claim");
        
        s.rewards[msg.sender] = 0;
        ERC20Facet(address(this)).mint(msg.sender, reward);
        
        emit RewardClaimed(msg.sender, reward);
    }
    
    function setRewardRate(uint256 rate) external {
        LibDiamond.enforceIsContractOwner();
        s.rewardRate = rate;
    }
    
    function setDecayRate(uint256 rate) external {
        LibDiamond.enforceIsContractOwner();
        require(rate <= 1e18, "Decay rate cannot exceed 100%");
        s.decayRate = rate;
    }
    
    function getRewardRate() external view returns (uint256) {
        return s.rewardRate;
    }
    
    function getDecayRate() external view returns (uint256) {
        return s.decayRate;
    }
    
    function getReward(address account) external view returns (uint256) {
        return s.rewards[account];
    }
}