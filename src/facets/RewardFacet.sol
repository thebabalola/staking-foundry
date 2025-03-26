// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, LibAppStorage, UserInfo} from "../libraries/LibAppStorage.sol";
import {LibERC20} from "../libraries/LibERC20.sol";
import {LibStaking} from "../libraries/LibStaking.sol";
import {IStakingDiamond} from "../interfaces/IStakingDiamond.sol";

contract RewardFacet {
    AppStorage internal s;

    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 newRate);
    event DecayRateUpdated(uint256 newRate);
    event ERC20RewardMultiplierUpdated(uint256 newMultiplier);
    event ERC721RewardMultiplierUpdated(uint256 newMultiplier);
    event ERC1155RewardMultiplierUpdated(uint256 newMultiplier);
    event MinStakingPeriodUpdated(uint256 newPeriod);

    function claimRewards() external {
        UserInfo storage userInfo = s.userInfo[msg.sender];
        require(userInfo.lastRewardClaim > 0, "RewardFacet: No stakes found");
        
        // Calculate rewards
        uint256 rewards = LibStaking.calculateRewards(msg.sender);
        require(rewards > 0, "RewardFacet: No rewards to claim");
        
        // Update user's reward info
        userInfo.lastRewardClaim = block.timestamp;
        userInfo.pendingRewards = 0;
        
        // Mint reward tokens to user
        LibERC20._mint(msg.sender, rewards);
        
        emit RewardsClaimed(msg.sender, rewards);
    }

    function pendingRewards(address user) external view returns (uint256) {
        return LibStaking.calculateRewards(user);
    }

    // Admin functions to update reward parameters
    function setBaseRewardRate(uint256 newRate) external {
        LibAppStorage.enforceIsContractOwner();
        s.baseRewardRate = newRate;
        emit RewardRateUpdated(newRate);
    }

    function setDecayRate(uint256 newRate) external {
        LibAppStorage.enforceIsContractOwner();
        s.decayRate = newRate;
        emit DecayRateUpdated(newRate);
    }

    function setERC20RewardMultiplier(uint256 newMultiplier) external {
        LibAppStorage.enforceIsContractOwner();
        s.erc20RewardMultiplier = newMultiplier;
        emit ERC20RewardMultiplierUpdated(newMultiplier);
    }

    function setERC721RewardMultiplier(uint256 newMultiplier) external {
        LibAppStorage.enforceIsContractOwner();
        s.erc721RewardMultiplier = newMultiplier;
        emit ERC721RewardMultiplierUpdated(newMultiplier);
    }

    function setERC1155RewardMultiplier(uint256 newMultiplier) external {
        LibAppStorage.enforceIsContractOwner();
        s.erc1155RewardMultiplier = newMultiplier;
        emit ERC1155RewardMultiplierUpdated(newMultiplier);
    }

    function setMinStakingPeriod(uint256 newPeriod) external {
        LibAppStorage.enforceIsContractOwner();
        s.minStakingPeriod = newPeriod;
        emit MinStakingPeriodUpdated(newPeriod);
    }

    // View functions for reward parameters
    function getRewardParameters() external view returns (
        uint256 baseRewardRate,
        uint256 decayRate,
        uint256 erc20RewardMultiplier,
        uint256 erc721RewardMultiplier,
        uint256 erc1155RewardMultiplier,
        uint256 minStakingPeriod
    ) {
        return (
            s.baseRewardRate,
            s.decayRate,
            s.erc20RewardMultiplier,
            s.erc721RewardMultiplier,
            s.erc1155RewardMultiplier,
            s.minStakingPeriod
        );
    }
}

