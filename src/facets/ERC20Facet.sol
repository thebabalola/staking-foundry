// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC20.sol";
import "../libraries/LibAppStorage.sol";
import "../libraries/LibDiamond.sol";  // Added this import
import {AppStorage} from "../libraries/LibAppStorage.sol";  // Added explicit import

contract ERC20Facet is IERC20 {
    function name() external view returns (string memory) {
        return LibAppStorage.diamondStorage().name;
    }
    
    function symbol() external view returns (string memory) {
        return LibAppStorage.diamondStorage().symbol;
    }
    
    function decimals() external view returns (uint8) {
        return LibAppStorage.diamondStorage().decimals;
    }
    
    function totalSupply() external view returns (uint256) {
        return LibAppStorage.diamondStorage().totalSupply;
    }
    
    function balanceOf(address account) external view returns (uint256) {
        return LibAppStorage.diamondStorage().balances[account];
    }
    
    function transfer(address recipient, uint256 amount) external returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(s.balances[msg.sender] >= amount, "ERC20: transfer amount exceeds balance");
        s.balances[msg.sender] -= amount;
        s.balances[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }
    
    function allowance(address owner, address spender) external view returns (uint256) {
        return LibAppStorage.diamondStorage().allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        LibAppStorage.diamondStorage().allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(s.allowances[sender][msg.sender] >= amount, "ERC20: transfer amount exceeds allowance");
        require(s.balances[sender] >= amount, "ERC20: transfer amount exceeds balance");
        
        s.allowances[sender][msg.sender] -= amount;
        s.balances[sender] -= amount;
        s.balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }
    
    function mint(address account, uint256 amount) external {
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(msg.sender == LibDiamond.contractOwner(), "Only owner can mint");
        s.totalSupply += amount;
        s.balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }
}