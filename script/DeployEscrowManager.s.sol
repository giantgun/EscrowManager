// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {EscrowManager} from "../src/EscrowManager.sol";

contract DeployEscrowManager is Script {
    function run() external returns (EscrowManager) {
        address mneeAddress = 0x8ccedbAe4916b79da7F3F612EfB2EB93A2bFD6cF;
        vm.startBroadcast();
        EscrowManager escrowManager = new EscrowManager(mneeAddress);
        vm.stopBroadcast();
        return escrowManager;
    }
}