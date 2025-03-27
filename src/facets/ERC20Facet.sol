// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import "../interfaces/IERC20.sol";

contract ERC20Facet is IERC20 {
    AppStorage internal s;
    
    // ERC20 standard functions
    function name() external view returns (string memory) {
        return s.name;
    }
    
    function symbol() external view returns (string memory) {
        return s.symbol;
    }
    
    function decimals() external view returns (uint8) {
        return s.decimals;
    }
    
    function totalSupply() external view override returns (uint256) {
        return s.totalSupply;
    }
    
    function balanceOf(address account) external view override returns (uint256) {
        return s.balances[account];
    }
    
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    
    function allowance(address owner, address spender) external view override returns (uint256) {
        return s.allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _transfer(sender, recipient, amount);
        
        uint256 currentAllowance = s.allowances[sender][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, msg.sender, currentAllowance - amount);
        }
        
        return true;
    }
    
    // Internal functions
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        
        uint256 senderBalance = s.balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            s.balances[sender] = senderBalance - amount;
        }
        s.balances[recipient] += amount;
        
        emit Transfer(sender, recipient, amount);
    }
    
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        
        s.allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    // Additional functions for the diamond token
    function mint(address to, uint256 amount) external {
        require(msg.sender == s.contractOwner, "ERC20: only owner can mint");
        require(to != address(0), "ERC20: mint to the zero address");
        
        s.totalSupply += amount;
        s.balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function burn(uint256 amount) external {
        require(s.balances[msg.sender] >= amount, "ERC20: burn amount exceeds balance");
        
        unchecked {
            s.balances[msg.sender] -= amount;
        }
        s.totalSupply -= amount;
        
        emit Transfer(msg.sender, address(0), amount);
    }
}

