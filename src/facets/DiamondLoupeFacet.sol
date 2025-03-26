// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, LibAppStorage, FacetAddressAndPosition} from "../libraries/LibAppStorage.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IERC165} from "../interfaces/IERC165.sol";

contract DiamondLoupeFacet is IDiamondLoupe, IERC165 {
    AppStorage internal s;

    // Diamond Loupe Functions
    ////////////////////////////////////////////////////////////////////
    /// These functions are expected to be called frequently by tools.
    //
    // struct Facet {
    //     address facetAddress;
    //     bytes4[] functionSelectors;
    // }

    /// @notice Gets all facets and their selectors.
    /// @return facets_ Facet
    function facets() external view override returns (Facet[] memory facets_) {
        uint256 numFacets = s.facetAddresses.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i; i < numFacets; i++) {
            address facetAddress_ = s.facetAddresses[i];
            facets_[i].facetAddress = facetAddress_;
            facets_[i].functionSelectors = s.facetFunctionSelectors[facetAddress_].functionSelectors;
        }
    }

    /// @notice Gets all the function selectors provided by a facet.
    /// @param _facet The facet address.
    /// @return facetFunctionSelectors_
    function facetFunctionSelectors(address _facet) external view override returns (bytes4[] memory facetFunctionSelectors_) {
        facetFunctionSelectors_ = s.facetFunctionSelectors[_facet].functionSelectors;
    }

    /// @notice Get all the facet addresses used by a diamond.
    /// @return facetAddresses_
    function facetAddresses() external view override returns (address[] memory facetAddresses_) {
        facetAddresses_ = s.facetAddresses;
    }

    /// @notice Gets the facet that supports the given selector.
    /// @param _functionSelector The function selector.
    /// @return facetAddress_ The facet address.
    function facetAddress(bytes4 _functionSelector) external view override returns (address facetAddress_) {
        facetAddress_ = s.selectorToFacetAndPosition[_functionSelector].facetAddress;
    }

    // This implements ERC-165.
    function supportsInterface(bytes4 _interfaceId) external view override returns (bool) {
        return s.supportedInterfaces[_interfaceId];
    }
}

