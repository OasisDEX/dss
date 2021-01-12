// SPDX-License-Identifier: AGPL-3.0-or-later

// Copyright (C) 2017, 2018, 2019 dbrock, rain, mrchico

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.5.12;

import "./dai.sol";

interface iOVM_BaseCrossDomainMessenger {
    /**********
     * Events *
     **********/
    event SentMessage(bytes message);
    event RelayedMessage(bytes32 msgHash);

    /**********************
     * Contract Variables *
     **********************/
    function xDomainMessageSender() external view returns (address);

    /********************
     * Public Functions *
     ********************/

    /**
     * Sends a cross domain message to the target messenger.
     * @param _target Target contract address.
     * @param _message Message to send to the target.
     * @param _gasLimit Gas limit for the provided message.
     */
    function sendMessage(
        address _target,
        bytes calldata _message,
        uint32 _gasLimit
    ) external;
}

contract oDai is Dai {
    address l1ERC20DepositAddress;
    iOVM_BaseCrossDomainMessenger internal messenger;

    constructor(uint256 chainId_) public Dai(chainId_) {}

    function init(address _messenger, address _L1ERC20DepositAddress) public {
        require(
            l1ERC20DepositAddress == address(0),
            "L2ERC20 instance has already been initalized"
        );
        messenger = iOVM_BaseCrossDomainMessenger(_messenger);
        l1ERC20DepositAddress = _L1ERC20DepositAddress;
    }

    function mint(address _depositor, uint256 _amount)
        public
        returns (bool success)
    {
        require(messenger.xDomainMessageSender() == l1ERC20DepositAddress);
        require(
            msg.sender == address(messenger),
            "Only messages relayed by L2CrossDomainMessenger can mint"
        );
        _mint(_depositor, _amount);
        return true;
    }

    function withdraw(uint256 _amount) public {
        _burn(msg.sender, _amount);
        // generate encoded calldata to be executed on L1
        bytes memory message =
            abi.encodeWithSignature(
                "withdraw(address,uint256)",
                msg.sender,
                _amount
            );

        // send the message over to the L1CrossDomainMessenger!
        messenger.sendMessage(l1ERC20DepositAddress, message, 1000000);
    }
}
