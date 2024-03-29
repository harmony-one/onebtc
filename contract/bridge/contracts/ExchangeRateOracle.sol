/**
SPDX-License-Identifier: MIT

Exchange Rate Oracle Module
https://onebtc-dev.web.app/spec/oracle.html

The Exchange Rate Oracle receives a continuous data feed on the exchange rate between BTC and ONE.
*/

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";

contract ExchangeRateOracle is Initializable {
    using SafeMathUpgradeable for uint256;

    uint256 constant MAX_DELAY = 1000;

    uint256 public lastExchangeRateTime;
    uint256 exchangeRate;

    mapping(address => bool) authorizedOracles;

    event SetExchangeRate(address oracle, uint256 rate);

    event recoverFromORACLEOFFLINE(address oracle, uint256 rate);

    function initialize(address provider) public initializer {
        lastExchangeRateTime = now;
        authorizedOracles[provider] = true;
    }

    function setExchangeRate(uint256 btcPrice, uint256 onePrice) public {
        address oracle = msg.sender;
        require(authorizedOracles[oracle], "Sender is not authorized");

        uint256 rate = btcPrice.div(onePrice);
        exchangeRate = rate;

        if (now - lastExchangeRateTime > MAX_DELAY) {
            emit recoverFromORACLEOFFLINE(oracle, rate);
        }

        lastExchangeRateTime = now;

        emit SetExchangeRate(oracle, rate);
    }

    function getExchangeRate() private view returns (uint256) {
        require(
            now - lastExchangeRateTime <= MAX_DELAY,
            "Exchange rate avaialble is too old"
        );

        return exchangeRate;
    }

    /**
     * @notice Get BTC amount by ONE.
     * @param amount collateral(ONE) amount
     * @return BTC amount
     */
    function collateralToWrapped(uint256 amount) public view returns (uint256) {
        uint256 rate = getExchangeRate();
        return amount.div(rate).mul(10**8).div(10**18);
    }

    /**
     * @notice Get ONE amount by BTC.
     * @param amount BTC amount
     * @return ONE amount
     */
    function wrappedToCollateral(uint256 amount) public view returns (uint256) {
        uint256 rate = getExchangeRate();
        return amount.mul(rate).mul(10**18).div(10**8);
    }
}
