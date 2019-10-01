

CONTRACT = "BTCRelay"


ERR_GENESIS_SET = "Initial parent has already been set"
ERR_INVALID_FORK_ID = "Incorrect fork identifier: id 0 is no available"
ERR_INVALID_HEADER_SIZE = "Invalid block header size"
ERR_DUPLICATE_BLOCK = "Block already stored"
ERR_PREV_BLOCK = "Previous block hash not found" 
ERR_LOW_DIFF = "PoW hash does not meet difficulty target of header"
ERR_DIFF_TARGET_HEADER = "Incorrect difficulty target specified in block header"
ERR_NOT_MAIN_CHAIN = "Main chain submission indicated, but submitted block is on a fork"
ERR_FORK_PREV_BLOCK = "Previous block hash does not match last block in fork submission"
ERR_NOT_FORK = "Indicated fork submission, but block is in main chain"
ERR_INVALID_TXID = "Invalid transaction identifier"
ERR_CONFIRMS = "Transaction has less confirmations than requested" 
ERR_MERKLE_PROOF = "Invalid Merkle Proof structure"