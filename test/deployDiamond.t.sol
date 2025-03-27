// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./helpers/DiamondUtils.sol";
import "../src/facets/ERC20Facet.sol";
import "../src/facets/StakingFacet.sol";
import "../src/facets/RewardFacet.sol";
import "../src/upgradeInitializers/DiamondInit.sol";

// Fix the inheritance order - Test should come first
contract DiamondDeployer is Test, DiamondUtils {
  ERC20Facet erc20Facet;
  StakingFacet stakingFacet;
  RewardFacet rewardFacet;
  DiamondInit diamondInit;
  
  function setUp() public {
      // Deploy base diamond
      deployDiamond();
      
      // Deploy additional facets
      erc20Facet = new ERC20Facet();
      stakingFacet = new StakingFacet();
      rewardFacet = new RewardFacet();
      diamondInit = new DiamondInit();
      
      // Add facets to diamond
      address[] memory facetAddresses = new address[](3);
      facetAddresses[0] = address(erc20Facet);
      facetAddresses[1] = address(stakingFacet);
      facetAddresses[2] = address(rewardFacet);
      
      // ERC20 selectors
      bytes4[] memory erc20Selectors = new bytes4[](11);
      erc20Selectors[0] = ERC20Facet.name.selector;
      erc20Selectors[1] = ERC20Facet.symbol.selector;
      erc20Selectors[2] = ERC20Facet.decimals.selector;
      erc20Selectors[3] = ERC20Facet.totalSupply.selector;
      erc20Selectors[4] = ERC20Facet.balanceOf.selector;
      erc20Selectors[5] = ERC20Facet.transfer.selector;
      erc20Selectors[6] = ERC20Facet.allowance.selector;
      erc20Selectors[7] = ERC20Facet.approve.selector;
      erc20Selectors[8] = ERC20Facet.transferFrom.selector;
      erc20Selectors[9] = ERC20Facet.mint.selector;
      erc20Selectors[10] = ERC20Facet.burn.selector;
      
      // Staking selectors - Remove the supportsInterface selector
      bytes4[] memory stakingSelectors = new bytes4[](11);
      stakingSelectors[0] = StakingFacet.stakeERC20.selector;
      stakingSelectors[1] = StakingFacet.unstakeERC20.selector;
      stakingSelectors[2] = StakingFacet.stakeERC721.selector;
      stakingSelectors[3] = StakingFacet.unstakeERC721.selector;
      stakingSelectors[4] = StakingFacet.stakeERC1155.selector;
      stakingSelectors[5] = StakingFacet.unstakeERC1155.selector;
      stakingSelectors[6] = StakingFacet.claimRewards.selector;
      stakingSelectors[7] = StakingFacet.calculateRewards.selector;
      stakingSelectors[8] = StakingFacet.onERC1155Received.selector;
      stakingSelectors[9] = StakingFacet.onERC1155BatchReceived.selector;
      stakingSelectors[10] = StakingFacet.onERC721Received.selector;
      // Removed: stakingSelectors[11] = StakingFacet.supportsInterface.selector;
      
      // Reward selectors
      bytes4[] memory rewardSelectors = new bytes4[](6);
      rewardSelectors[0] = RewardFacet.setRewardRate.selector;
      rewardSelectors[1] = RewardFacet.setDecayRate.selector;
      rewardSelectors[2] = RewardFacet.setMinimumStakingPeriod.selector;
      rewardSelectors[3] = RewardFacet.getRewardRate.selector;
      rewardSelectors[4] = RewardFacet.getDecayRate.selector;
      rewardSelectors[5] = RewardFacet.getMinimumStakingPeriod.selector;
      
      bytes4[][] memory selectors = new bytes4[][](3);
      selectors[0] = erc20Selectors;
      selectors[1] = stakingSelectors;
      selectors[2] = rewardSelectors;
      
      // Add facets
      addFacets(facetAddresses, selectors);
      
      // Initialize diamond
      DiamondInit.Args memory args = DiamondInit.Args({
          name: "Staking Diamond",
          symbol: "SDMD",
          decimals: 18,
          initialSupply: 1000000 * 10**18,
          initialSupplyRecipient: owner,
          rewardRate: 100, // 100 tokens per second per token staked
          decayRate: 10,   // 0.1% decay per day
          minimumStakingPeriod: 1 days
      });
      
      bytes memory initData = abi.encodeWithSelector(
          DiamondInit.init.selector,
          args
      );
      
      initializeDiamond(address(diamondInit), initData);
  }
  
  function testDeployDiamond() public {
      // Test that the diamond was deployed correctly
      assertEq(ownership.owner(), owner);
      
      // Test that all facets were added
      address[] memory facets = loupe.facetAddresses();
      assertEq(facets.length, 5); // DiamondCutFacet, DiamondLoupeFacet, OwnershipFacet, ERC20Facet, StakingFacet, RewardFacet
      
      // Test ERC20 functionality
      IERC20 token = IERC20(address(diamond));
      assertEq(token.balanceOf(owner), 1000000 * 10**18);
      
      // Test that the owner can transfer tokens
      vm.startPrank(owner);
      token.transfer(user1, 1000 * 10**18);
      vm.stopPrank();
      
      assertEq(token.balanceOf(user1), 1000 * 10**18);
  }
}

