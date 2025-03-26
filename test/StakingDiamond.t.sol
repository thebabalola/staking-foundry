// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Diamond.sol";
import "../src/facets/DiamondCutFacet.sol";
import "../src/facets/DiamondLoupeFacet.sol";
import "../src/facets/OwnershipFacet.sol";
import "../src/facets/ERC20Facet.sol";
import "../src/facets/ERC20StakingFacet.sol";
import "../src/facets/ERC721StakingFacet.sol";
import "../src/facets/ERC1155StakingFacet.sol";
import "../src/facets/RewardFacet.sol";
import "../src/upgradeInitializers/DiamondInit.sol";
import "../src/interfaces/IDiamondCut.sol";
import "../src/interfaces/IERC20.sol";
import "../src/interfaces/IERC721.sol";
import "../src/interfaces/IERC1155.sol";

// Mock tokens for testing
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
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(_balances[sender] >= amount, "ERC20: transfer amount exceeds balance");

        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    // For testing
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}

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

    function balanceOf(address owner) external view override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) external view override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function transferFrom(address from, address to, uint256 tokenId) external override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }

    function approve(address to, uint256 tokenId) external override {
        address owner = _owners[tokenId];
        require(to != owner, "ERC721: approval to current owner");
        require(msg.sender == owner || _operatorApprovals[owner][msg.sender], "ERC721: approve caller is not owner nor approved for all");
        _tokenApprovals[tokenId] = to;
    }

    function getApproved(uint256 tokenId) external view override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external override {
        require(operator != msg.sender, "ERC721: approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
    }

    function isApprovedForAll(address owner, address operator) external view override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = _owners[tokenId];
        return (spender == owner || _tokenApprovals[tokenId] == spender || _operatorApprovals[owner][spender]);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(_owners[tokenId] == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;
    }

    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _balances[to] += 1;
        _owners[tokenId] = to;
    }

    // For testing
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract MockERC1155 is IERC1155 {
    mapping(address => mapping(uint256 => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    function balanceOf(address account, uint256 id) external view override returns (uint256) {
        require(account != address(0), "ERC1155: balance query for the zero address");
        return _balances[account][id];
    }

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view override returns (uint256[] memory) {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = _balances[accounts[i]][ids[i]];
        }

        return batchBalances;
    }

    function setApprovalForAll(address operator, bool approved) external override {
        require(operator != msg.sender, "ERC1155: setting approval status for self");
        _operatorApprovals[msg.sender][operator] = approved;
    }

    function isApprovedForAll(address account, address operator) external view override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external override {
        require(from == msg.sender || _operatorApprovals[from][msg.sender], "ERC1155: caller is not owner nor approved");
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(_balances[from][id] >= amount, "ERC1155: insufficient balance for transfer");

        _balances[from][id] -= amount;
        _balances[to][id] += amount;
    }

    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external override {
        require(from == msg.sender || _operatorApprovals[from][msg.sender], "ERC1155: caller is not owner nor approved");
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            require(_balances[from][id] >= amount, "ERC1155: insufficient balance for transfer");

            _balances[from][id] -= amount;
            _balances[to][id] += amount;
        }
    }

    // For testing
    function mint(address to, uint256 id, uint256 amount) external {
        require(to != address(0), "ERC1155: mint to the zero address");
        _balances[to][id] += amount;
    }
}

contract StakingDiamondTest is Test {
    Diamond diamond;
    DiamondCutFacet diamondCutFacet;
    DiamondLoupeFacet diamondLoupeFacet;
    OwnershipFacet ownershipFacet;
    ERC20Facet erc20Facet;
    ERC20StakingFacet erc20StakingFacet;
    ERC721StakingFacet erc721StakingFacet;
    ERC1155StakingFacet erc1155StakingFacet;
    RewardFacet rewardFacet;
    DiamondInit diamondInit;
    
    MockERC20 mockERC20;
    MockERC721 mockERC721;
    MockERC1155 mockERC1155;
    
    address owner = address(1);
    address user1 = address(2);
    address user2 = address(3);
    
    function setUp() public {
        // Deploy facets
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        erc20Facet = new ERC20Facet();
        erc20StakingFacet = new ERC20StakingFacet();
        erc721StakingFacet = new ERC721StakingFacet();
        erc1155StakingFacet = new ERC1155StakingFacet();
        rewardFacet = new RewardFacet();
        diamondInit = new DiamondInit();
        
        // Deploy Diamond with DiamondCutFacet
        diamond = new Diamond(owner, address(diamondCutFacet));
        
        // Build cut struct for adding facets
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](7);
        
        // DiamondLoupeFacet
        bytes4[] memory loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = diamondLoupeFacet.facets.selector;
        loupeSelectors[1] = diamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = diamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = diamondLoupeFacet.facetAddress.selector;
        loupeSelectors[4] = diamondLoupeFacet.supportsInterface.selector;
        
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });
        
        // OwnershipFacet
        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = ownershipFacet.transferOwnership.selector;
        ownershipSelectors[1] = ownershipFacet.owner.selector;
        
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });
        
        // ERC20Facet
        bytes4[] memory erc20Selectors = new bytes4[](10);
        erc20Selectors[0] = erc20Facet.name.selector;
        erc20Selectors[1] = erc20Facet.symbol.selector;
        erc20Selectors[2] = erc20Facet.decimals.selector;
        erc20Selectors[3] = erc20Facet.totalSupply.selector;
        erc20Selectors[4] = erc20Facet.balanceOf.selector;
        erc20Selectors[5] = erc20Facet.transfer.selector;
        erc20Selectors[6] = erc20Facet.allowance.selector;
        erc20Selectors[7] = erc20Facet.approve.selector;
        erc20Selectors[8] = erc20Facet.transferFrom.selector;
        erc20Selectors[9] = erc20Facet.increaseAllowance.selector;
        
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(erc20Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: erc20Selectors
        });
        
        // ERC20StakingFacet
        bytes4[] memory erc20StakingSelectors = new bytes4[](7);
        erc20StakingSelectors[0] = erc20StakingFacet.addSupportedERC20Token.selector;
        erc20StakingSelectors[1] = erc20StakingFacet.removeSupportedERC20Token.selector;
        erc20StakingSelectors[2] = erc20StakingFacet.isSupportedERC20Token.selector;
        erc20StakingSelectors[3] = erc20StakingFacet.stakeERC20.selector;
        erc20StakingSelectors[4] = erc20StakingFacet.unstakeERC20.selector;
        erc20StakingSelectors[5] = erc20StakingFacet.getERC20StakeInfo.selector;
        
        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(erc20StakingFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: erc20StakingSelectors
        });
        
        // ERC721StakingFacet
        bytes4[] memory erc721StakingSelectors = new bytes4[](8);
        erc721StakingSelectors[0] = erc721StakingFacet.addSupportedERC721Token.selector;
        erc721StakingSelectors[1] = erc721StakingFacet.removeSupportedERC721Token.selector;
        erc721StakingSelectors[2] = erc721StakingFacet.isSupportedERC721Token.selector;
        erc721StakingSelectors[3] = erc721StakingFacet.stakeERC721.selector;
        erc721StakingSelectors[4] = erc721StakingFacet.unstakeERC721.selector;
        erc721StakingSelectors[5] = erc721StakingFacet.getERC721StakedTokens.selector;
        erc721StakingSelectors[6] = erc721StakingFacet.getERC721StakeTimestamp.selector;
        
        cut[4] = IDiamondCut.FacetCut({
            facetAddress: address(erc721StakingFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: erc721StakingSelectors
        });
        
        // ERC1155StakingFacet
        bytes4[] memory erc1155StakingSelectors = new bytes4[](8);
        erc1155StakingSelectors[0] = erc1155StakingFacet.addSupportedERC1155Token.selector;
        erc1155StakingSelectors[1] = erc1155StakingFacet.removeSupportedERC1155Token.selector;
        erc1155StakingSelectors[2] = erc1155StakingFacet.isSupportedERC1155Token.selector;
        erc1155StakingSelectors[3] = erc1155StakingFacet.stakeERC1155.selector;
        erc1155StakingSelectors[4] = erc1155StakingFacet.unstakeERC1155.selector;
        erc1155StakingSelectors[5] = erc1155StakingFacet.getERC1155StakedIds.selector;
        erc1155StakingSelectors[6] = erc1155StakingFacet.getERC1155StakeInfo.selector;
        
        cut[5] = IDiamondCut.FacetCut({
            facetAddress: address(erc1155StakingFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: erc1155StakingSelectors
        });
        
        // RewardFacet
        bytes4[] memory rewardSelectors = new bytes4[](9);
        rewardSelectors[0] = rewardFacet.claimRewards.selector;
        rewardSelectors[1] = rewardFacet.pendingRewards.selector;
        rewardSelectors[2] = rewardFacet.setBaseRewardRate.selector;
        rewardSelectors[3] = rewardFacet.setDecayRate.selector;
        rewardSelectors[4] = rewardFacet.setERC20RewardMultiplier.selector;
        rewardSelectors[5] = rewardFacet.setERC721RewardMultiplier.selector;
        rewardSelectors[6] = rewardFacet.setERC1155RewardMultiplier.selector;
        rewardSelectors[7] = rewardFacet.setMinStakingPeriod.selector;
        rewardSelectors[8] = rewardFacet.getRewardParameters.selector;
        
        cut[6] = IDiamondCut.FacetCut({
            facetAddress: address(rewardFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: rewardSelectors
        });
        
        // Initialize diamond with init contract
        DiamondInit.Args memory args = DiamondInit.Args({
            name: "Staking Diamond Token",
            symbol: "SDT",
            decimals: 18,
            baseRewardRate: 1e15, // 0.001 tokens per second
            erc20RewardMultiplier: 1e18, // 1.0
            erc721RewardMultiplier: 5e18, // 5.0
            erc1155RewardMultiplier: 2e18, // 2.0
            decayRate: 1e17, // 0.1 bonus per second
            minStakingPeriod: 1 days
        });
        
        bytes memory initCalldata = abi.encodeWithSelector(
            DiamondInit.init.selector,
            args
        );
        
        // Add facets to diamond
        vm.prank(owner);
        IDiamondCut(address(diamond)).diamondCut(cut, address(diamondInit), initCalldata);
        
        // Deploy mock tokens for testing
        mockERC20 = new MockERC20("Mock Token", "MTK");
        mockERC721 = new MockERC721("Mock NFT", "MNFT");
        mockERC1155 = new MockERC1155();
        
        // Add supported tokens
        vm.startPrank(owner);
        ERC20StakingFacet(address(diamond)).addSupportedERC20Token(address(mockERC20));
        ERC721StakingFacet(address(diamond)).addSupportedERC721Token(address(mockERC721));
        ERC1155StakingFacet(address(diamond)).addSupportedERC1155Token(address(mockERC1155));
        vm.stopPrank();
        
        // Mint tokens to users for testing
        mockERC20.mint(user1, 1000 ether);
        mockERC20.mint(user2, 1000 ether);
        
        mockERC721.mint(user1, 1);
        mockERC721.mint(user1, 2);
        mockERC721.mint(user2, 3);
        
        mockERC1155.mint(user1, 1, 10);
        mockERC1155.mint(user2, 2, 20);
    }
    
    function testDiamondCut() public {
        // Test that all facets were added correctly
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(address(diamond)).facets();
        assertEq(facets.length, 8); // Diamond + 7 facets
    }
    
    function testERC20Staking() public {
        // Approve tokens for staking
        vm.startPrank(user1);
        mockERC20.approve(address(diamond), 100 ether);
        
        // Stake tokens
        ERC20StakingFacet(address(diamond)).stakeERC20(address(mockERC20), 100 ether);
        
        // Check stake info
        (uint256 amount, uint256 timestamp) = ERC20StakingFacet(address(diamond)).getERC20StakeInfo(user1, address(mockERC20));
        assertEq(amount, 100 ether);
        assertEq(timestamp, block.timestamp);
        
        // Fast forward time
        vm.warp(block.timestamp + 2 days);
        
        // Unstake tokens
        ERC20StakingFacet(address(diamond)).unstakeERC20(address(mockERC20), 50 ether);
        
        // Check updated stake info
        (amount, timestamp) = ERC20StakingFacet(address(diamond)).getERC20StakeInfo(user1, address(mockERC20));
        assertEq(amount, 50 ether);
        
        vm.stopPrank();
    }
    
    function testERC721Staking() public {
        // Approve NFT for staking
        vm.startPrank(user1);
        mockERC721.approve(address(diamond), 1);
        
        // Stake NFT
        ERC721StakingFacet(address(diamond)).stakeERC721(address(mockERC721), 1);
        
        // Check staked tokens
        uint256[] memory stakedTokens = ERC721StakingFacet(address(diamond)).getERC721StakedTokens(user1, address(mockERC721));
        assertEq(stakedTokens.length, 1);
        assertEq(stakedTokens[0], 1);
        
        // Check stake timestamp
        uint256 timestamp = ERC721StakingFacet(address(diamond)).getERC721StakeTimestamp(user1, address(mockERC721), 1);
        assertEq(timestamp, block.timestamp);
        
        // Fast forward time
        vm.warp(block.timestamp + 2 days);
        
        // Unstake NFT
        ERC721StakingFacet(address(diamond)).unstakeERC721(address(mockERC721), 1);
        
        // Check updated staked tokens
        stakedTokens = ERC721StakingFacet(address(diamond)).getERC721StakedTokens(user1, address(mockERC721));
        assertEq(stakedTokens.length, 0);
        
        vm.stopPrank();
    }
    
    function testERC1155Staking() public {
        // Approve tokens for staking
        vm.startPrank(user1);
        mockERC1155.setApprovalForAll(address(diamond), true);
        
        // Stake tokens
        ERC1155StakingFacet(address(diamond)).stakeERC1155(address(mockERC1155), 1, 5);
        
        // Check staked ids
        uint256[] memory stakedIds = ERC1155StakingFacet(address(diamond)).getERC1155StakedIds(user1, address(mockERC1155));
        assertEq(stakedIds.length, 1);
        assertEq(stakedIds[0], 1);
        
        // Check stake info
        (uint256 amount, uint256 timestamp) = ERC1155StakingFacet(address(diamond)).getERC1155StakeInfo(user1, address(mockERC1155), 1);
        assertEq(amount, 5);
        assertEq(timestamp, block.timestamp);
        
        // Fast forward time
        vm.warp(block.timestamp + 2 days);
        
        // Unstake tokens
        ERC1155StakingFacet(address(diamond)).unstakeERC1155(address(mockERC1155), 1, 3);
        
        // Check updated stake info
        (amount, timestamp) = ERC1155StakingFacet(address(diamond)).getERC1155StakeInfo(user1, address(mockERC1155), 1);
        assertEq(amount, 2);
        
        vm.stopPrank();
    }
    
    function testRewards() public {
        // Stake tokens
        vm.startPrank(user1);
        mockERC20.approve(address(diamond), 100 ether);
        ERC20StakingFacet(address(diamond)).stakeERC20(address(mockERC20), 100 ether);
        
        // Fast forward time
        vm.warp(block.timestamp + 7 days);
        
        // Check pending rewards
        uint256 pendingRewards = RewardFacet(address(diamond)).pendingRewards(user1);
        assertGt(pendingRewards, 0);
        
        // Claim rewards
        RewardFacet(address(diamond)).claimRewards();
        
        // Check user balance
        uint256 balance = IERC20(address(diamond)).balanceOf(user1);
        assertEq(balance, pendingRewards);
        
        vm.stopPrank();
    }
    
    function testMultipleStakingTypes() public {
        // Stake ERC20, ERC721, and ERC1155 tokens
        vm.startPrank(user1);
        
        // Stake ERC20
        mockERC20.approve(address(diamond), 100 ether);
        ERC20StakingFacet(address(diamond)).stakeERC20(address(mockERC20), 100 ether);
        
        // Stake ERC721
        mockERC721.approve(address(diamond), 1);
        ERC721StakingFacet(address(diamond)).stakeERC721(address(mockERC721), 1);
        
        // Stake ERC1155
        mockERC1155.setApprovalForAll(address(diamond), true);
        ERC1155StakingFacet(address(diamond)).stakeERC1155(address(mockERC1155), 1, 5);
        
        // Fast forward time
        vm.warp(block.timestamp + 7 days);
        
        // Check pending rewards
        uint256 pendingRewards = RewardFacet(address(diamond)).pendingRewards(user1);
        assertGt(pendingRewards, 0);
        
        // Claim rewards
        RewardFacet(address(diamond)).claimRewards();
        
        // Check user balance
        uint256 balance = IERC20(address(diamond)).balanceOf(user1);
        assertEq(balance, pendingRewards);
        
        vm.stopPrank();
    }
    
    function testRewardParameters() public {
        // Test getting reward parameters
        (
            uint256 baseRewardRate,
            uint256 decayRate,
            uint256 erc20RewardMultiplier,
            uint256 erc721RewardMultiplier,
            uint256 erc1155RewardMultiplier,
            uint256 minStakingPeriod
        ) = RewardFacet(address(diamond)).getRewardParameters();
        
        assertEq(baseRewardRate, 1e15);
        assertEq(decayRate, 1e17);
        assertEq(erc20RewardMultiplier, 1e18);
        assertEq(erc721RewardMultiplier, 5e18);
        assertEq(erc1155RewardMultiplier, 2e18);
        assertEq(minStakingPeriod, 1 days);
        
        // Update reward parameters
        vm.startPrank(owner);
        RewardFacet(address(diamond)).setBaseRewardRate(2e15);
        RewardFacet(address(diamond)).setDecayRate(2e17);
        RewardFacet(address(diamond)).setERC20RewardMultiplier(2e18);
        RewardFacet(address(diamond)).setERC721RewardMultiplier(10e18);
        RewardFacet(address(diamond)).setERC1155RewardMultiplier(4e18);
        RewardFacet(address(diamond)).setMinStakingPeriod(2 days);
        vm.stopPrank();
        
        // Check updated parameters
        (
            baseRewardRate,
            decayRate,
            erc20RewardMultiplier,
            erc721RewardMultiplier,
            erc1155RewardMultiplier,
            minStakingPeriod
        ) = RewardFacet(address(diamond)).getRewardParameters();
        
        assertEq(baseRewardRate, 2e15);
        assertEq(decayRate, 2e17);
        assertEq(erc20RewardMultiplier, 2e18);
        assertEq(erc721RewardMultiplier, 10e18);
        assertEq(erc1155RewardMultiplier, 4e18);
        assertEq(minStakingPeriod, 2 days);
    }
    
    function testMinimumStakingPeriod() public {
        // Stake tokens
        vm.startPrank(user1);
        mockERC20.approve(address(diamond), 100 ether);
        ERC20StakingFacet(address(diamond)).stakeERC20(address(mockERC20), 100 ether);
        
        // Try to unstake before minimum staking period
        vm.expectRevert("ERC20StakingFacet: Minimum staking period not reached");
        ERC20StakingFacet(address(diamond)).unstakeERC20(address(mockERC20), 50 ether);
        
        // Fast forward time to just after minimum staking period
        vm.warp(block.timestamp + 1 days + 1);
        
        // Now unstake should work
        ERC20StakingFacet(address(diamond)).unstakeERC20(address(mockERC20), 50 ether);
        
        vm.stopPrank();
    }
}

