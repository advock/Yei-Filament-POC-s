// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IPool} from "src/interface/Ipool.sol";

import {IDeposit} from "src/interface/IDeposit.sol";

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract LendBorrowDeposit {
    IPool public yeiPool;
    IERC20 public lendToken;
    IERC20 public usdcToken;
    IDeposit public depositContract;

    // Mapping to track user positions
    mapping(address => UserPosition) public userPositions;

    struct UserPosition {
        uint256 lentAmount;
        uint256 borrowedAmount;
        uint256 depositedAmount;
    }

    constructor(
        address _yeiPool,
        address _lendToken,
        address _usdcToken,
        address _depositContract
    ) {
        yeiPool = IPool(_yeiPool);
        lendToken = IERC20(_lendToken);
        usdcToken = IERC20(_usdcToken);
        depositContract = IDeposit(_depositContract);
    }

    function lendBorrowAndDeposit(
        uint256 lendAmount,
        uint256 borrowAmount
    ) external {
        // Transfer lendToken from user to this contract
        lendToken.transferFrom(msg.sender, address(this), lendAmount);

        // Step 1: Lend tokens to Yei Finance
        lendToken.approve(address(yeiPool), lendAmount);
        yeiPool.supply(address(lendToken), lendAmount, msg.sender, 0);

        // Step 2: Borrow USDC from Yei Finance
        yeiPool.borrow(address(usdcToken), borrowAmount, 2, 0, msg.sender);

        // Step 3: Deposit USDC into the Deposit contract
        usdcToken.approve(address(depositContract), borrowAmount);
        depositContract.deposit(borrowAmount);

        // Update user position
        userPositions[msg.sender].lentAmount += lendAmount;
        userPositions[msg.sender].borrowedAmount += borrowAmount;
        userPositions[msg.sender].depositedAmount += borrowAmount;
    }

    function withdrawFromDeposit(uint256 amount) external {
        require(
            userPositions[msg.sender].depositedAmount >= amount,
            "Insufficient deposited amount"
        );

        depositContract.withdraw(amount);
        usdcToken.transfer(msg.sender, amount);

        userPositions[msg.sender].depositedAmount -= amount;
    }

    function repayAndWithdraw(
        uint256 repayAmount,
        uint256 withdrawAmount
    ) external {
        require(
            userPositions[msg.sender].borrowedAmount >= repayAmount,
            "Insufficient borrowed amount"
        );
        require(
            userPositions[msg.sender].lentAmount >= withdrawAmount,
            "Insufficient lent amount"
        );

        // Transfer USDC from user to this contract for repayment
        usdcToken.transferFrom(msg.sender, address(this), repayAmount);

        // Repay borrowed USDC
        usdcToken.approve(address(yeiPool), repayAmount);
        yeiPool.repay(address(usdcToken), repayAmount, 2, msg.sender);

        // Withdraw lent tokens
        yeiPool.withdraw(address(lendToken), withdrawAmount, msg.sender);

        userPositions[msg.sender].borrowedAmount -= repayAmount;
        userPositions[msg.sender].lentAmount -= withdrawAmount;
    }

    function estimateWithdrawAmount(
        address user,
        address asset,
        uint256 repayAmount
    ) external view returns (uint256) {
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = yeiPool.getUserAccountData(user);

        // Calculate new debt after repayment
        uint256 newDebtBase = totalDebtBase - repayAmount;

        // Calculate new available collateral
        uint256 newAvailableCollateral = (newDebtBase * 10000) / ltv;

        // Estimate withdraw amount
        uint256 estimatedWithdrawAmount = totalCollateralBase -
            newAvailableCollateral;

        return estimatedWithdrawAmount;
    }
}
