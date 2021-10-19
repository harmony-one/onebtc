// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import {IRelay} from "../IRelay.sol";

contract RelayMock is IRelay {
    function submitBlockHeader(bytes calldata header) external override {}

    function submitBlockHeaderBatch(bytes calldata headers) external override {}

    function getBlockHeight(bytes32 digest)
        external
        view
        override
        returns (uint32)
    {}

    function getBlockHash(uint32 height)
        external
        view
        override
        returns (bytes32)
    {}

    function getBestBlock()
        external
        view
        override
        returns (bytes32 digest, uint32 height)
    {}

    function verifyTx(
        uint32 height,
        uint256 index,
        bytes32 txid,
        bytes calldata header,
        bytes calldata proof,
        uint256 confirmations,
        bool insecure
    ) external view override returns (bool) {
        return true;
    }
}
