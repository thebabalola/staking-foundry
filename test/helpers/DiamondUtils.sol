// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/interfaces/IDiamondCut.sol";
import "../../src/interfaces/IDiamondLoupe.sol";
import "../../src/interfaces/IERC173.sol";
import "../../src/interfaces/IERC165.sol";
import "../../src/facets/DiamondCutFacet.sol";
import "../../src/facets/DiamondLoupeFacet.sol";
import "../../src/facets/OwnershipFacet.sol";
import "../../src/libraries/LibDiamond.sol";
import "../../src/libraries/LibAppStorage.sol";
import "../../src/Diamond.sol";
import "../../src/upgradeInitializers/DiamondInit.sol";

// Make DiamondUtils inherit from Test
abstract contract DiamondUtils is Test {
  // Diamond facet addresses
  DiamondCutFacet dCutFacet;
  DiamondLoupeFacet dLoupe;
  OwnershipFacet ownerF;
  
  // Diamond address
  Diamond diamond;
  
  // Diamond interfaces
  IDiamondCut cut;
  IDiamondLoupe loupe;
  IERC173 ownership;
  
  // Test addresses
  address owner = address(0x1234);
  address user1 = address(0x5678);
  address user2 = address(0x9ABC);
  
  // Helper function to check for duplicate selectors
  function checkForDuplicateSelectors(bytes4[][] memory allSelectors) internal pure {
      // Create a mapping to track which selectors we've seen
      bytes4[] memory seenSelectors = new bytes4[](1000); // Arbitrary large size
      uint256 count = 0;
      
      for (uint256 i = 0; i < allSelectors.length; i++) {
          bytes4[] memory facetSelectors = allSelectors[i];
          
          for (uint256 j = 0; j < facetSelectors.length; j++) {
              bytes4 selector = facetSelectors[j];
              
              // Check if we've seen this selector before
              for (uint256 k = 0; k < count; k++) {
                  if (seenSelectors[k] == selector) {
                      revert(string(abi.encodePacked(
                          "Duplicate selector found: ", 
                          bytes32(selector)
                      )));
                  }
              }
              
              // Add this selector to our seen list
              seenSelectors[count] = selector;
              count++;
          }
      }
  }
  
  function deployDiamond() internal {
      // Deploy DiamondCutFacet
      dCutFacet = new DiamondCutFacet();
      
      // Deploy Diamond
      diamond = new Diamond(owner, address(dCutFacet));
      
      // Deploy facets
      dLoupe = new DiamondLoupeFacet();
      ownerF = new OwnershipFacet();
      
      // Setup interfaces
      cut = IDiamondCut(address(diamond));
      loupe = IDiamondLoupe(address(diamond));
      ownership = IERC173(address(diamond));
      
      // Add facets
      IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](2);
      
      // Add DiamondLoupeFacet
      bytes4[] memory loupeSelectors = new bytes4[](5);
      loupeSelectors[0] = IDiamondLoupe.facets.selector;
      loupeSelectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
      loupeSelectors[2] = IDiamondLoupe.facetAddresses.selector;
      loupeSelectors[3] = IDiamondLoupe.facetAddress.selector;
      loupeSelectors[4] = IERC165.supportsInterface.selector;
      
      cuts[0] = IDiamondCut.FacetCut({
          facetAddress: address(dLoupe),
          action: IDiamondCut.FacetCutAction.Add,
          functionSelectors: loupeSelectors
      });
      
      // Add OwnershipFacet
      bytes4[] memory ownershipSelectors = new bytes4[](2);
      ownershipSelectors[0] = IERC173.owner.selector;
      ownershipSelectors[1] = IERC173.transferOwnership.selector;
      
      cuts[1] = IDiamondCut.FacetCut({
          facetAddress: address(ownerF),
          action: IDiamondCut.FacetCutAction.Add,
          functionSelectors: ownershipSelectors
      });
      
      // Execute cut with owner
      vm.startPrank(owner);
      cut.diamondCut(cuts, address(0), new bytes(0));
      vm.stopPrank();
  }
  
  function addFacets(address[] memory facetAddresses, bytes4[][] memory selectors) internal {
      require(facetAddresses.length == selectors.length, "Facet and selector arrays must be same length");
      
      // Check for duplicate selectors before adding
      checkForDuplicateSelectors(selectors);
      
      // Also check for duplicates with existing selectors
      if (address(loupe) != address(0)) {
          address[] memory existingFacets = loupe.facetAddresses();
          for (uint256 i = 0; i < existingFacets.length; i++) {
              bytes4[] memory existingSelectors = loupe.facetFunctionSelectors(existingFacets[i]);
              for (uint256 j = 0; j < selectors.length; j++) {
                  for (uint256 k = 0; k < selectors[j].length; k++) {
                      for (uint256 l = 0; l < existingSelectors.length; l++) {
                          if (selectors[j][k] == existingSelectors[l]) {
                              revert(string(abi.encodePacked(
                                  "Selector already exists in diamond: ", 
                                  bytes32(selectors[j][k])
                              )));
                          }
                      }
                  }
              }
          }
      }
      
      IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](facetAddresses.length);
      
      for (uint i = 0; i < facetAddresses.length; i++) {
          cuts[i] = IDiamondCut.FacetCut({
              facetAddress: facetAddresses[i],
              action: IDiamondCut.FacetCutAction.Add,
              functionSelectors: selectors[i]
          });
      }
      
      vm.startPrank(owner);
      cut.diamondCut(cuts, address(0), new bytes(0));
      vm.stopPrank();
  }
  
  function initializeDiamond(address initContract, bytes memory initData) internal {
      vm.startPrank(owner);
      IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);
      cut.diamondCut(cuts, initContract, initData);
      vm.stopPrank();
  }
}

