// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract MimboCar is Pausable, Ownable {
    event Buy(address indexed from, uint256 carAmount, uint256 price, string recommendCode);

    address payable public buyBackWallet_;
    uint256 public price_;
    mapping(string => address) public recommendCodes_;
    mapping(address => string) public walletCodes_;

    struct CodeStat {
        address codeOwner;
        uint256 buyCount;
        uint256 carAmount;
        uint256 totalFee;
    }
    mapping(string => CodeStat) public codeStats_;

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

    function setBuyBackWallet(address _buyBackWallet) public onlyOwner {
        require(_buyBackWallet != address(0), "buyBackWallet is zero address");
        buyBackWallet_ = payable(_buyBackWallet);
    }

    function setCarPrice(uint256 _price) public onlyOwner {
        require(0 < _price, "setCarPrice: price must be greater than zero");
        price_ = _price;
    }

    function setFee(uint256 _fee) public onlyOwner {
        fee_ = _fee;
    }

    function setRecommendCode(string[] memory _recommendCode, address[] memory _codeOwner) public onlyOwner {
        require(_recommendCode.length == _codeOwner.length, "setRecommendCode: codes and owners are not matched");
        for (uint256 i = 0; i < _recommendCode.length; ++i) {
            recommendCodes_[_recommendCode[i]] = _codeOwner[i];

            if(_codeOwner[i] != address(0)) {
                CodeStat storage codeStat = codeStats_[_recommendCode[i]];
                codeStat.codeOwner = _codeOwner[i];
            }
        }
    }

    function buy(string memory _recommendCode) public payable whenNotPaused {
        string memory recommendCode = _recommendCode;
        address payable feeAddress = payable(recommendCodes_[recommendCode]);
        uint256 bytelength = bytes(recommendCode).length;

        if(0 < bytelength) {
            require(feeAddress != address(0), "buy: Invalid recommend code");
            require(0 >= bytes(walletCodes_[msg.sender]).length, "buy: already registered recommend code");
            walletCodes_[msg.sender] = recommendCode;
        } else {
            recommendCode = walletCodes_[msg.sender];
            feeAddress = payable(recommendCodes_[recommendCode]);
        }

        uint256 carAmount = msg.value / price_;
        require(carAmount * price_ == msg.value, "buy: incorrect value");

        uint256 buyBackAmount = msg.value / 2;
        buyBackWallet_.transfer(buyBackAmount);

        if(feeAddress != address(0)) {
            uint256 feeAmount = (msg.value * fee_) / 1000;
            if(0 < feeAmount) {
                feeAddress.transfer(feeAmount);
            }

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
