// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/Diamond.sol";
import "../../src/facets/DiamondCutFacet.sol";
import "../../src/facets/DiamondLoupeFacet.sol";
import "../../src/facets/OwnershipFacet.sol";
import "../../src/facets/ERC20Facet.sol";
import "../../src/facets/StakingFacet.sol";
import "../../src/facets/RewardFacet.sol";
import "../../src/interfaces/IERC20.sol";
import "../../src/interfaces/IStaking.sol";
import "../helpers/DiamondUtils.sol";

contract ERC20StakingTest is DiamondUtils {
    Diamond diamond;
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

    function addFacets() internal {
        // ... (Same facet adding logic as in previous setup)
        // Refer to the earlier deployDiamond.t.sol implementation
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