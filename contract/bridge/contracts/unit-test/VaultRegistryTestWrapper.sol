// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
import { VaultRegistry } from "../VaultRegistry.sol";

contract VaultRegistryTestWrapper is VaultRegistry {
    address lastDepositAddress;

    function getLastDepositAddress() public view returns (address) {
        return lastDepositAddress;
    }

    function registerDepositAddress_public(address vaultId, uint256 issueId) public {
        lastDepositAddress = registerDepositAddress(vaultId, issueId);
    }

    function decreaseToBeIssuedTokens_public(address vaultId, uint256 amount) public {
        return decreaseToBeIssuedTokens(vaultId, amount);
    }

    function tryIncreaseToBeIssuedTokens_public(address vaultId, uint256 amount) public returns(bool) {
        return tryIncreaseToBeIssuedTokens(vaultId, amount);
    }

    function tryIncreaseToBeRedeemedTokens_public(address vaultId, uint256 amount) public returns(bool) {
        return tryIncreaseToBeRedeemedTokens(vaultId, amount);
    }

    function redeemableTokens_public(address vaultId) public returns(uint256) {
        return redeemableTokens(vaultId);
    }

    function redeemTokens_public(address vaultId, uint256 amount) public {
        return redeemTokens(vaultId, amount);
    }

    function issueTokens_public(address vaultId, uint256 amount) public {
        return issueTokens(vaultId, amount);
    }

    function getFreeCollateral_public(address vaultId) public view returns(uint256) {
        return getFreeCollateral(vaultId);
    }
}
