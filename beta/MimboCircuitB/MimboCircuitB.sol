// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract MimboCircuitB is Pausable, Ownable {
    ERC20 public TokenContract_;
    address public TokenRallyHolder_;
    address public TokenMergeHolder_;

    event Deposit(address indexed from, uint256 rallyNumber);
    event Withdraw(address indexed from, uint256 rallyNumber);
    event Merge(address indexed from, uint256 carId, uint256 mergeCount);
    event Claim(address indexed from, uint256 earnIdx);

    // 랠리 넘버 관리. 지갑 => 랠리넘버
    mapping(address => uint256) public rallyNumbers;

    // 랠리 넘버 별 돌려줘야 할 토큰 수량. 지갑 => 랠리넘버 => 토큰 수량
    mapping(address => mapping(uint256 => uint256)) public rallyTokens;

    // 랠리 넘버 별 오픈에 사용하는 토큰 수량. 랠리넘버 => 토큰 수량
    mapping(uint256 => uint256) public rallyDepositPrices;

    // 차량 ID별 1회 합성 비용. 차량 ID => 합성 비용 토큰 수량
    mapping(uint256 => uint256) public mergePrices;

    // 클레임 인덱스 관리. 클레임 인덱스(DB) => true이면 클레임 행위 성공
    mapping(uint256 => bool) public earns;

    constructor(address _TokenContract, address _TokenRallyHolder, address _TokenMergeHolder) {
        TokenContract_ = ERC20(_TokenContract);
        TokenRallyHolder_ = _TokenRallyHolder;
        TokenMergeHolder_ = _TokenMergeHolder;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // 랠리 오픈 토큰 수량 설정
    function setRallyDepositPrices(uint256[] memory _rallyNumber, uint256[] memory _prices) public onlyOwner {
        require(_rallyNumber.length == _prices.length, "setRallyDepositPrices: numbers and prices are not matched");
        for (uint256 i = 0; i < _rallyNumber.length; ++i) {
            require(_prices[i] > 0, "setRallyDepositPrices: Invalid price");
            rallyDepositPrices[_rallyNumber[i]] = _prices[i];
        }
    }

    // 차량 합성 토큰 수량 설정
    function setMergePrices(uint256[] memory _carIds, uint256[] memory _prices) public onlyOwner {
        require(_carIds.length == _prices.length, "setMergePrices: carIds and prices are not matched");
        for (uint256 i = 0; i < _carIds.length; ++i) {
            require(_prices[i] > 0, "setMergePrices: Invalid price");
            mergePrices[_carIds[i]] = _prices[i];
        }
    }

    function deposit(uint256 rallyNumber) public whenNotPaused {
        require(rallyNumbers[msg.sender] + 1 == rallyNumber, "deposit: Invalid order");
        require(rallyDepositPrices[rallyNumber] > 0, "deposit: Invlaid rallyNumber");
        require(TokenContract_.balanceOf(msg.sender) >= rallyDepositPrices[rallyNumber], "deposit: Not enough token amount");
        require(TokenContract_.allowance(msg.sender, address(this)) >= rallyDepositPrices[rallyNumber], "deposit: Not enough allowanced token amount");

        require(TokenContract_.transferFrom(msg.sender, TokenRallyHolder_, rallyDepositPrices[rallyNumber]), "deposit: erc20 transfer failed");

        ++rallyNumbers[msg.sender];
        rallyTokens[msg.sender][rallyNumber] = rallyDepositPrices[rallyNumber];

        emit Deposit(msg.sender, rallyNumber);
    }

    function withdraw(uint256 rallyNumber) public whenNotPaused {
        require(0 < rallyNumber, "withdraw: Invalid rallyNumber");
        require(rallyNumbers[msg.sender] == rallyNumber, "withdraw: Invalid rallyNumber");

        require(TokenContract_.transferFrom(TokenRallyHolder_, msg.sender, rallyTokens[msg.sender][rallyNumber]), "withdraw: erc20 transfer failed");

        --rallyNumbers[msg.sender];
        rallyTokens[msg.sender][rallyNumber] = 0;

        emit Withdraw(msg.sender, rallyNumber);
    }

    function merge(uint256 carId, uint256 mergeCount) public whenNotPaused {
        require(mergePrices[carId] > 0, "merge: Invlaid carId");

        uint256 tokenAmount = mergeCount * mergePrices[carId];

        require(TokenContract_.balanceOf(msg.sender) >= tokenAmount, "merge: Not enough token amount");
        require(TokenContract_.allowance(msg.sender, address(this)) >= tokenAmount, "merge: Not enough allowanced token amount");

        require(TokenContract_.transferFrom(msg.sender, TokenMergeHolder_, tokenAmount), "merge: erc20 transfer failed");

        emit Merge(msg.sender, carId, mergeCount);
    }

    function claim(uint256 earnIdx) public whenNotPaused {
        require(earns[earnIdx] == false, "claim: Already Claimed");

        earns[earnIdx] = true;

        emit Claim(msg.sender, earnIdx);
    }

    // getter
    // 서킷 & 슬롯 클로즈 시 받을 토큰 수량 조회
    function getWithdrawTokens(uint256 rallyNumber) public view returns (uint256 tokenAmount) {
        return rallyTokens[msg.sender][rallyNumber];
    }
}
