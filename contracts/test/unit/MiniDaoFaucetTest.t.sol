// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MiniDaoTestBase} from "../base/MiniDaoTestBase.t.sol";
import {MockFailToken}   from "../mocks/Mocks.sol";
import {MiniDaoToken}    from "../../src/MiniDaoToken.sol";
import {MiniDaoFaucet}   from "../../src/MiniDaoFaucet.sol";

contract MiniDaoFaucetTest is MiniDaoTestBase {
	function setUp() public {
		_deployAll();
	}

	// --- Claim Happy Path ---

	function testClaimSucceeds() public {
		vm.prank(USER_A);
		faucet.claim();
		assertEq(token.balanceOf(USER_A), faucet.FAUCET_AMOUNT(), "balance should equal FAUCET_AMOUNT");
	}

	function testClaimSetsHasClaimedTrue() public {
		vm.prank(USER_A);
		faucet.claim();
		assertTrue(faucet.hasClaimed(USER_A), "hasClaimed should be true");
	}

	function testHasClaimedFalseBeforeClaim() public view {
		assertFalse(faucet.hasClaimed(USER_A), "hasClaimed should be false before claim");
	}

	function testFaucetBalanceDecreasesAfterClaim() public {
		uint256 before = token.balanceOf(address(faucet));
		vm.prank(USER_A);
		faucet.claim();
		assertEq(token.balanceOf(address(faucet)), before - faucet.FAUCET_AMOUNT(), "faucet balance decreased");
	}

	function testMultipleUsersClaim() public {
		vm.prank(USER_A); faucet.claim();
		vm.prank(USER_B); faucet.claim();
		vm.prank(USER_C); faucet.claim();

		assertEq(token.balanceOf(USER_A), faucet.FAUCET_AMOUNT(), "USER_A claimed");
		assertEq(token.balanceOf(USER_B), faucet.FAUCET_AMOUNT(), "USER_B claimed");
		assertEq(token.balanceOf(USER_C), faucet.FAUCET_AMOUNT(), "USER_C claimed");
	}

	// --- Claim Error Paths ---

	function testRevertAlreadyClaimed() public {
		vm.startPrank(USER_A);
		faucet.claim();
		vm.expectRevert(MiniDaoFaucet.AlreadyClaimed.selector);
		faucet.claim();
		vm.stopPrank();
	}

	function testRevertFaucetEmpty_ZeroBalance() public {
		// Deploy a fresh faucet backed by the same token but with no balance
		MiniDaoFaucet emptyFaucet = new MiniDaoFaucet(address(token));
		vm.prank(USER_A);
		vm.expectRevert(MiniDaoFaucet.FaucetEmpty.selector);
		emptyFaucet.claim();
	}

	function testRevertFaucetEmpty_BelowThreshold() public {
		MiniDaoToken freshToken     = new MiniDaoToken(DEPLOYER, makeAddr("T2"));
		MiniDaoFaucet partialFaucet = new MiniDaoFaucet(address(freshToken));

		uint256 belowAmount = faucet.FAUCET_AMOUNT() - 1;
		vm.prank(DEPLOYER);
		freshToken.transfer(address(partialFaucet), belowAmount);

		vm.prank(USER_A);
		vm.expectRevert(MiniDaoFaucet.FaucetEmpty.selector);
		partialFaucet.claim();
	}

	function testRevertFaucetEmpty_ExactlyOneClaimLeft() public {
		MiniDaoToken freshToken   = new MiniDaoToken(DEPLOYER, makeAddr("T3"));
		MiniDaoFaucet exactFaucet = new MiniDaoFaucet(address(freshToken));

		uint256 faucetAmt = faucet.FAUCET_AMOUNT();
		vm.prank(DEPLOYER);
		freshToken.transfer(address(exactFaucet), faucetAmt);

		vm.prank(USER_A);
		exactFaucet.claim(); // succeeds

		vm.prank(USER_B);
		vm.expectRevert(MiniDaoFaucet.FaucetEmpty.selector);
		exactFaucet.claim(); // reverts
	}

	// --- Token Transfer Failure ---

	function testRevertTransferFailed_MockTokenReturnsFalse() public {
		MockFailToken mockToken  = new MockFailToken();
		MiniDaoFaucet mockFaucet = new MiniDaoFaucet(address(mockToken));
		// MockFailToken.balanceOf returns max so FaucetEmpty won't trigger
		vm.prank(USER_A);
		vm.expectRevert(MiniDaoFaucet.TransferFailed.selector);
		mockFaucet.claim();
	}
}
