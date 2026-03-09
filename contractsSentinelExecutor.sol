// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

/**
 * @title Sentinel Executor - Co-Pilot Intelligence with Critic Modules
 * @dev Validates and executes trades with multi-layered safety checks
 * @notice NOT just a signature checker - A CRITIC AND GUARDIAN
 */
contract SentinelExecutor is Ownable, ReentrancyGuard {
    // ============ STRUCTS ============
    struct TradeProposal {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 deadline;
        bytes swapData; // Encoded path and fee for Uniswap V3
        uint256 signalStrength; // 0-100, from signal agents
        uint256 agentConsensus; // Bitmask of agent approvals
    }
    
    struct OracleData {
        int256 chainlinkPrice;
        uint256 chainlinkTimestamp;
        uint256 uniswapTWAP;
        uint256 pythPrice;
        uint256 pythConfidence;
    }
    
    // ============ CONSTANTS ============
    uint256 public constant MAX_SLIPPAGE_BPS = 200; // 2%
    uint256 public constant MIN_SIGNAL_STRENGTH = 70; // 70/100 required
    uint256 public constant MIN_AGREEMENT = 2; // 2 of 3 agents must agree
    uint256 public constant TRADE_COOLDOWN = 5 minutes;
    
    // ============ IMMUTABLES ============
    address public immutable vault;
    ISwapRouter public immutable uniswapRouter;
    AggregatorV3Interface public immutable chainlinkFeed;
    address public immutable pythAddress;
    
    // ============ STATE VARIABLES ============
    mapping(address => uint256) public lastTradeTime;
    mapping(bytes32 => bool) public executedHashes;
    
    uint256 public totalTradesExecuted;
    uint256 public totalTradesRejected;
    uint256 public totalMEVAttemptsBlocked;
    
    // ============ EVENTS ============
    event TradeExecuted(
        bytes32 indexed tradeHash,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 slippageBps,
        uint256 gasUsed,
        uint256 timestamp
    );
    
    event TradeRejected(
        bytes32 indexed