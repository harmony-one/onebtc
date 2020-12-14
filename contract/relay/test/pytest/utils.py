# 
# Copyright 2018 Philipp Schindler
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

import web3
import solc
import time
import threading
import hashlib
import os
import subprocess
import types

SOLC_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "bin", "solc"))
CONTRACTS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "contracts"))
CONTRACTS_DIR_BIN = os.path.join(CONTRACTS_DIR, "bin")

w3 = None


def connect(port=8545):
    global w3
    if w3 is None or not w3.isConnected:
        # large request timeout required for performance tests
        w3 = web3.Web3(
            web3.HTTPProvider(f"http://127.0.0.1:{port}", request_kwargs={"timeout": 60 * 10})
        )
    assert w3.isConnected
    return w3


def get_account_address(account_idx=-1):
    connect()
    return w3.eth.accounts[account_idx]


def compile_contract(contract_name: str):
    return subprocess.check_output(
        [
            SOLC_PATH,
            "--abi",
            "--bin",
            "--optimize",
            "--overwrite",
            "--output-dir",
            CONTRACTS_DIR_BIN,
            os.path.join(CONTRACTS_DIR, contract_name + ".sol"),
        ]
    ).decode()


def load_contract(contract_name, str):
    with open(os.path.join(CONTRACTS_DIR_BIN, contract_name + ".bin"), "r") as f:
        contract_bin = f.read()
    with open(os.path.join(CONTRACTS_DIR_BIN, contract_name + ".abi"), "r") as f:
        contract_abi = f.read()
    return contract_abi, contract_bin

def deploy_contract(
    contract_name,
    deploying_account_address=None,
    gas=80_000_000,
    should_add_simplified_call_interfaces=True,
    return_tx_receipt=False,
    linked_contracts=None
):  # , patch_api=True, return_tx_receipt=False):
    """ Deploys the compiled contract (from the /contracts/bin folder) and
        returns the contract instance.
        Links imported contracts parsed as "linked_contracts" (from the /contracts/bin folder)
    """
    connect()
    if deploying_account_address is None:
        deploying_account_address = w3.eth.accounts[-1]

    with open(os.path.join(CONTRACTS_DIR_BIN, contract_name + ".abi"), "r") as f_abi:
        with open(os.path.join(CONTRACTS_DIR_BIN, contract_name + ".bin"), "r") as f_bin:

            contract = w3.eth.contract(abi=f_abi.read(), bytecode=f_bin.read())
    tx_hash = contract.constructor().transact({"from": deploying_account_address, "gas": gas})
    mine_block()
    tx_receipt = wait_for_tx_receipt(tx_hash)
    contract = get_contract(
        contract_name, tx_receipt["contractAddress"], should_add_simplified_call_interfaces
    )
    if return_tx_receipt:
        return contract, tx_receipt
    return contract


def link_contracts(contract, linked_contracts):
    for linked_contract in linked_contracts:
        contract

def get_contract(contract_name, contract_address, should_add_simplified_call_interfaces=True):
    """ Gets the instance of an already deployed contract.
        if patch_api is set, all transactions are automatically syncronized, unless wait=False is specified in the tx
    """
    connect()
    with open(os.path.join(CONTRACTS_DIR_BIN, contract_name + ".abi"), "r") as f_abi:
        contract = w3.eth.contract(address=contract_address, abi=f_abi.read())

    if should_add_simplified_call_interfaces:
        add_simplified_call_interfaces(contract)

    return contract


def wait_for_tx_receipt(tx_hash):
    connect()
    return w3.eth.waitForTransactionReceipt(tx_hash)


def wait_for_block(target_block_number):
    while block_number() < target_block_number:
        time.sleep(0.5)


# def call_async(contract)

# def call_sync(contract, func_name, *args, account_idx=-1):
#     account = get_account(account_idx)
#     tx_hash = contract.functions.__getattribute__(func_name)(*args).transact({"from": account})
#     mine_block()
#     tx


class SimplifiedCallInterface:
    def __init__(self, contract, fn_name):
        self._func = getattr(contract.functions, fn_name)

    def __call__(self, *args, **kwargs):
        return SimplifiedCallInterfaceCall(self._func, *args, **kwargs)


class SimplifiedCallInterfaceCall:
    def __init__(self, _func, *args, **kwargs):
        self._func = _func
        self.args = args
        self.kwargs = kwargs

    def call_sync(self, caller_account_address=None):
        if caller_account_address is None:
            caller_account_address = get_account_address()
        tx_hash = self.call_async(caller_account_address)
        mine_block()
        return wait_for_tx_receipt(tx_hash)

    def call_async(self, caller_account_address=None):
        if caller_account_address is None:
            caller_account_address = get_account_address()
        tx_hash = self._func(*self.args, **self.kwargs).transact({"from": caller_account_address})
        return tx_hash

    def call(self, caller_account_address=None, sync=True):
        if sync:
            return self.call_sync(caller_account_address)
        return self.call_async(caller_account_address)


def add_simplified_call_interfaces(contract):
    fn_names = []
    for func in contract.all_functions():
        try:
            getattr(contract, func.fn_name)
            raise Exception("Cannot add simplyfied call interface due to naming conflict!")
        except AttributeError:
            fn_names.append(func.fn_name)

    for fn_name in fn_names:
        setattr(contract, fn_name, SimplifiedCallInterface(contract, fn_name))


# def filehash(path):
#     with open(path, "rb") as f:
#         return hashlib.md5(f.read()).hexdigest()


# def compile_contract(contract_name):
#     """ compiles the given contract (from the ./contracts folder)
#         and returns its ABI interface
#     """

#     path = os.getcwd()
#     if path.endswith("client"):
#         path = f"../contracts/{contract_name}.sol"
#     else:
#         path = f"./contracts/{contract_name}.sol"

#     h = filehash(path)

#     interface = cache.get(h)
#     if interface:
#         return interface

#     with open(path) as f:
#         src = f.read()
#     for i in solc.compile_source(src, optimize=True).values():
#         interface = i
#         break

#     cache[h] = interface
#     return interface


# def get_contract(contract_name, contract_address, patch_api=True):
#     """ gets the instance of an already deployed contract
#         if patch_api is set, all transactions are automatically syncronized, unless wait=False is specified in the tx
#     """
#     connect()

#     interface = compile_contract(contract_name)
#     instance = w3.eth.contract(
#         address=contract_address, abi=interface["abi"], ContractFactoryClass=web3.contract.ConciseContract
#     )
#     if patch_api:
#         for name, func in instance.__dict__.items():
#             if isinstance(func, web3.contract.ConciseMethod):
#                 instance.__dict__[name] = _tx_executor(func)

#     # add event handling stuff to the instance object
#     contract = w3.eth.contract(abi=interface["abi"], bytecode=interface["bin"])
#     instance.eventFilter = contract.eventFilter
#     instance.events = contract.events
#     return instance


# def _tx_executor(contract_function):
#     """ modifies the contract instance interface function such that whenever a transaction is performed
#         it automatically waits until the transaction in included in the blockchain
#         (unless wait=False is specified, in the case the default the api acts as usual)
#     """

#     def f(*args, **kwargs):
#         wait = kwargs.pop("wait", True)
#         if "transact" in kwargs and wait:
#             tx_hash = contract_function(*args, **kwargs)
#             tx_receipt = w3.eth.waitForTransactionReceipt(tx_hash)
#             return tx_receipt
#         return contract_function(*args, **kwargs)

#     return f


# def deploy_contract(contract_name, account=None, patch_api=True, return_tx_receipt=False):
#     """ compiles and deploy the given contract (from the ./contracts folder)
#         returns the contract instance
#     """
#     connect()
#     if account is None:
#         account = w3.eth.accounts[-1]

#     interface = compile_contract(contract_name)
#     contract = w3.eth.contract(abi=interface["abi"], bytecode=interface["bin"])

#     # increase max gas t
#     # tx_hash = contract.constructor().transact({'from': account, 'gas': 7_500_000})

#     tx_hash = contract.constructor().transact({"from": account, "gas": 5_000_000})
#     tx_receipt = w3.eth.waitForTransactionReceipt(tx_hash)

#     c = get_contract(contract_name, tx_receipt["contractAddress"], patch_api)
#     if return_tx_receipt:
#         return c, tx_receipt
#     return c


# def flatten(list_of_lists):
#     return [y for x in list_of_lists for y in x]


# def get_events(contract_instance, event_name, from_block=0, to_block=None):
#     # eventFilter = contract.eventFilter(event_name, {'fromBlock': 0})
#     eventFilter = contract_instance.events.__dict__[event_name].createFilter(fromBlock=from_block, toBlock=to_block)
#     return [e for e in eventFilter.get_all_entries() if e.address == contract_instance.address]


# def wait_for(predicate, check_interval=1.0):
#     while not predicate():
#         time.sleep(check_interval)


def mine_block():
    connect()
    w3.provider.make_request("evm_mine", params="")


def mine_blocks(num_blocks):
    for i in range(num_blocks):
        mine_block()


def mine_blocks_until(predicate):
    while not predicate():
        mine_block()


def block_number():
    connect()
    return w3.eth.blockNumber


# def run(func_or_funcs, args=()):
#     """ executes the given functions in parallel and waits
#         until all execution have finished
#     """
#     threads = []
#     if isinstance(func_or_funcs, list):
#         funcs = func_or_funcs
#         for i, f in enumerate(funcs):
#             arg = args[i] if isinstance(args, list) else args
#             if (arg is not None) and (not isinstance(arg, tuple)):
#                 arg = (arg,)
#             threads.append(threading.Thread(target=f, args=arg))
#     else:
#         func = func_or_funcs
#         assert isinstance(args, list)
#         for arg in args:
#             xarg = arg if isinstance(arg, tuple) else (arg,)
#             threads.append(threading.Thread(target=func, args=xarg))

#     for t in threads:
#         t.start()
#     for t in threads:
#         t.join()

