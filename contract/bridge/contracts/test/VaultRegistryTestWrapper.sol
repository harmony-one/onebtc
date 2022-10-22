// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import {VaultRegistry} from "../VaultRegistry.sol";
import {ICollateral} from "../Collateral.sol";
import "../lib/VaultRegistryLib.sol";

contract VaultRegistryTestWrapper is VaultRegistry {
    event RedeemableTokens(address vaultId, uint256 amount);
    event RequestableToBeReplacedTokens(address vaultId, uint256 amount);

    address lastDepositAddress;

    function testRegisterVault(uint256 btcPublicKeyX, uint256 btcPublicKeyY)
        external
        payable
    {
        address vaultId = msg.sender;
        VaultRegistryLib.registerVault(vaults[vaultId], btcPublicKeyX, btcPublicKeyY);
        Vault storage vault = vaults[vaultId];
        uint256 _lockAmount = msg.value;
        vault.collateral = vault.collateral.add(_lockAmount);
        ICollateral.lockCollateral(vaultId, _lockAmount);
        emit RegisterVault(vaultId, msg.value, btcPublicKeyX, btcPublicKeyY);
    }

    function getLastDepositAddress() public view returns (address) {
        return lastDepositAddress;
    }

    function testRegisterDepositAddress(address vaultId, uint256 issueId)
        public
    {
        lastDepositAddress = registerDepositAddress(vaultId, issueId);
    }

    function testDecreaseToBeIssuedTokens(address vaultId, uint256 amount)
        public
    {
        decreaseToBeIssuedTokens(vaultId, amount);
    }

    function testTryIncreaseToBeIssuedTokens(address vaultId, uint256 amount)
        public
        returns (bool)
    {
        uint256 issuableTokens = getFreeCollateral(vaultId).mul(100).div(150); // mock oracle
        if (issuableTokens < amount) return false; // ExceedingVaultLimit
        Vault storage vault = vaults[vaultId];
        vault.toBeIssued = vault.toBeIssued.add(amount);
        emit IncreaseToBeIssuedTokens(vaultId, amount);
        return true;
    }

    function testTryIncreaseToBeRedeemedTokens(address vaultId, uint256 amount)
        public
        returns (bool)
    {
        return tryIncreaseToBeRedeemedTokens(vaultId, amount);
    }

    function testRedeemableTokens(address vaultId) public {
        uint256 redeemableTokens = redeemableTokens(vaultId);
        emit RedeemableTokens(vaultId, redeemableTokens);
    }

    function testRedeemTokens(address vaultId, uint256 amount) public {
        redeemTokens(vaultId, amount);
    }

    function testIssueTokens(address vaultId, uint256 amount) public {
        issueTokens(vaultId, amount);
    }

    function testGetFreeCollateral(address vaultId)
        public
        view
        returns (uint256)
    {
        return getFreeCollateral(vaultId);
    }

    // function testRequestableToBeReplacedTokens(address vaultId) public returns (uint256) {
    //     uint requestableTokens = requestableToBeReplacedTokens(vaultId);
    //     emit RequestableToBeReplacedTokens(vaultId, requestableTokens);
    // }
}