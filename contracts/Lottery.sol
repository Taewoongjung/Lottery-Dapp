pragma solidity >=0.4.21 <0.6.0;

contract Lottery {
    /* public으로 만들게 되면 자동으로 getter를 만들어준다. 그래서 스마트 컨트랙트 외부에서 owner값을 확인할 수 있게되는 것이다. */
    address public owner;

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
}