use web3::{
    api::Namespace,
    helpers::{self, CallFuture},
    types::{
        Address, Block, BlockId, BlockNumber, Bytes, CallRequest, Filter, Log, SyncState,
        Transaction, TransactionId, TransactionReceipt, TransactionRequest, H256, U256, U64,
    },
    Transport,
};

/// Hmy namespace
#[derive(Debug, Clone)]
pub struct Hmy<T> {
    transport: T,
}

impl<T: Transport> Namespace<T> for Hmy<T> {
    fn new(transport: T) -> Self
    where
        Self: Sized,
    {
        Hmy { transport }
    }

    fn transport(&self) -> &T {
        &self.transport
    }
}

impl<T: Transport> Hmy<T> {
    /// Get current block number
    pub fn block_number(&self) -> CallFuture<U64, T::Out> {
        CallFuture::new(self.transport.execute("hmy_blockNumber", vec![]))
    }

    /// Get current block number v2
    pub fn block_number_v2(&self) -> CallFuture<U64, T::Out> {
        CallFuture::new(self.transport.execute("hmyv2_blockNumber", vec![]))
    }

    /// Call a constant method of contract without changing the state of the blockchain.
    pub fn call(&self, req: CallRequest, block: Option<BlockId>) -> CallFuture<Bytes, T::Out> {
        let req = helpers::serialize(&req);
        let block = helpers::serialize(&block.unwrap_or_else(|| BlockNumber::Latest.into()));

        CallFuture::new(self.transport.execute("hmy_call", vec![req, block]))
    }

    /// Call a contract without changing the state of the blockchain to estimate gas usage.
    pub fn estimate_gas(
        &self,
        req: CallRequest,
        block: Option<BlockNumber>,
    ) -> CallFuture<U256, T::Out> {
        let req = helpers::serialize(&req);

        let args = match block {
            Some(block) => vec![req, helpers::serialize(&block)],
            None => vec![req],
        };

        CallFuture::new(self.transport.execute("hmy_estimateGas", args))
    }

    /// Get current recommended gas price
    pub fn gas_price(&self) -> CallFuture<U256, T::Out> {
        CallFuture::new(self.transport.execute("hmy_gasPrice", vec![]))
    }

    /// Get current recommended gas price v2
    pub fn gas_price_v2(&self) -> CallFuture<U256, T::Out> {
        CallFuture::new(self.transport.execute("hmyv2_gasPrice", vec![]))
    }

    /// Get balance of given address
    pub fn balance(
        &self,
        address: Address,
        block: Option<BlockNumber>,
    ) -> CallFuture<U256, T::Out> {
        let address = helpers::serialize(&address);
        let block = helpers::serialize(&block.unwrap_or(BlockNumber::Latest));

        CallFuture::new(
            self.transport
                .execute("hmy_getBalance", vec![address, block]),
        )
    }

    /// Get balance of given address v2
    pub fn balance_v2(
        &self,
        address: Address,
        block: Option<BlockNumber>,
    ) -> CallFuture<U256, T::Out> {
        let address = helpers::serialize(&address);
        let block = helpers::serialize(&block.unwrap_or(BlockNumber::Latest));

        CallFuture::new(
            self.transport
                .execute("hmyv2_getBalance", vec![address, block]),
        )
    }

    /// Get all logs matching a given filter object
    pub fn logs(&self, filter: Filter) -> CallFuture<Vec<Log>, T::Out> {
        let filter = helpers::serialize(&filter);
        CallFuture::new(self.transport.execute("hmy_getLogs", vec![filter]))
    }

    /// Get block details with transaction hashes.
    pub fn block(&self, block: BlockId) -> CallFuture<Option<Block<H256>>, T::Out> {
        let include_txs = helpers::serialize(&false);

        let result = match block {
            BlockId::Hash(hash) => {
                let hash = helpers::serialize(&hash);
                self.transport
                    .execute("hmy_getBlockByHash", vec![hash, include_txs])
            }
            BlockId::Number(num) => {
                let num = helpers::serialize(&num);
                self.transport
                    .execute("hmy_getBlockByNumber", vec![num, include_txs])
            }
        };

        CallFuture::new(result)
    }

    /// Get block details with transaction hashes v2
    pub fn block_v2(&self, block: BlockId) -> CallFuture<Option<Block<H256>>, T::Out> {
        let include_txs = helpers::serialize(&false);

        let result = match block {
            BlockId::Hash(hash) => {
                let hash = helpers::serialize(&hash);
                self.transport
                    .execute("hmyv2_getBlockByHash", vec![hash, include_txs])
            }
            BlockId::Number(num) => {
                let num = helpers::serialize(&num);
                self.transport
                    .execute("hmyv2_getBlockByNumber", vec![num, include_txs])
            }
        };

        CallFuture::new(result)
    }

    /// Get block details with full transaction objects.
    pub fn block_with_txs(&self, block: BlockId) -> CallFuture<Option<Block<Transaction>>, T::Out> {
        let include_txs = helpers::serialize(&true);

        let result = match block {
            BlockId::Hash(hash) => {
                let hash = helpers::serialize(&hash);
                self.transport
                    .execute("hmy_getBlockByHash", vec![hash, include_txs])
            }
            BlockId::Number(num) => {
                let num = helpers::serialize(&num);
                self.transport
                    .execute("hmy_getBlockByNumber", vec![num, include_txs])
            }
        };

        CallFuture::new(result)
    }

    /// Get block details with full transaction objects v2.
    pub fn block_with_txs_v2(
        &self,
        block: BlockId,
    ) -> CallFuture<Option<Block<Transaction>>, T::Out> {
        let include_txs = helpers::serialize(&true);

        let result = match block {
            BlockId::Hash(hash) => {
                let hash = helpers::serialize(&hash);
                self.transport
                    .execute("hmyv2_getBlockByHash", vec![hash, include_txs])
            }
            BlockId::Number(num) => {
                let num = helpers::serialize(&num);
                self.transport
                    .execute("hmyv2_getBlockByNumber", vec![num, include_txs])
            }
        };

        CallFuture::new(result)
    }

    /// Get number of transactions in block
    pub fn block_transaction_count(&self, block: BlockId) -> CallFuture<Option<U256>, T::Out> {
        let result = match block {
            BlockId::Hash(hash) => {
                let hash = helpers::serialize(&hash);
                self.transport
                    .execute("hmy_getBlockTransactionCountByHash", vec![hash])
            }
            BlockId::Number(num) => {
                let num = helpers::serialize(&num);
                self.transport
                    .execute("hmy_getBlockTransactionCountByNumber", vec![num])
            }
        };

        CallFuture::new(result)
    }

    /// Get number of transactions in block v2
    pub fn block_transaction_count_v2(&self, block: BlockId) -> CallFuture<Option<U256>, T::Out> {
        let result = match block {
            BlockId::Hash(hash) => {
                let hash = helpers::serialize(&hash);
                self.transport
                    .execute("hmyv2_getBlockTransactionCountByHash", vec![hash])
            }
            BlockId::Number(num) => {
                let num = helpers::serialize(&num);
                self.transport
                    .execute("hmyv2_getBlockTransactionCountByNumber", vec![num])
            }
        };

        CallFuture::new(result)
    }

    /// Get code under given address
    pub fn code(&self, address: Address, block: Option<BlockNumber>) -> CallFuture<Bytes, T::Out> {
        let address = helpers::serialize(&address);
        let block = helpers::serialize(&block.unwrap_or(BlockNumber::Latest));

        CallFuture::new(self.transport.execute("hmy_getCode", vec![address, block]))
    }

    /// Get storage entry
    pub fn storage(
        &self,
        address: Address,
        idx: U256,
        block: Option<BlockNumber>,
    ) -> CallFuture<H256, T::Out> {
        let address = helpers::serialize(&address);
        let idx = helpers::serialize(&idx);
        let block = helpers::serialize(&block.unwrap_or(BlockNumber::Latest));

        CallFuture::new(
            self.transport
                .execute("hmy_getStorageAt", vec![address, idx, block]),
        )
    }

    /// Get nonce
    pub fn transaction_count(
        &self,
        address: Address,
        block: Option<BlockNumber>,
    ) -> CallFuture<U256, T::Out> {
        let address = helpers::serialize(&address);
        let block = helpers::serialize(&block.unwrap_or(BlockNumber::Latest));

        CallFuture::new(
            self.transport
                .execute("hmy_getTransactionCount", vec![address, block]),
        )
    }

    /// Get nonce v2
    pub fn transaction_count_v2(
        &self,
        address: Address,
        block: Option<BlockNumber>,
    ) -> CallFuture<U256, T::Out> {
        let address = helpers::serialize(&address);
        let block = helpers::serialize(&block.unwrap_or(BlockNumber::Latest));

        CallFuture::new(
            self.transport
                .execute("hmyv2_getTransactionCount", vec![address, block]),
        )
    }

    /// Get transaction
    pub fn transaction(&self, id: TransactionId) -> CallFuture<Option<Transaction>, T::Out> {
        let result = match id {
            TransactionId::Hash(hash) => {
                let hash = helpers::serialize(&hash);
                self.transport
                    .execute("hmy_getTransactionByHash", vec![hash])
            }
            TransactionId::Block(BlockId::Hash(hash), index) => {
                let hash = helpers::serialize(&hash);
                let idx = helpers::serialize(&index);
                self.transport
                    .execute("hmy_getTransactionByBlockHashAndIndex", vec![hash, idx])
            }
            TransactionId::Block(BlockId::Number(number), index) => {
                let number = helpers::serialize(&number);
                let idx = helpers::serialize(&index);
                self.transport
                    .execute("hmy_getTransactionByBlockNumberAndIndex", vec![number, idx])
            }
        };

        CallFuture::new(result)
    }

    /// Get transaction v2
    pub fn transaction_v2(&self, id: TransactionId) -> CallFuture<Option<Transaction>, T::Out> {
        let result = match id {
            TransactionId::Hash(hash) => {
                let hash = helpers::serialize(&hash);
                self.transport
                    .execute("hmyv2_getTransactionByHash", vec![hash])
            }
            TransactionId::Block(BlockId::Hash(hash), index) => {
                let hash = helpers::serialize(&hash);
                let idx = helpers::serialize(&index);
                self.transport
                    .execute("hmyv2_getTransactionByBlockHashAndIndex", vec![hash, idx])
            }
            TransactionId::Block(BlockId::Number(number), index) => {
                let number = helpers::serialize(&number);
                let idx = helpers::serialize(&index);
                self.transport.execute(
                    "hmyv2_getTransactionByBlockNumberAndIndex",
                    vec![number, idx],
                )
            }
        };

        CallFuture::new(result)
    }

    /// Get transaction receipt
    pub fn transaction_receipt(
        &self,
        hash: H256,
    ) -> CallFuture<Option<TransactionReceipt>, T::Out> {
        let hash = helpers::serialize(&hash);

        CallFuture::new(
            self.transport
                .execute("hmy_getTransactionReceipt", vec![hash]),
        )
    }

    /// Get transaction receipt v2
    pub fn transaction_receipt_v2(
        &self,
        hash: H256,
    ) -> CallFuture<Option<TransactionReceipt>, T::Out> {
        let hash = helpers::serialize(&hash);

        CallFuture::new(
            self.transport
                .execute("hmyv2_getTransactionReceipt", vec![hash]),
        )
    }

    /// Start new block filter
    pub fn new_block_filter(&self) -> CallFuture<U256, T::Out> {
        CallFuture::new(self.transport.execute("eth_newBlockFilter", vec![]))
    }

    /// Start new pending transaction filter
    pub fn new_pending_transaction_filter(&self) -> CallFuture<U256, T::Out> {
        CallFuture::new(
            self.transport
                .execute("eth_newPendingTransactionFilter", vec![]),
        )
    }

    /// Sends a transaction transaction
    pub fn send_transaction(&self, tx: TransactionRequest) -> CallFuture<H256, T::Out> {
        let tx = helpers::serialize(&tx);
        CallFuture::new(self.transport.execute("eth_sendTransaction", vec![tx]))
    }

    /// Sends a rlp-encoded signed transaction
    pub fn send_raw_transaction(&self, rlp: Bytes) -> CallFuture<H256, T::Out> {
        let rlp = helpers::serialize(&rlp);
        CallFuture::new(self.transport.execute("hmy_sendRawTransaction", vec![rlp]))
    }

    /// Get syncing status
    pub fn syncing(&self) -> CallFuture<SyncState, T::Out> {
        CallFuture::new(self.transport.execute("hmy_syncing", vec![]))
    }
}

#[cfg(test)]
mod tests {}
