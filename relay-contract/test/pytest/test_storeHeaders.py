import pytest

import utils
import constants
from constants import *


@pytest.fixture(scope="session", autouse=True)
def compile_contract(request):
    utils.compile_contract(CONTRACT)
    utils.compile_contract("Utils")
    utils.compile_contract("SafeMath"
    utils.deploy_contract("Utils")
    utils.deploy_contract("SafeMath")


@pytest.fixture()
def contract():
    return utils.deploy_contract(CONTRACT)


def test_compilation():
    utils.compile_contract(CONTRACT)


def test_deployment(contract):
    # tests fixture for contract
    pass
