// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MocaToken} from "./../../src/MocaToken.sol";
import {MocaOFT} from "./../../src/MocaOFT.sol";
import {MocaTokenAdapter} from "./../../src/MocaTokenAdapter.sol";

import {LZMainnets} from "../LZEndpoints.sol";

import "forge-std/Script.sol";

abstract contract LZState is LZMainnets {

    // token data
    string public name = "Moca";
    string public symbol = "MOCA";

    function setUp() public {

        homeChainID = ethID;
        homeLzEP = ethEP;
        
        remoteChainID = baseID;
        remoteLzEP = baseEP;
    }
}

/**Note:
    Ordering reminder
    --------------------------------
    - setConfig(_oapp, _lib, _params) writes config under (oapp, lib, eid) — the lib address you pass, NOT the OApp's currently-active lib.

    - At send/receive time the OApp reads its *active* lib (set via setSendLibrary /setReceiveLibrary), and that lib reads its own config.
      Therefore, config and active lib must point at the same address.

    - You explicitly pass send302_mainnet to both SetLibraries… and SetDvn…, so order is functionally safe. 

    - But if LZ rotates the default to a new ULN before you call SetLibraries…, your OApp would route through that new default's (unconfigured) settings.

    - Safer rule: always SetLibraries… → SetDvn… → Check….
    --------------------------------
 */
abstract contract State is LZState {
    
    // home
    address public mocaTokenAddress = address(0xF944e35f95E819E752f3cCB5Faf40957d311e8c5);    
    address public mocaTokenAdapterAddress = address(0x2B11834Ed1FeAEd4b4b3a86A6F571315E25A884D);                     

    // remote
    address public mocaOFTAddress = address(0x2B11834Ed1FeAEd4b4b3a86A6F571315E25A884D); 

    // set contracts
    MocaToken public mocaToken = MocaToken(mocaTokenAddress);
    MocaTokenAdapter public mocaTokenAdapter = MocaTokenAdapter(mocaTokenAdapterAddress);

    MocaOFT public mocaOFT = MocaOFT(mocaOFTAddress);
}


// ------------------------------------------- DVN Config  -----------------------------------------
    import { SetConfigParam } from "node_modules/@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
    import { UlnConfig } from "node_modules/@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
    import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

    abstract contract DvnData is State {
        // https://docs.layerzero.network/v2/developers/evm/technical-reference/dvn-addresses?chains=base%2Cethereum&dvns=BitGo%2CGoogle+Cloud%2CNethermind%2CLayerZero+Labs
        
        // note we replace lz w/ canary
        //address public layerZero_mainnet = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b;
        //address public layerZero_base = 0x9e059a54699a285714207b43B055483E78FAac25;

        address public canary_mainnet = 0xa4fE5A5B9A846458a70Cd0748228aED3bF65c2cd;
        address public canary_base = 0x554833698Ae0FB22ECC90B01222903fD62CA4B47;
        
        // same address for both mainnet and base
        address public gcp = 0xD56e4eAb23cb81f43168F9F45211Eb027b9aC7cc;
        
        address public bitgo_mainnet = 0xc9ca319f6Da263910fd9B037eC3d817A814ef3d8;
        address public bitgo_base = 0x133e9fB2D339D8428476A714B1113B024343811E;
        
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

    contract SetLibrariesOnEthToBase is DvnData {
        
        function run() public broadcast("PRIVATE_KEY_ACTUAL") {
            // Initialize the endpoint contract
            ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(homeLzEP);

            // Set the send library
            endpoint.setSendLibrary(mocaTokenAdapterAddress, baseID, send302_mainnet);
            console.log("Send library set successfully.");

            // Set the receive library
            uint256 gracePeriod = 0;    // 0 means no grace period 
            endpoint.setReceiveLibrary(mocaTokenAdapterAddress, baseID, receive302_mainnet, gracePeriod);
            console.log("Receive library set successfully.");
        }
    }

    // forge script script/Base/UpdateEthBaseDvn.s.sol:SetLibrariesOnEthToBase --rpc-url mainnet --broadcast -vvvv 

// ---------------------------------- Set Send and Receive Libraries: Base ----------------------------------

    contract SetLibrariesOnBaseToEth is DvnData {
        
        function run() public broadcast("PRIVATE_KEY_ACTUAL") {
            // Initialize the endpoint contract
            ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(remoteLzEP);

            // Set the send library
            endpoint.setSendLibrary(mocaOFTAddress, ethID, send302_base);
            console.log("Send library set successfully.");

            // Set the receive library
            uint256 gracePeriod = 0;    // 0 means no grace period 
            endpoint.setReceiveLibrary(mocaOFTAddress, ethID, receive302_base, gracePeriod);
            console.log("Receive library set successfully.");
        }
    }

    // forge script script/Base/UpdateEthBaseDvn.s.sol:SetLibrariesOnBaseToEth --rpc-url base --broadcast -vvvv 

// ------------------------------------------- EthSend_BaseReceive -------------------------

    contract SetDvnEthSend is DvnData {

        function run() public broadcast("PRIVATE_KEY_ACTUAL") {

            // ulnConfig struct
            UlnConfig memory ulnConfig; 
                // confirmation on eth (txn origin chain)
                ulnConfig.confirmations = 15;      
                
                // optional
                //0 indicate DEFAULT, NIL_DVN_COUNT indicate NONE (to override the value of default)
                ulnConfig.optionalDVNCount = 255;   // 255 is NIL_DVN_COUNT: no optional DVNs
                //no duplicates. sorted an an ascending order. allowed overlap with requiredDVNs
                ulnConfig.optionalDVNThreshold; 
                
                //required
                ulnConfig.requiredDVNCount = 4; 
                address[] memory requiredDVNs = new address[](ulnConfig.requiredDVNCount); 
                    // no duplicates. sorted an an ascending order.
                    requiredDVNs[0] = canary_mainnet;
                    requiredDVNs[1] = nethermind_mainnet;
                    requiredDVNs[2] = bitgo_mainnet;
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

    // forge script script/Base/UpdateEthBaseDvn.s.sol:SetDvnEthSend --rpc-url mainnet --broadcast -vvvv 

    
    contract SetDvnBaseReceive is DvnData {

        function run() public broadcast("PRIVATE_KEY_ACTUAL") {

            // ulnConfig struct
            UlnConfig memory ulnConfig; 
                // confirmation on eth (txn origin chain)
                ulnConfig.confirmations = 15;      
                
                // optional
                //0 indicate DEFAULT, NIL_DVN_COUNT indicate NONE (to override the value of default)
                ulnConfig.optionalDVNCount = 255;   // 255 is NIL_DVN_COUNT: no optional DVNs
                //no duplicates. sorted an an ascending order. allowed overlap with requiredDVNs
                ulnConfig.optionalDVNThreshold; 
                
                //required
                ulnConfig.requiredDVNCount = 4; 
                address[] memory requiredDVNs = new address[](ulnConfig.requiredDVNCount); 
                    // no duplicates. sorted an an ascending order.
                    requiredDVNs[0] = bitgo_base;
                    requiredDVNs[1] = canary_base;
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
    

    // forge script script/Base/UpdateEthBaseDvn.s.sol:SetDvnBaseReceive --rpc-url base --broadcast -vvvv 


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
                // confirmation on base 
                ulnConfig.confirmations = 315;      
                
                // optional
                //0 indicate DEFAULT, NIL_DVN_COUNT indicate NONE (to override the value of default)
                ulnConfig.optionalDVNCount = 255;   // 255 is NIL_DVN_COUNT: no optional DVNs
                //no duplicates. sorted an an ascending order. allowed overlap with requiredDVNs
                ulnConfig.optionalDVNThreshold; 
                
                //required
                ulnConfig.requiredDVNCount = 4; 
                address[] memory requiredDVNs = new address[](ulnConfig.requiredDVNCount); 
                    // no duplicates. sorted an an ascending order.
                    requiredDVNs[0] = bitgo_base;
                    requiredDVNs[1] = canary_base;
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
    

    // forge script script/Base/UpdateEthBaseDvn.s.sol:SetDvnBaseSend --rpc-url base --broadcast -vvvv 

    
    contract SetDvnEthReceive is DvnData {

        function run() public broadcast("PRIVATE_KEY_ACTUAL") {

            // ulnConfig struct
            UlnConfig memory ulnConfig; 
                // confirmation on base 
                ulnConfig.confirmations = 315;      
                
                // optional
                //0 indicate DEFAULT, NIL_DVN_COUNT indicate NONE (to override the value of default)
                ulnConfig.optionalDVNCount = 255;   // 255 is NIL_DVN_COUNT: no optional DVNs
                //no duplicates. sorted an an ascending order. allowed overlap with requiredDVNs
                ulnConfig.optionalDVNThreshold; 
                
                //required
                ulnConfig.requiredDVNCount = 4; 
                address[] memory requiredDVNs = new address[](ulnConfig.requiredDVNCount); 
                    // no duplicates. sorted an an ascending order.
                    requiredDVNs[0] = canary_mainnet;
                    requiredDVNs[1] = nethermind_mainnet;
                    requiredDVNs[2] = bitgo_mainnet;
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
    

    // forge script script/Base/UpdateEthBaseDvn.s.sol:SetDvnEthReceive --rpc-url mainnet --broadcast -vvvv 

// ---------------------------------- Check Send/Receive Libraries: Eth ----------------------------------
   
   contract CheckLibrariesOnEthToBase is DvnData {

        function run() public view {

            ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(homeLzEP);
            console.log("--- ETH -> BASE | oapp:", mocaTokenAdapterAddress);

            // Send library: peer EID = Base
            address sendLib       = endpoint.getSendLibrary(mocaTokenAdapterAddress, baseID);
            bool    isDefaultSend = endpoint.isDefaultSendLibrary(mocaTokenAdapterAddress, baseID);
            console.log("send lib (actual)  ", sendLib);
            console.log("send lib (expected)", send302_mainnet);
            console.log("isDefaultSend      ", isDefaultSend);
            require(sendLib == send302_mainnet, "send lib mismatch");
            require(!isDefaultSend, "send lib still default");
            console.log("--------------------------------");

            // Receive library: peer EID = Base
            (address recvLib, bool isDefaultRecv) = endpoint.getReceiveLibrary(mocaTokenAdapterAddress, baseID);
            console.log("recv lib (actual)  ", recvLib);
            console.log("recv lib (expected)", receive302_mainnet);
            console.log("isDefaultRecv      ", isDefaultRecv);
            require(recvLib == receive302_mainnet, "recv lib mismatch");
            require(!isDefaultRecv, "recv lib still default");
            console.log("--------------------------------");
            
        }
    }

    // forge script script/Base/UpdateEthBaseDvn.s.sol:CheckLibrariesOnEthToBase --rpc-url mainnet -vvvv

// ---------------------------------- Check Send/Receive Libraries: Base ----------------------------------
    
    contract CheckLibrariesOnBaseToEth is DvnData {

        function run() public view {
            ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(remoteLzEP);
            console.log("--- BASE -> ETH | oapp:", mocaOFTAddress);

            // Send library: peer EID = Eth
            address sendLib       = endpoint.getSendLibrary(mocaOFTAddress, ethID);
            bool    isDefaultSend = endpoint.isDefaultSendLibrary(mocaOFTAddress, ethID);
            console.log("send lib (actual)  ", sendLib);
            console.log("send lib (expected)", send302_base);
            console.log("isDefaultSend      ", isDefaultSend);
            require(sendLib == send302_base, "send lib mismatch");
            require(!isDefaultSend, "send lib still default");
            console.log("--------------------------------");

            // Receive library: peer EID = Eth
            (address recvLib, bool isDefaultRecv) = endpoint.getReceiveLibrary(mocaOFTAddress, ethID);
            console.log("recv lib (actual)  ", recvLib);
            console.log("recv lib (expected)", receive302_base);
            console.log("isDefaultRecv      ", isDefaultRecv);
            require(recvLib == receive302_base, "recv lib mismatch");
            require(!isDefaultRecv, "recv lib still default");
            console.log("--------------------------------");
        }
    }

    // forge script script/Base/UpdateEthBaseDvn.s.sol:CheckLibrariesOnBaseToEth --rpc-url base -vvvv



// ------------------------------------------- Send sum tokens  -------------------------

// SendParam
import "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { MessagingParams, MessagingFee, MessagingReceipt } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract SendTokensFromBaseToEth is State {

    function run() public broadcast("PRIVATE_KEY_ACTUAL")  {

        bytes memory nullBytes = new bytes(0);
        SendParam memory sendParam = SendParam({
            dstEid: ethID,
            to: bytes32(uint256(uint160(address(0x84Db3d1de9a43Aa144C21b248AD31a1c83d8334D)))),
            amountLD: 1 ether,
            minAmountLD: 1 ether,
            extraOptions: nullBytes,
            composeMsg: nullBytes,
            oftCmd: nullBytes
        });

        // Fetching the native fee for the token send operation
        MessagingFee memory messagingFee = mocaOFT.quoteSend(sendParam, false);

        // send tokens xchain
        mocaOFT.send{value: messagingFee.nativeFee}(sendParam, messagingFee, payable(DEPLOYER_ADDRESS));
    }
}

//  forge script script/Base/UpdateEthBaseDvn.s.sol:SendTokensFromBaseToEth --rpc-url base --broadcast -vvvv


contract SendTokensFromEthToBase is State {

    function run() public broadcast("PRIVATE_KEY_ACTUAL")  {

        bytes memory nullBytes = new bytes(0);
        SendParam memory sendParam = SendParam({
            dstEid: baseID,
            to: bytes32(uint256(uint160(address(0x84Db3d1de9a43Aa144C21b248AD31a1c83d8334D)))),
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

//  forge script script/Base/UpdateEthBaseDvn.s.sol:SendTokensFromEthToBase --rpc-url mainnet --broadcast -vvvv