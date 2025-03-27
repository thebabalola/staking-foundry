// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/Diamond.sol";
import "../../src/interfaces/IERC1155.sol";
import "../../src/interfaces/IStaking.sol";
import "../helpers/DiamondUtils.sol";

contract ERC1155StakingTest is DiamondUtils {
    Diamond diamond;
    address user1 = address(1);
    address token1 = address(4); // Different address for ERC1155
    uint256 tokenId1 = 1;
    uint256 amount = 10;

    function setUp() public {
        DiamondCutFacet dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        addFacets();
        
        mockERC1155(token1, user1, tokenId1, amount);
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