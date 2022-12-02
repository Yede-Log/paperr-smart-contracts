// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

//EPNS Core Contract Interface
interface IEPNSCoreInterface {
   enum ChannelType {
        ProtocolNonInterest,
        ProtocolPromotion,
        InterestBearingOpen,
        InterestBearingMutual
    }

    function createChannelWithFees(
        ChannelType _channelType,
        bytes calldata _identity,
        uint256 _amount
    )external;

}