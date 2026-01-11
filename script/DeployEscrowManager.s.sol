// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {EscrowManager} from "../src/EscrowManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployEscrowManager is Script {
    function run() external returns (EscrowManager) {
        address mneeAddress = vm.envAddress(0x8ccedbAe4916b79da7F3F612EfB2EB93A2bFD6cF); //0x8ccedbAe4916b79da7F3F612EfB2EB93A2bFD6cF
        vm.startBroadcast();
        EscrowManager escrowManager = new EscrowManager(mneeAddress);
        vm.stopBroadcast();
        return escrowManager;
    }
}

contract DeployEscrowManagerToTestnet is Script {
    function run() external returns (EscrowManager) {
        address mneeAddress = vm.envAddress("MNEE_TESTNET_ADDRESS"); //0xc387Eed7806EBaca48335d859aE8D2F122aEFD54
        vm.startBroadcast();
        EscrowManager escrowManager = new EscrowManager(mneeAddress);
        vm.stopBroadcast();
        return escrowManager;
    }
}
