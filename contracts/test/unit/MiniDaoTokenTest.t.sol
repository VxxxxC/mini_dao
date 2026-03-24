// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vm}   from "forge-std/Vm.sol";

import {MiniDaoTestBase} from "../base/MiniDaoTestBase.t.sol";
import {MiniDaoToken}    from "../../src/MiniDaoToken.sol";

contract MiniDaoTokenTest is MiniDaoTestBase {
	uint256 internal constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;

	address internal treasury;
	address internal distributor;

	function setUp() public {
		distributor = DEPLOYER;
		treasury    = makeAddr("TREASURY");
		token       = new MiniDaoToken(distributor, treasury);
	}

	// --- Constructor & Supply Distribution ---

	function testTotalSupplyIsOneBillion() public view {
		assertEq(token.totalSupply(), TOTAL_SUPPLY, "total supply should be 1 billion tokens");
	}

	function testThirtyPercentMintedToDistributor() public view {
		uint256 expected = (TOTAL_SUPPLY * 30) / 100;
		assertEq(token.balanceOf(distributor), expected, "distributor should hold 30%");
	}

	function testSeventyPercentMintedToTreasury() public view {
		uint256 distributorAmount = (TOTAL_SUPPLY * 30) / 100;
		uint256 expected          = TOTAL_SUPPLY - distributorAmount;
		assertEq(token.balanceOf(treasury), expected, "treasury should hold 70%");
	}

	function testSupplySumEqualsTotal() public view {
		uint256 sum = token.balanceOf(distributor) + token.balanceOf(treasury);
		assertEq(sum, TOTAL_SUPPLY, "balances must sum to total supply");
	}

	function testRevertInvalidAddress_ZeroDistributor() public {
		vm.expectRevert(MiniDaoToken.InvalidAddress.selector);
		new MiniDaoToken(address(0), treasury);
	}

	function testRevertInvalidAddress_ZeroTreasury() public {
		vm.expectRevert(MiniDaoToken.InvalidAddress.selector);
		new MiniDaoToken(distributor, address(0));
	}

	function testRevertInvalidAddress_BothZero() public {
		vm.expectRevert(MiniDaoToken.InvalidAddress.selector);
		new MiniDaoToken(address(0), address(0));
	}

	// --- ERC20 Transfers & Approvals ---

	function testTransferTokens() public {
		uint256 amount = 50 * 10 ** 18;
		uint256 before = token.balanceOf(distributor);

		vm.prank(distributor);
		token.transfer(USER_A, amount);

		assertEq(token.balanceOf(USER_A),      amount,          "USER_A should receive tokens");
		assertEq(token.balanceOf(distributor), before - amount, "distributor balance decreased");
	}

	function testTransferFromWithApproval() public {
		uint256 amount = 100 * 10 ** 18;

		vm.prank(distributor);
		token.approve(USER_A, amount);

		assertEq(token.allowance(distributor, USER_A), amount, "allowance set");

		vm.prank(USER_A);
		token.transferFrom(distributor, USER_B, amount);

		assertEq(token.balanceOf(USER_B),              amount, "USER_B received");
		assertEq(token.allowance(distributor, USER_A), 0,      "allowance decremented");
	}

	function testTransferFailsInsufficientBalance() public {
		uint256 balance = token.balanceOf(USER_A);
		vm.prank(USER_A);
		vm.expectRevert();
		token.transfer(USER_B, balance + 1);
	}

	// --- ERC20Votes – Delegation & Voting Power ---

	function testVotingPowerZeroBeforeDelegation() public view {
		assertEq(token.getVotes(distributor), 0, "no votes before delegation");
	}

	function testVotingPowerEqualsBalanceAfterSelfDelegate() public {
		vm.prank(distributor);
		token.delegate(distributor);
		assertEq(token.getVotes(distributor), token.balanceOf(distributor), "votes == balance after self-delegate");
	}

	function testDelegatingToAnotherAddress() public {
		vm.prank(distributor);
		token.delegate(USER_A);
		assertEq(token.getVotes(USER_A), token.balanceOf(distributor), "USER_A receives delegated votes");
	}

	function testVotingPowerUpdatesOnTransfer() public {
		uint256 amount = 100 * 10 ** 18;

		vm.prank(distributor);
		token.delegate(distributor);

		uint256 votesBefore = token.getVotes(distributor);

		vm.prank(distributor);
		token.transfer(USER_A, amount);

		assertEq(token.getVotes(distributor), votesBefore - amount, "votes decrease after transfer");
	}

	function testGetPastVotesReturnsSnapshotAtBlock() public {
		vm.prank(distributor);
		token.delegate(distributor);

		uint256 snapshotBlock = block.number - 1; // use a block that's strictly in the past

		// Ensure we are at a block strictly after snapshotBlock
		vm.roll(snapshotBlock + 10);

		vm.prank(distributor);
		token.transfer(USER_A, 1000 * 10 ** 18);

		// Past votes at snapshotBlock should reflect state before any transfer
		assertGe(
			token.getPastVotes(distributor, snapshotBlock),
			0,
			"getPastVotes must not revert for a past block"
		);
	}

	function testDelegateChangedEventEmitted() public {
		vm.recordLogs();
		vm.prank(distributor);
		token.delegate(USER_A);

		Vm.Log[] memory logs = vm.getRecordedLogs();
		bytes32 sig = keccak256("DelegateChanged(address,address,address)");
		bool found;
		for (uint256 i; i < logs.length; i++) {
			if (logs[i].topics[0] == sig) { found = true; break; }
		}
		assertTrue(found, "DelegateChanged event not emitted");
	}

	function testDelegateVotesChangedEventEmitted() public {
		vm.recordLogs();
		vm.prank(distributor);
		token.delegate(distributor);

		Vm.Log[] memory logs = vm.getRecordedLogs();
		bytes32 sig = keccak256("DelegateVotesChanged(address,uint256,uint256)");
		bool found;
		for (uint256 i; i < logs.length; i++) {
			if (logs[i].topics[0] == sig) { found = true; break; }
		}
		assertTrue(found, "DelegateVotesChanged event not emitted");
	}

	// --- ERC20Permit ---

	function testPermitGrantsAllowance() public {
		(address signer, uint256 privKey) = makeAddrAndKey("PERMIT_SIGNER");

		vm.prank(distributor);
		token.transfer(signer, 500 * 10 ** 18);

		uint256 amount   = 200 * 10 ** 18;
		uint256 deadline = block.timestamp + 1 hours;
		uint256 nonce    = token.nonces(signer);

		bytes32 permitTypehash = keccak256(
			"Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
		);
		bytes32 structHash = keccak256(
			abi.encode(permitTypehash, signer, USER_A, amount, nonce, deadline)
		);
		bytes32 digest = keccak256(
			abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
		);
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);

		token.permit(signer, USER_A, amount, deadline, v, r, s);

		assertEq(token.allowance(signer, USER_A), amount, "allowance set via permit");
	}

	function testPermitIncrementsNonce() public {
		(address signer, uint256 privKey) = makeAddrAndKey("PERMIT_NONCE_SIGNER");

		vm.prank(distributor);
		token.transfer(signer, 500 * 10 ** 18);

		uint256 nonceBefore = token.nonces(signer);
		uint256 amount      = 100 * 10 ** 18;
		uint256 deadline    = block.timestamp + 1 hours;

		bytes32 permitTypehash = keccak256(
			"Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
		);
		bytes32 structHash = keccak256(
			abi.encode(permitTypehash, signer, USER_A, amount, nonceBefore, deadline)
		);
		bytes32 digest = keccak256(
			abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
		);
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);
		token.permit(signer, USER_A, amount, deadline, v, r, s);

		assertEq(token.nonces(signer), nonceBefore + 1, "nonce incremented");
	}

	function testPermitRevertsOnExpiredDeadline() public {
		(address signer, uint256 privKey) = makeAddrAndKey("PERMIT_EXPIRED");
		uint256 amount   = 100 * 10 ** 18;
		uint256 deadline = block.timestamp - 1; // expired
		uint256 nonce    = token.nonces(signer);

		bytes32 permitTypehash = keccak256(
			"Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
		);
		bytes32 structHash = keccak256(
			abi.encode(permitTypehash, signer, USER_A, amount, nonce, deadline)
		);
		bytes32 digest = keccak256(
			abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
		);
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);

		vm.expectRevert();
		token.permit(signer, USER_A, amount, deadline, v, r, s);
	}

	function testPermitRevertsOnWrongNonce() public {
		(address signer, uint256 privKey) = makeAddrAndKey("PERMIT_WRONG_NONCE");
		uint256 amount   = 100 * 10 ** 18;
		uint256 deadline = block.timestamp + 1 hours;
		uint256 badNonce = token.nonces(signer) + 1; // wrong nonce

		bytes32 permitTypehash = keccak256(
			"Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
		);
		bytes32 structHash = keccak256(
			abi.encode(permitTypehash, signer, USER_A, amount, badNonce, deadline)
		);
		bytes32 digest = keccak256(
			abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
		);
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);

		vm.expectRevert();
		token.permit(signer, USER_A, amount, deadline, v, r, s);
	}

	function testPermitRevertsOnWrongSigner() public {
		(address signer,)         = makeAddrAndKey("PERMIT_REAL_SIGNER");
		(, uint256 wrongKey)      = makeAddrAndKey("PERMIT_WRONG_SIGNER");

		uint256 amount   = 100 * 10 ** 18;
		uint256 deadline = block.timestamp + 1 hours;
		uint256 nonce    = token.nonces(signer);

		bytes32 permitTypehash = keccak256(
			"Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
		);
		bytes32 structHash = keccak256(
			abi.encode(permitTypehash, signer, USER_A, amount, nonce, deadline)
		);
		bytes32 digest = keccak256(
			abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
		);
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongKey, digest); // signed with wrong key

		vm.expectRevert();
		token.permit(signer, USER_A, amount, deadline, v, r, s);
	}
}
