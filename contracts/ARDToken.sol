// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IERC20Metadata.sol";
import "./utils/Ownable.sol";
import "./ERC20.sol";

contract ARDToken is ERC20, Ownable{
    constructor() ERC20("Ares DAO","ARD"){}
    
    function mint(address account, uint256 amount) external onlyOwner{
        _mint(account, amount);
    }
    
    function burn(address account, uint256 amount) external onlyOwner{
        _burn(account, amount);
    }
}