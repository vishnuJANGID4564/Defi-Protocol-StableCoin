// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions



// SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {DecentralisedStableCoin} from "src/DecentralisedStableCoin.sol";
import {ReentrancyGuard} from "lib/openzepplin-contracts/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "lib/openzepplin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
* @dev IERC20 is an interface that defines a standard set of functions that ERC20 tokens must implement. 
*      This standardization ensures that all ERC20 tokens behave consistently, 
*      making it easier for developers to interact with any ERC20 token using the same interface
*/

/** 
 * @title DSCEngine
 * @author Patrick Collins
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */

contract DSCEngine is ReentrancyGuard{
        //////////////////////////
        //// Errors ////
        ////////////////////////
        error DSCEngine__AmountEnteredIsZero();
        error DSCEngine__UnEqualTokenAddresses_And_priceFeedAddresses();
        error DSCEngine__TokenNotAllowed();
        error DSCEngine__TransferFailed();
        error DSCEngine__breaksHealthFactor(uint256 healthFactor);
        error DSCEngine__MintFailed();
        error DSCEngine__HealthFactorIsOk();
        error DSCEngine__HealthFactorNotImproved();

        //////////////////////////
        //// State Variables ////
        ////////////////////////
        DecentralisedStableCoin private immutable i_dsc;
        uint256 private constant ADDITIONAL_FEED_PRECISSION = 1e10;
        uint256 private constant FEED_PRECISSION = 1e18;
        uint256 private constant LIQUIDATION_THRESHOLD = 50; // means we need to be 200% over collateralised
        uint256 private constant LIQUIDATION_PRECISSION = 100;
        uint256 private constant MIN_HEALTH_FACTOR = 1e18;
        uint256 private constant LIQUIDATION_BONUS = 10; // means 10% bonus 

        //mapping(address => bool) private s_tokenToPriceFeed; 
        // as we know we would be usign price feeds 
        // its better to use the given below mapping than the above one as:-
        mapping(address token => address priceFeed) private s_tokenToPriceFeed; 
        /**      This mapping directly associates each token address with the address of its corresponding price feed contract. 
             This is more informative because it allows you to retrieve the actual price feed address for a given token,
               which you can then use to fetch price data.
        */

        // as we need to store that how much of which token has been submitted as collateral
        mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

        //we need to have an account of the minted DSC for the user
        mapping(address user => uint256 amountDSCMinted) private s_DSCMinted;
        address[] private s_collateralTokens; 
        

        //////////////////////////
        //// Events          ////
        //////////////////////// 
        event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
        event CollateralRedeemed(address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount);

        //////////////////////////
        //// Modifier        ////
        ////////////////////////
        modifier morethanZero(uint256 amount){
                if(amount == 0){
                        revert DSCEngine__AmountEnteredIsZero();
                }
                _;
        }
        modifier isAllowedToken(address token){
                if(s_tokenToPriceFeed[token]==address(0)){
                        revert DSCEngine__TokenNotAllowed();
                }
                _;
        }

        //////////////////////////
        //// Functions       ////
        ////////////////////////

        //constructor
        /**
        * @param dscAddress is the address of the deployed DecentralisedStableCoin contract
        */
        constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress){
                if(tokenAddresses.length != priceFeedAddresses.length ){
                        revert DSCEngine__UnEqualTokenAddresses_And_priceFeedAddresses();
                }

                for(uint256 i=0 ; i<tokenAddresses.length;i++){
                        s_tokenToPriceFeed[tokenAddresses[i]] = priceFeedAddresses[i];
                        s_collateralTokens.push(tokenAddresses[i]);
                }
                i_dsc = DecentralisedStableCoin(dscAddress);// you must be wondering that Decent. constructor didn't have any param as this 
                /**
                @notice this is done to :- 
                ->  creates an instance of the DecentralisedStableCoin contract at the specified address.
                ->  This allows the DSCEngine contract to call functions and interact with the DecentralisedStableCoin contract.
                This approach is common in Ethereum smart contract development 
                where one contract (in this case, DSCEngine) needs to interact with another contract (DecentralisedStableCoin). 
                ```````````By passing the contract address, you can easily set up these interactions.```````````````
                */

        }

        //////////////////////////
        //// External Functions ////
        ////////////////////////

        /**
        *  @param tokenCollateralAddress is the address to the token to deposit as collateral 
        *  @param amountCollateral is the amount to be considered as collateral
        *  @param amountDscToMint is the amount of DSC to Mint 
        *  
        * @notice this function deposites collateral and mint DSC in 1 Txn 
        */
        function depositCollateralAndMintDSC(
                address tokenCollateralAddress, 
                uint256 amountCollateral, 
                uint256 amountDscToMint
        )       
                external 
        {
                depositCollateral(tokenCollateralAddress, amountCollateral);
                mintDSC(amountDscToMint);
        }

        /**
        *  @param tokenCollateralAddress is the address to the token to deposit as collateral 
        *  @param amountCollateral is the amount to be considered as collateral 
        *  @notice we are following CEI (Check Effects Interactions)
        *  @notice As here we are accessing External COntracts so there is a threat of Reentrancy hence we are using nonReentrat modifier
        */
        function depositCollateral(
                address tokenCollateralAddress, 
                uint256 amountCollateral
        )       
                public 
                morethanZero(amountCollateral)
                isAllowedToken(tokenCollateralAddress)
                nonReentrant                    
        {
                // we need to know that how much of which token have they deposited 
                s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
                emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

                bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender,address(this), amountCollateral);
                //The `transferFrom` function is a standard function in the ERC20 token interface that allows 
                //a contract to transfer tokens on behalf of a token holder, given that the token holder has 
                //approved the contract to do so beforehand.
                if(!success){
                        revert DSCEngine__TransferFailed();
                }

        }

        /**
        * @dev this fucntion burns DSC and redeems the colateral in 1 Txn
        * @notice as directly redeeming the collareral will hit the hf and chances of unwanted liquidation.
        * 1. burn DSC
        * 2. Redeem Colateral 
        */
        function redeemCollateralForDSC(
                address tokenCollateralAddress,
                uint256 amountCollateralToPullOut,
                uint256 amountDSCToBurn
        )       external 
        {
                burnDSC(amountDSCToBurn);
                redeemCollateral(tokenCollateralAddress, amountCollateralToPullOut);
                /**@notice no need to check for hf here as reddemCollateral already has the check  */
        }

        /**
        @notice here we need to make sure that the the hf is >1 even after the collateral pull out   
        */
        function redeemCollateral(
                address tokenCollateralAddress,
                uint256 amountCollateralToPullOut
        ) 
                public
                morethanZero(amountCollateralToPullOut)
                nonReentrant
        {
        /** @notice solidity by itself revert to any overflow or underflow in case of  arithmatic operations 
        *   @notice msg.sender for both from and to as, if some person has to redeem other's collateral then it will call _redeemCollateral function instead. 
        *                if someone calls redeemCollateral then it means that he wants to redeems his collateral so from and to are same(msg.sender)
        */
                _redeemCollateral(tokenCollateralAddress, amountCollateralToPullOut, msg.sender, msg.sender);
                _revertIfHealthFactorIsBroken(msg.sender);
        }

        /**
        * @param amountDSCMinted is the amount of DSC the user want to mint
        * @notice Collateral value need to be more than the minimum threshhold
        */
        function mintDSC(uint256 amountDSCMinted) public morethanZero(amountDSCMinted){
                s_DSCMinted[msg.sender] += amountDSCMinted;
                // we need to check if they have minted too much (for eg $150 DSC, $100 ETH)
                _revertIfHealthFactorIsBroken(msg.sender);

                bool minted = i_dsc.mint(msg.sender, amountDSCMinted);
                if(!minted){
                        revert DSCEngine__MintFailed();
                }
        }

        function burnDSC(uint256 amount) public morethanZero(amount){
                _burnDSC(amount, msg.sender, msg.sender);
                // so if someone calls burnDSC then they are are burning onbehalf of themselves from themselves
        }

        // If someone is undercollateralised, we will pay the liquidator to liquidate them 
        /**
        * @param collateral is the erc20 collateral address that needs to be liquidated
        * @param user is the one who broke the health-factor. his/her hf is below MIN_HEALTH_FACTOR
        * @param debtToCover is the amount of DSC that the liquidator wants to liquidate in order to improve the user's hf

        * @notice You can partially liquidate someone. 
        * @notice You will be incentivised to liquidate people and take their funds 
        * @notice This function works with an understanding that the protocol is roughly over-collateralised(200%) 

        * @notice If the protocol is 100% or less collateralised then we wouldn't be able to incentivise the liquidator 
        * For Eg. $75 ETH backing $50 DSC -> undercollateralised => but here the liquidator will be incentivised
        *          $20 ETH backing $50 DSC -> undercollateralised => but here the liquidator will not be incentivised
        *                               also just think by yourself, why would someone pay off $50 worth of DSC for $20 ETH Funds 
         */
        function liquidate(
                address collateral,
                address user,
                uint256 debtToCover
        ) 
                external 
                morethanZero(debtToCover)
        {
                uint256 initialHealthFactor = _getHealthFactor(user);
                if(initialHealthFactor >= MIN_HEALTH_FACTOR){
                        revert DSCEngine__HealthFactorIsOk();
                }
                // we need to burn the DSC and take the collateral 
                // $140 ETH backing $100 DSC -> undercollateralised
                // debt to Cover = $100 
                // $100 DSC = ?? ETH
                uint256 tokenAmountFromDebtToCover = getTokenAmountFromUSD(collateral,debtToCover);
                // we are giving them an extra 10% incentive
                uint256 bonusCollateral = (tokenAmountFromDebtToCover * LIQUIDATION_BONUS)/LIQUIDATION_PRECISSION ;
                uint256 totalCollateralToRedeem = tokenAmountFromDebtToCover + bonusCollateral;
                // this need to be redeemed to the one calling this function(liquidator)
                _burnDSC(debtToCover, user, msg.sender);
                _redeemCollateral(collateral, totalCollateralToRedeem, user, msg.sender);

                uint256 finalHealthFactor = _getHealthFactor(user);
                if(finalHealthFactor <= initialHealthFactor){
                        revert DSCEngine__HealthFactorNotImproved();
                }
                // we need to check that if liquidator's hf is fine or not tooo
                _revertIfHealthFactorIsBroken(msg.sender);

        }

        function getHealthFactor() external view {}     


        /////////////////////////////////////////
        //// Private and Internal view Functions /////
        ////////////////////////////////////////

        function _burnDSC(
                uint256 amountDSCToBurn,
                address onbehalfOf,
                address dscFrom
        )
                private
                morethanZero(amountDSCToBurn)
        {
                s_DSCMinted[onbehalfOf] -= amountDSCToBurn;
                // we need to transer the dsc from the msg.sender => somewhere(lets say to this DSCEngine contract)
                bool success = i_dsc.transferFrom(dscFrom, address(this), amountDSCToBurn);
                if(!success){
                        revert DSCEngine__TransferFailed();
                }
                i_dsc.burn(amountDSCToBurn);
        }
        
        function _redeemCollateral(
                address tokenCollateralAddress, 
                uint256 amountCollateralToPullOut, 
                address from, 
                address to
        )       
                private 
                morethanZero(amountCollateralToPullOut)
        {
                s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateralToPullOut;
                emit CollateralRedeemed(from,to,tokenCollateralAddress, amountCollateralToPullOut);
                bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateralToPullOut);
                if(!success){
                        revert DSCEngine__TransferFailed();
                }
        } 

        /**
        * @notice figures out that how close is the user to get liquidated 
        * If (Hf < 1) => the user if more likely to be liquidated
        */
        function _getHealthFactor(address user) private view returns(uint256){
                // total DSC minted 
                // total Collateral VALUE
                (uint256 totalDSCMinted, uint256 totalCollateralValueInUSD) = _getAccountInfo(user);
                // you cannot just return (totalCollateralValueInUSD / totalDSCMinted) 
                // imagine you have  $150 ETH and $100 DSC  150/100 == 1.5 => 1 (solidity don't consider floating numbers)
                // we want Over collateralised 
                // as the LIQUIDATION_THRESHOLD is set to be 50 and LIQUIDATION PRESION is set to be 100 we are expecting 200% over collateralisation
                uint256 collateralAdjustedForThreshold = (totalCollateralValueInUSD * LIQUIDATION_THRESHOLD)/ LIQUIDATION_PRECISSION ;
                // 150 * 50 = 7500 /100 = 75  and 75/100 < 1 
                // 200 *50 = 10000/100 = 100 and 100/100 = 1
                // now for x>200 hf >1 so acc to the parameters we set atleast 100% over collateralisation is necesarry for hf>=1 ;
                // $1000 ETH / $100 DSC  => 1000*50 = 50000, 50000/100 = 500, 500/100 >1 

                /** @notice The main aim for doing all this adjustment in collateral value is that so that i can take into account 
                *              the over colllateralisation in the collateral before calculating hf 
                 */
                return (collateralAdjustedForThreshold * FEED_PRECISSION) / totalDSCMinted; 
                
        }

        function _getAccountInfo(address user) private view returns(uint256 totalDSCMinted, uint256 totalCollateralValueInUSD){
                totalDSCMinted = s_DSCMinted[user];
                totalCollateralValueInUSD = getAccountCollateralValue(user); // this getAccountCollateralValue should be public fucntion so that anybody can call that 
        }

        function _revertIfHealthFactorIsBroken(address user) internal view {
                // 1. check the health factor(if they have enough collateral)
                // 2. revert if not 
                uint256 userHealthFactor = _getHealthFactor(user);
                if(userHealthFactor < MIN_HEALTH_FACTOR){
                        revert DSCEngine__breaksHealthFactor(userHealthFactor);
                }

        }

        /////////////////////////////////////////
        //// Public and External view Functions /////
        ////////////////////////////////////////

        function getTokenAmountFromUSD(address collateral, uint256 usdAmountInWei) public view returns(uint256){
                // liquidator know how much $ worth of debt he/she need to cover 
                // he needs to knoe how much of ETH is that equivalent to 
                AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokenToPriceFeed[collateral]);
                (,int256 price,,,) = priceFeed.latestRoundData();
                // ($10e18 * 1e18 ) / (2000e8 * 1e10) 
                return (usdAmountInWei * FEED_PRECISSION)/(uint256(price)*ADDITIONAL_FEED_PRECISSION);
        }

        function getAccountCollateralValue(address user) public view returns(uint256 totalCollateralValueInUSD){
                // looping through all tokens getting the amount deposited in each and then acc to thier price get the ans

                for(uint256 i=0; i<s_collateralTokens.length; i++){
                        address token = s_collateralTokens[i];
                        uint256 amount = s_collateralDeposited[user][token];
                        // now need to get the price in USD -> pricefeeds by aggregatorV3Interface
                        totalCollateralValueInUSD += getUSDValue(token, amount);
                }
        }

        /** @notice returned value from Chainlink would be x*1e8 (due to 8 decimals for ETH/USD and BTC/USD)
        *   @param amount typically represents the number of tokens, which might have its own decimal precision. 
        *               For example, if dealing with an ERC-20 token, the amount might be given in units that consider 18 decimals.
        *
        *   @notice (xe8 * ye18) => can lead to ``PRECISSION ERROR``
        *       Therefore,    (xe8 * 1e10) * ye18 = xye36 =>  xye36/ 1e18 = xye18 
        */
        function getUSDValue(address token, uint256 amount) public view returns(uint256){
                AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokenToPriceFeed[token]);
                (,int256 price,,,) = priceFeed.latestRoundData();
                /** @notice next step is done to mitigate PRECISSION ERROR */
                return ((uint256(price) * ADDITIONAL_FEED_PRECISSION) * amount) / FEED_PRECISSION;
        }

        function getAccountInfo(address user) external view returns(uint256 totalDSCMinted, uint256 totalCollateralValueInUSD){
                ( totalDSCMinted,totalCollateralValueInUSD) = _getAccountInfo(user);
        }
}