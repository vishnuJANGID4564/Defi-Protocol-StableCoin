// SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {Script} from "lib/forge-std/src/Script.sol";
import {DecentralisedStableCoin} from "src/DecentralisedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns(DecentralisedStableCoin, DSCEngine, HelperConfig) {
        vm.startBroadcast();
        HelperConfig config = new HelperConfig();

        (address wethUSDPriceFeed,
        address wbtcUSDPriceFeed,
        address weth,
        address wbtc,
        uint256 deployerkey) = config.activeNetworkConfig();

        tokenAddresses = [weth,wbtc];
        priceFeedAddresses = [wethUSDPriceFeed, wbtcUSDPriceFeed];

        DecentralisedStableCoin dsc = new DecentralisedStableCoin();
        DSCEngine dscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        // we need to transfer the ownership of the dsc to dscEngine so that it can contral the DSC
        dsc.transferOwnership(address(dscEngine));
        
        vm.stopBroadcast();
        return (dsc , dscEngine,config);
    }
}