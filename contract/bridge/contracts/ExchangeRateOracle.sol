// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

contract ExchangeRateOracle {
    uint256 constant MAX_DELAY = 1000;
    uint256 public lastExchangeRateTime;
    uint256 exchangeRate;
    uint256 satoshiPerBytes;
    mapping (address => bool) authorizedOracles;

    event SetExchangeRate(
        address oracle,
        uint256 rate
    );

    event SetSatoshiPerByte(
        uint256 fee,
        uint256 inclusionEstimate
    );

    event recoverFromORACLEOFFLINE(
        address oracle,
        uint256 rate
    );

    constructor() public {
        authorizedOracles[0x5B38Da6a701c568545dCfcB03FcB875f56beddC4] = true;
     }

    function setExchangeRate(address oracle, uint256 rate) public {
        require(authorizedOracles[oracle], "ERR_INVALID_ORACLE_SOURCE");

        exchangeRate = rate;

        if (lastExchangeRateTime - now > MAX_DELAY) {
            emit recoverFromORACLEOFFLINE(oracle, rate);
        }

        lastExchangeRateTime = now;

        emit SetExchangeRate(oracle, rate);
    }

    function setSatoshiPerBytes(uint256 fee, uint256 inclusionEstimate) public {
        // 1. The BTC Bridge status in the Security component MUST be set to RUNNING:0.
        // TODO require()

        require(authorizedOracles[msg.sender], "ERR_INVALID_ORACLE_SOURCE");

        satoshiPerBytes = inclusionEstimate;

        emit SetSatoshiPerByte(fee, inclusionEstimate);
    }

    function getExchageRate() public view returns (uint256) {
        require (now - lastExchangeRateTime > MAX_DELAY, "ERR_MISSING_EXCHANGE_RATE");

        return exchangeRate;
    }

    /**
    * @notice Get BTC amount by ONE.
    * @param amount collateral(ONE) amount
    * @return BTC amount
    */
    function collateralToWrapped(uint256 amount) public view returns(uint256) {
        uint256 rate = getExchageRate();
        return amount/rate;
    }

    /**
    * @notice Get ONE amount by BTC.
    * @param amount BTC amount
    * @return ONE amount
    */
    function wrappedToCollateral(uint256 amount) public view returns(uint256) {
        uint256 rate = getExchageRate();
        return amount*rate;
    }
}
