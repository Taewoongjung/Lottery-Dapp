const assertRevert = require("./assertRevert");
const expectEvent = require("./expectEvent");
const Lottery = artifacts.require("Lottery");

contract('Lottery', function([deployer, user1, user2]) {
    let lottery;
    let betAmount = 5 * 10 ** 15;
    let bet_block_interval = 3;
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
            await assertRevert(lottery.bet('0xab', {from: user1, value: 4000000000000000}))
        })
        it.only('should put the bet to the bet queue with 1 bet', async () => {
            // bet
            let receipt = await lottery.bet('0xab', {from: user1, value: 5000000000000000})
            // console.log(receipt);

            let pot = await lottery.getPot();
            assert.equal(pot, 0);

            // check contract balance == 0.005
            let contractBalance = await web3.eth.getBalance(lottery.address);
            assert.equal(contractBalance, betAmount);
            
            // check bet info
            let currentBlockNumber = await web3.eth.getBlockNumber();
            let bet = await lottery.getBetInfo(0);
            
            bet.answerBlockNumber
            bet.bettor
            bet.challenges
            
            assert.equal(bet.answerBlockNumber, currentBlockNumber + bet_block_interval);
            assert.equal(bet.bettor, user1);
            assert.equal(bet.challenges, '0xab');

            // check log
            // console.log(receipt);
            await expectEvent.inLogs(receipt.logs, 'BET');
        })
    })
})