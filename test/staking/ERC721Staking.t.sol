// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../helpers/DiamondUtils.sol";
import "src/interfaces/IERC721.sol";
import "src/interfaces/IStaking.sol";

import "src/Diamond.sol";
import "src/facets/DiamondCutFacet.sol"; 

contract ERC721StakingTest is DiamondUtils {
    address user1 = address(1);
    address token1 = address(3);
    uint256 tokenId1 = 1;

    function setUp() public {
        DiamondCutFacet dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        
        addFacets();
        mockERC721(token1, user1, tokenId1);
    }

    function testStakeERC721() public {
        vm.startPrank(user1);
        
        IERC721(token1).approve(address(diamond), tokenId1);
        IStaking(address(diamond)).stakeERC721(token1, tokenId1);
        
        uint256[] memory staked = IStaking(address(diamond)).getStakedERC721Tokens(user1, token1);
        assertEq(staked.length, 1, "NFT not staked");
        assertEq(staked[0], tokenId1, "Wrong tokenId staked");
        
        vm.warp(block.timestamp + 1 days);
        uint256 earned = IStaking(address(diamond)).earned(user1);
        assertGt(earned, 0, "No rewards earned");
        
        vm.stopPrank();
    }
}