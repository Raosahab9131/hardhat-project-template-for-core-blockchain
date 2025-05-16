// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title PredictionMarket
 * @dev Smart contract for creating and participating in prediction markets for real-world events
 */
contract PredictionMarket {
    struct Market {
        string description;
        uint256 endTime;
        bool resolved;
        bool outcome;
        address oracle;
        uint256 totalYesShares;
        uint256 totalNoShares;
        uint256 totalYesStaked;
        uint256 totalNoStaked;
        mapping(address => uint256) yesShares;
        mapping(address => uint256) noShares;
    }

    mapping(uint256 => Market) public markets;
    uint256 public marketCount;
    uint256 public fee = 1; // 1% fee
    address public owner;

    event MarketCreated(uint256 indexed marketId, string description, uint256 endTime, address oracle);
    event SharesPurchased(uint256 indexed marketId, address indexed buyer, bool isYes, uint256 amount);
    event MarketResolved(uint256 indexed marketId, bool outcome);
    event RewardsClaimed(uint256 indexed marketId, address indexed user, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Create a new prediction market
     * @param description Description of the event
     * @param endTime Time when the market closes for betting
     * @param oracle Address authorized to resolve the market
     */
    function createMarket(string memory description, uint256 endTime, address oracle) public {
        require(endTime > block.timestamp, "End time must be in the future");
        require(oracle != address(0), "Invalid oracle address");

        uint256 marketId = marketCount;
        
        Market storage market = markets[marketId];
        market.description = description;
        market.endTime = endTime;
        market.oracle = oracle;
        market.resolved = false;
        
        marketCount++;
        
        emit MarketCreated(marketId, description, endTime, oracle);
    }

    /**
     * @dev Purchase shares in a market prediction
     * @param marketId The ID of the market
     * @param isYes True for Yes shares, False for No shares
     */
    function purchaseShares(uint256 marketId, bool isYes) public payable {
        Market storage market = markets[marketId];
        
        require(!market.resolved, "Market already resolved");
        require(block.timestamp < market.endTime, "Market closed for betting");
        require(msg.value > 0, "Must send ETH to purchase shares");
        
        uint256 feeAmount = (msg.value * fee) / 100;
        uint256 stakeAmount = msg.value - feeAmount;
        
        if (isYes) {
            uint256 shares = calculateShares(stakeAmount, market.totalYesStaked, market.totalYesShares);
            market.yesShares[msg.sender] += shares;
            market.totalYesShares += shares;
            market.totalYesStaked += stakeAmount;
        } else {
            uint256 shares = calculateShares(stakeAmount, market.totalNoStaked, market.totalNoShares);
            market.noShares[msg.sender] += shares;
            market.totalNoShares += shares;
            market.totalNoStaked += stakeAmount;
        }
        
        // Transfer fee to contract owner
        payable(owner).transfer(feeAmount);
        
        emit SharesPurchased(marketId, msg.sender, isYes, stakeAmount);
    }

    /**
     * @dev Resolve a market with the final outcome
     * @param marketId The ID of the market
     * @param outcome True if the event occurred, False if it didn't
     */
    function resolveMarket(uint256 marketId, bool outcome) public {
        Market storage market = markets[marketId];
        
        require(msg.sender == market.oracle, "Only oracle can resolve");
        require(!market.resolved, "Market already resolved");
        require(block.timestamp >= market.endTime, "Market not yet closed");
        
        market.resolved = true;
        market.outcome = outcome;
        
        emit MarketResolved(marketId, outcome);
    }

    /**
     * @dev Claim rewards after market resolution
     * @param marketId The ID of the resolved market
     */
    function claimRewards(uint256 marketId) public {
        Market storage market = markets[marketId];
        
        require(market.resolved, "Market not resolved yet");
        
        uint256 winningShares;
        uint256 reward = 0;
        
        if (market.outcome) {
            // Yes was correct
            winningShares = market.yesShares[msg.sender];
            if (winningShares > 0 && market.totalYesShares > 0) {
                reward = (winningShares * (market.totalYesStaked + market.totalNoStaked)) / market.totalYesShares;
                market.yesShares[msg.sender] = 0;
            }
        } else {
            // No was correct
            winningShares = market.noShares[msg.sender];
            if (winningShares > 0 && market.totalNoShares > 0) {
                reward = (winningShares * (market.totalYesStaked + market.totalNoStaked)) / market.totalNoShares;
                market.noShares[msg.sender] = 0;
            }
        }
        
        require(reward > 0, "No rewards to claim");
        
        payable(msg.sender).transfer(reward);
        
        emit RewardsClaimed(marketId, msg.sender, reward);
    }

    // Helper function to calculate shares based on stake amount
    function calculateShares(uint256 stakeAmount, uint256 totalStaked, uint256 totalShares) private pure returns (uint256) {
        if (totalStaked == 0 || totalShares == 0) {
            return stakeAmount;
        }
        return (stakeAmount * totalShares) / totalStaked;
    }
}
