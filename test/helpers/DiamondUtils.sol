// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/Diamond.sol";
import "lib/forge-std/src/Test.sol";
import "@arachnid/strings.sol";
import "src/interfaces/IERC20.sol";
import "src/interfaces/IERC721.sol";
import "src/interfaces/IERC1155.sol";
import "src/facets/DiamondLoupeFacet.sol";
import "src/facets/OwnershipFacet.sol";
import "src/facets/ERC721Facet.sol";
import "src/facets/StakingFacet.sol";
import "src/facets/RewardFacet.sol";
import "src/interfaces/IDiamondCut.sol";

// Declare interfaces at file level
interface IERC20Mock {
    function mint(address to, uint256 amount) external;
}

interface IERC721Mock {
    function mint(address to, uint256 tokenId) external;
}

interface IERC1155Mock {
    function mint(address to, uint256 id, uint256 amount, bytes memory data) external;
}

abstract contract DiamondUtils is Test {
    using strings for *;

    Diamond internal diamond;

   // In DiamondUtils.sol
function generateSelectors(string memory _facetName) internal returns (bytes4[] memory selectors) {
    string[] memory cmd = new string[](4);
    cmd[0] = "forge";
    cmd[1] = "inspect";
    cmd[2] = _facetName;
    cmd[3] = "methods";
    
    bytes memory res = vm.ffi(cmd);
    string memory st = string(res);
    
    // Count the number of functions
    strings.slice memory s = st.toSlice();
    strings.slice memory delim = "function".toSlice();
    uint count = s.count(delim) + 1;
    selectors = new bytes4[](count);
    
    // Parse function signatures
    s = st.toSlice();
    delim = "\n".toSlice();
    uint index = 0;
    
    while (s.len() > 0) {
        strings.slice memory line = s.split(delim);
        if (line.startsWith("function".toSlice())) {
            strings.slice memory sig = line.split("(".toSlice());
            selectors[index++] = bytes4(keccak256(bytes(sig.toString())));
        }
    }
    
    return selectors;
}

    function mockERC20(address token, address user, uint256 amount) internal {
        vm.prank(token);
        IERC20Mock(token).mint(user, amount);
    }

    function mockERC721(address token, address user, uint256 tokenId) internal {
        vm.prank(token);
        IERC721Mock(token).mint(user, tokenId);
    }

    function mockERC1155(address token, address user, uint256 tokenId, uint256 amount) internal {
        vm.prank(token);
        IERC1155Mock(token).mint(user, tokenId, amount, "");
    }

    // In DiamondUtils.sol
    function addFacets() internal virtual {
        // Deploy all standard facets
        address[] memory facets = new address[](5);
        facets[0] = address(new DiamondLoupeFacet());
        facets[1] = address(new OwnershipFacet());
        facets[2] = address(new ERC721Facet());
        facets[3] = address(new StakingFacet());
        facets[4] = address(new RewardFacet());

        // Build the facet cut
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](facets.length);
        
        string[] memory facetNames = new string[](5);
        facetNames[0] = "DiamondLoupeFacet";
        facetNames[1] = "OwnershipFacet";
        facetNames[2] = "ERC721Facet";
        facetNames[3] = "StakingFacet"; 
        facetNames[4] = "RewardFacet";

        for (uint i = 0; i < facets.length; i++) {
            bytes4[] memory selectors = generateSelectors(facetNames[i]);
            require(selectors.length > 0, string(abi.encodePacked("No selectors for ", facetNames[i])));
            
            cut[i] = IDiamondCut.FacetCut({
                facetAddress: facets[i],
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: selectors
            });
        }

        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }
}