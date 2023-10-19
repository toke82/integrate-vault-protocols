// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {VaultAPI} from "@yearnvaults/contracts/BaseStrategy.sol";

contract YearnYield is ERC20, ReentrancyGuard {
    //////////////////
    //  Errors
    //////////////////
    error YearnYield__NotZeroAddress();
    error YearnYield__NeedsMoreThanZero();

    //////////////////
    //  Modifiers
    //////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert YearnYield__NeedsMoreThanZero();
        }
        _;
    }    

    VaultAPI public immutable yVault;
    address public immutable token;
    uint256 public immutable _decimals;

    ////////////////// 
    /// EVENTS
    ////////////////// 
    event Deposit(address indexed calller, address indexed owner, uint256 assets, uint256 shares);

    constructor(VaultAPI _vault) 
        ERC20(
            string(abi.encodePacked(_vault.name(), "YearnYield")),
            string(abi.encodePacked(_vault.symbol(), "YND"))
        )
    {
        yVault = _vault;
        token = yVault.token();
        _decimals = _vault.decimals();
    }

    ///////////////////////////////
    ///// DEPOSIT/WITHDRAW LOGIC
    ///////////////////////////////

    function deposit(uint256 assets, address receiver) 
        external moreThanZero(assets) 
        nonReentrant 
        returns (uint256 shares) 
    {
        if (receiver == address(0)) {
            revert YearnYield__NotZeroAddress();
        }
        (assets, shares) = _deposit(assets, receiver, msg.sender);

        emit Deposit(msg.sender, receiver, assets, shares); 
    }

    ///////////////////////////////
    ///// INTERNAL FUNCTIONS
    ///////////////////////////////
    
    function _deposit(
        uint256 amount, // if `MAX_UINT256`, just deposit everything
        address receiver, 
        address depositor
        ) internal returns (uint256 deposited, uint256 mintedShares) 
    {
        VaultAPI _vault = yVault;
        IERC20 _token = IERC20(token);

        if (amount == type(uint256).max) {
            amount = Math.min(
                _token.balanceOf(depositor),
                _token.allowance(depositor, address(this))
            );
        }

        SafeERC20.safeTransferFrom(_token, depositor, address(this), amount);

        if(_token.allowance(address(this), address(_vault)) < amount) {
            _token.approve(address(_vault), 0); // Avoid issues with some tokens requiring 0
            _token.approve(address(_vault), type(uint256).max); // Vaults are trusted
        }

        // beforeDeposit Custom Logic

        uint256 beforeBal = _token.balanceOf(address(this));

        mintedShares = _vault.deposit(amount, address(this));

        uint256 afterBal = _token.balanceOf(address(this));
        deposited = beforeBal - afterBal;

        // afterDeposit Custom Logic
        _mint(receiver, mintedShares);

        // `receiver` now has shares of `_vault` as balance, converted to `token` here
        // Issue a refund if not everything was deposited
        uint256 refundable = amount -deposited;
        if (refundable > 0) {
            SafeERC20.safeTransfer(_token, depositor, refundable);
        }
    }

}