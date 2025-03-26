// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, UserInfo, LibAppStorage} from "./LibAppStorage.sol";

library LibStaking {
    // Calculate rewards based on staking parameters
    function calculateRewards(address user) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        UserInfo storage userInfo = s.userInfo[user];
        
        if (userInfo.lastRewardClaim == 0) {
            return 0;
        }
        
        uint256 totalRewards = userInfo.pendingRewards;
        
        // Calculate rewards for each ERC20 token staked
        for (uint i = 0; i < 10; i++) { // Limit loop to prevent gas issues
            address token = getNextERC20Token(i);
            if (token == address(0)) break;
            
            if (s.supportedERC20Tokens[token] && userInfo.erc20Stakes[token].amount > 0) {
                uint256 stakingDuration = block.timestamp - userInfo.erc20Stakes[token].timestamp;
                if (stakingDuration >= s.minStakingPeriod) {
                    // Apply decay factor based on staking duration
                    uint256 decayFactor = calculateDecayFactor(stakingDuration);
                    
                    // Calculate rewards: amount * rate * multiplier * duration * decayFactor / 1e18
                    uint256 reward = (userInfo.erc20Stakes[token].amount * s.baseRewardRate * s.erc20RewardMultiplier * stakingDuration * decayFactor) / 1e36;
                    totalRewards += reward;
                }
            }
        }
        
        // Calculate rewards for each ERC721 token staked
        for (uint i = 0; i < 10; i++) { // Limit loop to prevent gas issues
            address token = getNextERC721Token(i);
            if (token == address(0)) break;
            
            if (s.supportedERC721Tokens[token] && userInfo.erc721Stakes[token].tokenIds.length > 0) {
                for (uint j = 0; j < userInfo.erc721Stakes[token].tokenIds.length; j++) {
                    uint256 tokenId = userInfo.erc721Stakes[token].tokenIds[j];
                    uint256 stakingDuration = block.timestamp - userInfo.erc721Stakes[token].tokenIdToTimestamp[tokenId];
                    
                    if (stakingDuration >= s.minStakingPeriod) {
                        // Apply decay factor based on staking duration
                        uint256 decayFactor = calculateDecayFactor(stakingDuration);
                        
                        // Calculate rewards: 1 * rate * multiplier * duration * decayFactor / 1e18
                        uint256 reward = (s.baseRewardRate * s.erc721RewardMultiplier * stakingDuration * decayFactor) / 1e36;
                        totalRewards += reward;
                    }
                }
            }
        }
        
        // Calculate rewards for each ERC1155 token staked
        for (uint i = 0; i < 10; i++) { // Limit loop to prevent gas issues
            address token = getNextERC1155Token(i);
            if (token == address(0)) break;
            
            if (s.supportedERC1155Tokens[token] && userInfo.erc1155Stakes[token].ids.length > 0) {
                for (uint j = 0; j < userInfo.erc1155Stakes[token].ids.length; j++) {
                    uint256 id = userInfo.erc1155Stakes[token].ids[j];
                    uint256 amount = userInfo.erc1155Stakes[token].idToAmount[id];
                    uint256 stakingDuration = block.timestamp - userInfo.erc1155Stakes[token].idToTimestamp[id];
                    
                    if (stakingDuration >= s.minStakingPeriod) {
                        // Apply decay factor based on staking duration
                        uint256 decayFactor = calculateDecayFactor(stakingDuration);
                        
                        // Calculate rewards: amount * rate * multiplier * duration * decayFactor / 1e18
                        uint256 reward = (amount * s.baseRewardRate * s.erc1155RewardMultiplier * stakingDuration * decayFactor) / 1e36;
                        totalRewards += reward;
                    }
                }
            }
        }
        
        return totalRewards;
    }
    
    // Calculate decay factor based on staking duration
    // The longer the staking period, the higher the decay factor (up to a maximum)
    function calculateDecayFactor(uint256 stakingDuration) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        
        // Base decay factor is 1e18 (100%)
        uint256 baseFactor = 1e18;
        
        // Calculate bonus based on staking duration
        // The longer the staking, the higher the bonus (lower decay)
        uint256 durationBonus = (stakingDuration * s.decayRate) / 1e18;
        
        // Cap the bonus at 100% (2x reward)
        if (durationBonus > 1e18) {
            durationBonus = 1e18;
        }
        
        // Return the enhanced factor (base + bonus)
        return baseFactor + durationBonus;
    }
    
    // Helper functions to iterate through supported tokens
    // In a real implementation, you would use a more efficient data structure
    function getNextERC20Token(uint256 index) internal view returns (address) {
        // This is a simplified implementation
        // In a real contract, you would store and retrieve the list of supported tokens
        if (index >= 10) return address(0);
        AppStorage storage s = LibAppStorage.appStorage();
        
        // Dummy implementation - replace with actual token retrieval logic
        address[10] memory dummyTokens;
        uint256 count = 0;
        
        // This is inefficient but works for demonstration
        // In a real contract, you would maintain an array of supported tokens
        for (uint i = 1; i <= 10; i++) {
            address potentialToken = address(uint160(i));
            if (s.supportedERC20Tokens[potentialToken]) {
                dummyTokens[count] = potentialToken;
                count++;
            }
        }
        
        if (index < count) {
            return dummyTokens[index];
        }
        
        return address(0);
    }
    
    function getNextERC721Token(uint256 index) internal view returns (address) {
        // Similar implementation as getNextERC20Token
        if (index >= 10) return address(0);
        AppStorage storage s = LibAppStorage.appStorage();
        
        address[10] memory dummyTokens;
        uint256 count = 0;
        
        for (uint i = 1; i <= 10; i++) {
            address potentialToken = address(uint160(i + 100));
            if (s.supportedERC721Tokens[potentialToken]) {
                dummyTokens[count] = potentialToken;
                count++;
            }
        }
        
        if (index < count) {
            return dummyTokens[index];
        }
        
        return address(0);
    }
    
    function getNextERC1155Token(uint256 index) internal view returns (address) {
        // Similar implementation as getNextERC20Token
        if (index >= 10) return address(0);
        AppStorage storage s = LibAppStorage.appStorage();
        
        address[10] memory dummyTokens;
        uint256 count = 0;
        
        for (uint i = 1; i <= 10; i++) {
            address potentialToken = address(uint160(i + 200));
            if (s.supportedERC1155Tokens[potentialToken]) {
                dummyTokens[count] = potentialToken;
                count++;
            }
        }
        
        if (index < count) {
            return dummyTokens[index];
        }
        
        return address(0);
    }
}

