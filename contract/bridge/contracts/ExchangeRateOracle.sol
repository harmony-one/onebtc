// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import {ICollateral} from "./Collateral.sol";

abstract contract ExchangeRateOracle is ICollateral {
    uint128 constant MAX_DELAY = 1000;
    uint128 public last_exchange_rate_time;
    uint128 exchange_rate;
    uint128 satoshi_per_bytes;
    mapping (address => bool) authorized_oracles = ["oracle-address-goes-here"];

    event SetExchangeRate(
        address oracle,
        uint128 rate
    );

    event SetSatoshiPerByte(
        uint128 fee,
        uint128 inclusion_estimate
    );

    event recoverFromORACLEOFFLINE(
        address oracle,
        uint128 rate
    );

    function set_exchange_rate(address oracle, uint128 rate) public {
        // 1. Check if the caller of the function is the AuthorizedOracle. If not, throw ERR_INVALID_ORACLE_SOURCE.
        require(authorized_oracles[oracle].exists, "ERR_INVALID_ORACLE_SOURCE");

        // 2. Update the ExchangeRate with the rate.
        exchange_rate = rate;

        // 3. If LastExchangeRateTime minus the current UNIX timestamp is greater or equal to MAX_DELAY
        if (last_exchange_rate_time - now > MAX_DELAY) {
            // 3.1 call recoverFromORACLEOFFLINE to recover from an ORACLE_OFFLINE error (which was the case before this data submission).
            emit recoverFromORACLEOFFLINE(address, rate);
        }
        // 4. Set LastExchangeRateTime to the current UNIX timestamp.
        last_exchange_rate_time = now;

        // 5. Emit the SetExchangeRate event.
        emit SetExchangeRate(address, rate);
    }

    function set_satoshi_per_bytes(uint128 fee, uint128 inclusion_estimate) public {
        // 1. The BTC Bridge status in the Security component MUST be set to RUNNING:0.
        // TODO require()

        // 2. If the caller of the function is not in AuthorizedOracles MUST return ERR_INVALID_ORACLE_SOURCE.
        require(authorized_oracles[msg.sender].exists, "ERR_INVALID_ORACLE_SOURCE");

        // 3. If the above checks passed, the function MUST update the SatoshiPerBytes field indicated by the InclusionEstimate enum.
        satoshi_per_bytes = inclusion_estimate;

        // 4. If the above steps passed, MUST emit the SetSatoshiPerByte event.
        emit SetSatoshiPerByte(fee, inclusion_estimate);
    }

    function get_exchage_rate() public {
        // 1. Check if the current (UNIX) time minus the LastExchangeRateTime exceeds MAX_DELAY. If this is the case, return ERR_MISSING_EXCHANGE_RATE error.
        require (now - last_exchange_rate_time > MAX_DELAY, "ERR_MISSING_EXCHANGE_RATE");

        // 2. Otherwise, return the ExchangeRate from storage.
        return exchange_rate;
    }
}
