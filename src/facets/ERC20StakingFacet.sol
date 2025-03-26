// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, LibAppStorage, ERC20Stake, UserInfo} from "../libraries/LibAppStorage.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IStakingDiamond} from "../interfaces/IStakingDiamond.sol";

contract ERC20StakingFacet {
    AppStorage internal s;

    event ERC20Staked(address indexed user, address indexed token, uint256 amount);
    event ERC20Unstaked(address indexed user, address indexed token, uint256 amount);
    event SupportedERC20TokenAdded(address indexed token);
    event SupportedERC20TokenRemoved(address indexed token);

    modifier onlySupportedERC20(address token) {
        require(s.supportedERC20Tokens[token], "ERC20StakingFacet: Token not supported");
        _;
    }

    function addSupportedERC20Token(address token) external {
        LibAppStorage.enforceIsContractOwner();
        require(token != address(0), "ERC20StakingFacet: Cannot add zero address");
        require(!s.supportedERC20Tokens[token], "ERC20StakingFacet: Token already supported");
        
        s.supportedERC20Tokens[token] = true;
        emit SupportedERC20TokenAdded(token);
    }

    function removeSupportedERC20Token(address token) external {
        LibAppStorage.enforceIsContractOwner();
        require(s.supportedERC20Tokens[token], "ERC20StakingFacet: Token not supported");
        
        s.supportedERC20Tokens[token] = false;
        emit SupportedERC20TokenRemoved(token);
    }

    function isSupportedERC20Token(address token) external view returns (bool) {
        return s.supportedERC20Tokens[token];
    }

    function stakeERC20(address token, uint256 amount) external onlySupportedERC20(token) {
        require(amount > 0, "ERC20StakingFacet: Cannot stake 0 tokens");
        
        // Transfer tokens from user to contract
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        // Update user's staking info
        UserInfo storage userInfo = s.userInfo[msg.sender];
        ERC20Stake storage stake = userInfo.erc20Stakes[token];
        
        // If this is the first time staking this token, initialize the timestamp
        if (stake.amount == 0) {
            stake.timestamp = block.timestamp;
        } else {
            // If adding to existing stake, we need to calculate pending rewards first
            // This is a simplified approach - in a real contract you might want to
            // update the rewards without requiring the user to claim them
            stake.amount += amount;
            stake.timestamp = block.timestamp; // Reset the staking timestamp
        }
        
        // Update last reward claim time if it's the first stake
        if (userInfo.lastRewardClaim == 0) {
            userInfo.lastRewardClaim = block.timestamp;
        }
        
        emit ERC20Staked(msg.sender, token, amount);
    }

    function unstakeERC20(address token, uint256 amount) external onlySupportedERC20(token) {
        UserInfo storage userInfo = s.userInfo[msg.sender];
        ERC20Stake storage stake = userInfo.erc20Stakes[token];
        
        require(stake.amount >= amount, "ERC20StakingFacet: Insufficient staked amount");
        
        // Check minimum staking period
        require(
            block.timestamp - stake.timestamp >= s.minStakingPeriod,
            "ERC20StakingFacet: Minimum staking period not reached"
        );
        
        // Update staking info
        stake.amount -= amount;
        
        // If all tokens are unstaked, reset the timestamp
        if (stake.amount == 0) {
            stake.timestamp = 0;
        }
        
        // Transfer tokens back to user
        IERC20(token).transfer(msg.sender, amount);
        
        emit ERC20Unstaked(msg.sender, token, amount);
    }

    function getERC20StakeInfo(address user, address token) external view returns (uint256 amount, uint256 timestamp) {
        ERC20Stake storage stake = s.userInfo[user].erc20Stakes[token];
        return (stake.amount, stake.timestamp);
    }
}

