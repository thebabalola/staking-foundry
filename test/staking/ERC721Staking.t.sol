// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../helpers/DiamondUtils.sol";
import "../../src/facets/ERC20Facet.sol";
import "../../src/facets/StakingFacet.sol";
import "../../src/facets/RewardFacet.sol";
import "../../src/upgradeInitializers/DiamondInit.sol";
import "../../src/interfaces/IERC20.sol";
import "../../src/interfaces/IERC721.sol";
import "../../src/interfaces/IStaking.sol";

contract MockERC721 is IERC721 {
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
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
    
    function balanceOf(address owner) external view override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }
    
    function ownerOf(uint256 tokenId) external view override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }
    
    function approve(address to, uint256 tokenId) external override {
        address owner = _owners[tokenId];
        require(to != owner, "ERC721: approval to current owner");
        require(msg.sender == owner || _operatorApprovals[owner][msg.sender], "ERC721: approve caller is not owner nor approved for all");
        
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }
    
    function getApproved(uint256 tokenId) external view override returns (address) {
        require(_owners[tokenId] != address(0), "ERC721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }
    
    function setApprovalForAll(address operator, bool approved) external override {
        require(operator != msg.sender, "ERC721: approve to caller");
        
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    function isApprovedForAll(address owner, address operator) external view override returns (bool) {
        return _operatorApprovals[owner][operator];
    }
    
    function transferFrom(address from, address to, uint256 tokenId) external override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        
        _transfer(from, to, tokenId);
    }
    
    function safeTransferFrom(address from, address to, uint256 tokenId) external override {
        safeTransferFrom(from, to, tokenId, "");
    }
    
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }
    
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }
    
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: operator query for nonexistent token");
        return (spender == owner || _tokenApprovals[tokenId] == spender || _operatorApprovals[owner][spender]);
    }
    
    function _transfer(address from, address to, uint256 tokenId) internal {
        require(_owners[tokenId] == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");
        
        // Clear approvals
        _tokenApprovals[tokenId] = address(0);
        
        // Update balances
        _balances[from] -= 1;
        _balances[to] += 1;
        
        // Update owner
        _owners[tokenId] = to;
        
        emit Transfer(from, to, tokenId);
    }
    
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) private returns (bool) {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
    
    function mint(address to, uint256 tokenId) external {
        require(to != address(0), "ERC721: mint to the zero address");
        require(_owners[tokenId] == address(0), "ERC721: token already minted");
        
        _balances[to] += 1;
        _owners[tokenId] = to;
        
        emit Transfer(address(0), to, tokenId);
    }
}

// Fix inheritance order - Test should come first
contract ERC721StakingTest is Test, DiamondUtils {
    ERC20Facet erc20Facet;
    StakingFacet stakingFacet;
    RewardFacet rewardFacet;
    DiamondInit diamondInit;
    
    MockERC721 mockNFT;
    
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
        
        // Deploy mock ERC721 token for staking
        mockNFT = new MockERC721("Mock NFT", "MNFT");
        mockNFT.mint(user1, 1);
        mockNFT.mint(user1, 2);
        mockNFT.mint(user1, 3);
        
        // Setup interfaces
        diamondToken = IERC20(address(diamond));
        staking = IStaking(address(diamond));
    }
    
    function testStakeERC721() public {
        // User1 approves diamond to spend NFT
        vm.startPrank(user1);
        mockNFT.approve(address(diamond), 1);
        
        // User1 stakes NFT
        staking.stakeERC721(address(mockNFT), 1);
        vm.stopPrank();
        
        // Check that NFT was transferred
        assertEq(mockNFT.ownerOf(1), address(diamond));
        
        // Fast forward 2 days
        vm.warp(block.timestamp + 2 days);
        
        // Calculate rewards
        uint256 rewards = staking.calculateRewards(user1);
        assertTrue(rewards > 0, "Should have earned rewards");
        
        // User1 unstakes NFT
        vm.startPrank(user1);
        staking.unstakeERC721(0);
        vm.stopPrank();
        
        // Check that NFT was returned
        assertEq(mockNFT.ownerOf(1), user1);
        
        // Check that rewards were minted
        assertTrue(diamondToken.balanceOf(user1) > 0, "Should have received rewards");
    }
}

