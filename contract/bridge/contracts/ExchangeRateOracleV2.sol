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
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

contract ExchangeRateOracleV2 is Initializable {
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

        if (lastExchangeRateTime - now > MAX_DELAY) {
            emit recoverFromORACLEOFFLINE(oracle, rate);
        }

        lastExchangeRateTime = now;

        emit SetExchangeRate(oracle, rate);
    }

    /**
     * @notice Returns the latest BTC/ONE exchange rate, as received from the external data sources.
     * @return uint256 (aggregate) exchange rate value
     */
    function getExchangeRate() private view returns (uint256) {
        AggregatorV3Interface oneUSD = AggregatorV3Interface(
            0xcEe686F89bc0dABAd95AEAAC980aE1d97A075FAD
        );
        AggregatorV3Interface btcUSD = AggregatorV3Interface(
            0xEF637736B220a58C661bfF4b71e03ca898DCC0Bd
        );
        (, int256 onePrice, , uint256 oneTimeStamp, ) = oneUSD
            .latestRoundData();
        (, int256 btcPrice, , uint256 btcTimeStamp, ) = btcUSD
            .latestRoundData();

        uint256 minTimeStamp = MathUpgradeable.min(oneTimeStamp, btcTimeStamp);
        // oldest timestamp should be within the max delay
        require(
            now - minTimeStamp <= MAX_DELAY,
            "Exchange rate avaialble is too old"
        );

        uint256 a = uint256(btcPrice);
        uint256 b = uint256(onePrice);

        return a.div(b);
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
