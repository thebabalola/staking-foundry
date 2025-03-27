// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC20.sol";
import "../interfaces/IERC721.sol";
import "../interfaces/IERC1155.sol";
import "../libraries/LibAppStorage.sol";
import "../libraries/LibDiamond.sol";

contract StakingFacet {
    AppStorage internal s;
    
    event StakedERC20(address indexed user, address indexed token, uint256 amount);
    event StakedERC721(address indexed user, address indexed token, uint256 tokenId);
    event StakedERC1155(address indexed user, address indexed token, uint256 tokenId, uint256 amount);
    event UnstakedERC20(address indexed user, address indexed token, uint256 amount);
    event UnstakedERC721(address indexed user, address indexed token, uint256 tokenId);
    event UnstakedERC1155(address indexed user, address indexed token, uint256 tokenId, uint256 amount);
    
    function stakeERC20(address token, uint256 amount) external {
        require(amount > 0, "Cannot stake 0");
        updateReward(msg.sender);
        
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        s.erc20Stakes[msg.sender][token] += amount;
        
        emit StakedERC20(msg.sender, token, amount);
    }
    
    function stakeERC721(address token, uint256 tokenId) external {
        updateReward(msg.sender);
        
        IERC721(token).transferFrom(msg.sender, address(this), tokenId);
        s.erc721Stakes[msg.sender][token][tokenId] = block.timestamp;
        
        emit StakedERC721(msg.sender, token, tokenId);
    }
    
    function stakeERC1155(address token, uint256 tokenId, uint256 amount) external {
        require(amount > 0, "Cannot stake 0");
        updateReward(msg.sender);
        
        IERC1155(token).safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
        s.erc1155Stakes[msg.sender][token][tokenId] += amount;
        
        emit StakedERC1155(msg.sender, token, tokenId, amount);
    }
    
    function unstakeERC20(address token, uint256 amount) external {
        require(amount > 0, "Cannot unstake 0");
        require(s.erc20Stakes[msg.sender][token] >= amount, "Not enough staked");
        updateReward(msg.sender);
        
        s.erc20Stakes[msg.sender][token] -= amount;
        IERC20(token).transfer(msg.sender, amount);
        
        emit UnstakedERC20(msg.sender, token, amount);
    }
    
    function unstakeERC721(address token, uint256 tokenId) external {
        require(s.erc721Stakes[msg.sender][token][tokenId] > 0, "Not staked");
        updateReward(msg.sender);
        
        delete s.erc721Stakes[msg.sender][token][tokenId];
        IERC721(token).transferFrom(address(this), msg.sender, tokenId);
        
        emit UnstakedERC721(msg.sender, token, tokenId);
    }
    
    function unstakeERC1155(address token, uint256 tokenId, uint256 amount) external {
        require(amount > 0, "Cannot unstake 0");
        require(s.erc1155Stakes[msg.sender][token][tokenId] >= amount, "Not enough staked");
        updateReward(msg.sender);
        
        s.erc1155Stakes[msg.sender][token][tokenId] -= amount;
        IERC1155(token).safeTransferFrom(address(this), msg.sender, tokenId, amount, "");
        
        emit UnstakedERC1155(msg.sender, token, tokenId, amount);
    }
    
    function updateReward(address account) internal {
        s.rewardPerTokenStored = rewardPerToken();
        s.lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            s.rewards[account] = earned(account);
            s.userRewardPerTokenPaid[account] = s.rewardPerTokenStored;
            if (s.rewards[account] > 0 && s.rewardStartTime[account] == 0) {
                s.rewardStartTime[account] = block.timestamp;
            }
        }
    }
    
    function rewardPerToken() public view returns (uint256) {
        if (s.lastUpdateTime == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - s.lastUpdateTime;
        uint256 decayFactor = (1e18 - s.decayRate) ** timeElapsed;
        return s.rewardPerTokenStored + (s.rewardRate * timeElapsed * decayFactor / 1e18);
    }
    
    function earned(address account) public view returns (uint256) {
        uint256 currentRewardPerToken = rewardPerToken();
        uint256 stakedAmount = getTotalStaked(account);
        
        return (stakedAmount * (currentRewardPerToken - s.userRewardPerTokenPaid[account]) / 1e18) + s.rewards[account];
    }
    
    function getTotalStaked(address account) public view returns (uint256) {
        // This is a simplified version - in reality you'd sum up all staked tokens
        // For brevity, we're just returning ERC20 stakes here
        uint256 total;
        // Add logic to sum all ERC20, ERC721, and ERC1155 stakes
        // This would require tracking all staked tokens for each user
        return total;
    }
    
    // In StakingFacet.sol
    function getStakedERC721Tokens(address user, address token) external view returns (uint256[] memory) {
        return s.erc721StakedTokens[user][token];
    }

    function getStakedERC1155Tokens(address user, address token) external view returns (uint256[] memory) {
        return s.erc1155StakedTokens[user][token];
    }
}