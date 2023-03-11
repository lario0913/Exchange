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

    // REMOVE LIQUIDITY
    function removeLiquidity(uint _amount) public returns (uint , uint) {
        require(_amount > 0, "_amount should be greater than zero");
        uint ethReserve = address(this).balance;
        uint _totalSupply = totalSupply();

        // NB _amount = LP token to be removed and _totalSupply = TS of LP tokens
        //So the formular remains => _amount/_totalSupply = EthtoRemove/EthReserve
        // Get respective Eth and CD tokens to be returned to user
        uint ethAmount = (ethReserve * _amount)/ _totalSupply;
        uint cryptoDevTokenAmount = (getReserve() * _amount)/ _totalSupply;

        // burn the LP tokens received
        _burn(msg.sender, _amount);

        // Transfer `ethAmount` of Eth from the contract to the user's wallet
        payable(msg.sender).transfer(ethAmount);
    
        // Transfer `cryptoDevTokenAmount` of Crypto Dev tokens from the contract to the user's wallet
        ERC20(cryptoDevTokenAddress).transfer(msg.sender, cryptoDevTokenAmount);
        return (ethAmount, cryptoDevTokenAmount);
    }

    
    
    // SWAPPING FUNCTIONALITY
    // the swap functionality is gotten from the calculationsz assumtions (charge fee 0f 1%) and assignments below
    // We need to make sure (x + Δx) * (y - Δy) = x * y
    // So the final formula is Δy = (y * Δx) / (x + Δx)
    // Δy in our case is `tokens to be received`
    // Δx = ((input amount)*99)/100, x = inputReserve, y = outputReserve
    // So by putting the values in the formulae you can get the numerator and denominator
    function getAmountOfTokens(
    uint256 inputAmount, // Δx
    uint256 inputReserve, // x
    uint256 outputReserve // y
    ) public pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");
        uint256 inputAmountWithFee = inputAmount * 99;
        uint256 numerator = inputAmountWithFee * outputReserve; //(y * Δx)
        uint256 denominator = (inputReserve * 100) + inputAmountWithFee; //(x + Δx)
        return numerator / denominator;
    }

    // implementing Eth to CD swaps
    function ethToCryptoDevToken(uint _minTokens) public payable {
    uint256 tokenReserve = getReserve();
    // Notice that the `inputReserve` we are sending is equal to
    // `address(this).balance - msg.value` instead of just `address(this).balance`
    // because `address(this).balance` already contains the `msg.value` user has sent in the given call
    uint256 tokensBought = getAmountOfTokens(
        msg.value, // change in x
        address(this).balance - msg.value, // x
        tokenReserve // y
    );

    require(tokensBought >= _minTokens, "insufficient output amount");
    // Transfer the `Crypto Dev` tokens to the user
    ERC20(cryptoDevTokenAddress).transfer(msg.sender, tokensBought);
    }

    //implementinf CD to ETh swaps
    function cryptoDevTokenToEth(uint _tokensSold, uint _minEth) public {
    uint256 tokenReserve = getReserve();
    // call the `getAmountOfTokens` to get the amount of Eth
    // that would be returned to the user after the swap
    uint256 ethBought = getAmountOfTokens(
        _tokensSold,
        tokenReserve,
        address(this).balance
    );
    require(ethBought >= _minEth, "insufficient output amount");

    // Transfer `Crypto Dev` tokens from the user's address to the contract
    ERC20(cryptoDevTokenAddress).transferFrom( msg.sender, address(this), _tokensSold);
    
    // send the `ethBought` to the user from the contract
    payable(msg.sender).transfer(ethBought);
    }
}