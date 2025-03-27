// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";

contract RewardFacet {
    AppStorage internal s;
    
    // Events
    event RewardRateUpdated(uint256 newRate);
    event DecayRateUpdated(uint256 newRate);
    event MinimumStakingPeriodUpdated(uint256 newPeriod);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == s.contractOwner, "RewardFacet: Not contract owner");
        _;
    }
    
    // Admin Functions
    function setRewardRate(uint256 newRate) external onlyOwner {
        s.rewardRate = newRate;
        emit RewardRateUpdated(newRate);
    }
    
    function setDecayRate(uint256 newRate) external onlyOwner {
        require(newRate <= 10000, "RewardFacet: Decay rate cannot exceed 100%");
        s.decayRate = newRate;
        emit DecayRateUpdated(newRate);
    }
    
    function setMinimumStakingPeriod(uint256 newPeriod) external onlyOwner {
        s.minimumStakingPeriod = newPeriod;
        emit MinimumStakingPeriodUpdated(newPeriod);
    }
    
    // View Functions
    function getRewardRate() external view returns (uint256) {
        return s.rewardRate;
    }
    
    function getDecayRate() external view returns (uint256) {
        return s.decayRate;
    }
    
    function getMinimumStakingPeriod() external view returns (uint256) {
        return s.minimumStakingPeriod;
    }
}

