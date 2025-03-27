// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStaking {
    // Events
    event StakedERC20(address indexed user, address indexed token, uint256 amount);
    event StakedERC721(address indexed user, address indexed token, uint256 tokenId);
    event StakedERC1155(address indexed user, address indexed token, uint256 tokenId, uint256 amount);
    event UnstakedERC20(address indexed user, address indexed token, uint256 amount);
    event UnstakedERC721(address indexed user, address indexed token, uint256 tokenId);
    event UnstakedERC1155(address indexed user, address indexed token, uint256 tokenId, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 newRate);
    event DecayRateUpdated(uint256 newRate);

    // ERC20 Staking Functions
    function stakeERC20(address token, uint256 amount) external;
    function unstakeERC20(address token, uint256 amount) external;

    // ERC721 Staking Functions
    function stakeERC721(address token, uint256 tokenId) external;
    function unstakeERC721(address token, uint256 tokenId) external;

    // ERC1155 Staking Functions
    function stakeERC1155(address token, uint256 tokenId, uint256 amount) external;
    function unstakeERC1155(address token, uint256 tokenId, uint256 amount) external;

    // Reward Functions
    function claimReward() external;
    function earned(address account) external view returns (uint256);
    function rewardPerToken() external view returns (uint256);
    function updateReward(address account) external; // <-- Added this critical function

    // View Functions
    function getStakedERC20(address user, address token) external view returns (uint256);
    function getStakedERC721Tokens(address user, address token) external view returns (uint256[] memory);
    function getStakedERC1155(address user, address token, uint256 tokenId) external view returns (uint256);
    function getTotalStaked(address account) external view returns (uint256);
    function getRewardRate() external view returns (uint256);
    function getDecayRate() external view returns (uint256);

    // Admin Functions
    function setRewardRate(uint256 rate) external;
    function setDecayRate(uint256 rate) external;
}