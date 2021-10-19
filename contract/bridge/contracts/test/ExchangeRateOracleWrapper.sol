/**
SPDX-License-Identifier: MIT

Exchange Rate Oracle Module
https://onebtc-dev.web.app/spec/oracle.html

The Exchange Rate Oracle receives a continuous data feed on the exchange rate between BTC and ONE.
*/

pragma solidity 0.6.12;

contract ExchangeRateOracleWrapper {
    uint256 constant MAX_DELAY = 1000;
    uint256 public lastExchangeRateTime;
    uint256 exchangeRate;
    uint256 satoshiPerBytes;
    mapping(address => bool) public authorizedOracles;

    event SetExchangeRate(address oracle, uint256 rate);

    event SetSatoshiPerByte(uint256 fee, uint256 inclusionEstimate);

    event recoverFromORACLEOFFLINE(address oracle, uint256 rate);

    constructor() public {}

    /**
     * @notice add authorized oracle
     * @param _oracle authorized oracle address to add
     */
    function addAuthorizedOracle(address _oracle) public {
        authorizedOracles[_oracle] = true;
    }

    /**
    @notice Set the latest (aggregate) BTC/ONE exchange rate. This function invokes a check of vault collateral rates in the Vault Registry component.
    @param oracle the oracle account calling this function. Must be pre-authorized and tracked in this component!
    @param rate the u128 BTC/ONE exchange rate.
    */
    function setExchangeRate(address oracle, uint256 rate) public {
        require(authorizedOracles[oracle], "ERR_INVALID_ORACLE_SOURCE");

        exchangeRate = rate;

        if (lastExchangeRateTime - now > MAX_DELAY) {
            emit recoverFromORACLEOFFLINE(oracle, rate);
        }

        lastExchangeRateTime = now;

        emit SetExchangeRate(oracle, rate);
    }

    /**
    @notice Set the Satoshi per bytes fee
    @param fee the Satoshi per byte fee.
    @param inclusionEstimate the estimated inclusion time.
    */
    function setSatoshiPerBytes(uint256 fee, uint256 inclusionEstimate) public {
        // 1. The BTC Bridge status in the Security component MUST be set to RUNNING:0.
        // TODO require()

        require(authorizedOracles[msg.sender], "ERR_INVALID_ORACLE_SOURCE");

        satoshiPerBytes = inclusionEstimate;

        emit SetSatoshiPerByte(fee, inclusionEstimate);
    }

    /**
    @notice Returns the latest BTC/ONE exchange rate, as received from the external data sources.
    @return uint256 (aggregate) exchange rate value
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
        return amount / rate;
    }

    /**
     * @notice Get ONE amount by BTC.
     * @param amount BTC amount
     * @return ONE amount
     */
    function wrappedToCollateral(uint256 amount) public view returns (uint256) {
        uint256 rate = getExchangeRate();
        return amount * rate;
    }
}
