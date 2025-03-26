// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, LibAppStorage} from "./libraries/LibAppStorage.sol";
import {IDiamondCut} from "./interfaces/IDiamondCut.sol";

contract Diamond {
    AppStorage internal s;

    constructor(address _contractOwner, address _diamondCutFacet) payable {
        LibAppStorage.setContractOwner(_contractOwner);

        // Add the diamondCut external function from the diamondCutFacet
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IDiamondCut.diamondCut.selector;
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: _diamondCutFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
        LibAppStorage.diamondCut(cut, address(0), new bytes(0));

        // Initialize the diamond token
        s.name = "Staking Diamond Token";
        s.symbol = "SDT";
        s.decimals = 18;
        
        // Initialize staking parameters
        s.baseRewardRate = 1e15; // 0.001 tokens per second (scaled by 1e18)
        s.erc20RewardMultiplier = 1e18; // 1.0 (scaled by 1e18)
        s.erc721RewardMultiplier = 5e18; // 5.0 (scaled by 1e18)
        s.erc1155RewardMultiplier = 2e18; // 2.0 (scaled by 1e18)
        s.decayRate = 1e17; // 0.1 (scaled by 1e18) - bonus per second of staking
        s.minStakingPeriod = 1 days; // Minimum staking period of 1 day
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable {
        address facet = s.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Diamond: Function does not exist");
        
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    receive() external payable {}
}

