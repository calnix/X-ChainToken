// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./../../src/MocaTokenAdapter.sol";

contract MockTokenAdapter is MocaTokenAdapter {

    constructor(address token, address layerZeroEndpoint, address delegate, address owner) 
        MocaTokenAdapter(token, layerZeroEndpoint, delegate, owner) {}   


    function mockLzReceive(Origin calldata _origin, bytes32 _guid, bytes calldata _message, address unnamedAddress, bytes calldata unnamedBytes) public payable {
        _lzReceive(_origin, _guid, _message, unnamedAddress, unnamedBytes);
    }
    
    function credit(address to, uint256 amountLD, uint32 srcEid) public returns (uint256) {
       uint256 amountReceived = _credit(to, amountLD, srcEid);
    }


   function _lzSend(uint32 _dstEid, bytes memory _message, bytes memory _options, MessagingFee memory _fee, address _refundAddress) internal override returns (MessagingReceipt memory receipt) {}
}
