// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

import {MocaTokenMock} from "./../test/mocks/MocaTokenMock.sol";
import {MocaOFT} from "./../src/MocaOFT.sol";
import {MocaTokenAdapter} from "./../src/MocaTokenAdapter.sol";

abstract contract LZState is Script {
    
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

    uint16 homeChainID = sepoliaID;
    address homeLzEP = sepoliaEP;

    uint16 remoteChainID = baseSepoliaID;
    address remoteLzEP = baseSepoliaEP;

    address public deployerAddress = vm.envAddress("PUBLIC_KEY_TEST");

    modifier broadcast() {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TEST");
        vm.startBroadcast(deployerPrivateKey);

        _;

        vm.stopBroadcast();
    }
}

//Note: Deploy token + adaptor
contract DeployHome is LZState {
    
    function run() public broadcast {

        // mint supply to treasury
        string memory name = "TestToken"; 
        string memory symbol = "TT";
        address treasury = deployerAddress;
        MocaTokenMock mocaToken = new MocaTokenMock(name, symbol, treasury);
        
        // set msg.sender as delegate and owner
        address delegate = deployerAddress;
        address owner = deployerAddress;
        MocaTokenAdapter mocaTokenAdapter = new MocaTokenAdapter(address(mocaToken), homeLzEP, delegate, owner);
    }
}

// forge script script/DeployTestMock.s.sol:DeployHome --rpc-url sepolia --broadcast --verify -vvvv --etherscan-api-key sepolia
    

//Note: Deploy OFT on remote
contract DeployElsewhere is LZState {

    function run() public broadcast {

        //params
        string memory name = "TestToken"; 
        string memory symbol = "TT";
        address delegate = deployerAddress;
        address owner = deployerAddress;

        MocaOFT remoteOFT = new MocaOFT(name, symbol, remoteLzEP, delegate, owner);
    }
}

// forge script script/DeployTestMock.s.sol:DeployElsewhere --rpc-url base_sepolia --broadcast --verify -vvvv --etherscan-api-key base_sepolia


//------------------------------ SETUP ------------------------------------

abstract contract State is LZState {
    
    // home
    address public mocaTokenAddress = address(0x73ce27235B1d65028F1a7470B1f471Df66a9504f);    
    address public mocaTokenAdapterAddress = address(0x859eba9f58873d9284ccd211611494ED9D842204);                     

    // remote
    address public mocaOFTAddress = address(0x03946287b52B88C8357E813fbA3F472c60FaE727);

    // set contracts
    MocaTokenMock public mocaToken = MocaTokenMock(mocaTokenAddress);
    MocaTokenAdapter public mocaTokenAdapter = MocaTokenAdapter(mocaTokenAdapterAddress);

    MocaOFT public mocaOFT = MocaOFT(mocaOFTAddress);
}


// ------------------------------------------- Trusted Remotes: connect contracts -------------------------
contract SetRemoteOnHome is State {

    function run() public broadcast {
       
        // eid: The endpoint ID for the destination chain the other OFT contract lives on
        // peer: The destination OFT contract address in bytes32 format
        bytes32 peer = bytes32(uint256(uint160(address(mocaOFTAddress))));
        mocaTokenAdapter.setPeer(remoteChainID, peer);
    }
}

// forge script script/DeployTestMock.s.sol:SetRemoteOnHome --rpc-url sepolia --broadcast -vvvv

contract SetRemoteOnAway is State {

    function run() public broadcast {
        
        // eid: The endpoint ID for the destination chain the other OFT contract lives on
        // peer: The destination OFT contract address in bytes32 format
        bytes32 peer = bytes32(uint256(uint160(address(mocaTokenAdapter))));
        mocaOFT.setPeer(homeChainID, peer);
        
    }
}

// forge script script/DeployTestMock.s.sol:SetRemoteOnAway --rpc-url base_sepolia --broadcast -vvvv


// ------------------------------------------- Gas Limits -------------------------

import { IOAppOptionsType3, EnforcedOptionParam } from "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppOptionsType3.sol";

contract SetGasLimitsHome is State {

    function run() public broadcast {

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

// forge script script/DeployTestMock.s.sol:SetGasLimitsHome --rpc-url sepolia --broadcast -vvvv


contract SetGasLimitsAway is State {

    function run() public broadcast {
        
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

// forge script script/DeployTestMock.s.sol:SetGasLimitsAway --rpc-url base_sepolia --broadcast -vvvv

// ------------------------------------------- Set Rate Limits  -----------------------------------------

contract SetRateLimitsHome is State {

    function run() public broadcast {

        mocaTokenAdapter.setOutboundLimit(remoteChainID, 10000000 ether);
        mocaTokenAdapter.setInboundLimit(remoteChainID, 10000000 ether);
    }
}

// forge script script/DeployTestMock.s.sol:SetRateLimitsHome --rpc-url sepolia --broadcast -vvvv

contract SetRateLimitsRemote is State {

    function run() public broadcast {
        
        mocaOFT.setOutboundLimit(homeChainID, 10000000 ether);
        mocaOFT.setInboundLimit(homeChainID, 10000000 ether);

    }
}

// forge script script/DeployTestMock.s.sol:SetRateLimitsRemote --rpc-url base_sepolia --broadcast -vvvv

// ------------------------------------------- Send sum tokens  -------------------------

// SendParam
import "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { MessagingParams, MessagingFee, MessagingReceipt } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract SendTokensToAway is State {

    function run() public broadcast {

        //set approval for adaptor to spend tokens
        mocaToken.approve(mocaTokenAdapterAddress, 10 ether);
        
        bytes memory nullBytes = new bytes(0);
        SendParam memory sendParam = SendParam({
            dstEid: remoteChainID,
            to: bytes32(uint256(uint160(address(0xdE05a1Abb121113a33eeD248BD91ddC254d5E9Db)))),
            amountLD: 1 ether,
            minAmountLD: 1 ether,
            extraOptions: nullBytes,
            composeMsg: nullBytes,
            oftCmd: nullBytes
        });

        // Fetching the native fee for the token send operation
        MessagingFee memory messagingFee = mocaTokenAdapter.quoteSend(sendParam, false);

        // send tokens xchain
        mocaTokenAdapter.send{value: messagingFee.nativeFee}(sendParam, messagingFee, payable(0xdE05a1Abb121113a33eeD248BD91ddC254d5E9Db ));

    }
}

//  forge script script/DeployTestMock.s.sol:SendTokensToAway --rpc-url sepolia --broadcast -vvvv

contract SendTokensToRemotePlusGas is State {

    function run() public broadcast {

        //set approval for adaptor to spend tokens
        mocaToken.approve(mocaTokenAdapterAddress, 1 ether);
        
        // createLzNativeDropOption
        // gas: 6000000000000000 (amount of native gas to drop in wei)
        // receiver: 0x000000000000000000000000de05a1abb121113a33eed248bd91ddc254d5e9db (address in bytes32)
        bytes memory extraOptions = hex"0003010031020000000000000000001550f7dca70000000000000000000000000000de05a1abb121113a33eed248bd91ddc254d5e9db";

        bytes memory nullBytes = new bytes(0);
        SendParam memory sendParam = SendParam({
            dstEid: remoteChainID,                                                                  // Destination endpoint ID.
            to: bytes32(uint256(uint160(address(0xdE05a1Abb121113a33eeD248BD91ddC254d5E9Db)))),     // Recipient address.
            amountLD: 1 ether,                                                                      // Amount to send in local decimals        
            minAmountLD: 1 ether,                                                                   // Minimum amount to send in local decimals.
            extraOptions: extraOptions,                                                             // Additional options supplied by the caller to be used in the LayerZero message.
            composeMsg: nullBytes,                                                               // The composed message for the send() operation.
            oftCmd: nullBytes                                                                    // The OFT command to be executed, unused in default OFT implementations.
        });

        // Fetching the native fee for the token send operation
        MessagingFee memory messagingFee = mocaTokenAdapter.quoteSend(sendParam, false);

        // send tokens xchain
        mocaTokenAdapter.send{value: messagingFee.nativeFee}(sendParam, messagingFee, payable(0xdE05a1Abb121113a33eeD248BD91ddC254d5E9Db));

    }
}

//  forge script script/DeployTestMock.s.sol:SendTokensToRemotePlusGas --rpc-url sepolia --broadcast -vvvv