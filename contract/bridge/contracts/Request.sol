// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
enum RequestStatus {None, Pending, Completed, Cancelled}

struct S_IssueRequest {
    address payable vault; // vault one address
    uint256 opentime;
    address payable requester;
    address btc_address; // vault btc address
    bytes btc_public_key;
    uint256 amount;
    uint256 fee;
    uint256 griefing_collateral;
    uint256 period;
    uint256 btc_height;
    RequestStatus status;
}

struct S_RedeemRequest {
    address vault;
    uint256 opentime;
    uint256 period;
    uint256 fee;
    uint256 amount_btc;
    uint256 amount_one; // Amount of ONE to be paid to the user from liquidated Vaults’ collateral
    uint256 premium_one;
    address requester;
    address btc_address;
    // The latest Bitcoin height as reported by the BTC-Relay at time of opening.
    uint256 btc_height;
    RequestStatus status;
}
