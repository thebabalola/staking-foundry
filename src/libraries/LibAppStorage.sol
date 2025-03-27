// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Stake
 * @dev Struct to track staking information
 */
struct Stake {
    uint256 amount;
    uint256 timestamp;
}

/**
 * @title AppStorage
 * @dev Central storage layout for the diamond contract using EIP-2535 Diamond Standard
 */
struct AppStorage {
    // ============ ERC20 ============
    string name;
    string symbol;
    uint8 decimals;
    uint256 totalSupply;
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;

    // ============ ERC721 ============
    mapping(address => uint256) erc721Balances;
    mapping(uint256 => address) erc721Owners;
    mapping(address => mapping(address => bool)) erc721OperatorApprovals;
    mapping(uint256 => address) erc721TokenApprovals;

    // ============ ERC1155 ============
    mapping(address => mapping(uint256 => uint256)) erc1155Balances;
    mapping(address => mapping(address => bool)) erc1155OperatorApprovals;
    
    // ============ Staking ============
    // ERC20 Staking
    mapping(address => mapping(address => uint256)) erc20Stakes;
    
    // ERC721 Staking
    mapping(address => mapping(address => mapping(uint256 => Stake))) erc721Stakes;
    mapping(address => mapping(address => uint256[])) erc721StakedTokens;
    
    // ERC1155 Staking
    mapping(address => mapping(address => mapping(uint256 => Stake))) erc1155Stakes;
    mapping(address => mapping(address => uint256[])) erc1155StakedTokens;

    // ============ Rewards ============
    uint256 rewardRate;
    uint256 decayRate;
    uint256 lastUpdateTime;
    uint256 rewardPerTokenStored;
    mapping(address => uint256) userRewardPerTokenPaid;
    mapping(address => uint256) rewards;
    mapping(address => uint256) rewardStartTime;
    
    // ============ Admin ============
    address feeCollector;
    uint256 stakingFee;
    mapping(address => bool) whitelistedTokens;
}

/**
 * @title LibAppStorage
 * @dev Library for accessing the AppStorage struct in a deterministic location
 */
library LibAppStorage {
    // Constant string for storage position calculation
     bytes32 constant APP_STORAGE_POSITION = keccak256("diamond.standard.app.storage");

    function diamondStorage() internal pure returns (AppStorage storage ds) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    /**
     * @dev Initializes critical storage variables
     */
    function initialize() internal {
        AppStorage storage s = diamondStorage();
        require(s.lastUpdateTime == 0, "Already initialized");
        
        // Default reward parameters
        s.rewardRate = 1e16; // 0.01 tokens per second per staked token
        s.decayRate = 1e14; // 0.01% decay per second
        s.lastUpdateTime = block.timestamp;
        
        // Default fee settings
        s.feeCollector = msg.sender;
        s.stakingFee = 5e16; // 5% fee
    }

    /**
     * @dev Updates reward parameters safely
     */
    function updateRewardParameters(uint256 newRate, uint256 newDecay) internal {
        AppStorage storage s = diamondStorage();
        require(newDecay <= 1e18, "Decay rate too high");
        
        s.rewardRate = newRate;
        s.decayRate = newDecay;
        s.lastUpdateTime = block.timestamp;
    }
}