// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AppStorage, LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibERC20} from "../libraries/LibERC20.sol";
import {IERC20} from "../interfaces/IERC20.sol";

contract ERC20Facet is IERC20 {
    AppStorage internal s;

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
        LibERC20._transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return s.allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        LibERC20._approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        uint256 currentAllowance = s.allowances[sender][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        
        LibERC20._transfer(sender, recipient, amount);
        
        unchecked {
            LibERC20._approve(sender, msg.sender, currentAllowance - amount);
        }
        
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        uint256 currentAllowance = s.allowances[msg.sender][spender];
        LibERC20._approve(msg.sender, spender, currentAllowance + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = s.allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        
        unchecked {
            LibERC20._approve(msg.sender, spender, currentAllowance - subtractedValue);
        }
        
        return true;
    }
}

