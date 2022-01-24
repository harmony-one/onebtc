// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import {ICollateral} from "../Collateral.sol";

contract CollateralTestWrapper is ICollateral {
    function testLockCollateral(address sender, uint256 amount) public payable {
        return _lockCollateral(sender, amount);
    }

    function testReleaseCollateral(address sender, uint256 amount) public {
        return _releaseCollateral(sender, amount);
    }

    function testSlashCollateral(
        address from,
        address to,
        uint256 amount
    ) public {
        return _slashCollateral(from, to, amount);
    }

    function testGetFreeCollateral(address vaultId)
        public
        view
        returns (uint256)
    {
        return _getFreeCollateral(vaultId);
    }

    function testUseCollateralInc(address vaultId, uint256 amount) public {
        return _useCollateralInc(vaultId, amount);
    }

    function testUseCollateralDec(address vaultId, uint256 amount) public {
        return _useCollateralDec(vaultId, amount);
    }
}
