// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

import {MocaOFT} from "./../../src/MocaOFT.sol";

abstract contract State is Script {

    uint32 public constant ethereumID = 30101;

    // DeployFinal production Polygon OFT
    address public constant mocaOFTAddress = 0xF944e35f95E819E752f3cCB5Faf40957d311e8c5;

    // DeployFinal owner multisig
    address public constant ownerMultiSig = 0xcC29169dA9063f893D7958E8C021E788446e7229;

    MocaOFT public mocaOFT = MocaOFT(mocaOFTAddress);
}

/**
 * Disconnect Polygon OFT from Ethereum:
 *  1. Zero inbound/outbound rate limits for ethereum eid
 *  2. Clear the ethereum peer (resetPeer)
 *
 * Requires owner (rate limits are onlyOwner). resetPeer accepts owner or operator.
 */
contract DisconnectPolygonFromEthereum is State {

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_ACTUAL");
        vm.startBroadcast(deployerPrivateKey);

        mocaOFT.setOutboundLimit(ethereumID, 0);
        mocaOFT.setInboundLimit(ethereumID, 0);

        mocaOFT.resetPeer(ethereumID);

        console2.log("Polygon OFT disconnected from Ethereum eid", ethereumID);
        console2.log("Rate limits set to 0 for eid", ethereumID);

        vm.stopBroadcast();
    }
}

// forge script script/Polygon/Disconnect..sol:DisconnectPolygonFromEthereum --rpc-url polygon --broadcast -vvvv

/**
 * Sets LZ delegate to multisig, then Ownable2Step pendingOwner.
 * DAT must call acceptOwnership() on the OFT to complete ownership transfer.
 */
contract TransferOwnershipToMultisig is State {

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_ACTUAL");
        vm.startBroadcast(deployerPrivateKey);

        mocaOFT.setDelegate(ownerMultiSig);
        mocaOFT.transferOwnership(ownerMultiSig);

        console2.log("delegate set to", ownerMultiSig);
        console2.log("pendingOwner set to", ownerMultiSig);

        vm.stopBroadcast();
    }
}

// forge script script/Polygon/Disconnect..sol:TransferOwnershipToMultisig --rpc-url polygon --broadcast -vvvv

contract SetDelegateToMultisig is State {

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_ACTUAL");
        vm.startBroadcast(deployerPrivateKey);

        mocaOFT.setDelegate(ownerMultiSig);

        console2.log("delegate set to", ownerMultiSig);

        vm.stopBroadcast();
    }
}

// forge script script/Polygon/Disconnect..sol:SetDelegateToMultisig --rpc-url polygon --broadcast -vvvv
