// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IDiamondLoupe.sol";
import "../interfaces/IERC165.sol";
import "../libraries/LibDiamond.sol";

contract DiamondLoupeFacet is IDiamondLoupe, IERC165 {
    // Diamond Loupe Functions
    ////////////////////////////////////////////////////////////////////
    /// These functions are expected to be called frequently by tools.
    //
    // struct DiamondStorage {
    //     // maps function selectors to the facets that execute the functions
    //     // and maps the selectors to their position in the selectorSlots array
    //     // func selector => (facet address, selector position)
    //     mapping(bytes4 => bytes32) facets;
    //     // array of slots of function selectors
    //     // each slot holds 8 function selectors
    //     mapping(uint256 => bytes32) selectorSlots;
    //     // total number of selectors
    //     uint16 selectorCount;
    //     // used to query if a contract implements an interface
    //     // used to implement ERC-165
    //     mapping(bytes4 => bool) supportedInterfaces;
    //     // owner of the contract
    //     address contractOwner;
    // }

    function facets() external view override returns (Facet[] memory facets_) {
        DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint16 selectorCount = ds.selectorCount;
        // create an array set to the maximum potential size
        facets_ = new Facet[](selectorCount);
        // create an array for counting the number of selectors for each facet
        uint16[] memory numFacetSelectors = new uint16[](selectorCount);
        // total number of facets
        uint256 numFacets;
        // loop through function selectors
        for (uint256 slotIndex; selectorCount > 0; slotIndex++) {
            bytes32 slot = ds.selectorSlots[slotIndex];
            for (uint256 selectorIndex; selectorIndex < 8; selectorIndex++) {
                selectorCount--;
                if (selectorCount == 0) {
                    break;
                }
                bytes4 selector = bytes4(slot << (selectorIndex << 5));
                address facetAddr = address(bytes20(ds.facets[selector])); // Renamed variable
                bool continueLoop = false;
                // find the functionSelectors array for selector and add selector to it
                for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
                    if (facets_[facetIndex].facetAddress == facetAddr) { // Updated reference
                        facets_[facetIndex].functionSelectors[numFacetSelectors[facetIndex]] = selector;
                        numFacetSelectors[facetIndex]++;
                        continueLoop = true;
                        break;
                    }
                }
                // create a new functionSelectors array for selector
                if (!continueLoop) {
                    facets_[numFacets].facetAddress = facetAddr; // Updated reference
                    facets_[numFacets].functionSelectors = new bytes4[](selectorCount);
                    facets_[numFacets].functionSelectors[0] = selector;
                    numFacetSelectors[numFacets] = 1;
                    numFacets++;
                }
            }
        }
        // resize the facets array to the actual number of facets
        assembly {
            mstore(facets_, numFacets)
        }
        // resize the functionSelectors arrays to the actual number of selectors
        for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
            assembly {
                let functionSelectors := mload(add(mload(add(facets_, mul(add(facetIndex, 1), 32))), 32))
                mstore(functionSelectors, mload(add(numFacetSelectors, mul(add(facetIndex, 1), 32))))
            }
        }
    }

    function facetFunctionSelectors(address _facet) external view override returns (bytes4[] memory facetFunctionSelectors_) {
        DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint16 selectorCount = ds.selectorCount;
        // create an array set to the maximum potential size
        facetFunctionSelectors_ = new bytes4[](selectorCount);
        // total number of selectors
        uint256 numSelectors;
        // loop through function selectors
        for (uint256 slotIndex; selectorCount > 0; slotIndex++) {
            bytes32 slot = ds.selectorSlots[slotIndex];
            for (uint256 selectorIndex; selectorIndex < 8; selectorIndex++) {
                selectorCount--;
                if (selectorCount == 0) {
                    break;
                }
                bytes4 selector = bytes4(slot << (selectorIndex << 5));
                address facetAddr = address(bytes20(ds.facets[selector])); // Renamed variable
                if (_facet == facetAddr) { // Updated reference
                    facetFunctionSelectors_[numSelectors] = selector;
                    numSelectors++;
                }
            }
        }
        // resize the array to the actual number of selectors
        assembly {
            mstore(facetFunctionSelectors_, numSelectors)
        }
    }

    function facetAddresses() external view override returns (address[] memory facetAddresses_) {
        DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint16 selectorCount = ds.selectorCount;
        // create an array set to the maximum potential size
        facetAddresses_ = new address[](selectorCount);
        // total number of facets
        uint256 numFacets;
        // loop through function selectors
        for (uint256 slotIndex; selectorCount > 0; slotIndex++) {
            bytes32 slot = ds.selectorSlots[slotIndex];
            for (uint256 selectorIndex; selectorIndex < 8; selectorIndex++) {
                selectorCount--;
                if (selectorCount == 0) {
                    break;
                }
                bytes4 selector = bytes4(slot << (selectorIndex << 5));
                address facetAddr = address(bytes20(ds.facets[selector])); // Renamed variable
                bool continueLoop = false;
                // see if we have collected the address already
                for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
                    if (facetAddr == facetAddresses_[facetIndex]) { // Updated reference
                        continueLoop = true;
                        break;
                    }
                }
                // add the address
                if (!continueLoop) {
                    facetAddresses_[numFacets] = facetAddr; // Updated reference
                    numFacets++;
                }
            }
        }
        // resize the array to the actual number of facets
        assembly {
            mstore(facetAddresses_, numFacets)
        }
    }

    function facetAddress(bytes4 _functionSelector) external view override returns (address facetAddress_) {
        DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetAddress_ = address(bytes20(ds.facets[_functionSelector]));
    }

    function supportsInterface(bytes4 _interfaceId) external view override returns (bool) {
        DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.supportedInterfaces[_interfaceId];
    }
}

