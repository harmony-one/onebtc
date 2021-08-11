// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
import { ICollateral } from "../Collateral.sol";

contract CollateralTestWrapper is ICollateral {
    function lockCollateral_public(address sender, uint256 amount) public payable {
        return lockCollateral(sender, amount);
    }

    function releaseCollateral_public(address sender, uint256 amount) public {
        return releaseCollateral(sender, amount);
    }

    function slashCollateral_public(
        address from,
        address to,
        uint256 amount
    ) public {
        return slashCollateral(from, to, amount);
    }

    function getFreeCollateral_public(address vaultId) public view returns(uint256) {
        return getFreeCollateral(vaultId);
    }

    function useCollateralInc_public(address vaultId, uint256 amount) public {
        return useCollateralInc(vaultId, amount);
    }

    function useCollateralDec_public(address vaultId, uint256 amount) public {
        return useCollateralDec(vaultId, amount);
    }
}
