// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IExchangeRateOracle {
    /**
     * @notice Get BTC amount by ONE.
     * @param amount collateral(ONE) amount
     * @return BTC amount
     */
    function collateralToWrapped(uint256 amount)
        external
        view
        returns (uint256);

    /**
     * @notice Get ONE amount by BTC.
     * @param amount BTC amount
     * @return ONE amount
     */
    function wrappedToCollateral(uint256 amount)
        external
        view
        returns (uint256);
}
