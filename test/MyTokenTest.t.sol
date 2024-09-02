//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployMyToken} from "../script/DeployMyToken.s.sol";
import {MyToken} from "../src/MyToken.sol";


interface MintableToken {
    function mint(address, uint256) external;
}

contract MyTokenTest is Test {
    MyToken public myToken;
    DeployMyToken public deployer;

    uint256 public constant STARTING_BALANCE = 100 ether;
    uint256 public constant SPEND_AMOUNT = 50 ether;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        deployer = new DeployMyToken();
        myToken = deployer.run();

        vm.prank(msg.sender);
        myToken.transfer(bob, STARTING_BALANCE);
    }

    function testBobBalance() public view {
        assertEq(STARTING_BALANCE, myToken.balanceOf(bob));
    }

    function testAllowance() public {
        vm.prank(bob);
        myToken.approve(alice, SPEND_AMOUNT);

        assertEq(myToken.allowance(bob, alice), SPEND_AMOUNT);
    }

    function testInitialSupply() public view {
        assertEq(myToken.totalSupply(), deployer.INITIAL_SUPPLY());
    }

    function testTransfer() public {
        vm.prank(bob);
        myToken.transfer(alice, SPEND_AMOUNT);

        assertEq(myToken.balanceOf(alice), SPEND_AMOUNT);
        assertEq(myToken.balanceOf(bob), STARTING_BALANCE - SPEND_AMOUNT);
    }

    function testApproveAndTransferFrom() public {
        vm.prank(bob);
        myToken.approve(alice, SPEND_AMOUNT);

        address reciever = makeAddr("reciever");
        vm.prank(alice);
        myToken.transferFrom(bob, reciever, SPEND_AMOUNT);

        assertEq(myToken.balanceOf(reciever), SPEND_AMOUNT);
        assertEq(myToken.balanceOf(bob), STARTING_BALANCE - SPEND_AMOUNT);
        assertEq(myToken.allowance(bob, alice), 0);
    }

    function testTransferFromFailsWithoutApproval() public {
        address reciever = makeAddr("reciever");
        vm.expectRevert();
        vm.prank(alice);
        myToken.transferFrom(bob, reciever, SPEND_AMOUNT);
    }

    function testAllowanceDecrease() public {
        uint256 initialAllowance = 100 ether;
        vm.prank(bob);
        myToken.approve(alice, initialAllowance);

        vm.prank(alice);
        myToken.transferFrom(bob, alice, 50 ether);

        assertEq(myToken.allowance(bob, alice), initialAllowance - 50 ether);
    }

    function testTransferEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(bob, alice, SPEND_AMOUNT);

        vm.prank(bob);
        myToken.transfer(alice, SPEND_AMOUNT);
    }

    function testApproveEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Approval(bob, alice, SPEND_AMOUNT);

        vm.prank(bob);
        myToken.approve(alice, SPEND_AMOUNT);
    }

    function testFailTransferMoreThanBalance() public {
        vm.prank(bob);
        myToken.transfer(alice, STARTING_BALANCE + 1);
    }

    function testUsersCantMint() public {
        vm.expectRevert();
        vm.prank(bob);
        MintableToken(address(myToken)).mint(alice, 1 ether);
    }

    function testTransferToZeroAddressReverts() public {
        vm.expectRevert();
        vm.prank(bob);
        myToken.transfer(address(0), SPEND_AMOUNT);
    }

    function testTransferFromZeroAddressReverts() public {
        vm.expectRevert();
        vm.prank(address(0));
        myToken.transfer(alice, SPEND_AMOUNT);
    }

    function testApproveZeroAddressReverts() public {
        vm.expectRevert();
        vm.prank(bob);
        myToken.approve(address(0), SPEND_AMOUNT);
    }

    function testTransferToSelf() public {
        vm.prank(bob);
        myToken.transfer(bob, SPEND_AMOUNT);
        assertEq(myToken.balanceOf(bob), STARTING_BALANCE);
    }

    function testApproveMaximumUint256() public {
        vm.prank(bob);
        myToken.approve(alice, type(uint256).max);
        assertEq(myToken.allowance(bob, alice), type(uint256).max);

        address reciever = makeAddr("reciever");
        vm.prank(alice);
        myToken.transferFrom(bob, reciever, SPEND_AMOUNT);

        assertEq(myToken.balanceOf(reciever), SPEND_AMOUNT);
        assertEq(myToken.allowance(bob, alice), type(uint256).max);
    }

    function testApproveOverwritesPrevious() public {
        vm.prank(bob);
        myToken.approve(alice, 50 ether);
        vm.prank(bob);
        myToken.approve(alice, 100 ether);

        assertEq(myToken.allowance(bob, alice), 100 ether);
    }

    function testDecreaseAllowance() public {
        vm.prank(bob);
        myToken.approve(alice, 100 ether);
        vm.prank(bob);
        myToken.approve(alice, 50 ether);

        assertEq(myToken.allowance(bob, alice), 50 ether);
    }

    function testMultipleTransfersFromUsingAllowance() public {
        vm.prank(bob);
        myToken.approve(alice, 100 ether);
        address reciever = makeAddr("reciever");
        vm.prank(alice);
        myToken.transferFrom(bob, reciever, 50 ether);
        vm.prank(alice);
        myToken.transferFrom(bob, reciever, 50 ether);

        assertEq(myToken.balanceOf(reciever), 100 ether);
        assertEq(myToken.allowance(bob, alice), 0);
    }
}
