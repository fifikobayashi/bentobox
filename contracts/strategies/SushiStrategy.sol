// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import "../interfaces/IStrategy.sol";
import "@bartjman/boring-solidity/contracts/BoringOwnable.sol";
import "@bartjman/boring-solidity/contracts/libraries/BoringMath.sol";
import "@bartjman/boring-solidity/contracts/libraries/BoringERC20.sol";
// solhint-disable not-rely-on-time

interface ISushiBar is IERC20 {
    function enter(uint256 _amount) external;
    function leave(uint256 _share) external;
}

contract SushiStrategy is IStrategy, BoringOwnable {
    using BoringMath for uint256;
    using BoringERC20 for IERC20;

    IERC20 private immutable sushi;
    ISushiBar private immutable bar;

    constructor(ISushiBar bar_, IERC20 sushi_) public {
        bar = bar_;
        sushi = sushi_;
    }

    uint256 public override balance;

    // Send the assets to the Strategy and call skim to invest them
    function skim() external override returns (uint256 amount) {
        amount = sushi.balanceOf(address(this));
        balance = balance.add(amount);
        sushi.approve(address(bar), amount);
        bar.enter(amount);
    }

    // Harvest any profits made converted to the asset and pass them to the caller
    function harvest() external override onlyOwner returns (int256 amountAdded) {
        uint256 share = bar.balanceOf(address(this));
        uint256 totalShares = bar.totalSupply();
        uint256 totalSushi = sushi.balanceOf(address(bar));
        uint256 keepShare = balance.mul(totalShares) / totalSushi;
        uint256 harvestShare = share.sub(keepShare);
        bar.leave(harvestShare);
        amountAdded = int256(sushi.balanceOf(address(this)));
        sushi.safeTransfer(owner, uint256(amountAdded)); // Add as profit
    }

    // Withdraw assets. The returned amount can differ from the requested amount due to rounding or if the request was more than there is.
    function withdraw(uint256 amount) external override onlyOwner returns (int256 amountAdded) {
        uint256 totalShares = bar.totalSupply();
        uint256 totalSushi = sushi.balanceOf(address(bar));
        uint256 withdrawShare = amount.mul(totalShares) / totalSushi;
        uint256 share = bar.balanceOf(address(this));
        if (withdrawShare > share) {
            withdrawShare = share;
        }
        bar.leave(withdrawShare);
        uint256 actualAmount = sushi.balanceOf(address(this));
        balance = balance.sub(actualAmount);
        sushi.safeTransfer(owner, actualAmount);
        amountAdded = 0;
    }

    // Withdraw all assets in the safest way possible. This shouldn't fail.
    function exit() external override onlyOwner returns (int256 amountAdded) {
        uint256 share = bar.balanceOf(address(this));
        bar.leave(share);
        uint256 amount = sushi.balanceOf(address(this));
        amountAdded = int256(amount.sub(balance));
        balance = 0;
        sushi.safeTransfer(owner, amount);
    }
}