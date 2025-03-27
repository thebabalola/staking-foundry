// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/Diamond.sol";
import "src/facets/DiamondCutFacet.sol";
import "src/facets/DiamondLoupeFacet.sol";
import "src/facets/OwnershipFacet.sol";
import "src/facets/ERC20Facet.sol";
import "src/facets/StakingFacet.sol";
import "src/facets/RewardFacet.sol";
import "src/interfaces/IERC20.sol";
import "src/interfaces/IStaking.sol";
import "../helpers/DiamondUtils.sol";

contract ERC20StakingTest is DiamondUtils {
    // Diamond diamond;
    address user1 = address(1);
    address token1 = address(2);
    uint256 initialAmount = 1000 ether;

    function setUp() public {
        // Deploy and initialize diamond
        DiamondCutFacet dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        
        // Add all facets
        addFacets();
        
        // Setup test token
        mockERC20(token1, user1, initialAmount);
    }

    function addFacets() internal override {
        // Deploy all facets
        DiamondLoupeFacet dLoupe = new DiamondLoupeFacet();
        OwnershipFacet ownerF = new OwnershipFacet();
        ERC20Facet erc20F = new ERC20Facet();
        StakingFacet stakingF = new StakingFacet();
        RewardFacet rewardF = new RewardFacet();

        // Build cut struct
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](5);
        
        // Add DiamondLoupeFacet
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(dLoupe),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondLoupeFacet")
        });
        
        // Add OwnershipFacet
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(ownerF),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("OwnershipFacet")
        });
        
        // Add ERC20Facet
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(erc20F),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("ERC20Facet")
        });
        
        // Add StakingFacet
        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(stakingF),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("StakingFacet")
        });
        
        // Add RewardFacet
        cut[4] = IDiamondCut.FacetCut({
            facetAddress: address(rewardF),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("RewardFacet")
        });
        
        // Perform diamond cut
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function testStakeERC20() public {
        vm.startPrank(user1);
        
        // Approve and stake
        IERC20(token1).approve(address(diamond), 100 ether);
        IStaking(address(diamond)).stakeERC20(token1, 100 ether);
        
        // Verify stake
        uint256 staked = IStaking(address(diamond)).getStakedERC20(user1, token1);
        assertEq(staked, 100 ether, "Staked amount mismatch");
        
        // Check rewards after time passes
        vm.warp(block.timestamp + 1 days);
        uint256 earned = IStaking(address(diamond)).earned(user1);
        assertGt(earned, 0, "No rewards earned");
        
        // Claim rewards
        IStaking(address(diamond)).claimReward();
        uint256 balance = IERC20(address(diamond)).balanceOf(user1);
        assertEq(balance, earned, "Reward claim failed");
        
        vm.stopPrank();
    }

    function testUnstakeERC20() public {
        vm.startPrank(user1);
        
        // Stake first
        IERC20(token1).approve(address(diamond), 100 ether);
        IStaking(address(diamond)).stakeERC20(token1, 100 ether);
        
        // Unstake
        IStaking(address(diamond)).unstakeERC20(token1, 50 ether);
        
        // Verify
        uint256 staked = IStaking(address(diamond)).getStakedERC20(user1, token1);
        assertEq(staked, 50 ether, "Unstake failed");
        
        vm.stopPrank();
    }
}