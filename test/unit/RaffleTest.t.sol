// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test {
    //event
    event EnteredRaffle(address indexed paticipant);
    Raffle raffle;
    HelperConfig helperConfig;

    uint256 _entranceFee;
    uint256 entranceFee = 0.1 ether;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        (
            _entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link
        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.Open);
    }

    function testRaffleRevertWhenNotEnoughEth() public {
        vm.prank(PLAYER);

        vm.expectRevert(Raffle.Raffle__NotEnoughETHError.selector);

        raffle.enterRaffle();
    }

    function testRaffleRecordPlayerAfterEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testRaffleEvenOneEntry() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testRaffleWhenDrawing() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpkeepReturnsFalseIfIthasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    //performUpkeep()

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 10);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParaAreGood() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();
        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: _entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1); // 0 = open, 1 = calculating
    }

    /*//////////////////////////////////////////////////////////////
                           FULFILLRANDOMWORDS
    //////////////////////////////////////////////////////////////*/
    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: _entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    // function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep()
    //     public
    //     raffleEntered
    //     skipFork
    // {
    //     // Arrange
    //     // Act / Assert
    //     vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
    //     // vm.mockCall could be used here...
    //     VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
    //         0,
    //         address(raffle)
    //     );

    //     vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
    //     VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
    //         1,
    //         address(raffle)
    //     );
    // }

    // function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
    //     public
    //     raffleEntered
    //     skipFork
    // {
    //     address expectedWinner = address(1);

    //     // Arrange
    //     uint256 additionalEntrances = 3;
    //     uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

    //     for (
    //         uint256 i = startingIndex;
    //         i < startingIndex + additionalEntrances;
    //         i++
    //     ) {
    //         address player = address(uint160(i));
    //         hoax(player, 1 ether); // deal 1 eth to the player
    //         raffle.enterRaffle{value: _entranceFee}();
    //     }

    //     uint256 startingTimeStamp = raffle.getLastTimeStamp();
    //     uint256 startingBalance = expectedWinner.balance;

    //     // Act
    //     vm.recordLogs();
    //     raffle.performUpkeep(""); // emits requestId
    //     Vm.Log[] memory entries = vm.getRecordedLogs();
    //     console2.logBytes32(entries[1].topics[1]);
    //     bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

    //     VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
    //         uint256(requestId),
    //         address(raffle)
    //     );

    //     // Assert
    //     address recentWinner = raffle.getRecentWinner();
    //     Raffle.RaffleState raffleState = raffle.getRaffleState();
    //     uint256 winnerBalance = recentWinner.balance;
    //     uint256 endingTimeStamp = raffle.getLastTimeStamp();
    //     uint256 prize = _entranceFee * (additionalEntrances + 1);

    //     assert(recentWinner == expectedWinner);
    //     assert(uint256(raffleState) == 0);
    //     assert(winnerBalance == startingBalance + prize);
    //     assert(endingTimeStamp > startingTimeStamp);
    // }
}
