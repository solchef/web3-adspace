// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MICTOKEN is ERC20 {
    constructor() ERC20("Meta Invisible Cloak", "MIC Token") {
        _mint(msg.sender, 25000000000000000000000);
    }
}
