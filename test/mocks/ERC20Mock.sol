// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/**
 * @title ERC20Mock
 * @dev Mock ERC20 token for testing
 */
contract ERC20Mock is ERC20 {
    /**
     * @dev Constructor to initialize the token
     * @param name_ The name of the token
     * @param symbol_ The symbol of the token
     */
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    /**
     * @dev Mint tokens to an address
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
