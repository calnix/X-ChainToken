// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

import {MocaToken} from "./../src/MocaToken.sol";
import {MocaOFT} from "./../src/MocaOFT.sol";
import {MocaTokenAdapter} from "./../src/MocaTokenAdapter.sol";

abstract contract LZState is Script {
    
    uint16 public ethereumID = 30101;
    address public ethereumEP = 0x1a44076050125825900e736c501f859c50fE728c;

    uint16 public polygonID = 30109;
    address public polygonEP = 0x1a44076050125825900e736c501f859c50fE728c;

    uint16 homeChainID = ethereumID;
    address homeLzEP = ethereumEP;

    uint16 remoteChainID = polygonID;
    address remoteLzEP = polygonEP;

    // token data
    string public name = "Latte";
    string public symbol = "Latte";

    // priviledged addresses
    //address public ownerMultiSig = 0x1291d48f9524cE496bE32D2DC33D5E157b6Ed1e3;
    //address public treasuryMultiSig = 0xe35B78991633E8130131D6A73302F96678e80f8D;
    
    address public ownerMultiSig = 0x8C9C001F821c04513616fd7962B2D8c62f925fD2;
    address public treasuryMultiSig = 0x8C9C001F821c04513616fd7962B2D8c62f925fD2;

    address public deployer = 0x8C9C001F821c04513616fd7962B2D8c62f925fD2;

    modifier broadcast() {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        _;

        vm.stopBroadcast();
    }
}


//Note: Deploy token + adaptor
contract DeployHome is LZState {
    
    // Note: ownership will be handed over to multisig after deployment and config
    function run() public broadcast {

        // mint supply to treasury
        MocaToken mocaToken = new MocaToken(name, symbol, treasuryMultiSig);
        
        address delegate = deployer;
        address owner = deployer;
        MocaTokenAdapter mocaTokenAdapter = new MocaTokenAdapter(address(mocaToken), homeLzEP, delegate, owner);
    }
}

// forge script script/DeployFinalTest.s.sol:DeployHome --rpc-url mainnet --broadcast --verify -vvvv --etherscan-api-key mainnet 

//Note: Deploy OFT on remote
contract DeployElsewhere is LZState {

    // Note: ownership will be handed over to multisig after deployment and config
    function run() public broadcast {

        //params
        address delegate = deployer;
        address owner = deployer;
        MocaOFT remoteOFT = new MocaOFT(name, symbol, remoteLzEP, delegate, owner);
    }
}

// forge script script/DeployFinalTest.s.sol:DeployElsewhere --rpc-url polygon --broadcast --verify -vvvv --etherscan-api-key polygon 

//------------------------------ SETUP ------------------------------------

abstract contract State is LZState {
    
    // home
    address public mocaTokenAddress = address(0xE8d8fC1eB5BAbDE5FccFD5EFB788f075738E1044);    
    address public mocaTokenAdapterAddress = address(0x23E086A3AD04E8dAb40c263FE18Fa1f32ED28FB7);                     

    // remote
    address public mocaOFTAddress = address(0xfdf8c03CdbC1851BF5bd42a73F4fBA8102F4b515);

    // set contracts
    MocaToken public mocaToken = MocaToken(mocaTokenAddress);
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

// forge script script/DeployFinalTest.s.sol:SetRemoteOnHome --rpc-url mainnet --broadcast -vvvv 

contract SetRemoteOnAway is State {

    function run() public broadcast {
        // eid: The endpoint ID for the destination chain the other OFT contract lives on
        // peer: The destination OFT contract address in bytes32 format
        bytes32 peer = bytes32(uint256(uint160(address(mocaTokenAdapterAddress))));
        mocaOFT.setPeer(homeChainID, peer);
        
    }
}

// forge script script/DeployFinalTest.s.sol:SetRemoteOnAway --rpc-url polygon --broadcast -vvvv 

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

// forge script script/DeployFinalTest.s.sol:SetGasLimitsHome --rpc-url mainnet --broadcast -vvvv 


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

// forge script script/DeployFinalTest.s.sol:SetGasLimitsAway --rpc-url polygon --broadcast -vvvv 

// ------------------------------------------- Set Rate Limits  -----------------------------------------

contract SetRateLimitsHome is State {

    function run() public broadcast {
        
        mocaTokenAdapter.setOutboundLimit(remoteChainID, 10 ether);
        mocaTokenAdapter.setInboundLimit(remoteChainID, 10 ether);
    }
}

// forge script script/DeployFinalTest.s.sol:SetRateLimitsHome --rpc-url mainnet --broadcast -vvvv 

contract SetRateLimitsRemote is State {

    function run() public broadcast {

        mocaOFT.setOutboundLimit(homeChainID, 10 ether);
        mocaOFT.setInboundLimit(homeChainID, 10 ether);
    }
}

// forge script script/DeployFinalTest.s.sol:SetRateLimitsRemote --rpc-url polygon --broadcast -vvvv 


// ------------------------------------------- DVN Config  -----------------------------------------
import { SetConfigParam } from "node_modules/@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import { UlnConfig } from "node_modules/@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

abstract contract DvnData is State {
    
    address public layerZero_mainnet = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b;
    address public layerZero_polygon = 0x23DE2FE932d9043291f870324B74F820e11dc81A;
    
    // same address for both mainnet and polygon
    address public gcp = 0xD56e4eAb23cb81f43168F9F45211Eb027b9aC7cc;

    address public animoca_mainnet = 0x7E65BDd15C8Db8995F80aBf0D6593b57dc8BE437;
    address public animoca_polygon = 0xa6F5DDBF0Bd4D03334523465439D301080574742;
    
    address public nethermind_mainnet = 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5;
    address public nethermind_polygon = 0x31F748a368a893Bdb5aBB67ec95F232507601A73;

    // ...........................................................................

    // https://docs.layerzero.network/v2/developers/evm/technical-reference/messagelibs
    address public send302_mainnet = 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1;
    address public receive302_mainnet = 0xc02Ab410f0734EFa3F14628780e6e695156024C2;
    
    address public send302_polygon = 0x6c26c61a97006888ea9E4FA36584c7df57Cd9dA3;
    address public receive302_polygon = 0x1322871e4ab09Bc7f5717189434f97bBD9546e95;   
}

// ------------------------------------------- EthSend_PolyReceive -------------------------

contract SetDvnEthSend is DvnData {

    function run() public broadcast {

        // ulnConfig struct
        UlnConfig memory ulnConfig; 
            // confirmation on eth 
            ulnConfig.confirmations = 15;      
            
            // optional
            //0 indicate DEFAULT, NIL_DVN_COUNT indicate NONE (to override the value of default)
            ulnConfig.optionalDVNCount; 
            //no duplicates. sorted an an ascending order. allowed overlap with requiredDVNs
            ulnConfig.optionalDVNThreshold; 
            
            //required
            ulnConfig.requiredDVNCount = 4; 
            address[] memory requiredDVNs = new address[](ulnConfig.requiredDVNCount); 
                // no duplicates. sorted an an ascending order.
                requiredDVNs[0] = layerZero_mainnet;
                requiredDVNs[1] = animoca_mainnet;
                requiredDVNs[2] = nethermind_mainnet;
                requiredDVNs[3] = gcp;
                
            ulnConfig.requiredDVNs = requiredDVNs;
        
        // config bytes
        bytes memory configBytes;
        configBytes = abi.encode(ulnConfig);

        // params
        SetConfigParam memory param1 = SetConfigParam({
            eid: remoteChainID,     // dstEid
            configType: 2,
            config: configBytes
        });

        // array of params
        SetConfigParam[] memory configParams = new SetConfigParam[](1);
        configParams[0] = param1;
        
        //call endpoint
        address endPointAddress = homeLzEP;
        address oappAddress = mocaTokenAdapterAddress;

        ILayerZeroEndpointV2(endPointAddress).setConfig(oappAddress, send302_mainnet, configParams);
    }
}

// forge script script/DeployFinalTest.s.sol:SetDvnEthSend --rpc-url mainnet --broadcast -vvvv 

contract SetDvnPolyReceive is DvnData {

    function run() public broadcast {

        // ulnConfig struct
        UlnConfig memory ulnConfig; 
            // confirmation on eth 
            ulnConfig.confirmations = 15;      
            
            // optional
            //0 indicate DEFAULT, NIL_DVN_COUNT indicate NONE (to override the value of default)
            ulnConfig.optionalDVNCount; 
            //no duplicates. sorted an an ascending order. allowed overlap with requiredDVNs
            ulnConfig.optionalDVNThreshold; 
            
            //required
            ulnConfig.requiredDVNCount = 4; 
            address[] memory requiredDVNs = new address[](ulnConfig.requiredDVNCount); 
                // no duplicates. sorted an an ascending order.
                requiredDVNs[0] = layerZero_polygon;
                requiredDVNs[1] = nethermind_polygon;
                requiredDVNs[2] = animoca_polygon;
                requiredDVNs[3] = gcp;
                
            ulnConfig.requiredDVNs = requiredDVNs;
        
        // config bytes
        bytes memory configBytes;
        configBytes = abi.encode(ulnConfig);

        // params
        SetConfigParam memory param1 = SetConfigParam({
            eid: homeChainID,     //note: dstEid
            configType: 2,
            config: configBytes
        });

        // array of params
        SetConfigParam[] memory configParams = new SetConfigParam[](1);
        configParams[0] = param1;
        
        //call endpoint
        address endPointAddress = remoteLzEP;
        address oappAddress = mocaOFTAddress;

        ILayerZeroEndpointV2(endPointAddress).setConfig(oappAddress, receive302_polygon, configParams);
    }
}

// forge script script/DeployFinalTest.s.sol:SetDvnPolyReceive --rpc-url polygon --broadcast -vvvv 

// ------------------------------------------- POlySend_EthReceive -------------------------

contract SetDvnPolySend is DvnData {

    function run() public broadcast {

        // ulnConfig struct
        UlnConfig memory ulnConfig; 
            // confirmation on eth 
            ulnConfig.confirmations = 768;      
            
            // optional
            //0 indicate DEFAULT, NIL_DVN_COUNT indicate NONE (to override the value of default)
            ulnConfig.optionalDVNCount; 
            //no duplicates. sorted an an ascending order. allowed overlap with requiredDVNs
            ulnConfig.optionalDVNThreshold; 
            
            //required
            ulnConfig.requiredDVNCount = 4; 
            address[] memory requiredDVNs = new address[](ulnConfig.requiredDVNCount); 
                // no duplicates. sorted an an ascending order.
                requiredDVNs[0] = layerZero_polygon;
                requiredDVNs[1] = nethermind_polygon;
                requiredDVNs[2] = animoca_polygon;
                requiredDVNs[3] = gcp;
                
            ulnConfig.requiredDVNs = requiredDVNs;
        
        // config bytes
        bytes memory configBytes;
        configBytes = abi.encode(ulnConfig);

        // params
        SetConfigParam memory param1 = SetConfigParam({
            eid: homeChainID,     //note: dstEid
            configType: 2,
            config: configBytes
        });

        // array of params
        SetConfigParam[] memory configParams = new SetConfigParam[](1);
        configParams[0] = param1;
        
        //note: call endpoint
        address endPointAddress = remoteLzEP;
        address oappAddress = mocaOFTAddress;

        ILayerZeroEndpointV2(endPointAddress).setConfig(oappAddress, send302_polygon, configParams);
    }
}

// forge script script/DeployFinalTest.s.sol:SetDvnPolySend --rpc-url polygon --broadcast -vvvv 

contract SetDvnEthReceive is DvnData {

    function run() public broadcast {

        // ulnConfig struct
        UlnConfig memory ulnConfig; 
            // confirmation on eth 
            ulnConfig.confirmations = 768;      
            
            // optional
            //0 indicate DEFAULT, NIL_DVN_COUNT indicate NONE (to override the value of default)
            ulnConfig.optionalDVNCount; 
            //no duplicates. sorted an an ascending order. allowed overlap with requiredDVNs
            ulnConfig.optionalDVNThreshold; 
            
            //required
            ulnConfig.requiredDVNCount = 4; 
            address[] memory requiredDVNs = new address[](ulnConfig.requiredDVNCount); 
                // no duplicates. sorted an an ascending order.
                requiredDVNs[0] = layerZero_mainnet;
                requiredDVNs[1] = animoca_mainnet;
                requiredDVNs[2] = nethermind_mainnet;
                requiredDVNs[3] = gcp;
                
            ulnConfig.requiredDVNs = requiredDVNs;
        
        // config bytes
        bytes memory configBytes;
        configBytes = abi.encode(ulnConfig);

        // params
        SetConfigParam memory param1 = SetConfigParam({
            eid: remoteChainID,     //note: dstEid
            configType: 2,
            config: configBytes
        });

        // array of params
        SetConfigParam[] memory configParams = new SetConfigParam[](1);
        configParams[0] = param1;
        
        //note: call endpoint
        address endPointAddress = homeLzEP;
        address oappAddress = mocaTokenAdapterAddress;

        ILayerZeroEndpointV2(endPointAddress).setConfig(oappAddress, receive302_mainnet, configParams);
    }
}

// forge script script/DeployFinalTest.s.sol:SetDvnEthReceive --rpc-url mainnet --broadcast -vvvv 


// ------------------------------------------- Whitelisting Treasury  -----------------------------------------

contract whitelistTreasuryOnHome is DvnData {

    function run() public broadcast {
        
        mocaTokenAdapter.setWhitelist(treasuryMultiSig, true);
    }
}

// ------------------------------------------- Set Owner as delegate -----------------------------------------

contract SetOwnerAsDelegateHome is DvnData {

    function run() public broadcast {    
        mocaTokenAdapter.setDelegate(ownerMultiSig);
    }
}

// 

contract SetOwnerAsDelegateRemote is DvnData {

    function run() public broadcast {
        
        mocaOFT.setDelegate(ownerMultiSig);
    }
}

//

// ------------------------------------------- Transfer Ownership to multisig -----------------------------------------

contract TransferOwnershipHome is DvnData {

    function run() public broadcast {
        
        mocaTokenAdapter.transferOwnership(ownerMultiSig);
    }
}

// 

contract TransferOwnershipRemote is DvnData {

    function run() public broadcast {
        
        mocaOFT.transferOwnership(ownerMultiSig);
    }
}

//



// =================================== END =============================

contract acceptOwnerHome is DvnData {
    function run() public broadcast {
        mocaTokenAdapter.acceptOwnership();
    }
}

// forge script script/DeployFinalTest.s.sol:acceptOwnerHome --rpc-url mainnet --broadcast -vvvv 

contract acceptOwnerRemote is DvnData {
    function run() public broadcast {
        mocaOFT.acceptOwnership();
    }
}

// forge script script/DeployFinalTest.s.sol:acceptOwnerRemote --rpc-url polygon --broadcast -vvvv 


// ------------------------------------------- Send sum tokens  -------------------------
import "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { MessagingParams, MessagingFee, MessagingReceipt } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract SendTokensToAway is DvnData {

    function run() public broadcast {

        //set approval for adaptor to spend tokens
        mocaToken.approve(mocaTokenAdapterAddress, 10 ether);
        
        bytes memory nullBytes = new bytes(0);
        SendParam memory sendParam = SendParam({
            dstEid: remoteChainID,
            to: bytes32(uint256(uint160(address(deployer)))),
            amountLD: 1 ether,
            minAmountLD: 1 ether,
            extraOptions: nullBytes,
            composeMsg: nullBytes,
            oftCmd: nullBytes
        });

        // Fetching the native fee for the token send operation
        MessagingFee memory messagingFee = mocaTokenAdapter.quoteSend(sendParam, false);

        // send tokens xchain
        mocaTokenAdapter.send{value: messagingFee.nativeFee}(sendParam, messagingFee, payable(deployer));
    }
}

//  forge script script/DeployFinalTest.s.sol:SendTokensToAway --rpc-url mainnet --broadcast -vvvv


contract SendTokensToRemotePlusGas is DvnData {

    function run() public broadcast {
        
        // createLzNativeDropOption
        // gas: 6000000000000000 (amount of native gas to drop in wei)
        // receiver: 0x000000000000000000000000de05a1abb121113a33eed248bd91ddc254d5e9db (address in bytes32)
        bytes memory extraOptions = hex"0003010031020000000000000002aa57403d13f2917b0000000000000000000000008c9c001f821c04513616fd7962b2d8c62f925fd2";

        bytes memory nullBytes = new bytes(0);
        SendParam memory sendParam = SendParam({
            dstEid: remoteChainID,                                                                  // Destination endpoint ID.
            to: bytes32(uint256(uint160(address(deployer)))),     // Recipient address.
            amountLD: 1 ether,                                                                      // Amount to send in local decimals        
            minAmountLD: 1 ether,                                                                   // Minimum amount to send in local decimals.
            extraOptions: extraOptions,                                                             // Additional options supplied by the caller to be used in the LayerZero message.
            composeMsg: nullBytes,                                                               // The composed message for the send() operation.
            oftCmd: nullBytes                                                                    // The OFT command to be executed, unused in default OFT implementations.
        });

        // Fetching the native fee for the token send operation
        MessagingFee memory messagingFee = mocaTokenAdapter.quoteSend(sendParam, false);

        // send tokens xchain
        mocaTokenAdapter.send{value: messagingFee.nativeFee}(sendParam, messagingFee, payable(deployer));

    }
}

//  forge script script/DeployFinalTest.s.sol:SendTokensToRemotePlusGas --rpc-url mainnet --broadcast -vvvv


contract SendTokensToHome is DvnData {

    function run() public broadcast {
        
        bytes memory nullBytes = new bytes(0);
        SendParam memory sendParam = SendParam({
            dstEid: homeChainID,                                                                 // Destination endpoint ID.
            to: bytes32(uint256(uint160(address(deployer)))),  // Recipient address.
            amountLD: 1 ether,                                                                   // Amount to send in local decimals        
            minAmountLD: 1 ether,                                                                // Minimum amount to send in local decimals.
            extraOptions: nullBytes,                                                             // Additional options supplied by the caller to be used in the LayerZero message.
            composeMsg: nullBytes,                                                               // The composed message for the send() operation.
            oftCmd: nullBytes                                                                    // The OFT command to be executed, unused in default OFT implementations.
        });

        // Fetching the native fee for the token send operation
        MessagingFee memory messagingFee = mocaOFT.quoteSend(sendParam, false);
        //MessagingFee memory messagingFee = mocaTokenAdapter.quoteOFT(sendParam);

        // send tokens xchain
        mocaOFT.send{value: messagingFee.nativeFee}(sendParam, messagingFee, payable(deployer));
    }
}

//  forge script script/DeployFinalTest.s.sol:SendTokensToHome --rpc-url polygon --broadcast -vvvv


contract ResetPeers is DvnData {

    function run() public broadcast {
        mocaTokenAdapter.resetPeer(remoteChainID);
    }
}
         
//  forge script script/DeployFinalTest.s.sol:ResetPeers --rpc-url mainnet --broadcast -vvvv


contract Send is DvnData {


    function run() public broadcast {
        // Call returns a boolean value indicating success or failure.
        // This is the current recommended method to use.

        address _to = 0x81C2C46de0F533697C5AdFbf4a4C5746947109C9 ;

        (bool sent, bytes memory data) = _to.call{value: 0.05 ether}("");
        require(sent, "Failed to send Ether");
    }
    
}

//  forge script script/DeployFinalTest.s.sol:Send --rpc-url mainnet --broadcast -vvvv


contract SetOperatorHome is DvnData {

    function run() public broadcast {
        mocaTokenAdapter.setOperator(0xB740c4E1C89D05AE6C95777F89cBecD5555A3484, true);
    }
}

// forge script script/DeployFinalTest.s.sol:SetOperatorHome --rpc-url mainnet --broadcast -vvvv 


contract SetOperatorRemote is DvnData {

    function run() public broadcast {
        mocaOFT.setOperator(0x81C2C46de0F533697C5AdFbf4a4C5746947109C9 , true);
    }
}

// forge script script/DeployFinalTest.s.sol:SetOperatorRemote --rpc-url polygon --broadcast -vvvv 