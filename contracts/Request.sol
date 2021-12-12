// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./access/Ownable.sol";


contract Request is Ownable {

    uint256 private _insurance;

    address payable private _companyWallet;
    string private _goal;
    uint256 private _rate;
    uint256 private _minPayment;
    uint256 private _softCap;
    uint256 private _hardCap;
    uint256 private _hardEnd;

    uint256 private _nextCouponIx;
    uint256[] private _couponTimestamps;
    uint256 private _backTotal;
    uint256 private _total;

    uint256 private _adminTotal;

    struct Lot {
        uint256 price;
        uint256 pie;
        bool isActive;
    }

    //    struct Investor {
    //        uint256 investment;
    //        mapping(uint256 => uint256) coupons;
    //        bool withInsurance;
    //        Lot lot;
    //        uint256 withdrawal;
    //    }


    uint256[] public _investorIds;
    mapping(uint256 => uint256) public _investors;
    mapping(uint256 => mapping(uint256 => bool)) public _investorCoupons;
    mapping(uint256 => bool) public _investorInsurance;
    mapping(uint256 => Lot) public _lots;
    mapping(uint256 => uint256) public _withdrawals;


    constructor (string memory goal, uint256 rate, uint256 softCap, uint256 hardCap, uint256 hardEnd, uint256[] memory couponTimestamps,
        uint256 minPayment, address payable companyWallet)  {

        require(rate > 0, "Request: rate is 0");
        require(minPayment > 0, 'Minimum payment value should > 0');
        require(softCap > 0, 'Soft cap should > 0');
        require(hardCap > 0, 'Hard cap should > 0');

        require(companyWallet != address(0), "Request: companyWallet is the zero address");

        require(hardEnd > block.timestamp, 'duration should be > 0');
        require(softCap <= hardCap, "Soft cap must be lower or equal Hard cap");
        require(minPayment <= hardCap, "Minimum payment value must be lower or equal Hard cap");

        _goal = goal;
        _rate = rate;
        _hardCap = hardCap;
        _softCap = softCap;
        _hardEnd = hardEnd;
        _couponTimestamps = couponTimestamps;
        _minPayment = minPayment;

        _companyWallet = companyWallet;
    }


    event SetInsurance(uint256 amount);
    event Invest(uint256 from, uint256 amount, bool withInsurance);
    event Refund(uint256 to, uint256 amount);
    event RefundInsurance(uint256 amount);
    event DebtWithdrawal(uint256 amount);
    event TopUp(uint256 amount);
    event CouponWithdrawal(uint256 to, uint256 amount, uint256 insuranceFee);
    event SetLot(Lot lot);
    event RemoveLot(Lot lot);
    event CloseLot(uint256 buyer, Lot lot, bool withInsurance);
    event Payback(uint256 amount);
    event PaybackWithdrawal(uint256 to, uint256 amount);
    event InsuranceCase(uint256 to, uint256 amount);


    function invest(uint256 userId, uint256 amount, bool withInsurance) external onlyOwner {
        require(block.timestamp < _hardEnd && _total + amount <= _hardCap, "No invest more");
        require(amount >= _minPayment, "Less minimum payment value");

        _investors[userId] = _investors[userId] + amount;
        _investorInsurance[userId] = _investorInsurance[userId] || withInsurance;
        _total = _total + amount;
        _investorIds.push(userId);

        emit Invest(userId, amount, withInsurance);
    }


    function setInsurance(uint256 insurance) external {
        _insurance = insurance;

        emit SetInsurance(insurance);
    }


    function refundOf(uint256 userId) external {
        require(_total < _softCap && block.timestamp > _hardEnd, "No refund");

        if (_investors[userId] > 0) {
            uint256 amount = _investors[userId];
            _investors[userId] = 0;
            _total = _total - amount;


            emit Refund(userId, amount);
        }
    }


    function refundCompany() external {
        require(_total < _softCap && block.timestamp > _hardEnd, "No company refund");

        if (_insurance != 0) {
            // Smth
            _insurance = 0;

            emit RefundInsurance(_insurance);
        }
    }


    function withdrawDebt() external {
        require(_total >= _softCap && block.timestamp > _hardEnd, "No debt withdraw");

        // smth

        emit DebtWithdrawal(_total);
    }


    function topUp(uint256 amount) external {
        require(_nextCouponIx < _couponTimestamps.length, "Over");
        require(block.timestamp <= _couponTimestamps[_nextCouponIx], "Overdue...");
        if (block.timestamp > _couponTimestamps[_nextCouponIx]) {
            _endContractInsurance();
        }

        if (_nextCouponIx + 1 < _couponTimestamps.length) {
            uint256 needed = _total * _rate / 100;
            needed = needed / _couponTimestamps.length;

            require(amount + _backTotal <= needed, "Over money for next coupon");

            _backTotal = _backTotal + amount;

            if (_backTotal == needed) {
                _nextCouponIx = _nextCouponIx + 1;
            }

            emit TopUp(amount);
        } else {
            uint256 needed = _total * _rate / 100;
            needed = (needed + _total) / _couponTimestamps.length;

            require(amount + _backTotal <= needed, "Over money for next coupon");

            _backTotal = _backTotal + amount;

            if (_backTotal == needed) {
                _nextCouponIx = _nextCouponIx + 1;
                _endContract();
            }

            emit Payback(amount);
        }
    }


    function withdrawCoupon(uint256 userId) external {
        require(_nextCouponIx < _couponTimestamps.length, "Over");
        require(_nextCouponIx > 0, "Wait....");
        require(!_investorCoupons[userId][_nextCouponIx - 1], "You already have that coupon");

        uint256 needed = 0;
        uint256 insuranceFee = 0;
        bool withInsurance = _investorInsurance[userId];

        if (_nextCouponIx == _couponTimestamps.length) {
            needed = needed + _investors[userId];
        }

        for (uint i = _nextCouponIx - 1; i >= 0; i--) {
            if (!_investorCoupons[userId][i]) {
                uint256 coupon = _investors[userId] * _rate / 100 / _couponTimestamps.length;
                if (withInsurance) {
                    insuranceFee += coupon * _rate / 100 / _couponTimestamps.length;
                    needed = needed + coupon - coupon * _rate / 100 / _couponTimestamps.length;
                } else {
                    needed = needed + coupon;
                }
                _investorCoupons[userId][i] = true;
            }
        }

        if (_nextCouponIx == _couponTimestamps.length) {
            emit PaybackWithdrawal(userId, needed);
        } else {
            emit CouponWithdrawal(userId, needed, insuranceFee);
        }

        emit DebtWithdrawal(_total);
    }


    function setLot(uint256 sellerId, uint256 price, uint256 pie) external {
        require(pie <= _investors[sellerId], "More than user total pie");

        _lots[sellerId] = Lot(price, pie, true);

        emit SetLot(_lots[sellerId]);
    }


    function removeLot(uint256 sellerId) external {
        require(_lots[sellerId].isActive, "Non-active lot");

        _lots[sellerId].isActive = false;

        emit RemoveLot(_lots[sellerId]);
    }


    function buyLot(uint256 sellerId, uint256 buyerId, bool withInsurance) external {
        require(_lots[sellerId].isActive, "Non-active lot");

        Lot memory lot = _lots[sellerId];

        _lots[sellerId].isActive = false;
        _investors[buyerId] = _investors[buyerId] + lot.pie;
        _withdrawals[sellerId] += lot.price;
        _investorInsurance[buyerId] = withInsurance;

        if (_investors[sellerId] == 0) {
            _investorInsurance[sellerId] = false;
        }

        emit CloseLot(buyerId, lot, withInsurance);
    }


    function _endContract() internal {

        // Go back _insurance to startup
        _insurance = 0;
    }


    function _endContractInsurance() internal {
        uint256 insurance_num = 0;

        for (uint256 i = 0; i < _investorIds.length; i++) {
            if (_investorInsurance[i]) {
                uint256 pie = _investors[i] * _insurance / _total;
                _backTotal += _investors[i] * _insurance / _total;
                _insurance -= pie;
                emit InsuranceCase(i, pie);
            }
        }

        if (_insurance > 0) {
            _adminTotal += _insurance;
        }
    }


//    function goal() external view returns (string) {
//        return _goal;
//    }
}
