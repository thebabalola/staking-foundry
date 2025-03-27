// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "src/Diamond.sol";
import "src/facets/DiamondCutFacet.sol";
import "src/facets/DiamondLoupeFacet.sol";
import "src/facets/OwnershipFacet.sol";
import "src/facets/ERC20Facet.sol";
import "src/facets/ERC1155Facet.sol";
import "src/facets/StakingFacet.sol";
import "src/facets/RewardFacet.sol";
import "src/interfaces/IERC1155.sol";
import "src/interfaces/IStaking.sol";
import "../helpers/DiamondUtils.sol";

contract ERC1155StakingTest is DiamondUtils {
    // Diamond diamond;
    address user1 = address(1);
    address token1 = address(4);
    uint256 tokenId1 = 1;
    uint256 amount = 10;

    function debugGenerateSelectors(string memory facetName) public {
        bytes4[] memory selectors = generateSelectors(facetName);
        console.log("Selectors for %s:", facetName);
        for (uint i = 0; i < selectors.length; i++) {
            console.logBytes4(selectors[i]);
        }
    }

    function setUp() public {
        DiamondCutFacet dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet)); // Uses inherited variable
        addFacets();
        
        mockERC1155(token1, user1, tokenId1, amount);
    }
    
    function addFacets() internal override {
        // Deploy all facets
        address[6] memory facets = [
            address(new DiamondLoupeFacet()),
            address(new OwnershipFacet()),
            address(new ERC20Facet()),
            address(new ERC1155Facet()),
            address(new StakingFacet()),
            address(new RewardFacet())
        ];
        
        string[6] memory facetNames = [
            "DiamondLoupeFacet",
            "OwnershipFacet",
            "ERC20Facet",
            "ERC1155Facet",
            "StakingFacet",
            "RewardFacet"
        ];

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](6);
        
        for (uint i = 0; i < facets.length; i++) {
            bytes4[] memory selectors = generateSelectors(facetNames[i]);
            require(selectors.length > 0, string(abi.encodePacked("No selectors found for ", facetNames[i])));
            
            cut[i] = IDiamondCut.FacetCut({
                facetAddress: facets[i],
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: selectors
            });
        }
        
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function testDebugSelectors() public {
        debugGenerateSelectors("DiamondLoupeFacet");
        debugGenerateSelectors("OwnershipFacet");
        debugGenerateSelectors("ERC20Facet"); 
        debugGenerateSelectors("ERC1155Facet");
        debugGenerateSelectors("StakingFacet");
        debugGenerateSelectors("RewardFacet");
    }

    function testStakeERC1155() public {
        vm.startPrank(user1);
        
        IERC1155(token1).setApprovalForAll(address(diamond), true);
        IStaking(address(diamond)).stakeERC1155(token1, tokenId1, 5);
        
        uint256 staked = IStaking(address(diamond)).getStakedERC1155(user1, token1, tokenId1);
        assertEq(staked, 5, "Stake amount mismatch");
        
        vm.warp(block.timestamp + 1 days);
        uint256 earned = IStaking(address(diamond)).earned(user1);
        assertGt(earned, 0, "No rewards earned");
        
        vm.stopPrank();
    }
}