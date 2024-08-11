// SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {Script} from "lib/forge-std/src/Script.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "lib/openzepplin-contracts/contracts/mocks/ERC20Mock.sol";


contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUSDPriceFeed;
        address wbtcUSDPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerkey;
    }

    NetworkConfig public activeNetworkConfig;
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    uint256 public constant INITIAL_BALANCE = 1000e8;
    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaETHConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilETHConfig();
        }
    }

    function getSepoliaETHConfig() public view returns(NetworkConfig memory){
        return NetworkConfig({
            wethUSDPriceFeed : 0x694AA1769357215DE4FAC081bf1f309aDC325306,  // you can get these from the chainlink docs-> data-feeds -> price-feeds
            wbtcUSDPriceFeed : 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,  // 
            weth : 0xdd13E55209Fd76AfE204dBda4007C227904f0a81, // got it from the Course github, you can write your own weth and use its address too ig 
            wbtc : 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerkey : vm.envUint("PRIVATE_KEY")
        });
    } 

    function getOrCreateAnvilETHConfig() public returns(NetworkConfig memory){
        if(activeNetworkConfig.wethUSDPriceFeed != address(0)){
            // already configured
            return activeNetworkConfig;
        }

        // vm.startBroadcast(); 
        MockV3Aggregator ethUSDPriceFeed = new MockV3Aggregator(DECIMALS,ETH_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, INITIAL_BALANCE);

        MockV3Aggregator btcUSDPriceFeed = new MockV3Aggregator(DECIMALS,ETH_USD_PRICE);
        ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, INITIAL_BALANCE);

        // vm.stopBroadcast();
        return NetworkConfig({
            wethUSDPriceFeed : address(ethUSDPriceFeed),
            wbtcUSDPriceFeed : address(btcUSDPriceFeed),
            weth : address(wethMock),
            wbtc : address(wbtcMock),
            deployerkey : DEFAULT_ANVIL_KEY
        });
    }

}