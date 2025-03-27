// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IDiamondCut.sol";
import "./interfaces/IDiamondLoupe.sol";
import "./interfaces/IERC173.sol";
import "./interfaces/IERC165.sol";
import "./libraries/LibDiamond.sol";
import "./libraries/LibAppStorage.sol";

contract Diamond {
    AppStorage internal s;

    constructor(address _contractOwner, address _diamondCutFacet) payable {
        require(_contractOwner != address(0), "Diamond: owner can't be address(0)");
        require(_diamondCutFacet != address(0), "Diamond: diamondCutFacet can't be address(0)");
        
        LibDiamond.setContractOwner(_contractOwner);
        
        // Add the diamondCut external function from the diamondCutFacet
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IDiamondCut.diamondCut.selector;
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: _diamondCutFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
        LibDiamond.diamondCut(cut, address(0), new bytes(0));
        
        // Initialize AppStorage
        s.contractOwner = _contractOwner;
        
        // Add ERC165 data
        DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable {
        DiamondStorage storage ds = LibDiamond.diamondStorage();
        
        // get facet from function selector
        address facet = address(bytes20(ds.facets[msg.sig]));
        require(facet != address(0), "Diamond: Function does not exist");
        
        // Execute external function from facet using delegatecall
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
                case 0 {
                    revert(0, returndatasize())
                }
                default {
                    return(0, returndatasize())
                }
        }
    }

    receive() external payable {
        // If we receive Ether, emit an event
        emit LibDiamond.DiamondEvent("Diamond received Ether", msg.sender, msg.value);
    }
}

