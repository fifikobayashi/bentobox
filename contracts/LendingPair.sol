// SPDX-License-Identifier: UNLICENSED

// Medium Risk LendingPair

// ▄▄▌  ▄▄▄ . ▐ ▄ ·▄▄▄▄  ▪   ▐ ▄  ▄▄ •  ▄▄▄· ▄▄▄· ▪  ▄▄▄
// ██•  ▀▄.▀·•█▌▐███▪ ██ ██ •█▌▐█▐█ ▀ ▪▐█ ▄█▐█ ▀█ ██ ▀▄ █·
// ██▪  ▐▀▀▪▄▐█▐▐▌▐█· ▐█▌▐█·▐█▐▐▌▄█ ▀█▄ ██▀·▄█▀▀█ ▐█·▐▀▀▄
// ▐█▌▐▌▐█▄▄▌██▐█▌██. ██ ▐█▌██▐█▌▐█▄▪▐█▐█▪·•▐█ ▪▐▌▐█▌▐█•█▌
// .▀▀▀  ▀▀▀ ▀▀ █▪▀▀▀▀▀• ▀▀▀▀▀ █▪·▀▀▀▀ .▀    ▀  ▀ ▀▀▀.▀  ▀

// Copyright (c) 2021 BoringCrypto - All rights reserved
// Twitter: @Boring_Crypto

// Special thanks to:
// @burger_crypto - for the idea of trying to let the LPs benefit from liquidations

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@boringcrypto/boring-solidity/contracts/ERC20.sol";
import "@boringcrypto/boring-solidity/contracts/interfaces/IMasterContract.sol";
import "./interfaces/IOracle.sol";
import "./BentoBox.sol";
import "./interfaces/ISwapper.sol";
import "./interfaces/IWETH.sol";

// solhint-disable avoid-low-level-calls
// solhint-disable no-inline-assembly

/// @title LendingPair
/// @dev This contract allows contract calls to any contract (except BentoBox)
/// from arbitrary callers thus, don't trust calls from this contract in any circumstances.
contract LendingPair is ERC20, BoringOwnable, IMasterContract {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using RebaseLibrary for Rebase;
    using BoringERC20 for IERC20;

    event LogExchangeRate(uint256 rate);
    event LogAccrue(uint256 accruedAmount, uint256 feeFraction, uint256 rate, uint256 utilization);
    event LogAddCollateral(address indexed from, address indexed to, uint256 share);
    event LogAddAsset(address indexed from, address indexed to, uint256 share, uint256 fraction);
    event LogRemoveCollateral(address indexed from, address indexed to, uint256 share);
    event LogRemoveAsset(address indexed from, address indexed to, uint256 share, uint256 fraction);
    event LogBorrow(address indexed from, address indexed to, uint256 amount, uint256 part);
    event LogRepay(address indexed from, address indexed to, uint256 amount, uint256 part);
    event LogFeeTo(address indexed newFeeTo);
    event LogWithdrawFees(address indexed feeTo, uint256 feesEarnedFraction);

    // Immutables (for MasterContract and all clones)
    BentoBox public immutable bentoBox;
    address public immutable masterContract;

    // MasterContract variables
    address public feeTo;
    mapping(ISwapper => bool) public swappers;

    // Per clone variables
    // Clone init settings
    IERC20 public collateral;
    IERC20 public asset;
    IOracle public oracle;
    bytes public oracleData;

    // Total amounts
    uint256 public totalCollateralShare; // Total collateral supplied
    Rebase public totalAsset; // elastic = BentoBox shares held by the lendingPair, base = Total fractions held by asset suppliers
    Rebase public totalBorrow; // elastic = Total token amount to be repayed by borrowers, base = Total parts of the debt held by borrowers

    // User balances
    mapping(address => uint256) public userCollateralShare;
    // userAssetFraction is called balanceOf for ERC20 compatibility (it's in ERC20.sol)
    mapping(address => uint256) public userBorrowPart;

    /// @notice Exchange and interest rate tracking.
    /// This is 'cached' here because calls to Oracles can be very expensive.
    uint256 public exchangeRate;

    struct AccrueInfo {
        uint64 interestPerBlock;
        uint64 lastBlockAccrued;
        uint128 feesEarnedFraction;
    }

    AccrueInfo public accrueInfo;

    // ERC20 'variables'
    function symbol() external view returns (string memory) {
        return string(abi.encodePacked("bm", collateral.safeSymbol(), ">", asset.safeSymbol(), "-", oracle.symbol(oracleData)));
    }

    function name() external view returns (string memory) {
        return string(abi.encodePacked("Bento Med Risk ", collateral.safeName(), ">", asset.safeName(), "-", oracle.symbol(oracleData)));
    }

    function decimals() external view returns (uint8) {
        return asset.safeDecimals();
    }

    // totalSupply for ERC20 compatibility
    function totalSupply() public view returns (uint256) {
        return totalAsset.base;
    }

    // Settings for the Medium Risk LendingPair
    uint256 private constant CLOSED_COLLATERIZATION_RATE = 75000; // 75%
    uint256 private constant OPEN_COLLATERIZATION_RATE = 77000; // 77%
    uint256 private constant COLLATERIZATION_RATE_PRECISION = 1e5;
    uint256 private constant MINIMUM_TARGET_UTILIZATION = 7e17; // 70%
    uint256 private constant MAXIMUM_TARGET_UTILIZATION = 8e17; // 80%
    uint256 private constant UTILIZATION_PRECISION = 1e18;
    uint256 private constant FULL_UTILIZATION = 1e18;
    uint256 private constant FULL_UTILIZATION_MINUS_MAX = FULL_UTILIZATION - MAXIMUM_TARGET_UTILIZATION;
    uint256 private constant FACTOR_PRECISION = 1e18;

    uint256 private constant STARTING_INTEREST_PER_BLOCK = 4566210045; // approx 1% APR
    uint256 private constant MINIMUM_INTEREST_PER_BLOCK = 1141552511; // approx 0.25% APR
    uint256 private constant MAXIMUM_INTEREST_PER_BLOCK = 4566210045000; // approx 1000% APR
    uint256 private constant INTEREST_ELASTICITY = 2000e36; // Half or double in 2000 blocks (approx 8 hours)

    uint256 private constant EXCHANGE_RATE_PRECISION = 1e18;

    uint256 private constant LIQUIDATION_MULTIPLIER = 112000; // add 12%
    uint256 private constant LIQUIDATION_MULTIPLIER_PRECISION = 1e5;

    // Fees
    uint256 private constant PROTOCOL_FEE = 10000; // 10%
    uint256 private constant PROTOCOL_FEE_DIVISOR = 1e5;
    uint256 private constant BORROW_OPENING_FEE = 50; // 0.05%
    uint256 private constant BORROW_OPENING_FEE_PRECISION = 1e5;

    /// @notice The constructor is only used for the initial master contract. Subsequent clones are initialised via `init`.
    constructor(BentoBox bentoBox_) public {
        bentoBox = bentoBox_;
        masterContract = address(this);

        feeTo = msg.sender;
        emit LogFeeTo(msg.sender);

        // Not really an issue, but https://blog.trailofbits.com/2020/12/16/breaking-aave-upgradeability/
        collateral = IERC20(address(1)); // Just a dummy value for the Master Contract
    }

    /// @notice Serves as the constructor for clones, as clones can't have a regular constructor
    /// @dev `data` is abi encoded in the format: (IERC20 collateral, IERC20 asset, IOracle oracle, bytes oracleData)
    function init(bytes calldata data) public payable override {
        require(address(collateral) == address(0), "LendingPair: already initialized");
        (collateral, asset, oracle, oracleData) = abi.decode(data, (IERC20, IERC20, IOracle, bytes));

        accrueInfo.interestPerBlock = uint64(STARTING_INTEREST_PER_BLOCK); // 1% APR, with 1e18 being 100%
        // can fail
        updateExchangeRate();
    }

    /// @notice Helper function to get the abi encoded bytes for the `init` function.
    function getInitData(
        IERC20 collateral_,
        IERC20 asset_,
        IOracle oracle_,
        bytes calldata oracleData_
    ) public pure returns (bytes memory data) {
        return abi.encode(collateral_, asset_, oracle_, oracleData_);
    }

    /// @notice Accrues the interest on the borrowed tokens and handles the accumulation of fees.
    function accrue() public {
        AccrueInfo memory _accrueInfo = accrueInfo;
        // Number of blocks since accrue was called
        uint256 blocks = block.number - _accrueInfo.lastBlockAccrued;
        if (blocks == 0) {
            return;
        }
        _accrueInfo.lastBlockAccrued = uint64(block.number);

        Rebase memory _totalAsset = totalAsset;
        if (_totalAsset.base == 0) {
            if (_accrueInfo.interestPerBlock != STARTING_INTEREST_PER_BLOCK) {
                _accrueInfo.interestPerBlock = uint64(STARTING_INTEREST_PER_BLOCK);
                emit LogAccrue(0, 0, STARTING_INTEREST_PER_BLOCK, 0);
            }
            accrueInfo = _accrueInfo;
            return;
        }

        uint256 extraAmount = 0;
        uint256 feeFraction = 0;
        uint256 totalAssetAmount = bentoBox.toAmount(asset, _totalAsset.elastic, false);
        Rebase memory _totalBorrow = totalBorrow;
        if (_totalBorrow.elastic > 0) {
            // Accrue interest
            extraAmount = uint256(_totalBorrow.elastic).mul(_accrueInfo.interestPerBlock).mul(blocks) / 1e18;
            uint256 feeAmount = extraAmount.mul(PROTOCOL_FEE) / PROTOCOL_FEE_DIVISOR; // % of interest paid goes to fee
            _totalBorrow.elastic = _totalBorrow.elastic.add(extraAmount.to128());
            feeFraction = feeAmount.mul(_totalAsset.base) / totalAssetAmount.add(_totalBorrow.elastic).sub(feeAmount);
            _accrueInfo.feesEarnedFraction = _accrueInfo.feesEarnedFraction.add(feeFraction.to128());
            _totalAsset.base = _totalAsset.base.add(feeFraction.to128());
            totalBorrow = _totalBorrow;
        }

        // Update interest rate
        uint256 utilization = uint256(_totalBorrow.elastic).mul(UTILIZATION_PRECISION) / totalAssetAmount.add(_totalBorrow.elastic);
        uint256 newInterestPerBlock;
        if (utilization < MINIMUM_TARGET_UTILIZATION) {
            uint256 underFactor = MINIMUM_TARGET_UTILIZATION.sub(utilization).mul(FACTOR_PRECISION) / MINIMUM_TARGET_UTILIZATION;
            uint256 scale = INTEREST_ELASTICITY.add(underFactor.mul(underFactor).mul(blocks));
            newInterestPerBlock = uint256(_accrueInfo.interestPerBlock).mul(INTEREST_ELASTICITY) / scale;

            if (newInterestPerBlock < MINIMUM_INTEREST_PER_BLOCK) {
                newInterestPerBlock = MINIMUM_INTEREST_PER_BLOCK; // 0.25% APR minimum
            }
        } else if (utilization > MAXIMUM_TARGET_UTILIZATION) {
            uint256 overFactor = utilization.sub(MAXIMUM_TARGET_UTILIZATION).mul(FACTOR_PRECISION) / FULL_UTILIZATION_MINUS_MAX;
            uint256 scale = INTEREST_ELASTICITY.add(overFactor.mul(overFactor).mul(blocks));
            newInterestPerBlock = uint256(_accrueInfo.interestPerBlock).mul(scale) / INTEREST_ELASTICITY;

            if (newInterestPerBlock > MAXIMUM_INTEREST_PER_BLOCK) {
                newInterestPerBlock = MAXIMUM_INTEREST_PER_BLOCK; // 1000% APR maximum
            }
        } else {
            emit LogAccrue(extraAmount, feeFraction, _accrueInfo.interestPerBlock, utilization);
            accrueInfo = _accrueInfo;
            return;
        }

        _accrueInfo.interestPerBlock = uint64(newInterestPerBlock);
        emit LogAccrue(extraAmount, feeFraction, newInterestPerBlock, utilization);
        accrueInfo = _accrueInfo;
    }

    /// @notice Concrete implementation of `isSolvent`. Includes a third parameter to allow caching `exchangeRate`.
    /// @param _exchangeRate The exchange rate. Used to cache the `exchangeRate` between calls.
    function _isSolvent(
        address user,
        bool open,
        uint256 _exchangeRate
    ) internal view returns (bool) {
        // accrue must have already been called!
        if (userBorrowPart[user] == 0) return true;
        if (totalCollateralShare == 0) return false;

        Rebase memory _totalBorrow = totalBorrow;

        return
            bentoBox.toAmount(
                collateral,
                userCollateralShare[user].mul(EXCHANGE_RATE_PRECISION / COLLATERIZATION_RATE_PRECISION).mul(
                    open ? OPEN_COLLATERIZATION_RATE : CLOSED_COLLATERIZATION_RATE
                ),
                false
            ) >=
            // Moved exchangeRate here instead of dividing the other side to preserve more precision
            userBorrowPart[user].mul(_totalBorrow.elastic).mul(_exchangeRate) / _totalBorrow.base;
    }

    /// @notice Checks if the user is solvent.
    /// Has an option `open` to check if the user is solvent in an open/closed liquidation case.
    /// @param user The address of the user in question.
    /// @param open If True then the check is perfomed with `OPEN_COLLATERIZATION_RATE` else with `CLOSED_COLLATERIZATION_RATE`.
    /// @return (bool) User is solvent if True.
    function isSolvent(address user, bool open) public view returns (bool) {
        return _isSolvent(user, open, exchangeRate);
    }

    /// @dev Checks if the user is solvent in the closed liquidation case at the end of the function body.
    modifier solvent() {
        _;
        require(_isSolvent(msg.sender, false, exchangeRate), "LendingPair: user insolvent");
    }

    /// @notice Helper function for convenience. Peek should not modify state.
    function peekExchangeRate() public view returns (bool, uint256) {
        return oracle.peek(oracleData);
    }

    /// @notice Gets the exchange rate. I.e how much collateral to buy 1e18 asset.
    /// This function is supposed to be invoked if needed because Oracle queries can be expensive.
    /// @return updated True if `exchangeRate` was updated.
    /// @return rate The new exchange rate.
    function updateExchangeRate() public returns (bool updated, uint256 rate) {
        (updated, rate) = oracle.get(oracleData);

        if (updated) {
            exchangeRate = rate;
            emit LogExchangeRate(rate);
        } else {
            // Return the old rate if fetching wasn't successful
            rate = exchangeRate;
        }
    }

    /// @dev Helper function to move tokens.
    /// @param token The ERC-20 token.
    /// @param share The amount in shares to add.
    /// @param total Grand total amount to deduct from this contract's balance. Only applicable if `skim` is True.
    /// Only used for accounting checks.
    /// @param skim If True, only does a balance check on this contract.
    /// False if tokens from msg.sender in `bentoBox` should be transferred.
    function _addTokens(
        IERC20 token,
        uint256 share,
        uint256 total,
        bool skim
    ) internal {
        if (skim) {
            require(share <= bentoBox.balanceOf(token, address(this)).sub(total), "LendingPair: Skim too much");
        } else {
            bentoBox.transfer(token, msg.sender, address(this), share);
        }
    }

    /// @notice Adds `collateral` from msg.sender to the account `to`.
    /// @param to The receiver of the tokens.
    /// @param skim True if the amount should be skimmed from the deposit balance of msg.sender.
    /// False if tokens from msg.sender in `bentoBox` should be transferred.
    /// @param share The amount of shares to add for `to`.
    function addCollateral(
        address to,
        bool skim,
        uint256 share
    ) public {
        userCollateralShare[to] = userCollateralShare[to].add(share);
        totalCollateralShare = totalCollateralShare.add(share);
        _addTokens(collateral, share, totalCollateralShare, skim);
        emit LogAddCollateral(skim ? address(bentoBox) : msg.sender, to, share);
    }

    /// @dev Concrete implementation of `removeCollateral`.
    function _removeCollateral(address to, uint256 share) internal {
        userCollateralShare[msg.sender] = userCollateralShare[msg.sender].sub(share);
        totalCollateralShare = totalCollateralShare.sub(share);
        emit LogRemoveCollateral(msg.sender, to, share);
        bentoBox.transfer(collateral, address(this), to, share);
    }

    /// @notice Removes `share` amount of collateral and transfers it to `to`.
    /// @param to The receiver of the shares.
    /// @param share Amount of shares to remove.
    function removeCollateral(address to, uint256 share) public solvent {
        // accrue must be called because we check solvency
        accrue();
        _removeCollateral(to, share);
    }

    /// @dev Concrete implementation of `addAsset`.
    function _addAsset(
        address to,
        bool skim,
        uint256 share
    ) internal returns (uint256 fraction) {
        Rebase memory _totalAsset = totalAsset;
        uint256 totalAssetShare = _totalAsset.elastic;
        uint256 allShare = _totalAsset.elastic + bentoBox.toShare(asset, totalBorrow.elastic, true);
        fraction = allShare == 0 ? share : share.mul(_totalAsset.base) / allShare;
        totalAsset = _totalAsset.add(share, fraction);
        balanceOf[to] = balanceOf[to].add(fraction);
        _addTokens(asset, share, totalAssetShare, skim);
        emit LogAddAsset(skim ? address(bentoBox) : msg.sender, to, share, fraction);
    }

    /// @notice Adds assets to the lending pair.
    /// @param to The address of the user to receive the assets.
    /// @param skim True if the amount should be skimmed from the deposit balance of msg.sender.
    /// False if tokens from msg.sender in `bentoBox` should be transferred.
    /// @param share The amount of shares to add.
    /// @return fraction Total fractions added.
    function addAsset(
        address to,
        bool skim,
        uint256 share
    ) public returns (uint256 fraction) {
        accrue();
        fraction = _addAsset(to, skim, share);
    }

    /// @dev Concrete implementation of `removeAsset`.
    function _removeAsset(address to, uint256 fraction) internal returns (uint256 share) {
        Rebase memory _totalAsset = totalAsset;
        uint256 allShare = _totalAsset.elastic + bentoBox.toShare(asset, totalBorrow.elastic, true);
        share = fraction.mul(allShare) / _totalAsset.base;
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(fraction);
        _totalAsset.elastic = _totalAsset.elastic.sub(share.to128());
        _totalAsset.base = _totalAsset.base.sub(fraction.to128());
        totalAsset = _totalAsset;
        emit LogRemoveAsset(msg.sender, to, share, fraction);
        bentoBox.transfer(asset, address(this), to, share);
    }

    /// @notice Removes an asset from msg.sender and transfers it to `to`.
    /// @param to The user that receives the removed assets.
    /// @param fraction The amount/fraction of assets held to remove.
    /// @return share The amount of shares transferred to `to`.
    function removeAsset(address to, uint256 fraction) public returns (uint256 share) {
        accrue();
        share = _removeAsset(to, fraction);
    }

    /// @dev Concrete implementation of `borrow`.
    function _borrow(address to, uint256 amount) internal returns (uint256 part, uint256 share) {
        uint256 feeAmount = amount.mul(BORROW_OPENING_FEE) / BORROW_OPENING_FEE_PRECISION; // A flat % fee is charged for any borrow

        (totalBorrow, part) = totalBorrow.add(amount.add(feeAmount), true);
        userBorrowPart[msg.sender] = userBorrowPart[msg.sender].add(part);
        emit LogBorrow(msg.sender, to, amount.add(feeAmount), part);

        share = bentoBox.toShare(asset, amount, true);
        totalAsset.elastic = totalAsset.elastic.sub(share.to128());
        bentoBox.transfer(asset, address(this), to, share);
    }

    /// @notice Sender borrows `amount` and transfers it to `to`.
    /// @return part Total part of the debt held by borrowers.
    /// @return share Total amount in shares borrowed.
    function borrow(address to, uint256 amount) public solvent returns (uint256 part, uint256 share) {
        accrue();
        (part, share) = _borrow(to, amount);
    }

    /// @dev Concrete implementation of `repay`.
    function _repay(
        address to,
        bool skim,
        uint256 part
    ) internal returns (uint256 amount) {
        (totalBorrow, amount) = totalBorrow.sub(part, true);
        userBorrowPart[to] = userBorrowPart[to].sub(part);

        uint256 share = bentoBox.toShare(asset, amount, true);
        uint128 totalShare = totalAsset.elastic;
        _addTokens(asset, share, uint256(totalShare), skim);
        totalAsset.elastic = totalShare.add(share.to128());
        emit LogRepay(skim ? address(bentoBox) : msg.sender, to, amount, part);
    }

    /// @notice Repays a loan.
    /// @param to Address of the user this payment should go.
    /// @param skim True if the amount should be skimmed from the deposit balance of msg.sender.
    /// False if tokens from msg.sender in `bentoBox` should be transferred.
    /// @param part The amount to repay. See `userBorrowPart`.
    /// @return amount The total amount repayed.
    function repay(
        address to,
        bool skim,
        uint256 part
    ) public returns (uint256 amount) {
        accrue();
        amount = _repay(to, skim, part);
    }

    uint8 internal constant ACTION_ADD_COLLATERAL = 1;
    uint8 internal constant ACTION_ADD_ASSET = 2;
    uint8 internal constant ACTION_REPAY = 3;
    uint8 internal constant ACTION_REMOVE_ASSET = 4;
    uint8 internal constant ACTION_REMOVE_COLLATERAL = 5;
    uint8 internal constant ACTION_BORROW = 6;
    uint8 internal constant ACTION_CALL = 10;
    uint8 internal constant ACTION_BENTO_DEPOSIT = 20;
    uint8 internal constant ACTION_BENTO_WITHDRAW = 21;
    uint8 internal constant ACTION_BENTO_TRANSFER = 22;
    uint8 internal constant ACTION_BENTO_TRANSFER_MULTIPLE = 23;
    uint8 internal constant ACTION_BENTO_SETAPPROVAL = 24;
    uint8 internal constant ACTION_GET_REPAY_SHARE = 40;
    uint8 internal constant ACTION_GET_REPAY_PART = 41;

    int256 internal constant USE_VALUE1 = -1;
    int256 internal constant USE_VALUE2 = -2;

    /// @dev Helper function for choosing the correct value (`value1` or `value2`) depending on `inNum`.
    function _num(
        int256 inNum,
        uint256 value1,
        uint256 value2
    ) internal pure returns (uint256 outNum) {
        if (inNum >= 0) {
            outNum = uint256(inNum);
        } else if (inNum == USE_VALUE1) {
            outNum = value1;
        } else if (inNum == USE_VALUE2) {
            outNum = value2;
        } else {
            revert("LendingPair: Num out of bounds");
        }
    }

    /// @dev Helper function to extract a useful revert message from a failed call.
    /// If the returned data is malformed or not correctly abi encoded then this can fail by itself.
    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    /// @dev Helper function for depositing into `bentoBox`.
    function _bentoDeposit(
        bytes memory data,
        uint256 value,
        uint256 value1,
        uint256 value2
    ) internal returns (uint256, uint256) {
        (IERC20 token, address to, int256 amount, int256 share) = abi.decode(data, (IERC20, address, int256, int256));
        amount = int256(_num(amount, value1, value2)); // Done this way to avoid stack to deep errors
        share = int256(_num(share, value1, value2));
        return bentoBox.deposit{value: value}(token, msg.sender, to, uint256(amount), uint256(share));
    }

    /// @dev Helper function to withdraw from the `bentoBox`.
    function _bentoWithdraw(
        bytes memory data,
        uint256 value1,
        uint256 value2
    ) internal returns (uint256, uint256) {
        (IERC20 token, address to, int256 amount, int256 share) = abi.decode(data, (IERC20, address, int256, int256));
        return bentoBox.withdraw(token, msg.sender, to, _num(amount, value1, value2), _num(share, value1, value2));
    }

    /// @dev Helper function for conditional abi encoding based on inputs.
    function _callData(
        bytes memory callData,
        bool useValue1,
        bool useValue2,
        uint256 value1,
        uint256 value2
    ) internal pure returns (bytes memory callDataOut) {
        if (useValue1 && !useValue2) {
            callDataOut = abi.encodePacked(callData, value1);
        } else if (!useValue1 && useValue2) {
            callDataOut = abi.encodePacked(callData, value2);
        } else if (useValue1 && useValue2) {
            callDataOut = abi.encodePacked(callData, value1, value2);
        } else {
            callDataOut = callData;
        }
    }

    /// @dev Helper function to perform a contract call and eventually extracting revert messages on failure.
    /// Calls to `bentoBox` are not allowed for obvious security reasons.
    /// This also means that calls made from this contract shall *not* be trusted.
    /// @param value Amount of ETH to transfer.
    /// @param callee The address to call. Calling `bentoBox` is not allowed.
    /// @return (bytes) the data that the call returned.
    function _call(
        uint256 value,
        address callee,
        bytes memory callData
    ) internal returns (bytes memory) {
        require(callee != address(bentoBox), "LendingPair: can't call");

        (bool success, bytes memory returnData) = callee.call{value: value}(callData);
        require(success, _getRevertMsg(returnData));
        return returnData;
    }

    /// @notice Executes a set of actions and allows composability (contract calls) to other contracts.
    /// @param actions An array with a sequence of actions to execute (see ACTION_ declarations).
    /// @param values A one-to-one mapped array to `actions`. ETH amounts to send along with the actions.
    /// Only applicable to `ACTION_CALL`, `ACTION_BENTO_DEPOSIT`.
    /// @param datas A one-to-one mapped array to `actions`. Contains abi encoded data of function arguments.
    /// @return value1 May contain the first positioned return value of the last executed action (if applicable).
    /// @return value2 May contain the second positioned return value of the last executed action which returns 2 values (if applicable).
    function cook(
        uint8[] calldata actions,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external payable returns (uint256 value1, uint256 value2) {
        accrue();
        bool needsSolvencyCheck;
        for (uint256 i = 0; i < actions.length; i++) {
            uint8 action = actions[i];
            if (action == ACTION_ADD_COLLATERAL) {
                (int256 share, address to, bool skim) = abi.decode(datas[i], (int256, address, bool));
                addCollateral(to, skim, _num(share, value1, value2));
            } else if (action == ACTION_ADD_ASSET) {
                (int256 share, address to, bool skim) = abi.decode(datas[i], (int256, address, bool));
                value1 = _addAsset(to, skim, _num(share, value1, value2));
            } else if (action == ACTION_REPAY) {
                (int256 part, address to, bool skim) = abi.decode(datas[i], (int256, address, bool));
                _repay(to, skim, _num(part, value1, value2));
            } else if (action == ACTION_REMOVE_ASSET) {
                (int256 fraction, address to) = abi.decode(datas[i], (int256, address));
                value1 = _removeAsset(to, _num(fraction, value1, value2));
            } else if (action == ACTION_REMOVE_COLLATERAL) {
                (int256 share, address to) = abi.decode(datas[i], (int256, address));
                _removeCollateral(to, _num(share, value1, value2));
                needsSolvencyCheck = true;
            } else if (action == ACTION_BORROW) {
                (int256 amount, address to) = abi.decode(datas[i], (int256, address));
                (value1, value2) = _borrow(to, _num(amount, value1, value2));
                needsSolvencyCheck = true;
            } else if (action == ACTION_BENTO_SETAPPROVAL) {
                (address user, address _masterContract, bool approved, uint8 v, bytes32 r, bytes32 s) =
                    abi.decode(datas[i], (address, address, bool, uint8, bytes32, bytes32));
                bentoBox.setMasterContractApproval(user, _masterContract, approved, v, r, s);
            } else if (action == ACTION_BENTO_DEPOSIT) {
                (value1, value2) = _bentoDeposit(datas[i], values[i], value1, value2);
            } else if (action == ACTION_BENTO_WITHDRAW) {
                (value1, value2) = _bentoWithdraw(datas[i], value1, value2);
            } else if (action == ACTION_BENTO_TRANSFER) {
                (IERC20 token, address to, int256 share) = abi.decode(datas[i], (IERC20, address, int256));
                bentoBox.transfer(token, msg.sender, to, _num(share, value1, value2));
            } else if (action == ACTION_BENTO_TRANSFER_MULTIPLE) {
                (IERC20 token, address[] memory tos, uint256[] memory shares) = abi.decode(datas[i], (IERC20, address[], uint256[]));
                bentoBox.transferMultiple(token, msg.sender, tos, shares);
            } else if (action == ACTION_CALL) {
                (address callee, bytes memory callData, bool useValue1, bool useValue2, uint8 returnValues) =
                    abi.decode(datas[i], (address, bytes, bool, bool, uint8));
                callData = _callData(callData, useValue1, useValue2, value1, value2);
                bytes memory returnData = _call(values[i], callee, callData);

                if (returnValues == 1) {
                    (value1) = abi.decode(returnData, (uint256));
                } else if (returnValues == 2) {
                    (value1, value2) = abi.decode(returnData, (uint256, uint256));
                }
            } else if (action == ACTION_GET_REPAY_SHARE) {
                int256 part = abi.decode(datas[i], (int256));
                value1 = bentoBox.toShare(asset, totalBorrow.toElastic(_num(part, value1, value2), true), true);
            } else if (action == ACTION_GET_REPAY_PART) {
                int256 amount = abi.decode(datas[i], (int256));
                value1 = totalBorrow.toBase(_num(amount, value1, value2), false);
            }
        }

        if (needsSolvencyCheck) {
            require(_isSolvent(msg.sender, false, exchangeRate), "LendingPair: user insolvent");
        }
    }

    /// @notice Handles the liquidation of users' balances, once the users' amount of collateral is too low.
    /// @param users An array of user addresses.
    /// @param borrowParts A one-to-one mapping to `users`, contains partial borrow amounts (to liquidate) of the respective user.
    /// @param to Address of the receiver in open liquidations if `swapper` is zero.
    /// @param swapper Contract address of the `ISwapper` implementation. Swappers are restricted for closed liquidations. See `setSwapper`.
    /// @param open True to perform a open liquidation else False.
    function liquidate(
        address[] calldata users,
        uint256[] calldata borrowParts,
        address to,
        ISwapper swapper,
        bool open
    ) public {
        // Oracle can fail but we still need to allow liquidations
        (, uint256 _exchangeRate) = updateExchangeRate();
        accrue();

        uint256 allCollateralShare;
        uint256 allBorrowAmount;
        uint256 allBorrowPart;
        Rebase memory _totalBorrow = totalBorrow;
        uint256 len = users.length;
        for (uint256 i = 0; i < len; i++) {
            address user = users[i];
            if (!_isSolvent(user, open, _exchangeRate)) {
                uint256 borrowPart = borrowParts[i];
                uint256 borrowAmount = _totalBorrow.toElastic(borrowPart, false);
                uint256 collateralShare =
                    bentoBox.toShare(
                        collateral,
                        borrowAmount.mul(LIQUIDATION_MULTIPLIER).mul(_exchangeRate) /
                            (LIQUIDATION_MULTIPLIER_PRECISION * EXCHANGE_RATE_PRECISION),
                        false
                    );

                userCollateralShare[user] = userCollateralShare[user].sub(collateralShare);
                userBorrowPart[user] = userBorrowPart[user].sub(borrowPart);
                emit LogRemoveCollateral(user, address(this), collateralShare);
                emit LogRepay(address(this), user, borrowAmount, borrowPart);

                // Keep totals
                allCollateralShare = allCollateralShare.add(collateralShare);
                allBorrowAmount = allBorrowAmount.add(borrowAmount);
                allBorrowPart = allBorrowPart.add(borrowPart);
            }
        }
        require(allBorrowAmount != 0, "LendingPair: all are solvent");
        _totalBorrow.elastic = _totalBorrow.elastic.sub(allBorrowAmount.to128());
        _totalBorrow.base = _totalBorrow.base.sub(allBorrowPart.to128());
        totalBorrow = _totalBorrow;
        totalCollateralShare = totalCollateralShare.sub(allCollateralShare);

        if (!open) {
            // Closed liquidation using a pre-approved swapper for the benefit of the LPs
            require(LendingPair(masterContract).swappers(swapper), "LendingPair: Invalid swapper");

            // Swaps the users' collateral for the borrowed asset
            bentoBox.transfer(collateral, address(this), address(swapper), allCollateralShare);
            swapper.swap(collateral, asset, address(this), allBorrowAmount, allCollateralShare);

            uint256 extraShare = bentoBox.balanceOf(asset, address(this)).sub(uint256(totalAsset.elastic));

            uint256 feeShare = extraShare.mul(PROTOCOL_FEE) / PROTOCOL_FEE_DIVISOR; // % of profit goes to fee
            // solhint-disable-next-line reentrancy
            totalAsset.elastic = totalAsset.elastic.add(extraShare.sub(feeShare).to128());
            bentoBox.transfer(asset, address(this), LendingPair(masterContract).feeTo(), feeShare);
            emit LogAddAsset(address(swapper), address(this), extraShare.sub(feeShare), 0);
        } else {
            // Swap using a swapper freely chosen by the caller
            // Open (flash) liquidation: get proceeds first and provide the borrow after
            bentoBox.transfer(collateral, address(this), swapper != ISwapper(0) ? address(swapper) : to, allCollateralShare);
            if (swapper != ISwapper(0)) {
                swapper.swap(collateral, asset, msg.sender, allBorrowAmount, allCollateralShare);
            }

            bentoBox.transfer(asset, msg.sender, address(this), allBorrowAmount);
        }
    }

    /// @notice Withdraws the fees accumulated.
    function withdrawFees() public {
        accrue();
        address _feeTo = LendingPair(masterContract).feeTo();
        uint256 _feesEarnedFraction = accrueInfo.feesEarnedFraction;
        balanceOf[_feeTo] = balanceOf[_feeTo].add(_feesEarnedFraction);
        accrueInfo.feesEarnedFraction = 0;

        emit LogWithdrawFees(_feeTo, _feesEarnedFraction);
    }

    /// @notice Used to register and enable or disable swapper contracts used in closed liquidations.
    /// MasterContract Only Admin function.
    /// @param swapper The address of the swapper contract that conforms to `ISwapper`.
    /// @param enable True to enable the swapper. To disable use False.
    function setSwapper(ISwapper swapper, bool enable) public onlyOwner {
        swappers[swapper] = enable;
    }

    /// @notice Sets the beneficiary of fees accrued in liquidations.
    /// MasterContract Only Admin function.
    /// @param newFeeTo The address of the receiver.
    function setFeeTo(address newFeeTo) public onlyOwner {
        feeTo = newFeeTo;
        emit LogFeeTo(newFeeTo);
    }
}
