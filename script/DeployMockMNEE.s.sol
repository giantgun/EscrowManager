// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {MockMNEE} from "../src/MockMNEE.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployMockMNEE is Script {
    function run() external returns (MockMNEE) {
        address whaleAddress = vm.envAddress("MOCK_MNEE_WHALE_ADDRESS"); //0xbCa3Ef30b1dC0BeA40E96A016816CA1e79085C25
        vm.startBroadcast();
        MockMNEE mockMnee = new MockMNEE(whaleAddress, whaleAddress);
        vm.stopBroadcast();
        return mockMnee;
    }
}