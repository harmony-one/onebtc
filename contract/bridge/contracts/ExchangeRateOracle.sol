/**
SPDX-License-Identifier: MIT

Exchange Rate Oracle Module
https://onebtc-dev.web.app/spec/oracle.html

The Exchange Rate Oracle receives a continuous data feed on the exchange rate between BTC and ONE.
*/

pragma solidity 0.6.12;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";

contract ExchangeRateOracle is Initializable {
    using SafeMathUpgradeable for uint256;

    uint256 constant MAX_DELAY = 1000;

    AggregatorV3Interface internal oneUSD;
    AggregatorV3Interface internal btcUSD;

    function initialize() public initializer {
        oneUSD = AggregatorV3Interface(
            0xcEe686F89bc0dABAd95AEAAC980aE1d97A075FAD
        );
        btcUSD = AggregatorV3Interface(
            0xEF637736B220a58C661bfF4b71e03ca898DCC0Bd
        );
    }

    /**
    @notice Returns the latest BTC/ONE exchange rate, as received from the external data sources.
    @return uint256 (aggregate) exchange rate value
    */
    function getExchangeRate() private view returns (uint256) {
        (, int256 onePrice, , uint256 oneTimeStamp, ) = oneUSD
            .latestRoundData();
        (, int256 btcPrice, , uint256 btcTimeStamp, ) = btcUSD
            .latestRoundData();

        uint256 minTimeStamp = MathUpgradeable.min(oneTimeStamp, btcTimeStamp);
        // oldest timestamp should be within the max delay
        require(now - minTimeStamp > MAX_DELAY, "ERR_MISSING_EXCHANGE_RATE");

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
