// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract LendBorrowDeposit is Ownable {
    using SafeERC20 for IERC20;

    IPool public yeiPool;
    IERC20 public lendToken;
    IERC20 public usdcToken;
    IDeposit public depositContract;

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
    ) external onlyOwner {
        // Step 1: Lend tokens to Yei Finance
        lendToken.safeApprove(address(yeiPool), lendAmount);
        yeiPool.supply(address(lendToken), lendAmount, address(this), 0);

        // Step 2: Borrow USDC from Yei Finance
        yeiPool.borrow(address(usdcToken), borrowAmount, 2, 0, address(this));

        // Step 3: Deposit USDC into the Deposit contract
        usdcToken.safeApprove(address(depositContract), borrowAmount);
        depositContract.deposit(borrowAmount);
    }

    function withdrawFromDeposit(uint256 amount) external onlyOwner {
        depositContract.withdraw(amount);
    }

    function repayAndWithdraw(
        uint256 repayAmount,
        uint256 withdrawAmount
    ) external onlyOwner {
        // Repay borrowed USDC
        usdcToken.safeApprove(address(yeiPool), repayAmount);
        yeiPool.repay(address(usdcToken), repayAmount, 2, address(this));

        // Withdraw lent tokens
        yeiPool.withdraw(address(lendToken), withdrawAmount, address(this));
    }

    // Function to rescue tokens in case of emergency
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }
}
