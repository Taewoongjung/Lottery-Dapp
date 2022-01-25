const { assert } = require("chai");
const assertRevert = require("./assertRevert");
const expectEvent = require("./expectEvent");
const Lottery = artifacts.require("Lottery");

contract('Lottery', function([deployer, user1, user2]) {
    let lottery;
    let betAmount = 5 * 10 ** 15;
    let bet_block_interval = 3;
    let betAmountBN = new web3.utils.BN('5000000000000000');
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
        it('should fail when the bet money is not 0.005 ETH', async () => {
            // Fail transaction
            await assertRevert(lottery.bet('0xab', {from: user1, value: 4000000000000000}))
        })
        it('should put the bet to the bet queue with 1 bet', async () => {
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

    describe('isMatch', function () {
        let blockHash = '0xab3db5f8136be0b9de9179a5e774a561337b595137331a847257f34d7b55988f'

        it('should be BettingResult.Win when two characters match', async () => {
            let matchingResult = await lottery.isMatch('0xab', blockHash);
            assert.equal(matchingResult, 1);
        })

        it('should be BettingResult.Win when two characters match', async () => {
            let matchingResult = await lottery.isMatch('0xcd', blockHash);
            assert.equal(matchingResult, 0);
        })

        it('should be BettingResult.Win when two characters match', async () => {
            let matchingResult = await lottery.isMatch('0xaa', blockHash);
            assert.equal(matchingResult, 2);
        })  
    })

    describe('Distribute', function () {
        describe('When the answer is checkable', function () {
            it.only('should give the user the pot when the answer matches', async () => {
                // 두 글자 다 맞았을 때
                await lottery.setAnswerForTest('0xabb6379594a0126ff123bf764686b4f1ac0db4d01b662438c320c1c251aaf803', {from:deployer})
                
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 1 -> 4
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 2 -> 5
                await lottery.betAndDistribute('0xab', {from:user1, value:betAmount}) // 3 -> 6
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 4 -> 7
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 5 -> 8
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 6 -> 9
                
                let potBefore = await lottery.getPot(); // 0.005 ETH가 두 번 쌓이니 0.01 ETH가 있어야 한다. 
                let user1BalanceBefore = await web3.eth.getBalance(user1);

                let receipt7 = await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 7 -> 10 // 여기서 정답을 체크하고 user1에게 pot이 간다
                
                let potAfter = await lottery.getPot(); // == 0
                let user1BalanceAfter = await web3.eth.getBalance(user1); // == before + 0.015

                // pot 의 변화량 확인
                console.log("aaa ", user1BalanceBefore);
                assert.equal(potBefore.toString(), new web3.utils.BN('10000000000000000').toString());
                assert.equal(potAfter.toString(), new web3.utils.BN('0'.toString()));
                
                // user(winner)의 밸런스를 확인
                user1BalanceBefore = new web3.utils.BN(user1BalanceBefore);
                console.log("a = ", user1BalanceBefore.add(potBefore).add(betAmountBN).toString());
                console.log("b = ", new web3.utils.BN(user1BalanceAfter).toString());
                assert.equal(user1BalanceBefore.add(potBefore).add(betAmountBN).toString(), new web3.utils.BN(user1BalanceAfter).toString());
            })

            it('should give the user the amount he or she bet when a single character matches', async () => {
                // 한 글자만 맞았을 때
                await lottery.setAnswerForTest('0xabb6379594a0126ff123bf764686b4f1ac0db4d01b662438c320c1c251aaf803', {from:deployer})
                
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 1 -> 4
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 2 -> 5
                await lottery.betAndDistribute('0xaf', {from:user1, value:betAmount}) // 3 -> 6
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 4 -> 7
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 5 -> 8
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 6 -> 9
                
                let potBefore = await lottery.getPot(); //  == 0.01 ETH
                let user1BalanceBefore = await web3.eth.getBalance(user1);
                
                let receipt7 = await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 7 -> 10 // user1에게 pot이 간다

                let potAfter = await lottery.getPot(); // == 0.01 ETH
                let user1BalanceAfter = await web3.eth.getBalance(user1); // == before + 0.005 ETH
                
                // pot 의 변화량 확인
                assert.equal(potBefore.toString(), potAfter.toString());

                // user(winner)의 밸런스를 확인
                user1BalanceBefore = new web3.utils.BN(user1BalanceBefore);
                assert.equal(user1BalanceBefore.add(betAmountBN).toString(), new web3.utils.BN(user1BalanceAfter).toString())
            })

            it('should get the eth of user when the answer does not match at all', async () => {
                // 다 틀렷을 때
                await lottery.setAnswerForTest('0xabb6379594a0126ff123bf764686b4f1ac0db4d01b662438c320c1c251aaf803', {from:deployer})
                
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 1 -> 4
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 2 -> 5
                await lottery.betAndDistribute('0xef', {from:user1, value:betAmount}) // 3 -> 6
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 4 -> 7
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 5 -> 8
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 6 -> 9
                
                let potBefore = await lottery.getPot(); //  == 0.01 ETH
                let user1BalanceBefore = await web3.eth.getBalance(user1);
                
                let receipt7 = await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 7 -> 10 // user1에게 pot이 간다

                let potAfter = await lottery.getPot(); // == 0.015 ETH
                let user1BalanceAfter = await web3.eth.getBalance(user1); // == before
                
                // pot 의 변화량 확인
                assert.equal(potBefore.add(betAmountBN).toString(), potAfter.toString());

                // user(winner)의 밸런스를 확인
                user1BalanceBefore = new web3.utils.BN(user1BalanceBefore);
                assert.equal(user1BalanceBefore.toString(), new web3.utils.BN(user1BalanceAfter).toString())
            })
        })
        describe('When the answer is revealed(Not Mined)', function () {
            
        })
        describe('When the answer is not revealed(Block limit is passed)', function () {
            
        })
    })
})