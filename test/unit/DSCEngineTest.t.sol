// SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {Test} from "lib/forge-std/src/Test.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DecentralisedStableCoin} from "src/DecentralisedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "lib/openzepplin-contracts/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralisedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;

    address ethUSDPriceFeed;
    address btcUSDPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant COLLATERAL_AMOUNT = 10 ether;
    uint256 public constant USER_INITIAL_BALANCE = 100 ether;

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc,engine,config) = deployer.run();
        // (ethUSDPriceFeed, ,weth, ,) = config.activeNetworkConfig();
        (ethUSDPriceFeed,
        btcUSDPriceFeed,
        weth,
        ,
        ) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, USER_INITIAL_BALANCE);
    }

    /**
    * CONSTRUCTOR TESTS
    */
    function testRevertIfTokenAddressLengthNotMatchPriceFeedAddress() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUSDPriceFeed);
        priceFeedAddresses.push(btcUSDPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__UnEqualTokenAddresses_And_priceFeedAddresses.selector);
        new DSCEngine(tokenAddresses,priceFeedAddresses,address(dsc));
    }

    /**
    * PRICE TESTS
     */

    function testGetTokenUSDValue() public view{
        uint256 tokenUSDValueInWei = 100 ether;
        // $2000/ ETH, 100$ => 100/2000 = 0.05 
        uint256 expectedValue = 0.05 ether;
        uint256 obtainedValue = engine.getTokenAmountFromUSD(weth, tokenUSDValueInWei);
        assertEq(expectedValue, obtainedValue);
    }

    function testgetUsdValue() public view {
        uint256 ethAmount = 15e18; // 15eth
        uint256 expectedUSDValue = 30000e18; // 15e18*2000 = 30000e18
        uint256 obtainedUSDValue = engine.getUSDValue(weth, ethAmount);
        assertEq(expectedUSDValue, obtainedUSDValue);
    }

    /**
    * COLLATERAL DEPOSIT TEST
    */
    function testRevertIfCollateralIsZero() public {
        vm.startPrank(USER);
        //we need to aproove that the token can go to the protocol
        // ERC20Mock(weth).approve(address(engine),COLLATERAL_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__AmountEnteredIsZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertIfUnapprovedCollateralToken() public {
        // lets have a random token 
        ERC20Mock randomToken = new ERC20Mock("RAN","RAN",USER,COLLATERAL_AMOUNT);
        // now user se deposite karwate h 
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        engine.depositCollateral(address(randomToken), COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    modifier depositCollateral(){
        vm.startPrank(USER);
        // first need to approve weth 
        ERC20Mock(weth).approve(address(engine), COLLATERAL_AMOUNT);
        engine.depositCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testDepositCollateralAndGetAccountInfo() public depositCollateral{
        ( uint256 totalDSCMinted, uint256 collateralValueInUSD ) = engine.getAccountInfo(USER);

        uint256 expectedDSCMinted = 0;
        uint256 expectedCollateralValueInUSD = engine.getAccountCollateralValue(USER);
        assertEq(expectedDSCMinted, totalDSCMinted);
        assertEq(expectedCollateralValueInUSD, collateralValueInUSD);
    }
}
