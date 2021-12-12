const Request = artifacts.require('Request')

module.exports = async function (deployer, network, accounts) {

    const hardEnd = Date.now() + 1000 * 3600 * 24           // +1 day
    const coupon1 = Date.now() + 1000 * 3600 * 24 * 2       // +2 day
    const coupon2 = Date.now() + 1000 * 3600 * 24 * 3       // +3 day
    const coupon3 = Date.now() + 1000 * 3600 * 24 * 4       // +4 day
    const coupon4 = Date.now() + 1000 * 3600 * 24 * 5       // +5 day

    await deployer.deploy(Request, 'goal', 40, 50, 100, hardEnd,
        [coupon1, coupon2, coupon3, coupon4],
        1, accounts[1])
    const token = await Request.deployed()
    console.log(
        `Request deployed at ${token.address} in network: ${network}.`,
    )
} as Truffle.Migration

// because of https://stackoverflow.com/questions/40900791/cannot-redeclare-block-scoped-variable-in-unrelated-files
export {}
