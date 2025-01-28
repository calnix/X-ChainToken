// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MocaTokenMock} from "./../../test/mocks/MocaTokenMock.sol";
import {MocaOFT} from "./../../src/MocaOFT.sol";
import {MocaTokenAdapter} from "./../../src/MocaTokenAdapter.sol";

import {LZTestnets} from "../LZEndpoints.sol";

import "forge-std/Script.sol";

/** 
    note: eth: home, base: remote
    this test uses MockMocaToken for free mints

    it relies on a prior sepolia deployment of the token and adaptor.
*/

abstract contract LZState is LZTestnets {

    function setUp() public {

        homeChainID = sepoliaID;
        homeLzEP = sepoliaEP;
        
        remoteChainID = baseSepoliaID;
        remoteLzEP = baseSepoliaEP;

        DEPLOYER_ADDRESS = vm.envAddress("PUBLIC_KEY_TEST");
    }
}

/*
contract DeployHome is LZState {
    function run() public {
    }
}*/

//Remote
contract DeployElsewhere is LZState {

    function run() public broadcast("PRIVATE_KEY_TEST") {
        
        console2.log("deployerAddress", DEPLOYER_ADDRESS);

        //params
        string memory name = "TestToken"; 
        string memory symbol = "TT";
        address delegate = DEPLOYER_ADDRESS;
        address owner = DEPLOYER_ADDRESS;

        MocaOFT remoteOFT = new MocaOFT(name, symbol, remoteLzEP, delegate, owner);
    }
}

// forge script script/Base/DeployBaseTest.s.sol:DeployElsewhere --rpc-url base_sepolia --broadcast --verify -vvvv --etherscan-api-key base_sepolia

// note: update addresses in State
abstract contract State is LZState {
    
    // home: note uses MocaTokenMock for free mints 
    address public mocaTokenAddress = address(0x73ce27235B1d65028F1a7470B1f471Df66a9504f);    
    address public mocaTokenAdapterAddress = address(0x859eba9f58873d9284ccd211611494ED9D842204);                     

    // remote
    address public mocaOFTAddress = address(0xB35a100EAC70fFc06A7e9A2a5dc94B3AC3213c68);

    // set contracts
    MocaTokenMock public mocaToken = MocaTokenMock(mocaTokenAddress);
    MocaTokenAdapter public mocaTokenAdapter = MocaTokenAdapter(mocaTokenAdapterAddress);

    MocaOFT public mocaOFT = MocaOFT(mocaOFTAddress);
}


// ------------------------------------------- Trusted Remotes: connect contracts -------------------------
contract SetRemoteOnHome is State {

    function run() public broadcast("PRIVATE_KEY_TEST") {
        // eid: The endpoint ID for the destination chain the other OFT contract lives on
        // peer: The destination OFT contract address in bytes32 format
        bytes32 peer = bytes32(uint256(uint160(address(mocaOFTAddress))));
        mocaTokenAdapter.setPeer(remoteChainID, peer);
    }
}

// forge script script/Base/DeployBaseTest.s.sol:SetRemoteOnHome --rpc-url sepolia --broadcast -vvvv 

contract SetRemoteOnAway is State {

    function run() public broadcast("PRIVATE_KEY_TEST") {
        // eid: The endpoint ID for the destination chain the other OFT contract lives on
        // peer: The destination OFT contract address in bytes32 format
        bytes32 peer = bytes32(uint256(uint160(address(mocaTokenAdapterAddress))));
        mocaOFT.setPeer(homeChainID, peer);
        
    }
}

// forge script script/Base/DeployBaseTest.s.sol:SetRemoteOnAway --rpc-url base_sepolia --broadcast -vvvv 

// ------------------------------------------- Gas Limits -------------------------

import { IOAppOptionsType3, EnforcedOptionParam } from "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppOptionsType3.sol";

contract SetGasLimitsHome is State {

    function run() public broadcast("PRIVATE_KEY_TEST") {
        
        EnforcedOptionParam memory enforcedOptionParam;
        // msgType:1 -> a standard token transfer via send()
        // options: -> A typical lzReceive call will use 200000 gas on most EVM chains         
        EnforcedOptionParam[] memory enforcedOptionParams = new EnforcedOptionParam[](2);
        enforcedOptionParams[0] = EnforcedOptionParam(remoteChainID, 1, hex"00030100110100000000000000000000000000030d40");
        
        // block sendAndCall: createLzReceiveOption() set gas:0 and value:0 and index:0
        enforcedOptionParams[1] = EnforcedOptionParam(remoteChainID, 2, hex"000301001303000000000000000000000000000000000000");

        mocaTokenAdapter.setEnforcedOptions(enforcedOptionParams);
    }
}

// forge script script/Base/DeployBaseTest.s.sol:SetGasLimitsHome --rpc-url sepolia --broadcast -vvvv 

contract SetGasLimitsAway is State {

    function run() public broadcast("PRIVATE_KEY_TEST") {

        EnforcedOptionParam memory enforcedOptionParam;
        // msgType:1 -> a standard token transfer via send()
        // options: -> A typical lzReceive call will use 200000 gas on most EVM chains 
        EnforcedOptionParam[] memory enforcedOptionParams = new EnforcedOptionParam[](2);
        enforcedOptionParams[0] = EnforcedOptionParam(homeChainID, 1, hex"00030100110100000000000000000000000000030d40");
        
        // block sendAndCall: createLzReceiveOption() set gas:0 and value:0 and index:0
        enforcedOptionParams[1] = EnforcedOptionParam(homeChainID, 2, hex"000301001303000000000000000000000000000000000000");

        mocaOFT.setEnforcedOptions(enforcedOptionParams);
    }
}

// forge script script/Base/DeployBaseTest.s.sol:SetGasLimitsAway --rpc-url base_sepolia --broadcast -vvvv 

// ------------------------------------------- Whitelisting Treasury  -----------------------------------------

import "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { MessagingParams, MessagingFee, MessagingReceipt } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract whitelistTreasuryOnHome is State {

    function run() public broadcast("PRIVATE_KEY_TEST") {
        
        address treasuryMultiSig = DEPLOYER_ADDRESS;
        mocaTokenAdapter.setWhitelist(treasuryMultiSig, true);
    }
}

// forge script script/Base/DeployBaseTest.s.sol:whitelistTreasuryOnHome --rpc-url sepolia --broadcast -vvvv 


contract whitelistTreasuryOnRemote is State {

    function run() public broadcast("PRIVATE_KEY_TEST") {
        
        address treasuryMultiSig = DEPLOYER_ADDRESS;
        mocaOFT.setWhitelist(treasuryMultiSig, false);
    }
}

// forge script script/Base/DeployBaseTest.s.sol:whitelistTreasuryOnRemote --rpc-url base_sepolia --broadcast -vvvv 

// ------------------------------------------- Test Whitelisted Sending Tokens  -----------------------------------------

contract TestWhitelistSendingTokens is State {

    function run() public broadcast("PRIVATE_KEY_TEST") {
        //set approval for adaptor to spend tokens
        //mocaToken.approve(mocaTokenAdapterAddress, 10 ether);
        
        bytes memory nullBytes = new bytes(0);
        SendParam memory sendParam = SendParam({
            dstEid: remoteChainID,
            to: bytes32(uint256(uint160(address(DEPLOYER_ADDRESS)))),
            amountLD: 1 ether,
            minAmountLD: 1 ether,
            extraOptions: nullBytes,
            composeMsg: nullBytes,
            oftCmd: nullBytes
        });

        // Fetching the native fee for the token send operation
        MessagingFee memory messagingFee = mocaTokenAdapter.quoteSend(sendParam, false);

        // send tokens xchain
        mocaTokenAdapter.send{value: messagingFee.nativeFee}(sendParam, messagingFee, payable(DEPLOYER_ADDRESS));
    }
}

// forge script script/Base/DeployBaseTest.s.sol:TestWhitelistSendingTokens --rpc-url sepolia --broadcast -vvvv 

// ------------------------------------------- Set Rate Limits  -----------------------------------------

/*
contract SetRateLimitsHome is State {

    function run() public broadcast("PRIVATE_KEY_TEST") {
        
        mocaTokenAdapter.setOutboundLimit(remoteChainID, 10 ether);
        mocaTokenAdapter.setInboundLimit(remoteChainID, 10 ether);
    }
}

// forge script script/Base/DeployBaseTest.s.sol:SetRateLimitsHome --rpc-url sepolia --broadcast -vvvv 

contract SetRateLimitsRemote is State {

    function run() public broadcast("PRIVATE_KEY_TEST") {

        mocaOFT.setOutboundLimit(homeChainID, 10 ether);
        mocaOFT.setInboundLimit(homeChainID, 10 ether);
    }
}

// forge script script/Base/DeployBaseTest.s.sol:SetRateLimitsRemote --rpc-url base_sepolia --broadcast -vvvv 

*/

// ------------------------------------------- DVN Config ------------------------------------------

import { SetConfigParam } from "node_modules/@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import { UlnConfig } from "node_modules/@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

/**
    note:
    - set custom DVN configs
    - setOwnerAsDelegate
    - transferOwnership[home, remote]
    - check that DAT team has accepted ownership, by calling `acceptOwnership()` on both home and remote
 */