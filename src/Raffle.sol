// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

contract Raffle {
    error Raffle__NotEnoughETHError();

    uint256 private immutable i_entranceFee;
    address payable private immutable i_owner;

    constructor(uint256 _entranceFee) {
        i_entranceFee = _entranceFee;
        i_owner = payable(msg.sender);
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHError();
        }
    }

    function pickWinner() public {}

    /** Getter functions */

    function getOwner() public view returns (address payable) {
        return i_owner;
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
