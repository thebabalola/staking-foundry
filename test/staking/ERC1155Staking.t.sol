// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../helpers/DiamondUtils.sol";
import "../../src/facets/ERC20Facet.sol";
import "../../src/facets/StakingFacet.sol";
import "../../src/facets/RewardFacet.sol";
import "../../src/upgradeInitializers/DiamondInit.sol";
import "../../src/interfaces/IERC20.sol";
import "../../src/interfaces/IERC1155.sol";
import "../../src/interfaces/IStaking.sol";

contract MockERC1155 is IERC1155 {
    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    string private _uri;
    
    constructor(string memory uri_) {
        _uri = uri_;
    }
    
    function uri(uint256) external view returns (string memory) {
        return _uri;
    }
    
    function balanceOf(address account, uint256 id) external view override returns (uint256) {
        require(account != address(0), "ERC1155: balance query for the zero address");
        return _balances[id][account];
    }
    
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view override returns (uint256[] memory) {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");
        
        uint256[] memory batchBalances = new uint256[](accounts.length);
        
        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = _balances[ids[i]][accounts[i]];
        }
        
        return batchBalances;
    }
    
    function setApprovalForAll(address operator, bool approved) external override {
        require(operator != msg.sender, "ERC1155: setting approval status for self");
        
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    function isApprovedForAll(address account, address operator) external view override returns (bool) {
        return _operatorApprovals[account][operator];
    }
    
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external override {
        require(
            from == msg.sender || _operatorApprovals[from][msg.sender],
            "ERC1155: caller is not owner nor approved"
        );
        require(to != address(0), "ERC1155: transfer to the zero address");
        
        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;
        
        emit TransferSingle(msg.sender, from, to, id, amount);
        
        _doSafeTransferAcceptanceCheck(msg.sender, from, to, id, amount, data);
    }
    
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external override {
        require(
            from == msg.sender || _operatorApprovals[from][msg.sender],
            "ERC1155: caller is not owner nor approved"
        );
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            
            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }
        
        emit TransferBatch(msg.sender, from, to, ids, amounts);
        
        _doSafeBatchTransferAcceptanceCheck(msg.sender, from, to, ids, amounts, data);
    }
    
    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }
    
    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }
    
    function mint(address to, uint256 id, uint256 amount) external {
        require(to != address(0), "ERC1155: mint to the zero address");
        
        _balances[id][to] += amount;
        emit TransferSingle(msg.sender, address(0), to, id, amount);
        
        _doSafeTransferAcceptanceCheck(msg.sender, address(0), to, id, amount, "");
    }
}

// Fix inheritance order - Test should come first
contract ERC1155StakingTest is Test, DiamondUtils {
    ERC20Facet erc20Facet;
    StakingFacet stakingFacet;
    RewardFacet rewardFacet;
    DiamondInit diamondInit;
    
    MockERC1155 mockToken;
    
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
        
        // Deploy mock ERC1155 token for staking
        mockToken = new MockERC1155("https://example.com/token/{id}");
        mockToken.mint(user1, 1, 100);
        
        // Setup interfaces
        diamondToken = IERC20(address(diamond));
        staking = IStaking(address(diamond));
    }
    
    function testStakeERC1155() public {
        // User1 approves diamond to spend tokens
        vm.startPrank(user1);
        mockToken.setApprovalForAll(address(diamond), true);
        
        // User1 stakes tokens
        staking.stakeERC1155(address(mockToken), 1, 50);
        vm.stopPrank();
        
        // Check that tokens were transferred
        assertEq(mockToken.balanceOf(address(diamond), 1), 50);
        assertEq(mockToken.balanceOf(user1, 1), 50);
        
        // Fast forward 2 days
        vm.warp(block.timestamp + 2 days);
        
        // Calculate rewards
        uint256 rewards = staking.calculateRewards(user1);
        assertTrue(rewards > 0, "Should have earned rewards");
        
        // User1 unstakes tokens
        vm.startPrank(user1);
        staking.unstakeERC1155(0);
        vm.stopPrank();
        
        // Check that tokens were returned
        assertEq(mockToken.balanceOf(user1, 1), 100);
        
        // Check that rewards were minted
        assertTrue(diamondToken.balanceOf(user1) > 0, "Should have received rewards");
    }
}

