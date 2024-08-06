// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// Importing necessary interfaces and libraries from OpenZeppelin
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title AMM
 * @dev This contract implements a basic Automated Market Maker (AMM) using the constant product formula x * y = k.
 * It supports adding/removing liquidity and swapping between two ERC20 tokens.
 */
contract AMM is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Tokens involved in the AMM
    IERC20 public tokenX;
    IERC20 public tokenY;

    // Reserves of the tokens in the AMM pool
    uint256 private reserveX;
    uint256 private reserveY;

    // Fee parameters
    uint256 public feeBasisPoints = 30; // 0.3% fee
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    // Governance parameters
    mapping(address => bool) public governors;
    address[] public governorList;

    // Time-weighted average price (TWAP) protection
    uint256 public twapInterval = 1 hours;
    uint256 public lastTwapPriceX;
    uint256 public lastTwapPriceY;
    uint256 public lastTwapTimestamp;

    event LiquidityAdded(address indexed provider, uint256 amountX, uint256 amountY, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountX, uint256 amountY, uint256 liquidity);
    event Swap(address indexed swapper, uint256 amountIn, uint256 amountOut, address tokenIn, address tokenOut);
    event GovernorAdded(address indexed governor);
    event GovernorRemoved(address indexed governor);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event TwapUpdated(uint256 newTwapPriceX, uint256 newTwapPriceY, uint256 timestamp);

    modifier onlyGovernor() {
        require(governors[msg.sender], "AMM: caller is not a governor");
        _;
    }

    /**
     * @dev Initializes the contract with two ERC20 tokens.
     * @param _tokenX Address of the first token (Token X).
     * @param _tokenY Address of the second token (Token Y).
     */
    constructor(address _tokenX, address _tokenY) ERC20("AMM Liquidity Token", "AMMLT") {
        tokenX = IERC20(_tokenX);
        tokenY = IERC20(_tokenY);
        governors[msg.sender] = true;
        governorList.push(msg.sender);
    }

    /**
     * @notice Adds liquidity to the pool.
     * @dev The liquidity provider must approve the tokens to be transferred before calling this function.
     * @param amountX The amount of Token X to add.
     * @param amountY The amount of Token Y to add.
     * @return liquidity The amount of liquidity tokens minted.
     */
    function addLiquidity(uint256 amountX, uint256 amountY) external nonReentrant returns (uint256 liquidity) {
        tokenX.safeTransferFrom(msg.sender, address(this), amountX);
        tokenY.safeTransferFrom(msg.sender, address(this), amountY);

        if (reserveX > 0 || reserveY > 0) {
            require(amountX * reserveY == amountY * reserveX, "AMM: Unbalanced liquidity provided");
        }

        if (totalSupply() == 0) {
            liquidity = sqrt(amountX * amountY);
        } else {
            liquidity = min((amountX * totalSupply()) / reserveX, (amountY * totalSupply()) / reserveY);
        }

        require(liquidity > 0, "AMM: Insufficient liquidity provided");

        _mint(msg.sender, liquidity);

        reserveX += amountX;
        reserveY += amountY;

        emit LiquidityAdded(msg.sender, amountX, amountY, liquidity);
    }

    /**
     * @notice Removes liquidity from the pool.
     * @dev The liquidity provider receives the proportionate share of the reserves.
     * @param liquidity The amount of liquidity tokens to remove.
     * @return amountX The amount of Token X returned.
     * @return amountY The amount of Token Y returned.
     */
    function removeLiquidity(uint256 liquidity) external nonReentrant returns (uint256 amountX, uint256 amountY) {
        require(liquidity > 0, "AMM: Invalid liquidity amount");

        uint256 totalSupply = totalSupply();

        amountX = (liquidity * reserveX) / totalSupply;
        amountY = (liquidity * reserveY) / totalSupply;

        _burn(msg.sender, liquidity);

        reserveX -= amountX;
        reserveY -= amountY;

        tokenX.safeTransfer(msg.sender, amountX);
        tokenY.safeTransfer(msg.sender, amountY);

        emit LiquidityRemoved(msg.sender, amountX, amountY, liquidity);
    }

    /**
     * @notice Swaps Token X for Token Y.
     * @param amountXIn The amount of Token X to swap.
     * @param minAmountYOut The minimum amount of Token Y to receive.
     * @return amountYOut The amount of Token Y received.
     */
    function swapXForY(uint256 amountXIn, uint256 minAmountYOut) external nonReentrant returns (uint256 amountYOut) {
        require(amountXIn > 0, "AMM: Invalid input amount");
        amountYOut = getAmountOut(amountXIn, reserveX, reserveY);
        require(amountYOut >= minAmountYOut, "AMM: Insufficient output amount");

        tokenX.safeTransferFrom(msg.sender, address(this), amountXIn);
        tokenY.safeTransfer(msg.sender, amountYOut);

        reserveX += amountXIn;
        reserveY -= amountYOut;

        updateTwap();

        emit Swap(msg.sender, amountXIn, amountYOut, address(tokenX), address(tokenY));
    }

    /**
     * @notice Swaps Token Y for Token X.
     * @param amountYIn The amount of Token Y to swap.
     * @param minAmountXOut The minimum amount of Token X to receive.
     * @return amountXOut The amount of Token X received.
     */
    function swapYForX(uint256 amountYIn, uint256 minAmountXOut) external nonReentrant returns (uint256 amountXOut) {
        require(amountYIn > 0, "AMM: Invalid input amount");
        amountXOut = getAmountOut(amountYIn, reserveY, reserveX);
        require(amountXOut >= minAmountXOut, "AMM: Insufficient output amount");

        tokenY.safeTransferFrom(msg.sender, address(this), amountYIn);
        tokenX.safeTransfer(msg.sender, amountXOut);

        reserveY += amountYIn;
        reserveX -= amountXOut;

        updateTwap();

        emit Swap(msg.sender, amountYIn, amountXOut, address(tokenY), address(tokenX));
    }

    /**
     * @notice Calculates the output amount for a given input amount using the constant product formula.
     * @param inputAmount The amount of input tokens.
     * @param inputReserve The reserve of input tokens.
     * @param outputReserve The reserve of output tokens.
     * @return The amount of output tokens.
     */
    function getAmountOut(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public view returns (uint256) {
        uint256 inputAmountWithFee = inputAmount * (BASIS_POINTS_DIVISOR - feeBasisPoints);
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * BASIS_POINTS_DIVISOR) + inputAmountWithFee;
        return numerator / denominator;
    }

    /**
     * @notice Returns the reserves of Token X and Token Y.
     * @return reserveX The reserve of Token X.
     * @return reserveY The reserve of Token Y.
     */
    function getReserves() external view returns (uint256, uint256) {
        return (reserveX, reserveY);
    }

    /**
     * @notice Updates the time-weighted average price (TWAP).
     */
    function updateTwap() internal {
        if (block.timestamp >= lastTwapTimestamp + twapInterval) {
            lastTwapPriceX = reserveX;
            lastTwapPriceY = reserveY;
            lastTwapTimestamp = block.timestamp;
            emit TwapUpdated(lastTwapPriceX, lastTwapPriceY, lastTwapTimestamp);
        }
    }

    /**
     * @notice Sets the fee in basis points.
     * @param _feeBasisPoints The new fee in basis points.
     */
    function setFee(uint256 _feeBasisPoints) external onlyGovernor {
        require(_feeBasisPoints < BASIS_POINTS_DIVISOR, "AMM: Invalid fee");
        emit FeeUpdated(feeBasisPoints, _feeBasisPoints);
        feeBasisPoints = _feeBasisPoints;
    }

    /**
     * @notice Adds a new governor.
     * @param _governor The address of the new governor.
     */
    function addGovernor(address _governor) external onlyGovernor {
        require(_governor != address(0), "AMM: Invalid governor address");
        require(!governors[_governor], "AMM: Already a governor");
        governors[_governor] = true;
        governorList.push(_governor);
        emit GovernorAdded(_governor);
    }

    /**
     * @notice Removes an existing governor.
     * @param _governor The address of the governor to remove.
     */
    function removeGovernor(address _governor) external onlyGovernor {
        require(_governor != address(0), "AMM: Invalid governor address");
        require(governors[_governor], "AMM: Not a governor");
        governors[_governor] = false;
        for (uint i = 0; i < governorList.length; i++) {
            if (governorList[i] == _governor) {
                governorList[i] = governorList[governorList.length - 1];
                governorList.pop();
                break;
            }
        }
        emit GovernorRemoved(_governor);
    }

    /**
     * @notice Calculates the square root of a given number.
     * @param y The number to calculate the square root of.
     * @return z The square root of the given number.
     */
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /**
     * @notice Returns the minimum of two numbers.
     * @param x The first number.
     * @param y The second number.
     * @return The minimum of the two numbers.
     */
    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }
}
