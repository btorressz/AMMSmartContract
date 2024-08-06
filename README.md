# AMMSmartContract
This project implements a basic Automated Market Maker (AMM). The contract is fully developed and tested in the Remix IDE and written entirely in Solidity. 

## Features

- **Liquidity Management**: Allows users to add and remove liquidity, updating the token reserves and maintaining the invariant.
- **Token Swaps**: Facilitates token swaps using the AMM model with fees.
- **Fee Distribution**: Collects and distributes swap fees to liquidity providers.
- **Governance Mechanism**: Enables token holders to vote on protocol changes and fee adjustments.
- **Price Oracle and TWAP**: Integrates an internal price oracle mechanism with time-weighted average price (TWAP) protection.
- **Flash Loan Protection**: Implements checks to mitigate risks associated with flash loans.
- **Robust Error Handling**: Provides comprehensive error messages and checks to ensure robustness.

## Contract Files

- **`AMM.sol`**: The main contract file containing the AMM logic.
- **`AMMTest.sol`**: The test contract used to test the AMM functionality.

  ### Test Contract

The `AMMTest.sol` contract is used to test the AMM functionality. It deploys instances of the `AMM` contract and ERC20 tokens, then performs various operations and verifies the expected outcomes.

#### Test Cases

- **testAddLiquidity**: Tests adding liquidity to the AMM and checks the reserves.
- **testRemoveLiquidity**: Tests removing liquidity from the AMM and checks the returned amounts.
- **testSwapXForY**: Tests swapping Token X for Token Y and checks the reserves.
- **testSwapYForX**: Tests swapping Token Y for Token X and checks the reserves.

## Acknowledgments

This project was developed and tested entirely in the Remix IDE.

## License

This project is licensed under the MIT License.
