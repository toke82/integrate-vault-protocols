// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import "../../src/YearnYield.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
string constant vaultArtifact = "out/BaseStrategy.sol/VaultAPI.json";

contract YearnYieldTest is Test {
    // Define the mock contracts
    ERC20Mock stakingToken;
    VaultAPI yieldVault;

    // Define the contract under test
    YearnYield yieldContract;

    address public USER = makeAddr("user");
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant AMOUNT = 10 ether;

    function setUp() public {
        stakingToken = new ERC20Mock("Mock Token", "MOCK", USER, STARTING_ERC20_BALANCE);
        address _vaultAddress = deployCode(vaultArtifact);
        yieldVault = VaultAPI(_vaultAddress);
        yieldContract = new YearnYield(yieldVault);
    }

    // Test the deposit function
    function testDeposit() public 
    {
        // Mint some tokens to the caller
        stakingToken.mint(USER, AMOUNT);

        // Approve the transfer to the contract
        stakingToken.approve(address(yieldContract), AMOUNT);

        // Call the deposit function
        yieldContract.deposit(AMOUNT, address(yieldContract));

        // Check the balances and shares
        assertEq(stakingToken.balanceOf(address(yieldContract)), AMOUNT, "Wrong balance of the contract");

        assertEq(yieldVault.balanceOf(address(yieldContract)), AMOUNT, "Wrong shares of the contract");

        assertEq(stakingToken.balanceOf(msg.sender), 0, "Wrong balance of the caller");
    }

    // Test the withdraw function
    function testWithdraw() public 
    {
        // Set up the deposit scenario
        testDeposit();

        // Call the withdraw function
        yieldContract.withdraw(AMOUNT, USER, address(yieldContract));

        // Check the balances and shares
        assertEq(stakingToken.balanceOf(address(yieldContract)), 0, "Wrong balance of the contract");

        assertEq(yieldVault.balanceOf(address(yieldContract)), 0, "Wrong shares of the contract");

        assertEq(yieldVault.balanceOf(msg.sender), 0, "Wrong shares of caller");
    }
}