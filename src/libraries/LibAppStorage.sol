// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";

struct FacetAddressAndPosition {
    address facetAddress;
    uint96 functionSelectorPosition; // position in facetFunctionSelectors.functionSelectors array
}

struct FacetFunctionSelectors {
    bytes4[] functionSelectors;
    uint256 facetAddressPosition; // position of facetAddress in facetAddresses array
}

struct ERC20Stake {
    uint256 amount;
    uint256 timestamp;
}

struct ERC721Stake {
    uint256[] tokenIds;
    mapping(uint256 => uint256) tokenIdToIndex;
    mapping(uint256 => uint256) tokenIdToTimestamp;
}

struct ERC1155Stake {
    uint256[] ids;
    mapping(uint256 => uint256) idToIndex;
    mapping(uint256 => uint256) idToAmount;
    mapping(uint256 => uint256) idToTimestamp;
}

struct UserInfo {
    mapping(address => ERC20Stake) erc20Stakes;
    mapping(address => ERC721Stake) erc721Stakes;
    mapping(address => ERC1155Stake) erc1155Stakes;
    uint256 lastRewardClaim;
    uint256 pendingRewards;
}

struct AppStorage {
    // Diamond storage
    mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
    mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
    address[] facetAddresses;
    mapping(bytes4 => bool) supportedInterfaces;
    address contractOwner;
    
    // ERC20 token data
    string name;
    string symbol;
    uint8 decimals;
    uint256 totalSupply;
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;
    
    // Staking data
    mapping(address => UserInfo) userInfo;
    mapping(address => bool) supportedERC20Tokens;
    mapping(address => bool) supportedERC721Tokens;
    mapping(address => bool) supportedERC1155Tokens;
    
    // Reward parameters
    uint256 baseRewardRate; // Base reward rate per second (scaled by 1e18)
    uint256 erc20RewardMultiplier; // Multiplier for ERC20 staking rewards (scaled by 1e18)
    uint256 erc721RewardMultiplier; // Multiplier for ERC721 staking rewards (scaled by 1e18)
    uint256 erc1155RewardMultiplier; // Multiplier for ERC1155 staking rewards (scaled by 1e18)
    uint256 decayRate; // Rate at which rewards decay over time (scaled by 1e18)
    uint256 minStakingPeriod; // Minimum staking period in seconds
}

library LibAppStorage {
    function appStorage() internal pure returns (AppStorage storage s) {
        assembly {
            s.slot := 0
        }
    }
    
    // Diamond events
    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // Diamond functions
    function setContractOwner(address _newOwner) internal {
        AppStorage storage s = appStorage();
        address previousOwner = s.contractOwner;
        s.contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function contractOwner() internal view returns (address contractOwner_) {
        contractOwner_ = appStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        require(msg.sender == appStorage().contractOwner, "LibAppStorage: Not contract owner");
    }
    
    // Diamond cut functions
    function diamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else {
                revert("LibAppStorage: Incorrect FacetCutAction");
            }
        }
        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibAppStorage: No selectors in facet to cut");
        AppStorage storage s = appStorage();
        require(_facetAddress != address(0), "LibAppStorage: Add facet can't be address(0)");
        uint96 selectorPosition = uint96(s.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(s, _facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = s.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacetAddress == address(0), "LibAppStorage: Can't add function that already exists");
            addFunction(s, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibAppStorage: No selectors in facet to cut");
        AppStorage storage s = appStorage();
        require(_facetAddress != address(0), "LibAppStorage: Replace facet can't be address(0)");
        uint96 selectorPosition = uint96(s.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(s, _facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = s.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacetAddress != _facetAddress, "LibAppStorage: Can't replace function with same function");
            removeFunction(s, oldFacetAddress, selector);
            addFunction(s, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibAppStorage: No selectors in facet to cut");
        AppStorage storage s = appStorage();
        // if function does not exist then do nothing and return
        require(_facetAddress == address(0), "LibAppStorage: Remove facet address must be address(0)");
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = s.selectorToFacetAndPosition[selector].facetAddress;
            removeFunction(s, oldFacetAddress, selector);
        }
    }

    function addFacet(AppStorage storage s, address _facetAddress) internal {
        enforceHasContractCode(_facetAddress, "LibAppStorage: New facet has no code");
        s.facetFunctionSelectors[_facetAddress].facetAddressPosition = s.facetAddresses.length;
        s.facetAddresses.push(_facetAddress);
    }

    function addFunction(AppStorage storage s, bytes4 _selector, uint96 _selectorPosition, address _facetAddress) internal {
        s.selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        s.facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
        s.selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    function removeFunction(AppStorage storage s, address _facetAddress, bytes4 _selector) internal {
        require(_facetAddress != address(0), "LibAppStorage: Can't remove function that doesn't exist");
        // an immutable function is a function defined directly in a diamond
        require(_facetAddress != address(this), "LibAppStorage: Can't remove immutable function");
        // replace selector with last selector, then delete last selector
        uint256 selectorPosition = s.selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = s.facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;
        // if not the same then replace _selector with lastSelector
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = s.facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            s.facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] = lastSelector;
            s.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
        }
        // delete the last selector
        s.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete s.selectorToFacetAndPosition[_selector];

        // if no more selectors for facet address then delete the facet address
        if (lastSelectorPosition == 0) {
            // replace facet address with last facet address and delete last facet address
            uint256 lastFacetAddressPosition = s.facetAddresses.length - 1;
            uint256 facetAddressPosition = s.facetFunctionSelectors[_facetAddress].facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = s.facetAddresses[lastFacetAddressPosition];
                s.facetAddresses[facetAddressPosition] = lastFacetAddress;
                s.facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }
            s.facetAddresses.pop();
            delete s.facetFunctionSelectors[_facetAddress].facetAddressPosition;
        }
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            require(_calldata.length == 0, "LibAppStorage: _init is address(0) but_calldata is not empty");
        } else {
            require(_calldata.length > 0, "LibAppStorage: _calldata is empty but _init is not address(0)");
            if (_init != address(this)) {
                enforceHasContractCode(_init, "LibAppStorage: _init address has no code");
            }
            (bool success, bytes memory error) = _init.delegatecall(_calldata);
            if (!success) {
                if (error.length > 0) {
                    // bubble up the error
                    revert(string(error));
                } else {
                    revert("LibAppStorage: _init function reverted");
                }
            }
        }
    }

    function enforceHasContractCode(address _contract, string memory _errorMessage) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        require(contractSize > 0, _errorMessage);
    }
}

