// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract MimboCarB is Pausable, Ownable {
    event Buy(address indexed from, uint256 carAmount, uint256 price, string recommendCode);

    // 바이백 지갑
    address payable public buyBackWallet_;

    // 차량 단가. wei
    uint256 public price_;

    // 추천인 코드. 코드 => 지갑
    mapping(string => address) public recommendCodes_;

    // 지갑 => 추천인 코드
    mapping(address => string) public walletCodes_;

    // 추천인 코드 별 기록
    struct CodeStat {
        address codeOwner;  // 대상 지갑
        uint256 buyCount;   // 판매 횟수
        uint256 carAmount;  // 판매 차량 수
        uint256 totalFee;   // 수수료로 지급한 총 코인 수
    }

    mapping(string => CodeStat) public codeStats_;

    // 추천인에게 지급할 수수료
    // 2.5% => 25
    uint256 public fee_;

    constructor(address _buyBackWallet, uint256 _price, uint256 _fee) {
        buyBackWallet_ = payable(_buyBackWallet);
        price_ = _price;
        fee_ = _fee;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // 바이백 지갑 변경
    function setBuyBackWallet(address _buyBackWallet) public onlyOwner {
        require(_buyBackWallet != address(0), "buyBackWallet is zero address");
        buyBackWallet_ = payable(_buyBackWallet);
    }

    // 차량 단가 설정
    function setCarPrice(uint256 _price) public onlyOwner {
        require(0 < _price, "setCarPrice: price must be greater than zero");
        price_ = _price;
    }

    // 추천인에게 지급할 수수료 설정
    function setFee(uint256 _fee) public onlyOwner {
        fee_ = _fee;
    }

    // 추천인 코드 설정
    function setRecommendCode(string[] memory _recommendCode, address[] memory _codeOwner) public onlyOwner {
        // 아래 require 주석이면 zero address를 넣는 경우에 추천인 코드 삭제하는 기능과 동일.
        // require(_codeOwner != address(0), "setRecommendCode: can not set codeOwner to the zero address");

        require(_recommendCode.length == _codeOwner.length, "setRecommendCode: codes and owners are not matched");
        for (uint256 i = 0; i < _recommendCode.length; ++i) {
            recommendCodes_[_recommendCode[i]] = _codeOwner[i];

            if(_codeOwner[i] != address(0)) {
                CodeStat storage codeStat = codeStats_[_recommendCode[i]];
                codeStat.codeOwner = _codeOwner[i];
            }
        }
    }

    // 차량 구매
    function buy(string memory _recommendCode) public payable whenNotPaused {
        string memory recommendCode = _recommendCode;

        // 수수료 받을 지갑
        address payable feeAddress = payable(recommendCodes_[recommendCode]);

        // 추천인 코드 체크
        uint256 bytelength = bytes(recommendCode).length;

        // 코드가 있으면
        if(0 < bytelength) {
            // 코드의 지갑이 있어야 함
            require(feeAddress != address(0), "buy: Invalid recommend code");

            // 이미 코드가 등록되어 있으면 안 됨
            require(0 >= bytes(walletCodes_[msg.sender]).length, "buy: already registered recommend code");

            // 구매하는 유저에게 코드 등록
            walletCodes_[msg.sender] = recommendCode;
        } else {
            // 코드가 없고, 2회 이상 구매 시에는 이미 등록한 코드의 지갑을 가져온다
            recommendCode = walletCodes_[msg.sender];
            feeAddress = payable(recommendCodes_[recommendCode]);
        }

        // 수량 결정
        uint256 carAmount = msg.value / price_;
        require(carAmount * price_ == msg.value, "buy: incorrect value");

        // 바이백 지갑으로 전송
        uint256 buyBackAmount = msg.value / 2;
        buyBackWallet_.transfer(buyBackAmount);

        // 수수료 처리 및 기록 보관
        if(feeAddress != address(0)) {
            // 수수료
            uint256 feeAmount = (msg.value * fee_) / 1000;
            if(0 < feeAmount) {
                feeAddress.transfer(feeAmount);
            }

            // 기록
            CodeStat storage codeStat = codeStats_[recommendCode];
            codeStat.buyCount++;
            codeStat.carAmount += carAmount;
            codeStat.totalFee += feeAmount;
        }

        emit Buy(msg.sender, carAmount, price_, recommendCode);
    }

    function withdrawEth(address to) public onlyOwner() {
        require(to != address(0), "[MimboCar][withdrawEth]: transfer to the zero address");
        address payable receiver = payable(to);
        receiver.transfer(address(this).balance);
    }
}
