from brownie import (
    network,
    config,
    accounts,
    Contract,
    interface,
    Exchange,
)
from scripts.helpful_scripts import get_account


def main():
    account = get_account()
    exchange = Exchange.deploy(
        config["contract_address"]["cryptodev_token"],
        {"from": account},
        publish_source=config["networks"][network.show_active()]["verify"],
    )
