// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {EscrowManager} from "../src/EscrowManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployEscrowManager is Script {
    function run() external returns (EscrowManager) {
        address mneeAddress = vm.envAddress("MNEE_MAINNET_ADDRESS"); //0x8ccedbAe4916b79da7F3F612EfB2EB93A2bFD6cF
        vm.startBroadcast();
        EscrowManager escrowManager = new EscrowManager(mneeAddress);
        vm.stopBroadcast();
        return escrowManager;
    }
}

contract DeployEscrowManagerToTestnet is Script {
    function run() external returns (EscrowManager) {
        address mneeAddress = vm.envAddress("MNEE_TESTNET_ADDRESS"); //0x4752d00551699858899161607FFF9D24804CA86c
        vm.startBroadcast();
        EscrowManager escrowManager = new EscrowManager(mneeAddress);
        vm.stopBroadcast();
        return escrowManager;
    }
}
