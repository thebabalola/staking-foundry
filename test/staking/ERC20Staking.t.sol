// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../helpers/DiamondUtils.sol";
import "../../src/facets/ERC20Facet.sol";
import "../../src/facets/StakingFacet.sol";
import "../../src/facets/RewardFacet.sol";
import "../../src/upgradeInitializers/DiamondInit.sol";
import "../../src/interfaces/IERC20.sol";
import "../../src/interfaces/IStaking.sol";

contract MockERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }
    
    function name() external view returns (string memory) {
        return _name;
    }
    
    function symbol() external view returns (string memory) {
        return _symbol;
    }
    
    function decimals() external pure returns (uint8) {
        return 18;
    }
    
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    
    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _transfer(sender, recipient, amount);
        
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, msg.sender, currentAllowance - amount);
        }
        
        return true;
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        
        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;
        
        emit Transfer(sender, recipient, amount);
    }
    
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function mint(address to, uint256 amount) external {
        require(to != address(0), "ERC20: mint to the zero address");
        
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }
}

// Fix inheritance order - Test should come first
contract ERC20StakingTest is Test, DiamondUtils {
    ERC20Facet erc20Facet;
    StakingFacet stakingFacet;
    RewardFacet rewardFacet;
    DiamondInit diamondInit;
    
    MockERC20 mockToken;
    
    IERC20 diamondToken;
    IStaking staking;
    
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
        
        // Deploy mock ERC20 token for staking
        mockToken = new MockERC20("Mock Token", "MOCK");
        mockToken.mint(user1, 1000 * 10**18);
        
        // Setup interfaces
        diamondToken = IERC20(address(diamond));
        staking = IStaking(address(diamond));
    }
    
    function testStakeERC20() public {
        // User1 approves diamond to spend tokens
        vm.startPrank(user1);
        mockToken.approve(address(diamond), 100 * 10**18);
        
        // User1 stakes tokens
        staking.stakeERC20(address(mockToken), 100 * 10**18);
        vm.stopPrank();
        
        // Check that tokens were transferred
        assertEq(mockToken.balanceOf(address(diamond)), 100 * 10**18);
        
        // Fast forward 2 days
        vm.warp(block.timestamp + 2 days);
        
        // Calculate rewards
        uint256 rewards = staking.calculateRewards(user1);
        assertTrue(rewards > 0, "Should have earned rewards");
        
        // User1 unstakes tokens
        vm.startPrank(user1);
        staking.unstakeERC20(0);
        vm.stopPrank();
        
        // Check that tokens were returned
        assertEq(mockToken.balanceOf(user1), 1000 * 10**18);
        
        // Check that rewards were minted
        assertTrue(diamondToken.balanceOf(user1) > 0, "Should have received rewards");
    }
    
    function testClaimRewards() public {
        // User1 approves diamond to spend tokens
        vm.startPrank(user1);
        mockToken.approve(address(diamond), 100 * 10**18);
        
        // User1 stakes tokens
        staking.stakeERC20(address(mockToken), 100 * 10**18);
        vm.stopPrank();
        
        // Fast forward 1 day
        vm.warp(block.timestamp + 1 days);
        
        // User1 claims rewards
        vm.startPrank(user1);
        staking.claimRewards();
        vm.stopPrank();
        
        // Check that rewards were minted
        assertTrue(diamondToken.balanceOf(user1) > 0, "Should have received rewards");
        
        // Fast forward another day
        vm.warp(block.timestamp + 1 days);
        
        // User1 claims rewards again
        vm.startPrank(user1);
        staking.claimRewards();
        vm.stopPrank();
        
        // Check that more rewards were minted
        assertTrue(diamondToken.balanceOf(user1) > 0, "Should have received more rewards");
    }
}

