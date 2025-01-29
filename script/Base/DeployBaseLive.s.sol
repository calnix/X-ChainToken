// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MocaToken} from "./../../src/MocaToken.sol";
import {MocaOFT} from "./../../src/MocaOFT.sol";
import {MocaTokenAdapter} from "./../../src/MocaTokenAdapter.sol";

import {LZMainnets} from "../LZEndpoints.sol";

import "forge-std/Script.sol";


/** Note:
    ---------
    We are deploying the OFT on base.
    And updating the TokenAdaptor on eth; which was previously deployed.

    Deploy OFT on base
    1. check TokenAdaptor on eth [ownership, state]
        mocaTokenAdapterAddress: 0x2B11834Ed1FeAEd4b4b3a86A6F571315E25A884D
        contract onwer: 0x84Db3d1de9a43Aa144C21b248AD31a1c83d8334D 
        LZ delegate: 0x84Db3d1de9a43Aa144C21b248AD31a1c83d8334D
        operator: no operators have been set

        ** only set peers and enforced options called for polygonOFT **

    2. deploy OFT on base[owner/delegate: deployer]
    3. setPeers 
    4. setEnforcedOptions
    5. whitelist DAT address on both home and remote chain
    6. set custom dvn config
    7. set owner as delegate [handover delegate role from deployer to owner multi-sig]
    8. transfer ownership to owner multi-sig [tokenAdaptor on home, OFT on remote]
    9. ensure that DAT has accepted ownership [tokenAdaptor on home, OFT on remote]

 */

abstract contract LZState is LZMainnets {

    // token data
    string public name = "Moca";
    string public symbol = "MOCA";

    // treasury
    address public DAT_ADDRESS = address(0); // note: fill-in 
    address public OWNER_MULTISIG = address(0); // note: fill-in

    function setUp() public {

        homeChainID = ethID;
        homeLzEP = ethEP;
        
        remoteChainID = baseID;
        remoteLzEP = baseEP;

        DEPLOYER_ADDRESS = vm.envAddress("PUBLIC_KEY_ACTUAL");
        console2.log("deployerAddress", DEPLOYER_ADDRESS);
    }
}

/* not needed 
contract DeployHome is LZState {
    function run() public {
    }
}*/

// Remote
contract DeployElsewhere is LZState {

    function run() public broadcast("PRIVATE_KEY_ACTUAL") {
        
        console2.log("deployerAddress", DEPLOYER_ADDRESS);

        // params
        address delegate = DEPLOYER_ADDRESS;
        address owner = DEPLOYER_ADDRESS;

        MocaOFT remoteOFT = new MocaOFT(name, symbol, remoteLzEP, delegate, owner);
    }
}

// forge script script/Base/DeployBaseLive.s.sol:DeployElsewhere --rpc-url base --broadcast --verify -vvvv --etherscan-api-key base

//------------------------------ SETUP ------------------------------------

abstract contract State is LZState {
    
    // home
    address public mocaTokenAddress = address(0xF944e35f95E819E752f3cCB5Faf40957d311e8c5);    
    address public mocaTokenAdapterAddress = address(0x2B11834Ed1FeAEd4b4b3a86A6F571315E25A884D);                     

    // remote
    address public mocaOFTAddress = address(0); // note: fill-in after deployment

    // set contracts
    MocaToken public mocaToken = MocaToken(mocaTokenAddress);
    MocaTokenAdapter public mocaTokenAdapter = MocaTokenAdapter(mocaTokenAdapterAddress);

    MocaOFT public mocaOFT = MocaOFT(mocaOFTAddress);
}

// ------------------------------------------- Trusted Remotes: connect contracts -------------------------
contract SetRemoteOnHome is State {

    function run() public broadcast("PRIVATE_KEY_ACTUAL")  {
        // eid: The endpoint ID for the destination chain the other OFT contract lives on
        // peer: The destination OFT contract address in bytes32 format
        bytes32 peer = bytes32(uint256(uint160(address(mocaOFTAddress))));
        mocaTokenAdapter.setPeer(remoteChainID, peer);
    }
}

// forge script script/Base/DeployBaseLive.s.sol:SetRemoteOnHome --rpc-url mainnet --broadcast -vvvv 

contract SetRemoteOnAway is State {

    function run() public broadcast("PRIVATE_KEY_ACTUAL")  {
        // eid: The endpoint ID for the destination chain the other OFT contract lives on
        // peer: The destination OFT contract address in bytes32 format
        bytes32 peer = bytes32(uint256(uint160(address(mocaTokenAdapter))));
        mocaOFT.setPeer(homeChainID, peer);
        
    }
}

// forge script script/Base/DeployBaseLive.s.sol:SetRemoteOnAway --rpc-url base --broadcast -vvvv 


// ------------------------------------------- Gas Limits -------------------------

import { IOAppOptionsType3, EnforcedOptionParam } from "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppOptionsType3.sol";

contract SetGasLimitsHome is State {

    function run() public broadcast("PRIVATE_KEY_ACTUAL") {
        
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

// forge script script/Base/DeployBaseLive.s.sol:SetGasLimitsHome --rpc-url mainnet --broadcast -vvvv 


contract SetGasLimitsAway is State {

    function run() public broadcast("PRIVATE_KEY_ACTUAL") {
        
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

// forge script script/Base/DeployBaseLive.s.sol:SetGasLimitsAway --rpc-url base --broadcast -vvvv 

// ------------------------------------------- Whitelist DAT -----------------------------------------

contract WhitelistDATOnHome is State {

    function run() public broadcast("PRIVATE_KEY_ACTUAL") {
        mocaTokenAdapter.setWhitelist(DEPLOYER_ADDRESS, true);
        mocaTokenAdapter.setWhitelist(DAT_ADDRESS, true);
    }
}

// forge script script/Base/DeployBaseLive.s.sol:WhitelistDATOnHome --rpc-url mainnet --broadcast -vvvv 

contract WhitelistDATOnRemote is State {

    function run() public broadcast("PRIVATE_KEY_ACTUAL") {
        mocaOFT.setWhitelist(DEPLOYER_ADDRESS, true);
        mocaOFT.setWhitelist(DAT_ADDRESS, true);
    }
}

// forge script script/Base/DeployBaseLive.s.sol:WhitelistDATOnRemote --rpc-url base --broadcast -vvvv 


// ------------------------------------------- DVN Config  -----------------------------------------
    import { SetConfigParam } from "node_modules/@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
    import { UlnConfig } from "node_modules/@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
    import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

    abstract contract DvnData is State {
        // https://docs.layerzero.network/v2/developers/evm/technical-reference/dvn-addresses?chains=base%2Cethereum&dvns=BitGo%2CGoogle+Cloud%2CNethermind%2CLayerZero+Labs
        
        address public layerZero_mainnet = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b;
        address public layerZero_base = 0x9e059a54699a285714207b43B055483E78FAac25;
        
        // same address for both mainnet and polygon
        address public gcp = 0xD56e4eAb23cb81f43168F9F45211Eb027b9aC7cc;
        
        // note: cannot use animocadvn; since it does not support base
        // note: bitgo has 2 pairs of DVNS; we just randomly pick one set of them
        address public bitgo_mainnet = 0x133e9fB2D339D8428476A714B1113B024343811E;
        address public bitgo_base = 0x05D78174b97cf2EC223eE578CD1f401FF792ca31;
        
        address public nethermind_mainnet = 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5;
        address public nethermind_base = 0xcd37CA043f8479064e10635020c65FfC005d36f6;

        // ...........................................................................

        // https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts?stages=mainnet&chains=base%2Cethereum
        address public send302_mainnet = 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1;
        address public receive302_mainnet = 0xc02Ab410f0734EFa3F14628780e6e695156024C2;
        
        address public send302_base = 0xB5320B0B3a13cC860893E2Bd79FCd7e13484Dda2;
        address public receive302_base = 0xc70AB6f32772f59fBfc23889Caf4Ba3376C84bAf;   
    }

// ---------------------------------- Set Send and Receive Libraries: Eth ----------------------------------

    contract SetSendLibraryHome is DvnData {
        
        function run() public broadcast("PRIVATE_KEY_ACTUAL") {
            // Initialize the endpoint contract
            ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(homeLzEP);

            // Set the send library
            endpoint.setSendLibrary(mocaTokenAdapterAddress, homeChainID, send302_mainnet);
            console.log("Send library set successfully.");

            // Set the receive library
            uint256 gracePeriod = 0;    // 0 means no grace period 
            endpoint.setReceiveLibrary(mocaTokenAdapterAddress, homeChainID, receive302_mainnet, gracePeriod);
            console.log("Receive library set successfully.");
        }
    }

    // forge script script/Base/DeployBaseLive.s.sol:SetSendLibraryHome --rpc-url mainnet --broadcast -vvvv 

// ---------------------------------- Set Send and Receive Libraries: Base ----------------------------------

    contract SetSendLibraryRemote is DvnData {
        
        function run() public broadcast("PRIVATE_KEY_ACTUAL") {
            // Initialize the endpoint contract
            ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(remoteLzEP);

            // Set the send library
            endpoint.setSendLibrary(mocaOFTAddress, remoteChainID, send302_base);
            console.log("Send library set successfully.");

            // Set the receive library
            uint256 gracePeriod = 0;    // 0 means no grace period 
            endpoint.setReceiveLibrary(mocaOFTAddress, remoteChainID, receive302_base, gracePeriod);
            console.log("Receive library set successfully.");
        }
    }

    // forge script script/Base/DeployBaseLive.s.sol:SetSendLibraryRemote --rpc-url base --broadcast -vvvv 

    // ------------------------------------------- EthSend_BaseReceive -------------------------

    contract SetDvnEthSend is DvnData {

        function run() public broadcast("PRIVATE_KEY_ACTUAL") {

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
                    requiredDVNs[0] = bitgo_mainnet;
                    requiredDVNs[1] = layerZero_mainnet;
                    requiredDVNs[2] = nethermind_mainnet;
                    requiredDVNs[3] = gcp;
                    
                ulnConfig.requiredDVNs = requiredDVNs;
            
            // config bytes
            bytes memory configBytes;
            configBytes = abi.encode(ulnConfig);

            // params
            SetConfigParam memory param1 = SetConfigParam({
                eid: remoteChainID,     // dstEid
                configType: 2,          // Security Stack and block confirmation config
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

    // forge script script/DeployBaseLive.s.sol:SetDvnEthSend --rpc-url mainnet --broadcast -vvvv 

    
    contract SetDvnBaseReceive is DvnData {

        function run() public broadcast("PRIVATE_KEY_ACTUAL") {

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
                    requiredDVNs[0] = bitgo_base;
                    requiredDVNs[1] = layerZero_base;
                    requiredDVNs[2] = nethermind_base;
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

            ILayerZeroEndpointV2(endPointAddress).setConfig(oappAddress, receive302_base, configParams);
        }
    }
    

    // forge script script/DeployBaseLive.s.sol:SetDvnBaseReceive --rpc-url base --broadcast -vvvv 


    // ------------------------------------------- BaseSend_EthReceive -------------------------

    /**
        L2 (Base) => L1 (ETH) finality:
        it’s not deterministic since we don’t know when the blob data will be included in L1 block. 
        finalization time: 5-10 minutes + ETH 
            Base block time: 2 seconds
            10mis in blocks: (10*60) / 2 = 300 blocks
        finalization blocks = 300 + ETH finalization blocks
                            = 315 blocks
     */

    contract SetDvnBaseSend is DvnData {

        function run() public broadcast("PRIVATE_KEY_ACTUAL") {

            // ulnConfig struct
            UlnConfig memory ulnConfig; 
                // confirmation on eth 
                ulnConfig.confirmations = 315;      
                
                // optional
                //0 indicate DEFAULT, NIL_DVN_COUNT indicate NONE (to override the value of default)
                ulnConfig.optionalDVNCount; 
                //no duplicates. sorted an an ascending order. allowed overlap with requiredDVNs
                ulnConfig.optionalDVNThreshold; 
                
                //required
                ulnConfig.requiredDVNCount = 4; 
                address[] memory requiredDVNs = new address[](ulnConfig.requiredDVNCount); 
                    // no duplicates. sorted an an ascending order.
                    requiredDVNs[0] = bitgo_base;
                    requiredDVNs[1] = layerZero_base;
                    requiredDVNs[2] = nethermind_base;
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

            ILayerZeroEndpointV2(endPointAddress).setConfig(oappAddress, send302_base, configParams);
        }
    }
    

    // forge script script/DeployFinal.s.sol:SetDvnPolySend --rpc-url polygon --broadcast -vvvv 

    
    contract SetDvnEthReceive is DvnData {

        function run() public broadcast("PRIVATE_KEY_ACTUAL") {

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
                    requiredDVNs[0] = bitgo_mainnet;
                    requiredDVNs[1] = layerZero_mainnet;
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
    

    // forge script script/DeployFinal.s.sol:SetDvnEthReceive --rpc-url mainnet --broadcast -vvvv 


// ------------------------------------------- Test: whitelisted address can send and receive -----------------------------------------

import "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { MessagingParams, MessagingFee, MessagingReceipt } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";


contract SendTokensToAway is State {

    function run() public broadcast("PRIVATE_KEY_ACTUAL") {

        // set approval for adaptor to spend tokens
        mocaToken.approve(mocaTokenAdapterAddress, 10 ether);
        
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

// forge script script/Base/DeployBaseLive.s.sol:SendTokensToAway --rpc-url mainnet --broadcast -vvvv 


contract SendTokensToHome is State {

    function run() public broadcast("PRIVATE_KEY_ACTUAL") {
        
        bytes memory nullBytes = new bytes(0);
        SendParam memory sendParam = SendParam({
            dstEid: homeChainID,                                                                 // Destination endpoint ID.
            to: bytes32(uint256(uint160(address(DEPLOYER_ADDRESS)))),  // Recipient address.
            amountLD: 1 ether,                                                                   // Amount to send in local decimals        
            minAmountLD: 1 ether,                                                                // Minimum amount to send in local decimals.
            extraOptions: nullBytes,                                                             // Additional options supplied by the caller to be used in the LayerZero message.
            composeMsg: nullBytes,                                                               // The composed message for the send() operation.
            oftCmd: nullBytes                                                                    // The OFT command to be executed, unused in default OFT implementations.
        });

        // Fetching the native fee for the token send operation
        MessagingFee memory messagingFee = mocaOFT.quoteSend(sendParam, false);

        // send tokens xchain
        mocaOFT.send{value: messagingFee.nativeFee}(sendParam, messagingFee, payable(DEPLOYER_ADDRESS));
    }
}

//  forge script script/Base/DeployBaseLive.s.sol:SendTokensToHome --rpc-url base --broadcast -vvvv

// ------------------------------------------- Test: NON-whitelisted address cannot send -----------------------------------------
    /**
        remove deployer from whitelist
        test sending tokens to remote, via deployer address
    */

contract RemoveDeployerFromWhitelistOnHome is State {

    function run() public broadcast("PRIVATE_KEY_ACTUAL") {
        mocaTokenAdapter.setWhitelist(DEPLOYER_ADDRESS, false);
    }
}

// forge script script/Base/DeployBaseLive.s.sol:RemoveDeployerFromWhitelistOnHome --rpc-url mainnet --broadcast -vvvv

contract RemoveDeployerFromWhitelistOnRemote is State {

    function run() public broadcast("PRIVATE_KEY_ACTUAL") {
        mocaOFT.setWhitelist(DEPLOYER_ADDRESS, false);
    }
}

// forge script script/Base/DeployBaseLive.s.sol:RemoveDeployerFromWhitelistOnRemote --rpc-url base --broadcast -vvvv

contract SendTokensToRemoteNonWhitelisted is State {

    function run() public broadcast("PRIVATE_KEY_ACTUAL") {

        // set approval for adaptor to spend tokens
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

// note: this should revert
// forge script script/Base/DeployBaseLive.s.sol:SendTokensToRemoteNonWhitelisted --rpc-url mainnet --broadcast -vvvv 

/** 
    now that everything is set up, and checks out, we can hand-over delegate to the owner multisig
    if we need to modify DVN config, or setup a new chain connection, we will need the role to be set back to the deployer
 */

// ------------------------------------------- Set Owner as delegate -----------------------------------------

contract SetOwnerAsDelegateHome is State {

    function run() public broadcast("PRIVATE_KEY_ACTUAL") {    
        mocaTokenAdapter.setDelegate(OWNER_MULTISIG);
    }
}

// forge script script/Base/DeployBaseLive.s.sol:SetOwnerAsDelegateHome --rpc-url mainnet --broadcast -vvvv 

contract SetOwnerAsDelegateRemote is State {

    function run() public broadcast("PRIVATE_KEY_ACTUAL") {
        mocaOFT.setDelegate(OWNER_MULTISIG);
    }
}

// forge script script/Base/DeployBaseLive.s.sol:SetOwnerAsDelegateRemote --rpc-url base --broadcast -vvvv 

/** 
    Assuming all is well, we can now transfer ownership to the owner multisig. 
    In the future, we will need the owner role to be set back to the deployer; for:
        - setOperators
        - setRateLimits 
*/

// ------------------------------------------- Transfer Ownership to multisig -----------------------------------------

contract TransferOwnershipHome is State {

    function run() public broadcast("PRIVATE_KEY_ACTUAL") {
        mocaTokenAdapter.transferOwnership(OWNER_MULTISIG);
    }
}

// forge script script/Base/DeployBaseLive.s.sol:TransferOwnershipHome --rpc-url mainnet --broadcast -vvvv 

contract TransferOwnershipRemote is State {

    function run() public broadcast("PRIVATE_KEY_ACTUAL") {
        mocaOFT.transferOwnership(OWNER_MULTISIG);
    }
}

// forge script script/Base/DeployBaseLive.s.sol:TransferOwnershipRemote --rpc-url base --broadcast -vvvv 

/** 
    Note: Check that DAT team has accepted ownership for both contracts: TokenAdapter and OFT.
*/


// ==================================================================================================================
// ------------------------------------------- NOTE: To be done -------------------------------------------------- 

// 1. setRateLimitsHome
// 2. setRateLimitsAway
// 3. setOperators: AwsScript, TenderlyScript

// ==================================================================================================================
