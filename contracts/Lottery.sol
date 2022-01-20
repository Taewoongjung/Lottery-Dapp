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
    address public owner;

    uint256 constant internal BLOCK_LIMIT = 256;
    uint256 constant internal BET_BLOCK_INTERVAL = 3; // 블록들 간의 간격
    uint256 constant internal BET_AMOUNT = 5 * 10 ** 15; // 0.005ETH
    uint256 private _pot;

    /* 
        스마트 컨트랙트가 생성이 될 때(배포가 될 때) 가장 처음 실행되는 함수인데, 
        배포가 될 때 보낸 사람(msg.sender)으로 owner를 저장하는 의미이다.
    */
    constructor() public { // 생성자
        owner = msg.sender;
    }

    // truffle 사용해서 스마트 컨트랙터랑 상호작용 하는 것을 보여준다.
    function getSomeValue() public pure returns (uint256 value) {
        return 5;
    }

    // pot에 대한 getter
    function getPot() public view returns (uint256 value) { // 스마트 컨트랙트에 있는 변수를 줘야하는 수식어는 "view"가 들어가야한다
        return _pot;
    }

    // Bet
        // save the bet to the queue

    // Distribute
        // check the answer
            // if the answer right 
                //insert

    function getBetInfo(uint256 index) public view returns (uint256 answerBlockNumber, address bettor, byte challenges) {
        BetInfo memory b = _bets[index];
        answerBlockNumber = b.answerBlockNumber;
        bettor = b.bettor;
        challenges = b.challenges;
    }

    // queue에 push 하는 함수
    function pushBet(byte challenges) public returns (bool) {
        BetInfo memory b;
        b.bettor = msg.sender;
        b.answerBlockNumber = block.number + BET_BLOCK_INTERVAL;
        b.challenges = challenges;

        _bets[_tail] = b;
        _tail++;
        // tail값을 safeMath로 해줘도 되긴 하는데 여기서는 오버플로우 값을 검사 안해도 되기 때문에 할 필요는 없을 것 같다.
    }

    // queue에서 pop 하는 함수
    function popBet(uint256 index) public returns (bool) {
        // delete 하면 블록체인에 데이터를 더이상 저장하지 않겠다(state database에서 값들을 없애겠다)는 의미로서 일정량의 가스를 돌려받는다.
        delete _bets[index];
        return true;
    }
}