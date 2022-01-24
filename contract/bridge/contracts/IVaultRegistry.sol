// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IVaultRegistry {
    // // set functions for Vault
    // function setBtcPublicKeyX(address, uint256) external;
    // function setBtcPublicKeyY(address, uint256) external;
    // function setCollateral(address, uint256) external;
    // function setIssued(address, uint256) external;
    // function setToBeIssued(address, uint256) external;
    // function setToBeRedeemed(address, uint256) external;
    // function setReplaceCollateral(address, uint256) external;
    // function setToBeReplaced(address, uint256) external;
    // function setLiquidatedCollateral(address, uint256) external;

    // // set function for vaultDepositAddress
    // function setVaultDepositAddress(address, address, bool) external;

    // interfaces used by VaultRegistry contract
    function vaults(address) external returns(uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256);
    function vaultDepositAddress(address, address) external returns(bool);
    function registerVault(uint256, uint256) external;
    function registerDepositAddress(address, uint256) external returns(address);
    function insertVaultDepositAddress(address, uint256, uint256, uint256) external returns(address);
    function updatePublicKey(uint256, uint256) external;
    function decreaseToBeIssuedTokens(address, uint256) external;
    function tryIncreaseToBeIssuedTokens(address, uint256) external returns(bool);
    function tryIncreaseToBeRedeemedTokens(address, uint256) external returns(bool);
    function redeemTokens(address, uint256) external;
    function issuableTokens(address) external view returns(uint256);
    function issueTokens(address, uint256) external;
    function calculateCollateral(uint256, uint256, uint256) external view returns(uint256);
    function requestableToBeReplacedTokens(address) external returns(uint256);
    function tryIncreaseToBeReplacedTokens(address, uint256, uint256) external returns(uint256, uint256);
    function decreaseToBeReplacedTokens(address, uint256) external returns(uint256, uint256);
    function replaceTokens(address, address, uint256, uint256) external;
    function tryDepositCollateral(address, uint256) external;
    function liquidateVaul(address, address) external;
    function lockCollateral(address, uint256) external;
    function releaseCollateral(address, uint256) external;
    function slashCollateral(address, address, uint256) external;
    function useCollateralInc(address, uint256) external;
    function useCollateralDec(address, uint256) external;

    // interface used by StakedRelayer contract
    function liquidateTheftVault(address vaultId, address reporterId) external;
}
