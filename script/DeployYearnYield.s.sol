// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "../src/YearnYield.sol";
import {VaultAPI} from "@yearnvaults/contracts/BaseStrategy.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployYearnYield is Script {

    function run() public {
        address _vault = address(1);

        HelperConfig helperConfig = new HelperConfig();

        uint256 deployerKey = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);

        // Deploy the YearnYield contract
        YearnYield yearnVault = new YearnYield(VaultAPI(_vault));

        vm.stopBroadcast();
        // Log the deployed contract address
        console.log("YearnYield deployed at", address(yearnVault));
    }
}
