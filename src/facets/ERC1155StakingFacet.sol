// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, LibAppStorage, ERC1155Stake, UserInfo} from "../libraries/LibAppStorage.sol";
import {IERC1155} from "../interfaces/IERC1155.sol";
import {IStakingDiamond} from "../interfaces/IStakingDiamond.sol";

contract ERC1155StakingFacet {
    AppStorage internal s;

    event ERC1155Staked(address indexed user, address indexed token, uint256 id, uint256 amount);
    event ERC1155Unstaked(address indexed user, address indexed token, uint256 id, uint256 amount);
    event SupportedERC1155TokenAdded(address indexed token);
    event SupportedERC1155TokenRemoved(address indexed token);

    modifier onlySupportedERC1155(address token) {
        require(s.supportedERC1155Tokens[token], "ERC1155StakingFacet: Token not supported");
        _;
    }

    function addSupportedERC1155Token(address token) external {
        LibAppStorage.enforceIsContractOwner();
        require(token != address(0), "ERC1155StakingFacet: Cannot add zero address");
        require(!s.supportedERC1155Tokens[token], "ERC1155StakingFacet: Token already supported");
        
        s.supportedERC1155Tokens[token] = true;
        emit SupportedERC1155TokenAdded(token);
    }

    function removeSupportedERC1155Token(address token) external {
        LibAppStorage.enforceIsContractOwner();
        require(s.supportedERC1155Tokens[token], "ERC1155StakingFacet: Token not supported");
        
        s.supportedERC1155Tokens[token] = false;
        emit SupportedERC1155TokenRemoved(token);
    }

    function isSupportedERC1155Token(address token) external view returns (bool) {
        return s.supportedERC1155Tokens[token];
    }

    function stakeERC1155(address token, uint256 id, uint256 amount) external onlySupportedERC1155(token) {
        require(amount > 0, "ERC1155StakingFacet: Cannot stake 0 tokens");
        
        // Transfer tokens from user to contract
        IERC1155(token).safeTransferFrom(msg.sender, address(this), id, amount, "");
        
        // Update user's staking info
        UserInfo storage userInfo = s.userInfo[msg.sender];
        ERC1155Stake storage stake = userInfo.erc1155Stakes[token];
        
        // If this is the first time staking this token id, add it to the list
        if (stake.idToAmount[id] == 0) {
            stake.ids.push(id);
            stake.idToIndex[id] = stake.ids.length;
            stake.idToTimestamp[id] = block.timestamp;
        } else {
            // If adding to existing stake, update the amount and timestamp
            stake.idToAmount[id] += amount;
            stake.idToTimestamp[id] = block.timestamp; // Reset the staking timestamp
        }
        
        // Update last reward claim time if it's the first stake
        if (userInfo.lastRewardClaim == 0) {
            userInfo.lastRewardClaim = block.timestamp;
        }
        
        emit ERC1155Staked(msg.sender, token, id, amount);
    }

    function unstakeERC1155(address token, uint256 id, uint256 amount) external onlySupportedERC1155(token) {
        UserInfo storage userInfo = s.userInfo[msg.sender];
        ERC1155Stake storage stake = userInfo.erc1155Stakes[token];
        
        require(stake.idToAmount[id] >= amount, "ERC1155StakingFacet: Insufficient staked amount");
        
        // Check minimum staking period
        require(
            block.timestamp - stake.idToTimestamp[id] >= s.minStakingPeriod,
            "ERC1155StakingFacet: Minimum staking period not reached"
        );
        
        // Update staking info
        stake.idToAmount[id] -= amount;
        
        // If all tokens of this id are unstaked, remove it from the list
        if (stake.idToAmount[id] == 0) {
            uint256 index = stake.idToIndex[id];
            uint256 lastIndex = stake.ids.length;
            
            if (index < lastIndex) {
                uint256 lastId = stake.ids[lastIndex - 1];
                stake.ids[index - 1] = lastId;
                stake.idToIndex[lastId] = index;
            }
            
            stake.ids.pop();
            delete stake.idToIndex[id];
            delete stake.idToTimestamp[id];
        }
        
        // Transfer tokens back to user
        IERC1155(token).safeTransferFrom(address(this), msg.sender, id, amount, "");
        
        emit ERC1155Unstaked(msg.sender, token, id, amount);
    }

    function getERC1155StakedIds(address user, address token) external view returns (uint256[] memory) {
        return s.userInfo[user].erc1155Stakes[token].ids;
    }

    function getERC1155StakeInfo(address user, address token, uint256 id) external view returns (uint256 amount, uint256 timestamp) {
        ERC1155Stake storage stake = s.userInfo[user].erc1155Stakes[token];
        return (stake.idToAmount[id], stake.idToTimestamp[id]);
    }
}

