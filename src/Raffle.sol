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

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol"; ///Users/paco/Downloads/FCC/foundry/foundry-smart-contract-lottery/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughETHError();
    error Raffle__Transferfailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        RaffleState state
    );

    enum RaffleState {
        Open,
        Drawing
    }

    uint256 private immutable i_entranceFee;
    // @dev The interval in seconds between each raffle drawing.
    uint256 private immutable i_interval;
    address payable private immutable i_owner;
    address payable[] private s_participants;
    uint256 private s_lastDrawingTimeStamp;
    // address private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable private s_recentWinner;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    RaffleState private s_raffleState;

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    constructor(
        uint256 _entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        address link
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = _entranceFee;
        i_owner = payable(msg.sender);
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastDrawingTimeStamp = block.timestamp;
        s_raffleState = RaffleState.Open;
        // init vrf
    }

    /** event(); */
    event EnteredRaffle(address indexed paticipant);
    event WinnerPicked(address indexed winner);

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHError();
        }
        if (s_raffleState != RaffleState.Open) {
            revert Raffle__RaffleNotOpen();
        }
        s_participants.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastDrawingTimeStamp >=
            i_interval);
        upkeepNeeded =
            timeHasPassed &&
            s_raffleState == RaffleState.Open &&
            s_participants.length > 0 &&
            address(this).balance >= 0;
        return (upkeepNeeded, bytes("0x0"));
    }

    function performUpkeep(bytes calldata /* performData */) external {
        // check if time interval has passed
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_participants.length,
                s_raffleState
            );
        }

        s_raffleState = RaffleState.Drawing;

        // Will revert if subscription is not set and funded.
        i_vrfCoordinator.requestRandomWords(
            i_gasLane, //gas lane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        // Will revert if request ID is invalid.
        uint256 indexOfWinner = randomWords[0] % s_participants.length;
        // Send the winning prize to the winner.
        address payable winner = s_participants[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.Open;

        s_lastDrawingTimeStamp = block.timestamp;
        s_participants = new address payable[](0);

        (bool success, ) = s_participants[indexOfWinner].call{
            value: address(this).balance
        }("");
        if (!success) {
            revert Raffle__Transferfailed();
        }
        emit WinnerPicked(winner);
    }

    /** Getter functions */

    function getOwner() public view returns (address payable) {
        return i_owner;
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(
        uint256 indexOfPlayer
    ) external view returns (address payable) {
        return s_participants[indexOfPlayer];
    }

    function getlastDrawingTimeStamp() public view returns (uint256) {
        return s_lastDrawingTimeStamp;
    }
}
