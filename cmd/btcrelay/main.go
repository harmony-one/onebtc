// Copyright (c) 2014-2017 The btcsuite developers
// Use of this source code is governed by an ISC
// license that can be found in the LICENSE file.

package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"path"

	"github.com/btcsuite/btcd/rpcclient"
)

var (
	version string
	builtBy string
	builtAt string
	commit  string
)

func printVersion(me string) {
	fmt.Fprintf(os.Stderr, "Harmony (C) 2020. %v, version %v-%v (%v %v)\n", path.Base(me), version, commit, builtBy, builtAt)
	os.Exit(0)
}

func main() {
	blockNum := flag.Int64("block", -1, "bitcoin block number (-1: latest block)")
	ip := flag.String("ip", "127.0.0.1", "IP of the bitcoin node")
	port := flag.String("port", "8332", "RPC port of the bitcoin node")
	user := flag.String("user", "", "user name to access the bitcoin rpc")
	passwd := flag.String("pass", "", "password to access the bitcoin rpc")
	versionFlag := flag.Bool("version", false, "Output version info")

	flag.Parse()

	if *versionFlag {
		printVersion(os.Args[0])
	}

	// Connect to local bitcoin core RPC server using HTTP POST mode.
	connCfg := &rpcclient.ConnConfig{
		Host:         fmt.Sprintf("%s:%s", *ip, *port),
		User:         *user,
		Pass:         *passwd,
		HTTPPostMode: true, // Bitcoin core only supports HTTP POST mode
		DisableTLS:   true, // Bitcoin core does not provide TLS by default
	}
	// Notice the notification parameter is nil since notifications are
	// not supported in HTTP POST mode.
	client, err := rpcclient.New(connCfg, nil)
	if err != nil {
		log.Fatal(err)
	}
	defer client.Shutdown()

	// Get the current block count.
	blockCount, err := client.GetBlockCount()
	if err != nil {
		log.Fatal(err)
	}

	theBlockNum := *blockNum
	if *blockNum == -1 {
		theBlockNum = blockCount
	}
	log.Printf("Get block: %d", theBlockNum)

	blockHash, err := client.GetBlockHash(theBlockNum)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("Block hash: %s", blockHash)
	blockHeader, err := client.GetBlockHeader(blockHash)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("Block header: %v", blockHeader)
	log.Printf("version: %d", blockHeader.Version)
	log.Printf("hashPrevBlock: %v", blockHeader.PrevBlock)
	log.Printf("merkleRoot: %v", blockHeader.MerkleRoot)
	log.Printf("time: %v", blockHeader.Timestamp)
	log.Printf("nBits: %d", blockHeader.Bits)
	log.Printf("Nonce: %d", blockHeader.Nonce)

	theBlock, err := client.GetBlock(blockHash)
	if err != nil {
		log.Fatal(err)
	}

	log.Printf("Header: %v", theBlock.Header)
	log.Printf("Num Tx: %d", len(theBlock.Transactions))

	for i, tx := range theBlock.Transactions {
		log.Printf("tx: %d", i)
		log.Printf("tx ver: %d", tx.Version)
		log.Printf("tx in: %d", len(tx.TxIn))
		for _, txi := range tx.TxIn {
			log.Printf("txi.prev: %v", txi.PreviousOutPoint)
			log.Printf("txi.signature: %v", txi.SignatureScript)
			log.Printf("txi.witness: %v", txi.Witness)
			log.Printf("txi.seq: %v", txi.Sequence)
		}
		log.Printf("tx out: %d", len(tx.TxOut))
		for _, txo := range tx.TxOut {
			log.Printf("txo.v: %v", txo.Value)
			log.Printf("txo.size: %d", len(txo.PkScript))
			log.Printf("txo.script: %v", txo.PkScript)
		}
		log.Printf("tx locktime: %v", tx.LockTime)
	}
}
