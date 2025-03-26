// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStakingDiamond {
    // ERC20 Staking Events
    event ERC20Staked(address indexed user, address indexed token, uint256 amount);
    event ERC20Unstaked(address indexed user, address indexed token, uint256 amount);
    
    // ERC721 Staking Events
    event ERC721Staked(address indexed user, address indexed token, uint256 tokenId);
    event ERC721Unstaked(address indexed user, address indexed token, uint256 tokenId);
    
    // ERC1155 Staking Events
    event ERC1155Staked(address indexed user, address indexed token, uint256 id, uint256 amount);
    event ERC1155Unstaked(address indexed user, address indexed token, uint256 id, uint256 amount);
    
    // Reward Events
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 newRate);
    event DecayRateUpdated(uint256 newRate);
}

