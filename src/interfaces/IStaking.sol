// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStaking {
    // ERC20 Staking
    function stakeERC20(address tokenAddress, uint256 amount) external;
    function unstakeERC20(uint256 stakedIndex) external;
    
    // ERC721 Staking
    function stakeERC721(address tokenAddress, uint256 tokenId) external;
    function unstakeERC721(uint256 stakedIndex) external;
    
    // ERC1155 Staking
    function stakeERC1155(address tokenAddress, uint256 tokenId, uint256 amount) external;
    function unstakeERC1155(uint256 stakedIndex) external;
    
    // Rewards
    function claimRewards() external;
    function calculateRewards(address user) external view returns (uint256);
}

