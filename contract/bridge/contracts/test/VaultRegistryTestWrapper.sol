// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
import { VaultRegistry } from "../VaultRegistry.sol";

contract VaultRegistryTestWrapper is VaultRegistry {
    address lastDepositAddress;

    function getLastDepositAddress() public view returns (address) {
        return lastDepositAddress;
    }

    function testRegisterDepositAddress(address vaultId, uint256 issueId) public {
        lastDepositAddress = registerDepositAddress(vaultId, issueId);
    }

    function testDecreaseToBeIssuedTokens(address vaultId, uint256 amount) public {
        return decreaseToBeIssuedTokens(vaultId, amount);
    }

    function testTryIncreaseToBeIssuedTokens(address vaultId, uint256 amount) public returns(bool) {
        return tryIncreaseToBeIssuedTokens(vaultId, amount);
    }

    function testTryIncreaseToBeRedeemedTokens(address vaultId, uint256 amount) public returns(bool) {
        return tryIncreaseToBeRedeemedTokens(vaultId, amount);
    }

    function testRedeemableTokens(address vaultId) public returns(uint256) {
        return redeemableTokens(vaultId);
    }

    function testRedeemTokens(address vaultId, uint256 amount) public {
        return redeemTokens(vaultId, amount);
    }

    function testIssueTokens(address vaultId, uint256 amount) public {
        return issueTokens(vaultId, amount);
    }

    function testGetFreeCollateral(address vaultId) public view returns(uint256) {
        return getFreeCollateral(vaultId);
    }
}
