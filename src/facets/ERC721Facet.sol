// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC721.sol";
import "../interfaces/IERC721Receiver.sol";
import "../libraries/LibAppStorage.sol";
import "../libraries/LibDiamond.sol";

contract ERC721Facet is IERC721 {
    AppStorage internal s;

    function balanceOf(address owner) external view override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return s.erc721Balances[owner];
    }

    function ownerOf(uint256 tokenId) external view override returns (address) {
        address owner = s.erc721Owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, data);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external override {
        _safeTransfer(from, to, tokenId, ""); // Changed to call _safeTransfer instead of safeTransferFrom
    }
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }

    function approve(address to, uint256 tokenId) external override {
        address owner = s.erc721Owners[tokenId];
        require(to != owner, "ERC721: approval to current owner");
        require(
            msg.sender == owner || s.erc721OperatorApprovals[owner][msg.sender],
            "ERC721: approve caller is not owner nor approved for all"
        );
        s.erc721TokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external override {
        require(operator != msg.sender, "ERC721: approve to caller");
        s.erc721OperatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function getApproved(uint256 tokenId) external view override returns (address) {
        require(s.erc721Owners[tokenId] != address(0), "ERC721: approved query for nonexistent token");
        return s.erc721TokenApprovals[tokenId];
    }

    function isApprovedForAll(address owner, address operator) external view override returns (bool) {
        return s.erc721OperatorApprovals[owner][operator];
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        require(s.erc721Owners[tokenId] == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        // Clear approvals from the previous owner
        delete s.erc721TokenApprovals[tokenId];

        s.erc721Balances[from] -= 1;
        s.erc721Balances[to] += 1;
        s.erc721Owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = s.erc721Owners[tokenId];
        require(owner != address(0), "ERC721: operator query for nonexistent token");
        return (spender == owner || 
                s.erc721TokenApprovals[tokenId] == spender || 
                s.erc721OperatorApprovals[owner][spender]);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.code.length == 0) {
            return true;
        }
        try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
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
    }

    // Mint function for testing
    function mint(address to, uint256 tokenId) external {
        require(LibDiamond.contractOwner() == msg.sender, "Only owner can mint");
        require(to != address(0), "ERC721: mint to the zero address");
        require(s.erc721Owners[tokenId] == address(0), "ERC721: token already minted");

        s.erc721Balances[to] += 1;
        s.erc721Owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }
}