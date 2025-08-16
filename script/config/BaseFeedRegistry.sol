// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title BaseFeedRegistry
 * @notice Registry of Chainlink price feed addresses on Base network
 * @dev Separate mainnet and testnet configurations
 */
library BaseFeedRegistry {
    // ============ Base Mainnet Feeds (Chain ID: 8453) ============
    
    struct FeedConfig {
        address token;
        address feed;
        string description;
    }
    
    /**
     * @notice Get Base mainnet Chainlink price feeds
     * @dev Verified feeds from: https://docs.chain.link/data-feeds/price-feeds/addresses?network=base
     */
    function getMainnetFeeds() internal pure returns (FeedConfig[] memory) {
        FeedConfig[] memory feeds = new FeedConfig[](3);
        
        // ETH/USD - Most important feed
        feeds[0] = FeedConfig({
            token: 0x4200000000000000000000000000000000000006, // WETH on Base
            feed: 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70,  // ETH/USD feed
            description: "ETH/USD"
        });
        
        // cbETH/USD - Coinbase ETH
        feeds[1] = FeedConfig({
            token: 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22, // cbETH on Base
            feed: 0xd7818272B9e248357d13057AAb0B417aF31E817d,  // cbETH/USD feed
            description: "cbETH/USD"
        });
        
        // USDC/USD - Though we handle USDC specially, can add for completeness
        feeds[2] = FeedConfig({
            token: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, // USDC on Base
            feed: 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B,  // USDC/USD feed
            description: "USDC/USD"
        });
        
        return feeds;
    }
    
    /**
     * @notice Get Base Sepolia testnet Chainlink price feeds
     * @dev Testnet feeds for development and testing
     */
    function getSepoliaFeeds() internal pure returns (FeedConfig[] memory) {
        FeedConfig[] memory feeds = new FeedConfig[](2);
        
        // ETH/USD on Base Sepolia
        feeds[0] = FeedConfig({
            token: 0x4200000000000000000000000000000000000006, // WETH on Base Sepolia
            feed: 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1,  // ETH/USD feed on Base Sepolia
            description: "ETH/USD Sepolia"
        });
        
        // BTC/USD on Base Sepolia (if available)
        feeds[1] = FeedConfig({
            token: address(0), // BTC wrapper address when available
            feed: 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298,  // BTC/USD feed on Base Sepolia
            description: "BTC/USD Sepolia"
        });
        
        return feeds;
    }
    
    /**
     * @notice Token addresses on Base mainnet
     */
    function getTokenAddresses() internal pure returns (address, address, address, address) {
        address USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        address WETH = 0x4200000000000000000000000000000000000006;
        address cbETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
        address DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb; // DAI on Base
        
        return (USDC, WETH, cbETH, DAI);
    }
}