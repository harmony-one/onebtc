// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import {ICollateral} from "./Collateral.sol";
import {BitcoinKeyDerivation} from "./crypto/BitcoinKeyDerivation.sol";
import {ExchangeRateOracle} from "./ExchangeRateOracle.sol";

abstract contract VaultRegistry is ICollateral {
    struct Vault {
        uint256 btc_public_key_x;
        uint256 btc_public_key_y;
        uint256 collateral;
        uint256 issued;
        uint256 toBeIssued;
        uint256  toBeRedeemed;
        address[] deposit_addresses;
    }
    mapping(address => Vault) public vaults;
    uint256 public constant secure_collateral_threshold = 150; // 150%
    ExchangeRateOracle oracle;
    
    event RegisterVault(
        address indexed vault_id,
        uint256 collateral,
        uint256 btc_public_key_x,
        uint256 btc_public_key_y
    );

    event VaultPublicKeyUpdate(address indexed vault_id, uint256 x, uint256 y);
    event IncreaseToBeIssuedTokens(address indexed vault_id, uint256 amount);
    event DecreaseToBeIssuedTokens(address indexed vault_id, uint256 amount);
    event IssueTokens(address indexed vault_id, uint256 amount);

    function register_vault(uint256 btc_public_key_x, uint256 btc_public_key_y)
        external
        payable
    {
        address vault_id = msg.sender;
        Vault storage vault = vaults[vault_id];
        require(vault.btc_public_key_x == 0, "vaultExist");
        require(
            btc_public_key_x != 0 && btc_public_key_y != 0,
            "invalidPubkey"
        );
        vault.btc_public_key_x = btc_public_key_x;
        vault.btc_public_key_y = btc_public_key_y;
        lock_additional_collateral();
        emit RegisterVault(
            vault_id,
            msg.value,
            btc_public_key_x,
            btc_public_key_y
        );
    }

    function register_deposit_address(address vault_id, uint256 issue_id)
        internal
        returns (address)
    {
        Vault storage vault = vaults[vault_id];
        require(vault.btc_public_key_x != 0, "vaultNotExist");
        address derivedKey =
            BitcoinKeyDerivation.derivate(
                vault.btc_public_key_x,
                vault.btc_public_key_y,
                issue_id
            );
        vault.deposit_addresses.push(derivedKey);
        return derivedKey;
    }

    function update_public_key(
        uint256 btc_public_key_x,
        uint256 btc_public_key_y
    ) external {
        address vault_id = msg.sender;
        Vault storage vault = vaults[vault_id];
        require(vault.btc_public_key_x != 0, "vaultNotExist");
        vault.btc_public_key_x = btc_public_key_x;
        vault.btc_public_key_y = btc_public_key_y;
        emit VaultPublicKeyUpdate(vault_id, btc_public_key_x, btc_public_key_y);
    }

    function lock_additional_collateral() public payable {
        address vault_id = msg.sender;
        Vault storage vault = vaults[vault_id];
        require(vault.btc_public_key_x != 0, "vaultNotExist");
        vault.collateral += msg.value;
        ICollateral.lock_collateral(vault_id, msg.value);
    }

    function withdraw_collateral(uint256 amount) external {
        Vault storage vault = vaults[msg.sender];
        require(vault.btc_public_key_x != 0, "vaultNotExist");
        vault.collateral -= amount;
        ICollateral.release_collateral(msg.sender, amount);
    }

    function calculate_collateral(uint256 collateral, uint256 numerator, uint256 denominator) internal pure returns(uint256){
        return collateral*numerator/denominator;
    }

    function decrease_to_be_issued_tokens(address vault_id, uint256 amount) internal {
        Vault storage vault = vaults[vault_id];
        vault.toBeIssued -= amount;
        emit DecreaseToBeIssuedTokens(vault_id, amount);
    }

    function try_increase_to_be_issued_tokens(address vault_id, uint256 amount) internal {
        uint256 issuable_tokens = issuable_tokens(vault_id);
        require(issuable_tokens >= amount, "ExceedingVaultLimit");
        Vault storage vault = vaults[vault_id];
        vault.toBeIssued += amount;
        emit IncreaseToBeIssuedTokens(vault_id, amount);
    }

    function calculate_max_wrapped_from_collateral_for_threshold(uint256 collateral, uint256 threshold) internal view returns(uint256) {
        uint256 collateral_in_wrapped = oracle.collateralToWrapped(collateral);
        return collateral_in_wrapped*100/threshold;
    }

    function issuable_tokens(address vault_id) public view returns(uint256) {
        uint256 free_collateral = ICollateral.get_free_collateral(vault_id);
        return calculate_max_wrapped_from_collateral_for_threshold(free_collateral, secure_collateral_threshold);
    }

    function issue_tokens(address vault_id, uint256 amount) internal {
        Vault storage vault = vaults[vault_id];
        vault.issued += amount;
        vault.toBeIssued -= amount;
        emit IssueTokens(vault_id, amount);
    }
}
