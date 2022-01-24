/**
SPDX-License-Identifier: MIT

Exchange Rate Oracle Module
https://onebtc-dev.web.app/spec/oracle.html

The Exchange Rate Oracle receives a continuous data feed on the exchange rate between BTC and ONE.
*/

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

contract ExchangeRateOracleWrapper is Initializable {
    using SafeMathUpgradeable for uint256;

    event SetExchangeRate(uint256 lastExchangeRateTime, uint256 exchangeRate);

    uint256 constant MAX_DELAY = 1000;
    uint256 public lastExchangeRateTime;
    uint256 exchangeRate;

    function initialize() public initializer {
    }

    /**
     * @notice Set the latest (aggregate) BTC/ONE exchange rate. This function invokes a check of vault collateral rates in the Vault Registry component.
     * @param rate uint256 BTC/ONE exchange rate.
     */
    function setExchangeRate(uint256 rate) public {
        exchangeRate = rate;
        lastExchangeRateTime = now;

        emit SetExchangeRate(lastExchangeRateTime, exchangeRate);
    }

    /**
     * @notice Returns the latest BTC/ONE exchange rate, as received from the external data sources.
     * @return uint256 (aggregate) exchange rate value
     */
    function getExchangeRate() public view returns (uint256) {
        require(
            now - lastExchangeRateTime > MAX_DELAY,
            "ERR_MISSING_EXCHANGE_RATE"
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
