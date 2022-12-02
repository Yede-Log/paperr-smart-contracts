// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

//EPNS Comm Contract Interface
interface IEPNSCommInterface {
        function sendNotification(address _channel,
        address _recipient,
        bytes memory _identity)
        external;
}