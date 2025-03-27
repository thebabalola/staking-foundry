// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IERC721.sol";
import "../interfaces/IERC1155.sol";
import "../interfaces/IERC1155Receiver.sol";
import "../interfaces/IERC721Receiver.sol";
import "../interfaces/IStaking.sol";

contract StakingFacet is IERC1155Receiver, IERC721Receiver, IStaking {
    AppStorage internal s;

    // Events
    event ERC20Staked(address indexed user, address indexed token, uint256 amount);
    event ERC20Unstaked(address indexed user, address indexed token, uint256 amount);
    event ERC721Staked(address indexed user, address indexed token, uint256 tokenId);
    event ERC721Unstaked(address indexed user, address indexed token, uint256 tokenId);
    event ERC1155Staked(address indexed user, address indexed token, uint256 tokenId, uint256 amount);
    event ERC1155Unstaked(address indexed user, address indexed token, uint256 tokenId, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == s.contractOwner, "StakingFacet: Not contract owner");
        _;
    }

    // ERC20 Staking Functions
    function stakeERC20(address tokenAddress, uint256 amount) external override {
        require(amount > 0, "StakingFacet: Cannot stake 0 tokens");
        
        // Transfer tokens from user to contract
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        
        // Update user's staking data
        s.stakedERC20s[msg.sender].push(StakedERC20({
            tokenAddress: tokenAddress,
            amount: amount,
            stakedAt: block.timestamp
        }));
        
        s.totalERC20StakedByUser[msg.sender] += amount;
        
        // Update reward debt
        updateRewardDebt(msg.sender);
        
        emit ERC20Staked(msg.sender, tokenAddress, amount);
    }
    
    function unstakeERC20(uint256 stakedIndex) external override {
        require(stakedIndex < s.stakedERC20s[msg.sender].length, "StakingFacet: Invalid staked index");
        
        StakedERC20 memory staked = s.stakedERC20s[msg.sender][stakedIndex];
        require(block.timestamp >= staked.stakedAt + s.minimumStakingPeriod, "StakingFacet: Minimum staking period not met");
        
        // Calculate rewards
        uint256 rewards = calculateRewards(msg.sender);
        
        // Remove staked token from array
        s.totalERC20StakedByUser[msg.sender] -= staked.amount;
        
        // Remove from array by swapping with last element and popping
        uint256 lastIndex = s.stakedERC20s[msg.sender].length - 1;
        if (stakedIndex != lastIndex) {
            s.stakedERC20s[msg.sender][stakedIndex] = s.stakedERC20s[msg.sender][lastIndex];
        }
        s.stakedERC20s[msg.sender].pop();
        
        // Update reward debt
        updateRewardDebt(msg.sender);
        
        // Transfer tokens back to user
        IERC20(staked.tokenAddress).transfer(msg.sender, staked.amount);
        
        // Mint rewards
        if (rewards > 0) {
            mintRewards(msg.sender, rewards);
        }
        
        emit ERC20Unstaked(msg.sender, staked.tokenAddress, staked.amount);
        if (rewards > 0) {
            emit RewardClaimed(msg.sender, rewards);
        }
    }
    
    // ERC721 Staking Functions
    function stakeERC721(address tokenAddress, uint256 tokenId) external override {
        // Transfer NFT from user to contract
        IERC721(tokenAddress).safeTransferFrom(msg.sender, address(this), tokenId);
        
        // Update user's staking data
        s.stakedERC721s[msg.sender].push(StakedERC721({
            tokenAddress: tokenAddress,
            tokenId: tokenId,
            stakedAt: block.timestamp
        }));
        
        s.totalERC721StakedByUser[msg.sender] += 1;
        
        // Update reward debt
        updateRewardDebt(msg.sender);
        
        emit ERC721Staked(msg.sender, tokenAddress, tokenId);
    }
    
    function unstakeERC721(uint256 stakedIndex) external override {
        require(stakedIndex < s.stakedERC721s[msg.sender].length, "StakingFacet: Invalid staked index");
        
        StakedERC721 memory staked = s.stakedERC721s[msg.sender][stakedIndex];
        require(block.timestamp >= staked.stakedAt + s.minimumStakingPeriod, "StakingFacet: Minimum staking period not met");
        
        // Calculate rewards
        uint256 rewards = calculateRewards(msg.sender);
        
        // Remove staked token from array
        s.totalERC721StakedByUser[msg.sender] -= 1;
        
        // Remove from array by swapping with last element and popping
        uint256 lastIndex = s.stakedERC721s[msg.sender].length - 1;
        if (stakedIndex != lastIndex) {
            s.stakedERC721s[msg.sender][stakedIndex] = s.stakedERC721s[msg.sender][lastIndex];
        }
        s.stakedERC721s[msg.sender].pop();
        
        // Update reward debt
        updateRewardDebt(msg.sender);
        
        // Transfer NFT back to user
        IERC721(staked.tokenAddress).safeTransferFrom(address(this), msg.sender, staked.tokenId);
        
        // Mint rewards
        if (rewards > 0) {
            mintRewards(msg.sender, rewards);
        }
        
        emit ERC721Unstaked(msg.sender, staked.tokenAddress, staked.tokenId);
        if (rewards > 0) {
            emit RewardClaimed(msg.sender, rewards);
        }
    }
    
    // ERC1155 Staking Functions
    function stakeERC1155(address tokenAddress, uint256 tokenId, uint256 amount) external override {
        require(amount > 0, "StakingFacet: Cannot stake 0 tokens");
        
        // Transfer tokens from user to contract
        IERC1155(tokenAddress).safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
        
        // Update user's staking data
        s.stakedERC1155s[msg.sender].push(StakedERC1155({
            tokenAddress: tokenAddress,
            tokenId: tokenId,
            amount: amount,
            stakedAt: block.timestamp
        }));
        
        s.totalERC1155StakedByUser[msg.sender] += amount;
        
        // Update reward debt
        updateRewardDebt(msg.sender);
        
        emit ERC1155Staked(msg.sender, tokenAddress, tokenId, amount);
    }
    
    function unstakeERC1155(uint256 stakedIndex) external override {
        require(stakedIndex < s.stakedERC1155s[msg.sender].length, "StakingFacet: Invalid staked index");
        
        StakedERC1155 memory staked = s.stakedERC1155s[msg.sender][stakedIndex];
        require(block.timestamp >= staked.stakedAt + s.minimumStakingPeriod, "StakingFacet: Minimum staking period not met");
        
        // Calculate rewards
        uint256 rewards = calculateRewards(msg.sender);
        
        // Remove staked token from array
        s.totalERC1155StakedByUser[msg.sender] -= staked.amount;
        
        // Remove from array by swapping with last element and popping
        uint256 lastIndex = s.stakedERC1155s[msg.sender].length - 1;
        if (stakedIndex != lastIndex) {
            s.stakedERC1155s[msg.sender][stakedIndex] = s.stakedERC1155s[msg.sender][lastIndex];
        }
        s.stakedERC1155s[msg.sender].pop();
        
        // Update reward debt
        updateRewardDebt(msg.sender);
        
        // Transfer tokens back to user
        IERC1155(staked.tokenAddress).safeTransferFrom(address(this), msg.sender, staked.tokenId, staked.amount, "");
        
        // Mint rewards
        if (rewards > 0) {
            mintRewards(msg.sender, rewards);
        }
        
        emit ERC1155Unstaked(msg.sender, staked.tokenAddress, staked.tokenId, staked.amount);
        if (rewards > 0) {
            emit RewardClaimed(msg.sender, rewards);
        }
    }
    
    // Reward Functions
    function claimRewards() external override {
        uint256 rewards = calculateRewards(msg.sender);
        require(rewards > 0, "StakingFacet: No rewards to claim");
        
        // Update reward debt
        updateRewardDebt(msg.sender);
        
        // Mint rewards
        mintRewards(msg.sender, rewards);
        
        emit RewardClaimed(msg.sender, rewards);
    }
    
    function calculateRewards(address user) public view override returns (uint256) {
        uint256 totalStaked = s.totalERC20StakedByUser[user] + 
                             (s.totalERC721StakedByUser[user] * 1e18) + 
                             s.totalERC1155StakedByUser[user];
        
        if (totalStaked == 0) {
            return 0;
        }
        
        uint256 rewardDebt = s.erc20RewardDebt[user] + s.erc721RewardDebt[user] + s.erc1155RewardDebt[user];
        
        // Calculate time-weighted rewards with decay
        uint256 rewards = 0;
        
        // Calculate ERC20 rewards
        for (uint256 i = 0; i < s.stakedERC20s[user].length; i++) {
            StakedERC20 memory staked = s.stakedERC20s[user][i];
            uint256 stakingDuration = block.timestamp - staked.stakedAt;
            uint256 decayFactor = calculateDecayFactor(stakingDuration);
            rewards += (staked.amount * s.rewardRate * stakingDuration * decayFactor) / 1e18;
        }
        
        // Calculate ERC721 rewards (each NFT counts as 1e18 tokens)
        for (uint256 i = 0; i < s.stakedERC721s[user].length; i++) {
            StakedERC721 memory staked = s.stakedERC721s[user][i];
            uint256 stakingDuration = block.timestamp - staked.stakedAt;
            uint256 decayFactor = calculateDecayFactor(stakingDuration);
            rewards += (1e18 * s.rewardRate * stakingDuration * decayFactor) / 1e18;
        }
        
        // Calculate ERC1155 rewards
        for (uint256 i = 0; i < s.stakedERC1155s[user].length; i++) {
            StakedERC1155 memory staked = s.stakedERC1155s[user][i];
            uint256 stakingDuration = block.timestamp - staked.stakedAt;
            uint256 decayFactor = calculateDecayFactor(stakingDuration);
            rewards += (staked.amount * s.rewardRate * stakingDuration * decayFactor) / 1e18;
        }
        
        return rewards > rewardDebt ? rewards - rewardDebt : 0;
    }
    
    function calculateDecayFactor(uint256 stakingDuration) internal view returns (uint256) {
        // Decay factor decreases over time (starts at 10000 = 100%)
        // For example, if decayRate is 100 (1%), then after 100 days, the decay factor would be 0
        uint256 daysPassed = stakingDuration / 1 days;
        if (daysPassed >= 10000 / s.decayRate) {
            return 0;
        }
        return 10000 - (daysPassed * s.decayRate);
    }
    
    function updateRewardDebt(address user) internal {
        uint256 rewards = calculateRewards(user);
        s.erc20RewardDebt[user] = rewards;
        s.erc721RewardDebt[user] = 0;
        s.erc1155RewardDebt[user] = 0;
    }
    
    function mintRewards(address user, uint256 amount) internal {
        // Mint new tokens as rewards (using ERC20 functionality)
        s.balances[user] += amount;
        s.totalSupply += amount;
    }
    
    // Admin Functions
    function setRewardRate(uint256 newRate) external onlyOwner {
        s.rewardRate = newRate;
    }
    
    function setDecayRate(uint256 newRate) external onlyOwner {
        require(newRate <= 10000, "StakingFacet: Decay rate cannot exceed 100%");
        s.decayRate = newRate;
    }
    
    function setMinimumStakingPeriod(uint256 newPeriod) external onlyOwner {
        s.minimumStakingPeriod = newPeriod;
    }
    
    // ERC1155Receiver and ERC721Receiver implementation
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
    
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
    
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
    
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == 0x01ffc9a7; // ERC165 interface ID
    }
}

