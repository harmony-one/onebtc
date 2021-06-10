// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

abstract contract ICollateral {
    event LockCollateral(address sender, uint256 amount);
    event ReleaseCollateral(address sender, uint256 amount);
    event SlashCollateral(address sender, address receiver, uint256 amount);
    mapping(address => uint256) public CollateralBalances;
    mapping(address => uint256) public CollateralUsed; // for vaults

    function TotalCollateral() external view returns (uint256) {
        return address(this).balance;
    }

    function lockCollateral(address sender, uint256 amount) internal {
        require(msg.value >= amount, "InvalidCollateral");
        CollateralBalances[sender] += amount;
        emit LockCollateral(sender, amount);
    }

    function release(
        address sender,
        address to,
        uint256 amount
    ) private {
        require(
            CollateralBalances[sender] - CollateralUsed[sender] >= amount,
            "InSufficientCollateral"
        );
        CollateralBalances[sender] -= amount;
        address payable _to = address(uint160(to));
        _to.transfer(amount);
    }

    function releaseCollateral(address sender, uint256 amount) internal {
        release(sender, sender, amount);
        emit ReleaseCollateral(sender, amount);
    }

    function slashCollateral(
        address from,
        address to,
        uint256 amount
    ) internal {
        release(from, to, amount);
        emit SlashCollateral(from, to, amount);
    }

    function useCollateralInc(address vaultId, uint256 amount) internal {
        CollateralUsed[vaultId] += amount;
        require(
            CollateralBalances[vaultId] >= CollateralUsed[vaultId],
            "InSufficientCollateral"
        );
    }

    function useCollateralDec(address vaultId, uint256 amount) internal {
        require(CollateralUsed[vaultId] >= amount, "InSufficientCollateral");
        CollateralUsed[vaultId] -= amount;
    }
}
