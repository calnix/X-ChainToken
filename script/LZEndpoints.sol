// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

abstract contract LZTestnets is Script {
    
    //Note: LZV2 testnet addresses

    uint16 public sepoliaID = 40161;
    address public sepoliaEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    uint16 public mumbaiID = 40109;
    address public mumbaiEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    uint16 public bnbID = 40102;
    address public bnbEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    uint16 public arbSepoliaID = 40231;
    address public arbSepoliaEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    uint16 public opSepoliaID = 40232;
    address public opSepoliaEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    uint16 public baseSepoliaID = 40245;
    address public baseSepoliaEP = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    // TO BE SET IN SCRIPT
    uint16 public homeChainID;
    address public homeLzEP;
    uint16 public remoteChainID;
    address public remoteLzEP;
    address public DEPLOYER_ADDRESS;


    modifier broadcast(string memory privateKey) {

        uint256 deployerPrivateKey = vm.envUint(privateKey);
        vm.startBroadcast(deployerPrivateKey);

        _;

        vm.stopBroadcast();
    }

}


abstract contract LZMainnets is Script {
    
    //Note: LZV2 Mainnet addresses

    uint16 public ethID = 30101;
    address public ethEP = 0x1a44076050125825900e736c501f859c50fE728c;

    uint16 public baseID = 30184;
    address public baseEP = 0x1a44076050125825900e736c501f859c50fE728c;

    // TO BE SET IN SCRIPT
    uint16 public homeChainID;
    address public homeLzEP;
    uint16 public remoteChainID;
    address public remoteLzEP;
    address public DEPLOYER_ADDRESS;

    modifier broadcast(string memory privateKey) {

        uint256 deployerPrivateKey = vm.envUint(privateKey);
        vm.startBroadcast(deployerPrivateKey);

        _;

        vm.stopBroadcast();
    }

}
