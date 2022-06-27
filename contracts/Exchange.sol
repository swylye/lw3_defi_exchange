// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Build an exhange with only one asset pair (Eth <> Crypto Dev)
// Your Decentralized Exchange should take a fees of 1% on swaps
// When user adds liquidity, they should be given Crypto Dev LP tokens (Liquidity Provider tokens)
// CD LP tokens should be given propotional to the Ether user is willing to add to the liquidity

contract Exchange is ERC20, Ownable {
    address public cryptoDevTokenAddress;

    uint256 public tokenSwapFees;
    uint256 public ethSwapFees;

    constructor(address _cryptoDevTokenAddress)
        ERC20("CryptoDev LP Token", "CDLP")
    {
        require(
            _cryptoDevTokenAddress != address(0),
            "Token address must not be null!"
        );
        cryptoDevTokenAddress = _cryptoDevTokenAddress;
    }

    function getReserve() public view returns (uint256) {
        return ERC20(cryptoDevTokenAddress).balanceOf(address(this));
    }

    function addLiquidity(uint256 _amount) public payable returns (uint256) {
        require(_amount > 0, "Token amount must be more than 0");
        require(msg.value > 0, "ETH amount must be more than 0");

        uint256 liquidity;
        uint256 ethBalance = address(this).balance;
        uint256 tokenBalance = getReserve();
        ERC20 cryptoDevToken = ERC20(cryptoDevTokenAddress);

        if (tokenBalance == 0) {
            cryptoDevToken.transferFrom(msg.sender, address(this), _amount);
            liquidity = msg.value;
            _mint(msg.sender, liquidity);
        } else {
            uint256 ethBalanceBefore = ethBalance - msg.value;
            uint256 correctTokenAmount = (msg.value / ethBalanceBefore) *
                tokenBalance;
            require(
                _amount >= correctTokenAmount,
                "Token amount sent is too low!"
            );

            cryptoDevToken.transferFrom(msg.sender, address(this), _amount);

            liquidity = (totalSupply() * msg.value) / ethBalanceBefore;
            _mint(msg.sender, liquidity);
        }
        return liquidity;
    }

    function removeLiquidity(uint256 _amount)
        public
        returns (uint256, uint256)
    {
        require(_amount > 0, "LP token amount must be more than 0!");
        require(
            _amount <= balanceOf(msg.sender),
            "You must have enough LP tokens to remove!"
        );

        uint256 ethBalance = address(this).balance;
        uint256 tokenBalance = getReserve();

        uint256 ethReturn = (ethBalance * _amount) / totalSupply();
        uint256 tokenReturn = (tokenBalance * _amount) / totalSupply();

        ERC20 cryptoDevToken = ERC20(cryptoDevTokenAddress);

        _burn(msg.sender, _amount);

        payable(msg.sender).transfer(ethReturn);
        cryptoDevToken.transfer(msg.sender, tokenReturn);

        return (ethReturn, tokenReturn);
    }

    function getAmountOfTokens(
        uint256 _inputAmount,
        uint256 _inputReserve,
        uint256 _outputReserve
    ) public pure returns (uint256, uint256) {
        require(_inputReserve > 0 && _outputReserve > 0, "Invalid reserves!");
        uint256 oriOutputAmount = (_outputReserve * _inputAmount) /
            (_inputAmount + _inputReserve);
        uint256 finalOutputAmount = (oriOutputAmount * 99) / 100;
        return (finalOutputAmount, oriOutputAmount - finalOutputAmount);
    }

    function ethToCryptoDevToken(uint256 _minAmount) public payable {
        require(msg.value > 0, "You have not transferred any ETH!");
        uint256 ethBalance = address(this).balance;
        uint256 ethBalanceBefore = ethBalance = msg.value;
        uint256 tokenBalance = getReserve();
        (uint256 boughtAmount, uint256 feeAmount) = getAmountOfTokens(
            msg.value,
            ethBalanceBefore,
            tokenBalance
        );

        ERC20 cryptoDevToken = ERC20(cryptoDevTokenAddress);
        require(boughtAmount >= _minAmount, "Insufficient output amount!");
        tokenSwapFees += feeAmount;
        cryptoDevToken.transfer(msg.sender, boughtAmount);
    }

    function cryptoDevTokenToEth(uint256 _tokenSaleAmount, uint256 _minAmount)
        public
    {
        require(_tokenSaleAmount > 0, "Token sale amount must be more than 0");
        uint256 ethBalance = address(this).balance;
        uint256 tokenBalance = getReserve();
        (uint256 boughtAmount, uint256 feeAmount) = getAmountOfTokens(
            _tokenSaleAmount,
            tokenBalance,
            ethBalance
        );

        ERC20 cryptoDevToken = ERC20(cryptoDevTokenAddress);
        require(boughtAmount >= _minAmount, "Insufficient output amount!");
        cryptoDevToken.transferFrom(
            msg.sender,
            address(this),
            _tokenSaleAmount
        );
        ethSwapFees += feeAmount;
        payable(msg.sender).transfer(boughtAmount);
    }

    function withdraw() public onlyOwner {
        require(ethSwapFees > 0 || tokenSwapFees > 0, "Nothing to withdraw!");
        uint256 ethWithdrawal = ethSwapFees;
        uint256 tokenWithdrawal = tokenSwapFees;
        ERC20 cryptoDevToken = ERC20(cryptoDevTokenAddress);
        ethSwapFees = 0;
        payable(msg.sender).transfer(ethWithdrawal);
        tokenSwapFees = 0;
        cryptoDevToken.transfer(msg.sender, tokenWithdrawal);
    }
}
