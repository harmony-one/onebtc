// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

abstract contract ICollateral {
    event LockCollateral(address sender, uint256 amount);
    event ReleaseCollateral(address sender, uint256 amount);
    event SlashCollateral(address sender, address receiver, uint256 amount);
    mapping(address=>uint256) public CollateralBalances;
    mapping(address=>uint256) public CollateralUsed; // for vaults

    function TotalCollateral() external view returns(uint256) {
        return address(this).balance;
    }

    function lock_collateral(address sender, uint256 amount) internal {
        require(msg.value >= amount, "InvalidCollateral");
        CollateralBalances[sender] += amount;
        emit LockCollateral(sender, amount);
    }

    function release(address sender, address to, uint256 amount) private {
        require(CollateralBalances[sender] - CollateralUsed[vault_id] >= amount, "InSufficientCollateral");
        CollateralBalances[sender] -= amount;
        address payable _to = address(uint160(to));
        _to.transfer(amount);
    }

    function release_collateral(address sender, uint256 amount) internal {
        release(sender, sender, amount);
        emit ReleaseCollateral(sender, amount);
    }

    function slash_collateral(address from, address to, uint256 amount) internal {
        release(from, to, amount);
        emit SlashCollateral(from, to, amount);
    }

    function use_collateral_inc(address vault_id, uint256 amount) internal {
        CollateralUsed[vault_id] += amount;
        require(CollateralBalances[vault_id] <= CollateralUsed[vault_id], "InSufficientCollateral");
    }
    function use_collateral_dec(address vault_id, uint256 amount) internal {
        require(CollateralUsed[vault_id] >= amount, "InSufficientCollateral");
        CollateralUsed[vault_id] -= amount;
    }
}