// SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {ERC20} from "lib/openzepplin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "lib/openzepplin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "lib/openzepplin-contracts/contracts/access/Ownable.sol";
/** 
*  @title DecentralisedStableCoin
*  @author Vishnu Sharma
*  Collateral-Type: Exogenous (wETH and wBTC)
*  Stablility-Mech : Algorithmic 
*  Relative Stablitly : Pegged to USD
*
* This is a contract ment to be governed by DSCEngine. This contract is an ERC20 implementation of a stableCoin system
*
* As we want this contract to be completely controled by our logic, we need to make this OWNABLE 
* which means that we will have an onlyOwner modifier and the owner would be the the Logic 
*/
contract DecentralisedStableCoin is ERC20Burnable, Ownable{
    error DecentralisedStableCoin__AmountMustBePositive();
    error DecentralisedStableCoin__AmountMustBeLessThanBalance();
    error DecentralisedStableCoin__NotMintingToZeroAddress();

    
    constructor () ERC20("DecentralisedStableCoin","DSC") {}

    function burn(uint256 _amount) public virtual override onlyOwner{
        uint256 balance = balanceOf(msg.sender);
        if(_amount<=0){
            revert DecentralisedStableCoin__AmountMustBePositive();
        }
        if(_amount > balance){
            revert DecentralisedStableCoin__AmountMustBeLessThanBalance();
        }
        super.burn(_amount); // super keyword is used for refereing to the parent contract 
        // ie, this will run the burn function in ERC20Burnable with amount 
        // helpful in situations where u have to add some additionals with the pre-existing function 
    }

    function mint(address _to, uint256 _amount) external view onlyOwner returns(bool){
        // here no need to override as ERC20 nor the ERC20Burnable has mint function they have_mint function 
        if(_to == address(0)){
            revert DecentralisedStableCoin__NotMintingToZeroAddress();
        }
        if(_amount <=0){
            revert DecentralisedStableCoin__AmountMustBePositive();
        } 
        return true;
    }


}