// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/Diamond.sol";
import "../../src/facets/DiamondCutFacet.sol";
import "../../src/facets/DiamondLoupeFacet.sol";
import "../../src/facets/OwnershipFacet.sol";
import "../../src/facets/ERC20Facet.sol";
import "../../src/facets/ERC721Facet.sol";
import "../../src/facets/ERC1155Facet.sol";
import "../../src/facets/StakingFacet.sol";
import "../../src/facets/RewardFacet.sol";
// import "../helpers/DiamondUtils.sol";
import "./helpers/DiamondUtils.sol";

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    Diamond diamond;
    
    function testDeployDiamond() public {
        // Deploy all facets
        DiamondCutFacet dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        
        // Add all facets
        addAllFacets();
        
        // Verify deployment
        (bool success,) = address(diamond).call(abi.encodeWithSignature("owner()"));
        assertTrue(success, "Diamond deployment failed");
    }

    function addAllFacets() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](7);
        
        // Add DiamondLoupeFacet
        cut[0] = FacetCut({
            facetAddress: address(new DiamondLoupeFacet()),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondLoupeFacet")
        });
        
        // Add OwnershipFacet
        cut[1] = FacetCut({
            facetAddress: address(new OwnershipFacet()),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("OwnershipFacet")
        });
        
        // Add ERC20Facet
        cut[2] = FacetCut({
            facetAddress: address(new ERC20Facet()),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("ERC20Facet")
        });
        
        // Add ERC721Facet
        cut[3] = FacetCut({
            facetAddress: address(new ERC721Facet()),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("ERC721Facet")
        });
        
        // Add ERC1155Facet
        cut[4] = FacetCut({
            facetAddress: address(new ERC1155Facet()),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("ERC1155Facet")
        });
        
        // Add StakingFacet
        cut[5] = FacetCut({
            facetAddress: address(new StakingFacet()),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("StakingFacet")
        });
        
        // Add RewardFacet
        cut[6] = FacetCut({
            facetAddress: address(new RewardFacet()),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("RewardFacet")
        });
        
        // Perform diamond cut
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function diamondCut(FacetCut[] calldata, address, bytes calldata) external override {}
}