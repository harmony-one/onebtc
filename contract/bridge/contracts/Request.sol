// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
enum RequestStatus {None, Pending, Completed, Cancelled}

struct S_IssueRequest {
    address payable vault; // vault one address
    uint256 opentime;
    address payable requester;
    address btcAddress; // vault btc address
    bytes btcPublicKey;
    uint256 amount;
    uint256 fee;
    uint256 griefingCollateral;
    uint256 period;
    uint256 btcHeight;
    RequestStatus status;
}

struct S_RedeemRequest {
    address vault;
    uint256 opentime;
    uint256 period;
    uint256 fee;
    uint256 amountBtc;
    uint256 transferFeeBtc;
    uint256 amountOne; // Amount of ONE to be paid to the user from liquidated Vaults’ collateral
    uint256 premiumOne;
    address requester;
    address btcAddress;
    // The latest Bitcoin height as reported by the BTC-Relay at time of opening.
    uint256 btcHeight;
    RequestStatus status;
}

struct S_ReplaceRequest {
    address payable oldVault;
    address payable newVault;
    uint256 collateral;
    uint256 acceptTime;
    uint256 amount;
    address btcAddress;
    uint256 griefingCollateral;
    uint256 period;
    uint256 btcHeight;
    RequestStatus status;
}
