// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {EscrowManager} from "../src/EscrowManager.sol";
import {DeployEscrowManager} from "../script/DeployEscrowManager.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EscrowManagerTest is Test {
    address owner;
    EscrowManager escrowManager;
    DeployEscrowManager deployEscrowManager;
    IERC20 mnee;
    uint64 timeout = 60;
    address alice = makeAddr("alice");
    address buyer = makeAddr("buyer");
    address seller = makeAddr("seller");
    address arbiter = makeAddr("arbiter");
    uint256 amount = 20e18;
    uint256 testAmount = 1e18;
    uint256 startingBalance = 10 ether;

    function setUp() external {
        mnee = IERC20(0x8ccedbAe4916b79da7F3F612EfB2EB93A2bFD6cF);
        deployEscrowManager = new DeployEscrowManager();
        escrowManager = deployEscrowManager.run();
        owner = escrowManager.I_OWNER();
        vm.deal(alice, startingBalance);
        deal(0x8ccedbAe4916b79da7F3F612EfB2EB93A2bFD6cF, buyer, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                DEPLOYMENT   
    //////////////////////////////////////////////////////////////*/

    function testOwnerIsMsgSender() public view {
        assertEq(escrowManager.I_OWNER(), msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            ESCROW CREATION   
    //////////////////////////////////////////////////////////////*/

    function testBuyerCanCreateEscrow() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        vm.stopPrank();
        (
            address eBuyer,
            address eSeller,
            address eArbiter,
            uint256 eAmount,
            ,
            uint64 eTimeout,
            EscrowManager.EscrowStatus eStatus
        ) = escrowManager.escrows(eId);
        assertEq(eBuyer, buyer);
        assertEq(eSeller, seller);
        assertEq(eArbiter, arbiter);
        assertEq(eAmount, testAmount);
        assertEq(eTimeout, timeout);
        assertEq(
            uint8(eStatus),
            uint8(EscrowManager.EscrowStatus.AWAITING_DELIVERY)
        );
    }

    function testFundsAreTransferredIntoContract() public {
        uint256 buyerOldBalance = mnee.balanceOf(buyer);
        uint256 contractOldBalance = mnee.balanceOf(address(escrowManager));

        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        escrowManager.createEscrow(seller, arbiter, testAmount, timeout);
        vm.stopPrank();

        uint256 buyerNewBalance = mnee.balanceOf(buyer);
        uint256 contractNewBalance = mnee.balanceOf(address(escrowManager));

        assertEq(buyerNewBalance, buyerOldBalance - testAmount);
        assertEq(contractNewBalance, contractOldBalance + testAmount);
    }

    function testCreateEscrowRevertsOnInvalidInput() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        vm.expectRevert();
        escrowManager.createEscrow(address(0), arbiter, testAmount, timeout);
        vm.expectRevert();
        escrowManager.createEscrow(seller, address(0), testAmount, timeout);
        vm.expectRevert();
        escrowManager.createEscrow(seller, arbiter, 0, timeout);
        vm.expectRevert();
        escrowManager.createEscrow(seller, arbiter, testAmount, 0);
        vm.stopPrank();
    }

    function testArbiterCannotBeBuyerOrSeller() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        vm.expectRevert();
        escrowManager.createEscrow(seller, seller, testAmount, timeout);
        vm.expectRevert();
        escrowManager.createEscrow(seller, buyer, testAmount, timeout);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL   
    //////////////////////////////////////////////////////////////*/

    function testOnlyBuyerCanRelease() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        vm.stopPrank();

        vm.prank(arbiter);
        vm.expectRevert();
        escrowManager.release(eId);

        vm.prank(seller);
        vm.expectRevert();
        escrowManager.release(eId);

        uint256 sellerOldBalance = mnee.balanceOf(seller);
        vm.prank(buyer);
        escrowManager.release(eId);
        uint256 sellerNewBalance = mnee.balanceOf(seller);
        assert(sellerOldBalance < sellerNewBalance);
    }

    function testOnlyBuyerCanDispute() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        vm.stopPrank();

        vm.prank(arbiter);
        vm.expectRevert();
        escrowManager.dispute(eId);

        vm.prank(seller);
        vm.expectRevert();
        escrowManager.dispute(eId);

        vm.prank(buyer);
        escrowManager.dispute(eId);
        EscrowManager.EscrowStatus expectedEscrowStatus = EscrowManager
            .EscrowStatus
            .DISPUTED;
        (, , , , , , EscrowManager.EscrowStatus eStatus) = escrowManager
            .escrows(eId);
        assertEq(uint8(expectedEscrowStatus), uint8(eStatus));
    }

    function testOnlySellerCanAutoRelease() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        vm.stopPrank();

        vm.warp(timeout + block.timestamp);

        vm.prank(arbiter);
        vm.expectRevert();
        escrowManager.autoRelease(eId);

        vm.prank(buyer);
        vm.expectRevert();
        escrowManager.autoRelease(eId);

        uint256 sellerOldBalance = mnee.balanceOf(seller);
        vm.prank(seller);
        escrowManager.autoRelease(eId);
        uint256 sellerNewBalance = mnee.balanceOf(seller);
        assert(sellerNewBalance > sellerOldBalance);
    }

    function testOnlyArbiterCanArbitrate() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        escrowManager.dispute(eId);
        vm.stopPrank();

        vm.prank(seller);
        vm.expectRevert();
        escrowManager.arbitrate(eId, true);

        vm.prank(buyer);
        vm.expectRevert();
        escrowManager.arbitrate(eId, true);

        uint256 sellerOldBalance = mnee.balanceOf(seller);
        vm.prank(arbiter);
        escrowManager.arbitrate(eId, true);
        uint256 sellerNewBalance = mnee.balanceOf(seller);
        assert(sellerNewBalance > sellerOldBalance);
    }

    /*//////////////////////////////////////////////////////////////
                            BUYER RELEASE FLOW   
    //////////////////////////////////////////////////////////////*/

    function testReleaseSendsFundsCorrectly() public {
        vm.startPrank(buyer);
        uint256 ownerOldBalance = mnee.balanceOf(owner);
        uint256 sellerOldBalance = mnee.balanceOf(seller);
        uint256 pointOnePercent = (testAmount * 10) / 10000;

        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        escrowManager.release(eId);
        vm.stopPrank();

        uint256 ownerNewBalance = mnee.balanceOf(owner);
        uint256 sellerNewBalance = mnee.balanceOf(seller);
        uint256 contractBalance = mnee.balanceOf(address(escrowManager));

        assertEq(ownerNewBalance, ownerOldBalance + pointOnePercent);
        assertEq(
            sellerNewBalance,
            sellerOldBalance + testAmount - pointOnePercent
        );
        assertEq(contractBalance, 0);
    }

    function testReleaseEmitsEvent() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        vm.expectEmit();
        emit EscrowManager.Released(eId);
        escrowManager.release(eId);
        vm.stopPrank();
    }

    function testCannotReleaseTwice() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        escrowManager.release(eId);
        vm.expectRevert();
        escrowManager.release(eId);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            AUTO RELEASE FLOW   
    //////////////////////////////////////////////////////////////*/

    function testAutoReleaseBeforeTimeoutReverts() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        vm.stopPrank();

        vm.warp(timeout - 3 + block.timestamp);

        vm.expectRevert();
        vm.prank(seller);
        escrowManager.autoRelease(eId);
    }

    function testAutoReleaseAfterTimeoutSucceeds() public {
        uint256 ownerOldBalance = mnee.balanceOf(owner);
        uint256 sellerOldBalance = mnee.balanceOf(seller);
        uint256 pointOnePercent = (testAmount * 10) / 10000;

        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        vm.stopPrank();

        vm.warp(timeout + block.timestamp);

        vm.prank(seller);
        escrowManager.autoRelease(eId);

        uint256 ownerNewBalance = mnee.balanceOf(owner);
        uint256 sellerNewBalance = mnee.balanceOf(seller);

        EscrowManager.EscrowStatus expectedStatus = EscrowManager
            .EscrowStatus
            .COMPLETED;
        (, , , , , , EscrowManager.EscrowStatus eStatus) = escrowManager
            .escrows(eId);
        assertEq(uint8(expectedStatus), uint8(eStatus));

        assertEq(ownerNewBalance, ownerOldBalance + pointOnePercent);
        assertEq(
            sellerNewBalance,
            sellerOldBalance + testAmount - pointOnePercent
        );
    }

    function testAutoReleaseEmitsEvent() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        vm.stopPrank();

        vm.warp(timeout + block.timestamp);

        vm.prank(seller);
        vm.expectEmit();
        emit EscrowManager.AutoReleased(eId);
        escrowManager.autoRelease(eId);
    }

    /*//////////////////////////////////////////////////////////////
                                DISPUTE FLOW   
    //////////////////////////////////////////////////////////////*/

    function testDisputeEmitsEvent() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );

        vm.expectEmit();
        emit EscrowManager.Disputed(eId);
        escrowManager.dispute(eId);
        vm.stopPrank();
    }

    function testCannotDisputeTwice() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        escrowManager.dispute(eId);
        vm.expectRevert();
        escrowManager.dispute(eId);
        vm.stopPrank();
    }

    function testCannotReleaseAfterDispute() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        escrowManager.dispute(eId);
        vm.expectRevert();
        escrowManager.release(eId);
        vm.stopPrank();
    }

    function testCannotAutoReleaseAfterDispute() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        escrowManager.dispute(eId);
        vm.stopPrank();

        vm.expectRevert();
        escrowManager.autoRelease(eId);
    }

    /*//////////////////////////////////////////////////////////////
                            ARBITRATION FLOW   
    //////////////////////////////////////////////////////////////*/

    function testArbiterReleaseToSellerSendsFundsCorrectly() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        escrowManager.dispute(eId);
        vm.stopPrank();

        uint256 ownerOldBalance = mnee.balanceOf(owner);
        uint256 sellerOldBalance = mnee.balanceOf(seller);
        uint256 arbiterOldBalance = mnee.balanceOf(arbiter);
        uint256 pointOnePercent = (testAmount * 10) / 10000;
        uint256 onePercent = (testAmount * 100) / 10000;

        vm.prank(arbiter);
        escrowManager.arbitrate(eId, true);

        uint256 ownerNewBalance = mnee.balanceOf(owner);
        uint256 sellerNewBalance = mnee.balanceOf(seller);
        uint256 arbiterNewBalance = mnee.balanceOf(arbiter);

        assertEq(ownerNewBalance, ownerOldBalance + pointOnePercent);
        assertEq(
            sellerNewBalance,
            sellerOldBalance + testAmount - pointOnePercent - onePercent
        );
        assertEq(arbiterNewBalance, arbiterOldBalance + onePercent);
    }

    function testArbiterReleaseToBuyerSendsFundsCorrectly() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        escrowManager.dispute(eId);
        vm.stopPrank();

        uint256 ownerOldBalance = mnee.balanceOf(owner);
        uint256 buyerOldBalance = mnee.balanceOf(buyer);
        uint256 arbiterOldBalance = mnee.balanceOf(arbiter);
        uint256 pointOnePercent = (testAmount * 10) / 10000;
        uint256 onePercent = (testAmount * 100) / 10000;

        vm.prank(arbiter);
        escrowManager.arbitrate(eId, false);

        uint256 ownerNewBalance = mnee.balanceOf(owner);
        uint256 buyerNewBalance = mnee.balanceOf(buyer);
        uint256 arbiterNewBalance = mnee.balanceOf(arbiter);

        assertEq(ownerNewBalance, ownerOldBalance + pointOnePercent);
        assertEq(
            buyerNewBalance,
            buyerOldBalance + testAmount - pointOnePercent - onePercent
        );
        assertEq(arbiterNewBalance, arbiterOldBalance + onePercent);
    }

    function testArbitrationEmitsEvent() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        escrowManager.dispute(eId);
        vm.stopPrank();

        vm.expectEmit();
        emit EscrowManager.Arbitrated(eId, false);
        vm.prank(arbiter);
        escrowManager.arbitrate(eId, false);
    }

    /*//////////////////////////////////////////////////////////////
                            STATE SAFETY   
    //////////////////////////////////////////////////////////////*/

    function testArbitrationAllowedOnlyAfterDispute() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        vm.stopPrank();

        vm.expectRevert();
        vm.prank(arbiter);
        escrowManager.arbitrate(eId, false);
    }

    function testNoActionAllowedAfterEscrowStatusIsCOMPLETED() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        escrowManager.release(eId);

        vm.expectRevert();
        escrowManager.release(eId);

        vm.expectRevert();
        escrowManager.dispute(eId);
        vm.stopPrank();

        vm.expectRevert();
        vm.prank(seller);
        escrowManager.autoRelease(eId);

        vm.expectRevert();
        vm.prank(arbiter);
        escrowManager.arbitrate(eId, false);
    }

    function testNoActionAllowedAfterEscrowStatusIsREFUNDED() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        escrowManager.dispute(eId);
        vm.stopPrank();

        vm.prank(arbiter);
        escrowManager.arbitrate(eId, false);

        vm.expectRevert();
        vm.prank(buyer);
        escrowManager.release(eId);

        vm.expectRevert();
        vm.prank(buyer);
        escrowManager.dispute(eId);

        vm.expectRevert();
        vm.prank(seller);
        escrowManager.autoRelease(eId);

        vm.expectRevert();
        vm.prank(arbiter);
        escrowManager.arbitrate(eId, false);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNT INVARIANTS   
    //////////////////////////////////////////////////////////////*/

    function testContractBalanceIsZeroAfterRelease() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        escrowManager.release(eId);
        vm.stopPrank();

        uint256 contractBalance = mnee.balanceOf(address(escrowManager));
        assertEq(contractBalance, 0);
    }

    function testContractBalanceIsZeroAfterAutoRelease() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        vm.stopPrank();

        vm.warp(block.timestamp + timeout);

        vm.prank(seller);
        escrowManager.autoRelease(eId);
        uint256 contractBalance = mnee.balanceOf(address(escrowManager));
        assertEq(contractBalance, 0);
    }

    function testContractBalanceIsZeroAfterArbitrationPaysSeller() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        escrowManager.dispute(eId);
        vm.stopPrank();

        vm.prank(arbiter);
        escrowManager.arbitrate(eId, true);

        uint256 contractBalance = mnee.balanceOf(address(escrowManager));
        assertEq(contractBalance, 0);
    }

    function testContractBalanceIsZeroAfterArbitrationPaysBuyer() public {
        vm.startPrank(buyer);
        mnee.approve(address(escrowManager), testAmount);
        uint256 eId = escrowManager.createEscrow(
            seller,
            arbiter,
            testAmount,
            timeout
        );
        escrowManager.dispute(eId);
        vm.stopPrank();

        vm.prank(arbiter);
        escrowManager.arbitrate(eId, false);

        uint256 contractBalance = mnee.balanceOf(address(escrowManager));
        assertEq(contractBalance, 0);
    }
}
