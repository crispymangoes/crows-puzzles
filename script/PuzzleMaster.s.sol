// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { PuzzleMaster } from "src/PuzzleMaster.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Script.sol";

contract PuzzleMasterScript is Script {

    ERC20 private WETH = ERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);

    function run() public {
        vm.startBroadcast();
        
        PuzzleMaster puzzleMaster = new PuzzleMaster(bytes32(0), WETH);
        
        vm.stopBroadcast();
    }
}
