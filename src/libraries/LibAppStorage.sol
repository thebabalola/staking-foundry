// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC20.sol";
import "../interfaces/IERC721.sol";
import "../interfaces/IERC1155.sol";
import "./LibDiamond.sol"; // Import LibDiamond instead of defining it here

// Staking related structs
struct StakedERC20 {
    address tokenAddress;
    uint256 amount;
    uint256 stakedAt;
}

struct StakedERC721 {
    address tokenAddress;
    uint256 tokenId;
    uint256 stakedAt;
}

struct StakedERC1155 {
    address tokenAddress;
    uint256 tokenId;
    uint256 amount;
    uint256 stakedAt;
}

// App storage
struct AppStorage {
    // Diamond token (ERC20) properties
    string name;
    string symbol;
    uint8 decimals;
    uint256 totalSupply;
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;
    
    // Staking properties
    uint256 rewardRate; // Rewards per second per token staked
    uint256 decayRate; // Rate at which rewards decrease over time (in basis points)
    uint256 minimumStakingPeriod; // Minimum time tokens must be staked (in seconds)
    
    // ERC20 staking
    mapping(address => StakedERC20[]) stakedERC20s;
    mapping(address => uint256) totalERC20StakedByUser;
    mapping(address => uint256) erc20RewardDebt;
    
    // ERC721 staking
    mapping(address => StakedERC721[]) stakedERC721s;
    mapping(address => uint256) totalERC721StakedByUser;
    mapping(address => uint256) erc721RewardDebt;
    
    // ERC1155 staking
    mapping(address => StakedERC1155[]) stakedERC1155s;
    mapping(address => uint256) totalERC1155StakedByUser;
    mapping(address => uint256) erc1155RewardDebt;
    
    // Contract owner
    address contractOwner;
}

library LibAppStorage {
    function diamondStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}

