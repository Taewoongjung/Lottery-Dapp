pragma solidity >=0.4.21 <0.6.0;

contract Lottery {
    struct BetInfo {
        uint256 answerBlockNumber;  // 맞추려는 정답 블록
        address payable bettor;  // 정답을 맞출 때 bettor에게 돈을 보내야 함. (0.42 이상 부터 돈을 보내려면 payable을 붙여야 돈을 보내기 가능하다)
        byte challenges; // 0xab...
    }

    uint256 private _tail;
    uint256 private _head;

    // map을 이용한 선형 queue
    mapping (uint256 => BetInfo) private _bets;

    /* public으로 만들게 되면 자동으로 getter를 만들어준다. 그래서 스마트 컨트랙트 외부에서 owner값을 확인할 수 있게되는 것이다. */
    address payable public owner;

    uint256 constant internal BLOCK_LIMIT = 256;
    uint256 constant internal BET_BLOCK_INTERVAL = 3; // 블록들 간의 간격
    uint256 constant internal BET_AMOUNT = 5 * 10 ** 15; // 0.005ETH
    uint256 private _pot;

    bool private mode = false; // false : use answer for test, true : real block hash
    bytes32 public answerForTest;

    enum BlockStatus {Checkable, NotRevealed, BlockLimitPassed}
    enum BettingResult{Fail, Win, Draw}
    event BET(uint256 index, address bettor, uint256 amount, byte challenges, uint256 answerBlockNumber);
    event WIN(uint256 index, address bettor, uint256 amount, byte challenges, byte answer, uint256 answerBlockNumber);
    event FAIL(uint256 index, address bettor, uint256 amount, byte challenges, byte answer, uint256 answerBlockNumber);
    event DRAW(uint256 index, address bettor, uint256 amount, byte challenges, byte answer, uint256 answerBlockNumber);
    event REFUND(uint256 index, address bettor, uint256 amount, byte challenges, uint256 answerBlockNumber);

    /* 
        스마트 컨트랙트가 생성이 될 때(배포가 될 때) 가장 처음 실행되는 함수인데, 
        배포가 될 때 보낸 사람(msg.sender)으로 owner를 저장하는 의미이다.
    */
    constructor() public { // 생성자
        owner = msg.sender;
    }

    // pot에 대한 getter
    function getPot() public view returns (uint256 value) { // 스마트 컨트랙트에 있는 변수를 줘야하는 수식어는 "view"가 들어가야한다
        return _pot;
    }

    // Bet - 배팅하는 함수
    /**
     *  @dev 배팅을 한다. 유저는 0.005 ETH를 보내야 하고, 베팅을 1 byte 글자를 보낸다.
        큐에 저장된 배팅 정보는 이후 distribute 함수에서 해결된다.
     *  @param challenges 유저가 배팅하는 글자
     *  @return 함수가 잘 수행되었는지 확인하는 bool 값
     */
    function bet(byte challenges) public payable returns (bool result) {
        // check the proper ether is sent
        require(msg.value == BET_AMOUNT, "Not enough ETH"); // 들어 온 돈에 대해서 확인할 수 있는게 msg.value 이다.
        
        // push bet to the queue
        require(pushBet(challenges), "Fail to add a new Bet Info");

        // emit event
        emit BET(_tail - 1, msg.sender, msg.value, challenges, block.number + BET_BLOCK_INTERVAL);
        
        return true;
    }
        // save the bet to the queue
    /**
     * @dev 베팅 결과값을 확인 하고 팟머니를 분배한다.
     * 정답 실패: 팟머니 축척, 정답 맞춤: 팟머니 획득, 한글자 맞춤 or 정답 확인 불가: 베팅 금액만 획득
    */
    // Distribute - 베팅을 하면 정답을 맞춘 사람에게는 돈을 돌려주고 아니면 돈을 pot에 갖는 시스템
    function distribute() public {
        uint256 cur;
        uint256 transferAmount;

        BetInfo memory b;
        BlockStatus currentBlockStatus;
        BettingResult currentBettingResult;

        for(cur=_head;cur<_tail;cur++) {
            b = _bets[cur];
            currentBlockStatus = getBlockStatus((b.answerBlockNumber));
            bytes32 answerBlockHash = getAnswerBlockHash(b.answerBlockNumber);
            if(currentBlockStatus == BlockStatus.Checkable) {
                currentBettingResult = isMatch(b.challenges, answerBlockHash);
                // if win, bettor gets pot
                if(currentBettingResult == BettingResult.Win) {
                    // transfer pot
                    transferAmount = transferAfterPayingFee(b.bettor, _pot + BET_AMOUNT);
                    
                    // pot = 0
                    _pot = 0;
                    
                    // emit event(WIN)
                    emit WIN(cur, b.bettor, transferAmount, b.challenges, answerBlockHash[0], b.answerBlockNumber);
                }
                // if fail bettor's money goes pot
                if(currentBettingResult == BettingResult.Fail) {
                    // pot = pot + BET_AMOUNT
                    _pot += BET_AMOUNT;
                    // emit FAIL
                    emit FAIL(cur, b.bettor, 0, b.challenges, answerBlockHash[0], b.answerBlockNumber);
                }
                // if draw, refund bettor's money
                if(currentBettingResult == BettingResult.Fail) {
                    // transfer only BET_AMOUNT
                    transferAmount = transferAfterPayingFee(b.bettor, BET_AMOUNT);

                    // emit DRAW
                    emit FAIL(cur, b.bettor, transferAmount, b.challenges, answerBlockHash[0], b.answerBlockNumber);
                }
            }

            if(currentBlockStatus == BlockStatus.NotRevealed) {
                break;
            }

            if(currentBlockStatus == BlockStatus.BlockLimitPassed) {
                // refund
                transferAmount = transferAfterPayingFee(b.bettor, BET_AMOUNT);
                //emit refund
                emit REFUND(cur, b.bettor, transferAmount, b.challenges, b.answerBlockNumber);
            }
            popBet(cur);
        }
        _head = cur;
    }
    function transferAfterPayingFee(address payable addr, uint256 amount) internal returns (uint256) {
        uint256 fee = 0;
        uint256 amountWithoutFee = amount - fee;

        // transfer to addr
        addr.transfer(amountWithoutFee);
        // transfer to owner
        owner.transfer(fee);

        // call, send, transfer
        
        return amountWithoutFee;
    }
    function setAnswerForTest(bytes32 answer) public returns (bool result) {
        require(msg.sender == owner, "Only owner can set the answer for test mode");
        answerForTest = answer;
        return true;
    }
    function getAnswerBlockHash(uint256 answerBlockNumber) internal view returns (bytes32 answer) {
        return mode ? blockhash(answerBlockNumber) : answerForTest;
    }
    /**
     * @dev 베팅금지와 정답을 확인한다.
     * @param challenges 베팅 금지
     * @param answer 블락 해쉬
     * @return 정답결과
     */
    function isMatch(byte challenges, bytes32 answer) public pure returns (BettingResult) {
        // challenges 0xab
        // answer 0xab......ff 32 bytes

        byte c1 = challenges;
        byte c2 = challenges;

        byte a1 = answer[0];
        byte a2 = answer[0];

        // Get first number
        c1 = c1 >> 4; // 0xab -> 0x0a
        c1 = c1 << 4; // 0x0a -> 0xa0

        a1 = a1 >> 4;
        a1 = a1 << 4;

        // Get Second number
        c2 = c2 << 4; // 0xab -> 0xb0
        c2 = c2 >> 4; // 0xb0 -> 0x0b

        a2 = a2 << 4;
        a2 = a2 >> 4;

        if(a1 == c1 && a2 == c2) {
            return BettingResult.Win;
        }

        if(a1 == c1 || a2 == c2) {
            return BettingResult.Draw;
        }

        return BettingResult.Fail;

    }

    function getBlockStatus(uint256 answerBlockNumber) internal view returns(BlockStatus) {
        if(block.number > answerBlockNumber && block.number < BLOCK_LIMIT + answerBlockNumber) {
            return BlockStatus.Checkable;
        }

        if(block.number > answerBlockNumber) {
            return BlockStatus.NotRevealed;
        }

        if(block.number > answerBlockNumber + BLOCK_LIMIT) {
            return BlockStatus.BlockLimitPassed;
        }
        return BlockStatus.BlockLimitPassed;
    }

    function getBetInfo(uint256 index) public view returns (uint256 answerBlockNumber, address bettor, byte challenges) {
        BetInfo memory b = _bets[index];
        answerBlockNumber = b.answerBlockNumber;
        bettor = b.bettor;
        challenges = b.challenges;
    }

    // queue에 push 하는 함수
    function pushBet(byte challenges) internal returns (bool) {
        BetInfo memory b;
        b.bettor = msg.sender; // 20 byte
        b.answerBlockNumber = block.number + BET_BLOCK_INTERVAL; // 32 byte = 20000 gas
        b.challenges = challenges; // byte  b.bettor의 20 byte와 합쳐서 = 20000 gas

        _bets[_tail] = b;
        _tail++; // 32byte 값 변화 = 20000 gas
        // tail값을 safeMath로 해줘도 되긴 하는데 여기서는 오버플로우 값을 검사 안해도 되기 때문에 할 필요는 없을 것 같다.
        
        return true;
    }

    // queue에서 pop 하는 함수
    function popBet(uint256 index) internal returns (bool) {
        // delete 하면 블록체인에 데이터를 더이상 저장하지 않겠다(state database에서 값들을 없애겠다)는 의미로서 일정량의 가스를 돌려받는다.
        delete _bets[index];
        return true;
    }
}