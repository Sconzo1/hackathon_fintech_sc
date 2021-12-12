const Request = artifacts.require('Request')

module.exports = async function (deployer, network, accounts) {
    await deployer.deploy(Request, 'goal', 40, 50, 100, Date.now(), [-1, -1, -1, -1], 1, accounts[1])
    const token = await Request.deployed()
    console.log(
        `Request deployed at ${token.address} in network: ${network}.`
    );
} as Truffle.Migration

// because of https://stackoverflow.com/questions/40900791/cannot-redeclare-block-scoped-variable-in-unrelated-files
export {}
