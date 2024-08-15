// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IDeposit {
    function deposit(uint256 _amount) external;
    function withdraw(uint256 _amount) external;
    function lockForAnOrder(address _account, uint256 _amount) external;
    function transferIn(address _trader, uint256 amount) external;
    function transferOut(address _trader, uint256 amount) external;
    function transferOutLiquidity(address _trader, uint256 amount) external;
    function balances(address _trader) external view returns (uint256);
}
