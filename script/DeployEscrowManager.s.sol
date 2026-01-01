// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {EscrowManager} from "../src/EscrowManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployEscrowManager is Script {
    function run() external returns (EscrowManager) {
        address mneeAddress = 0x8ccedbAe4916b79da7F3F612EfB2EB93A2bFD6cF;
        address devBuyer = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        address devSeller = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
        address devArbiter = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
        address devPlatform = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        address whale = 0x4240781A9ebDB2EB14a183466E8820978b7DA4e2; 
        uint256 amount = 20e18;

        vm.deal(devBuyer, 1 ether);
        vm.deal(devPlatform, 1 ether);
        vm.deal(devSeller, 1 ether);
        vm.deal(devArbiter, 1 ether);

        vm.startPrank(whale);
        IERC20(mneeAddress).transfer(devBuyer, amount);
        IERC20(mneeAddress).transfer(devPlatform, amount);
        vm.stopPrank();

        vm.startBroadcast();
        EscrowManager escrowManager = new EscrowManager(mneeAddress);
        vm.stopBroadcast();
        return escrowManager;
    }
}