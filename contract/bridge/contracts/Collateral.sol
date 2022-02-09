// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

abstract contract ICollateral {
    using SafeMathUpgradeable for uint256;

    event LockCollateral(address sender, uint256 amount);
    event ReleaseCollateral(address sender, uint256 amount);
    event SlashCollateral(address sender, address receiver, uint256 amount);

    mapping(address => uint256) public CollateralBalances;
    mapping(address => uint256) public CollateralUsed; // for vaults

    function totalCollateral() external view returns (uint256) {
        return address(this).balance;
    }

    function lockCollateral(address sender, uint256 amount) internal {
        require(msg.value >= amount, "Invalid collateral");
        CollateralBalances[sender] = CollateralBalances[sender].add(amount);
        emit LockCollateral(sender, amount);
    }

    function release(
        address sender,
        address to,
        uint256 amount
    ) private {
        require(
            CollateralBalances[sender].sub(CollateralUsed[sender]) >= amount,
            "Insufficient collateral"
        );
        CollateralBalances[sender] = CollateralBalances[sender].sub(amount);
        address payable _to = address(uint160(to));
        (bool sent, ) = _to.call{value: amount}("");
        require(sent, "Transfer failed.");
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

    function getFreeCollateral(address vaultId)
        internal
        view
        returns (uint256)
    {
        return CollateralBalances[vaultId].sub(CollateralUsed[vaultId]);
    }

    function getTotalCollateral(address vaultId) internal view returns (uint256) {
        return CollateralBalances[vaultId];
    }

    function useCollateralInc(address vaultId, uint256 amount) internal {
        CollateralUsed[vaultId] = CollateralUsed[vaultId].add(amount);
        require(
            CollateralBalances[vaultId] >= CollateralUsed[vaultId],
            "inc:Insufficient collateral"
        );
    }

    function useCollateralDec(address vaultId, uint256 amount) internal {
        require(CollateralUsed[vaultId] >= amount, "dec:Insufficient collateral");
        CollateralUsed[vaultId] = CollateralUsed[vaultId].sub(amount);
    }

    uint256[45] private __gap;
}
