// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IDiamondCut.sol";

// Diamond storage position
bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

struct DiamondStorage {
    // maps function selectors to the facets that execute the functions
    // and maps the selectors to their position in the selectorSlots array
    // func selector => (facet address, selector position)
    mapping(bytes4 => bytes32) facets;
    // array of slots of function selectors
    // each slot holds 8 function selectors
    mapping(uint256 => bytes32) selectorSlots;
    // total number of selectors
    uint16 selectorCount;
    // used to query if a contract implements an interface
    // used to implement ERC-165
    mapping(bytes4 => bool) supportedInterfaces;
    // owner of the contract
    address contractOwner;
}

library LibDiamond {
    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);
    event DiamondEvent(string message, address sender, uint value);

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        ds.contractOwner = _newOwner;
    }

    function contractOwner() internal view returns (address) {
        DiamondStorage storage ds = diamondStorage();
        return ds.contractOwner;
    }

    function enforceIsContractOwner() internal view {
        require(msg.sender == contractOwner(), "LibDiamond: Must be contract owner");
    }

    // Internal function version of diamondCut
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
                revert("LibDiamondCut: Incorrect FacetCutAction");
            }
        }
        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        DiamondStorage storage ds = diamondStorage();
        require(_facetAddress != address(0), "LibDiamondCut: Add facet can't be address(0)");
        uint16 selectorCount = ds.selectorCount;
        // Check if facet address already exists
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = address(bytes20(ds.facets[selector]));
            require(oldFacetAddress == address(0), "LibDiamondCut: Can't add function that already exists");
            // Store facet address and selector position
            ds.facets[selector] = bytes32(uint256(uint160(_facetAddress)) << 96) | bytes32(uint256(selectorCount));
            selectorCount++;
        }
        ds.selectorCount = selectorCount;
    }

    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        DiamondStorage storage ds = diamondStorage();
        require(_facetAddress != address(0), "LibDiamondCut: Replace facet can't be address(0)");
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = address(bytes20(ds.facets[selector]));
            // Can't replace immutable functions -- functions defined directly in the diamond
            require(oldFacetAddress != address(this), "LibDiamondCut: Can't replace immutable function");
            require(oldFacetAddress != _facetAddress, "LibDiamondCut: Can't replace function with same function");
            require(oldFacetAddress != address(0), "LibDiamondCut: Can't replace function that doesn't exist");
            // Replace old facet address
            uint256 selectorPosition = uint256(ds.facets[selector]) & 0xFFFFFFFFFFFFFFFFFFFFFFFF;
            ds.facets[selector] = bytes32(uint256(uint160(_facetAddress)) << 96) | bytes32(selectorPosition);
        }
    }

    function removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        DiamondStorage storage ds = diamondStorage();
        // If facet address is address(0), remove all function selectors
        if (_facetAddress == address(0)) {
            for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
                bytes4 selector = _functionSelectors[selectorIndex];
                address oldFacetAddress = address(bytes20(ds.facets[selector]));
                require(oldFacetAddress != address(0), "LibDiamondCut: Can't remove function that doesn't exist");
                require(oldFacetAddress != address(this), "LibDiamondCut: Can't remove immutable function");
                // Remove the selector
                ds.facets[selector] = 0;
            }
        } else {
            // If facet address is not address(0), ensure it matches the stored facet address
            for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
                bytes4 selector = _functionSelectors[selectorIndex];
                address oldFacetAddress = address(bytes20(ds.facets[selector]));
                require(oldFacetAddress == _facetAddress, "LibDiamondCut: Function facet address doesn't match facet address");
                // Remove the selector
                ds.facets[selector] = 0;
            }
        }
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            require(_calldata.length == 0, "LibDiamondCut: _init is address(0) but_calldata is not empty");
        } else {
            require(_calldata.length > 0, "LibDiamondCut: _calldata is empty but _init is not address(0)");
            if (_init != address(this)) {
                (bool success, bytes memory error) = _init.delegatecall(_calldata);
                if (!success) {
                    if (error.length > 0) {
                        // bubble up the error
                        revert(string(error));
                    } else {
                        revert("LibDiamondCut: _init function reverted");
                    }
                }
            } else {
                (bool success, bytes memory error) = address(this).call(_calldata);
                if (!success) {
                    if (error.length > 0) {
                        // bubble up the error
                        revert(string(error));
                    } else {
                        revert("LibDiamondCut: _init function reverted");
                    }
                }
            }
        }
    }
}

