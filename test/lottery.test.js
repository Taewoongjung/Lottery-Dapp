const _deploy_smart_contract = require("../migrations/2_deploy_smart_contract");

const Lottery = artifacts.require("Lottery");

contract('Lottery', function([deployer, user1, user2]) {
    let lottery;
    beforeEach(async () => {
        console.log('Before each')

        lottery = await Lottery.new();
    })

    it.only('getPot should return current pot', async () => {
        let pot = await lottery.getPot();
        assert.equal(pot, 0)
    })
})