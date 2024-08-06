// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../contracts/AMM.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Simple ERC20 token for testing purposes
contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}

contract AMMTest {
    TestToken public tokenX;
    TestToken public tokenY;
    AMM public amm;

    constructor() {
        // Deploy test tokens
        tokenX = new TestToken("Token X", "TKNX", 1000000 * 10**18);
        tokenY = new TestToken("Token Y", "TKNY", 1000000 * 10**18);

        // Deploy the AMM contract
        amm = new AMM(address(tokenX), address(tokenY));

        // Allocate initial tokens to this contract for testing
        tokenX.transfer(address(this), 500000 * 10**18);
        tokenY.transfer(address(this), 500000 * 10**18);
    }

    function testAddLiquidity() public {
        // Approve tokens to be transferred to AMM
        tokenX.approve(address(amm), 1000 * 10**18);
        tokenY.approve(address(amm), 1000 * 10**18);

        // Add liquidity
        uint256 liquidity = amm.addLiquidity(1000 * 10**18, 1000 * 10**18);
        require(liquidity > 0, "Liquidity not added");

        // Check AMM reserves
        (uint256 reserveX, uint256 reserveY) = amm.getReserves();
        require(reserveX == 1000 * 10**18, "Incorrect Token X reserve");
        require(reserveY == 1000 * 10**18, "Incorrect Token Y reserve");
    }

    function testRemoveLiquidity() public {
        // Approve tokens and add liquidity first
        tokenX.approve(address(amm), 1000 * 10**18);
        tokenY.approve(address(amm), 1000 * 10**18);
        uint256 liquidity = amm.addLiquidity(1000 * 10**18, 1000 * 10**18);

        // Remove liquidity
        (uint256 amountX, uint256 amountY) = amm.removeLiquidity(liquidity);
        require(amountX == 1000 * 10**18, "Incorrect Token X amount removed");
        require(amountY == 1000 * 10**18, "Incorrect Token Y amount removed");
    }

    function testSwapXForY() public {
        // Approve tokens and add liquidity first
        tokenX.approve(address(amm), 1000 * 10**18);
        tokenY.approve(address(amm), 1000 * 10**18);
        amm.addLiquidity(1000 * 10**18, 1000 * 10**18);

        // Approve tokens for swap
        tokenX.approve(address(amm), 100 * 10**18);

        // Perform swap
        uint256 amountYOut = amm.swapXForY(100 * 10**18, 1);
        require(amountYOut > 0, "Swap did not succeed");

        // Check reserves after swap
        (uint256 reserveX, uint256 reserveY) = amm.getReserves();
        require(reserveX > 1000 * 10**18, "Token X reserve did not increase");
        require(reserveY < 1000 * 10**18, "Token Y reserve did not decrease");
    }

    function testSwapYForX() public {
        // Approve tokens and add liquidity first
        tokenX.approve(address(amm), 1000 * 10**18);
        tokenY.approve(address(amm), 1000 * 10**18);
        amm.addLiquidity(1000 * 10**18, 1000 * 10**18);

        // Approve tokens for swap
        tokenY.approve(address(amm), 100 * 10**18);

        // Perform swap
        uint256 amountXOut = amm.swapYForX(100 * 10**18, 1);
        require(amountXOut > 0, "Swap did not succeed");

        // Check reserves after swap
        (uint256 reserveX, uint256 reserveY) = amm.getReserves();
        require(reserveY > 1000 * 10**18, "Token Y reserve did not increase");
        require(reserveX < 1000 * 10**18, "Token X reserve did not decrease");
    }
}
