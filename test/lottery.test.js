const _deploy_smart_contract = require("../migrations/2_deploy_smart_contract");

const Lottery = artifacts.require("Lottery");

contract('Lottery', function([deployer, user1, user2]) {
    let lottery;
    beforeEach(async () => {
        console.log('Before each')
        lottery = await Lottery.new();
    })

    it('getPot should return current pot', async () => {
        let pot = await lottery.getPot();
        assert.equal(pot, 0)
    })

    // bet function test
    describe('Bet', function() {
        it.only('should fail when the bet money is not 0.005 ETH', async () => {
            // Fail transaction
            await lottery.bet('0xab', {from: user1, value: 5000000000000000})
        })
        it('should put the bet to the bet queue with 1 bet', async () => {
            // bet
                
            // check contract balance == 0.005

            // check bet info

            // check log
        })
    })
})