// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20 {

    address public cryptoDevTokenAddress;


    // Exchange is inheriting ERC20, because our exchange would keep track of Crypto Dev LP tokens
    // _cryptodevtoken is the address of the token to be traded on the dex
    constructor(address _CryptoDevtoken) ERC20("CryptoDev LP Token", "CDLP") {
        require(_CryptoDevtoken != address(0), "Token address passed is a null address");
        cryptoDevTokenAddress = _CryptoDevtoken;
    }

    
    //There is need to get the reserves of the Eth and Crypto Dev tokens held by the contract.
    //No need writing a function to get eth reserve because The ETH reserve would be equal to the balance of the contract and can be found using address(this).balance
    //this function returns the amount of `Crypto Dev Tokens` held by the contract
    function getReserve() public view returns (uint) {
        return ERC20(cryptoDevTokenAddress).balanceOf(address(this));
    }


    //ADD LIQUIDITY
    function addLiquidity(uint _amount) public payable returns (uint) {
        uint liquidity;
        uint ethBalance = address(this).balance;
        uint cryptoDevTokenReserve = getReserve();
        ERC20 cryptoDevToken = ERC20(cryptoDevTokenAddress);

        // if the reserve is empty i.e for the first person adding liquidity
        if(cryptoDevTokenReserve == 0) {
            // Transfer the `cryptoDevToken` from the user's account to the contract
            cryptoDevToken.transferFrom(msg.sender, address(this), _amount);

            //since liquidity is the LP token to be minted, and being the first LP provider
            // it will be the same as the eth balance in the LP-contract
             liquidity = ethBalance;
            _mint(msg.sender, liquidity);

        // do this is there is liquidity in the reserve already    
        }else{
            //get the eth in the reserve by subtracting what the user supply now from the ether
            // balance in the contract so as to calculate the corresponding CD token to supply
            uint ethReserve =  ethBalance - msg.value;
            uint cryptoDevTokenAmount = (msg.value * cryptoDevTokenReserve)/(ethReserve);
            cryptoDevToken.transferFrom(msg.sender, address(this), cryptoDevTokenAmount);

            //mint the LP tokens based on the ratio supplied
            liquidity = (totalSupply() * msg.value)/ ethReserve;
            _mint(msg.sender, liquidity);
        }
        return liquidity;

    }
}