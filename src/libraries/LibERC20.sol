// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, LibAppStorage} from "./LibAppStorage.sol";

library LibERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function _transfer(address from, address to, uint256 amount) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(s.balances[from] >= amount, "ERC20: transfer amount exceeds balance");
        
        s.balances[from] -= amount;
        s.balances[to] += amount;
        
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        require(to != address(0), "ERC20: mint to the zero address");
        
        s.totalSupply += amount;
        s.balances[to] += amount;
        
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        require(from != address(0), "ERC20: burn from the zero address");
        require(s.balances[from] >= amount, "ERC20: burn amount exceeds balance");
        
        s.balances[from] -= amount;
        s.totalSupply -= amount;
        
        emit Transfer(from, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        
        s.allowances[owner][spender] = amount;
        
        emit Approval(owner, spender, amount);
    }
}

