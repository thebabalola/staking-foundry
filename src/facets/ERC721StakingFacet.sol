// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, LibAppStorage, ERC721Stake, UserInfo} from "../libraries/LibAppStorage.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {IStakingDiamond} from "../interfaces/IStakingDiamond.sol";

contract ERC721StakingFacet {
    AppStorage internal s;

    event ERC721Staked(address indexed user, address indexed token, uint256 tokenId);
    event ERC721Unstaked(address indexed user, address indexed token, uint256 tokenId);
    event SupportedERC721TokenAdded(address indexed token);
    event SupportedERC721TokenRemoved(address indexed token);

    modifier onlySupportedERC721(address token) {
        require(s.supportedERC721Tokens[token], "ERC721StakingFacet: Token not supported");
        _;
    }

    function addSupportedERC721Token(address token) external {
        LibAppStorage.enforceIsContractOwner();
        require(token != address(0), "ERC721StakingFacet: Cannot add zero address");
        require(!s.supportedERC721Tokens[token], "ERC721StakingFacet: Token already supported");
        
        s.supportedERC721Tokens[token] = true;
        emit SupportedERC721TokenAdded(token);
    }

    function removeSupportedERC721Token(address token) external {
        LibAppStorage.enforceIsContractOwner();
        require(s.supportedERC721Tokens[token], "ERC721StakingFacet: Token not supported");
        
        s.supportedERC721Tokens[token] = false;
        emit SupportedERC721TokenRemoved(token);
    }

    function isSupportedERC721Token(address token) external view returns (bool) {
        return s.supportedERC721Tokens[token];
    }

    function stakeERC721(address token, uint256 tokenId) external onlySupportedERC721(token) {
        // Transfer NFT from user to contract
        IERC721(token).transferFrom(msg.sender, address(this), tokenId);
        
        // Update user's staking info
        UserInfo storage userInfo = s.userInfo[msg.sender];
        ERC721Stake storage stake = userInfo.erc721Stakes[token];
        
        // Check if token is already staked
        require(stake.tokenIdToIndex[tokenId] == 0, "ERC721StakingFacet: Token already staked");
        
        // Add token to staked tokens
        stake.tokenIds.push(tokenId);
        stake.tokenIdToIndex[tokenId] = stake.tokenIds.length;
        stake.tokenIdToTimestamp[tokenId] = block.timestamp;
        
        // Update last reward claim time if it's the first stake
        if (userInfo.lastRewardClaim == 0) {
            userInfo.lastRewardClaim = block.timestamp;
        }
        
        emit ERC721Staked(msg.sender, token, tokenId);
    }

    function unstakeERC721(address token, uint256 tokenId) external onlySupportedERC721(token) {
        UserInfo storage userInfo = s.userInfo[msg.sender];
        ERC721Stake storage stake = userInfo.erc721Stakes[token];
        
        // Check if token is staked
        uint256 index = stake.tokenIdToIndex[tokenId];
        require(index > 0, "ERC721StakingFacet: Token not staked");
        
        // Check minimum staking period
        require(
            block.timestamp - stake.tokenIdToTimestamp[tokenId] >= s.minStakingPeriod,
            "ERC721StakingFacet: Minimum staking period not reached"
        );
        
        // Remove token from staked tokens (swap and pop)
        uint256 lastIndex = stake.tokenIds.length;
        if (index < lastIndex) {
            uint256 lastTokenId = stake.tokenIds[lastIndex - 1];
            stake.tokenIds[index - 1] = lastTokenId;
            stake.tokenIdToIndex[lastTokenId] = index;
        }
        
        stake.tokenIds.pop();
        delete stake.tokenIdToIndex[tokenId];
        delete stake.tokenIdToTimestamp[tokenId];
        
        // Transfer NFT back to user
        IERC721(token).transferFrom(address(this), msg.sender, tokenId);
        
        emit ERC721Unstaked(msg.sender, token, tokenId);
    }

    function getERC721StakedTokens(address user, address token) external view returns (uint256[] memory) {
        return s.userInfo[user].erc721Stakes[token].tokenIds;
    }

    function getERC721StakeTimestamp(address user, address token, uint256 tokenId) external view returns (uint256) {
        return s.userInfo[user].erc721Stakes[token].tokenIdToTimestamp[tokenId];
    }
}

