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
    error YearnYield__NoAvailableShares();
    error YearnYield__NotEnoughAvailableSharesForAmount();

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
    event Deposit(
        address indexed calller, 
        address indexed owner, 
        uint256 assets, 
        uint256 shares
    );
    event Withdraw(
        address indexed caller, 
        address indexed receiver, 
        address indexed owner, 
        uint256 assets, 
        uint256 shares
    );

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

    function withdraw(uint256 assets, address receiver, address owner) 
        external moreThanZero(assets)
        nonReentrant
        returns (uint256 shares) 
    {
        (uint256 _withdrawn, uint256 _burntShares) = _withdraw(assets, receiver, msg.sender);

        emit Withdraw(msg.sender, receiver, owner, _withdrawn, _burntShares);
        return _burntShares;
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

    function _withdraw(
        uint256 amount, 
        address receiver, 
        address sender
        ) internal returns(uint256 withdrawn, uint256 burntShares) 
    {
        VaultAPI _vault = yVault;

        // Star with the total shares that `sender` has
        // Limit by maximum withdrawl size of each vault
        uint256 availableShares = Math.min(
            this.balanceOf(sender),
            _vault.maxAvailableShares()
        );

        if (availableShares == 0) revert YearnYield__NoAvailableShares();

        uint256 estimatedMaxShares = (amount * 10**uint256(_vault.decimals()));

        if (estimatedMaxShares > availableShares) 
            revert YearnYield__NotEnoughAvailableSharesForAmount();

        // beforeWithDraw custom logic

        // withdraw from the vault and get total used shares
        uint256 beforeBal = _vault.balanceOf(address(this));
        withdrawn = _vault.withdraw(estimatedMaxShares, receiver);
        burntShares = beforeBal - _vault.balanceOf(address(this));
        uint256 unusedShares = estimatedMaxShares - burntShares;  


        // afterWithDraw custom logic
        _burn(sender, burntShares);

        if (unusedShares > 0)
            SafeERC20.safeTransfer(_vault, sender, unusedShares);
    }

}