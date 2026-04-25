// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MiniDaoTestBase}    from "../base/MiniDaoTestBase.t.sol";
import {TimelockNoopTarget} from "../mocks/Mocks.sol";
import {MiniDaoToken}       from "../../src/MiniDaoToken.sol";
import {MiniDaoTimeLock}    from "../../src/MiniDaoTimeLock.sol";
import {MiniDaoGovernance}  from "../../src/MiniDaoGovernance.sol";
import {MiniDaoFaucet}      from "../../src/MiniDaoFaucet.sol";

contract MiniDaoFuzzTest is MiniDaoTestBase {
	uint256 internal constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;

	function setUp() public {
		_deployAll();
		_claimAndDelegate(USER_A);
	}

	// --- Token Fuzz ---

	function testFuzz_TransferNeverChangesTotalSupply(address to, uint256 amount) public {
		vm.assume(to != address(0));
		vm.assume(to != USER_A);
		amount = bound(amount, 1, token.balanceOf(USER_A));

		vm.prank(USER_A);
		token.transfer(to, amount);

		assertEq(token.totalSupply(), TOTAL_SUPPLY, "total supply must not change");
	}

	function testFuzz_TransferFromUpdatesBalancesCorrectly(
		address from,
		address to,
		uint256 amount
	) public {
		vm.assume(from != address(0) && to != address(0));
		vm.assume(from != to);
		vm.assume(from != USER_A && to != USER_A);
		vm.assume(from != address(faucet) && to != address(faucet));
		vm.assume(from != address(timelock) && to != address(timelock));

		// Give `from` some tokens from USER_A (capped at USER_A's available balance)
		uint256 seedAmt = token.balanceOf(USER_A) / 2;
		vm.assume(seedAmt > 0);
		vm.prank(USER_A);
		token.transfer(from, seedAmt);

		amount = bound(amount, 1, token.balanceOf(from));

		uint256 fromBefore = token.balanceOf(from);
		uint256 toBefore   = token.balanceOf(to);

		vm.prank(from);
		token.approve(address(this), amount);
		token.transferFrom(from, to, amount);

		assertEq(token.balanceOf(from), fromBefore - amount, "from balance decreased correctly");
		assertEq(token.balanceOf(to),   toBefore   + amount, "to balance increased correctly");
	}

	function testFuzz_DelegationVotingPowerMatchesBalance(address delegatee) public {
		vm.assume(delegatee != address(0));
		uint256 balance = token.balanceOf(USER_A);

		vm.prank(USER_A);
		token.delegate(delegatee);

		assertEq(token.getVotes(delegatee), balance, "voting power must equal delegated balance");
	}

	function testFuzz_PermitNonceIncrementsMonotonically(uint256 amount, uint256 deadline) public {
		deadline = bound(deadline, block.timestamp + 1, block.timestamp + 365 days);
		amount   = bound(amount, 1, TOTAL_SUPPLY);

		(address signer, uint256 privKey) = makeAddrAndKey("FUZZ_PERMIT_SIGNER");
		uint256 nonceBefore = token.nonces(signer);

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

		assertEq(token.nonces(signer), nonceBefore + 1, "nonce must increment by 1");
	}

	function testFuzz_VotingPowerNotCountedBeforeSnapshotBlock(uint256 extraTokens) public {
		extraTokens = bound(extraTokens, 1, 500e18);

		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldatas,
		) = _buildProposal(address(voteBox), "Snapshot fuzz");

		vm.prank(USER_A);
		uint256 pid = governance.propose(targets, values, calldatas, "Snapshot fuzz");
		uint256 snapshotBlock = governance.proposalSnapshot(pid);

		// Advance past the snapshot first
		_passVotingDelay();

		// Transfer tokens to USER_B and delegate AFTER snapshot
		vm.prank(address(timelock));
		token.transfer(USER_B, extraTokens);
		vm.prank(USER_B);
		token.delegate(USER_B);

		vm.prank(USER_B);
		governance.castVote(pid, 1);

		assertEq(
			token.getPastVotes(USER_B, snapshotBlock),
			0,
			"USER_B's extra tokens must not count at snapshot"
		);
	}

	// --- Faucet Fuzz ---

	function testFuzz_ClaimAmountIsAlwaysFaucetAmount(address user) public {
		vm.assume(user != address(0));
		vm.assume(user != address(faucet)); // self-transfer leaves balance unchanged
		vm.assume(!faucet.hasClaimed(user));

		uint256 before = token.balanceOf(user);
		vm.prank(user);
		faucet.claim();

		assertEq(
			token.balanceOf(user),
			before + faucet.FAUCET_AMOUNT(),
			"received amount must equal FAUCET_AMOUNT"
		);
	}

	function testFuzz_CannotClaimTwice(address user) public {
		vm.assume(user != address(0));
		vm.assume(!faucet.hasClaimed(user));

		vm.prank(user);
		faucet.claim();

		vm.prank(user);
		vm.expectRevert(MiniDaoFaucet.AlreadyClaimed.selector);
		faucet.claim();
	}

	function testFuzz_FaucetEmptyWhenBalanceBelowThreshold(uint256 balance) public {
		balance = bound(balance, 0, faucet.FAUCET_AMOUNT() - 1);

		MiniDaoToken freshToken     = new MiniDaoToken(DEPLOYER, makeAddr("FT_FUZZ"));
		MiniDaoFaucet partialFaucet = new MiniDaoFaucet(address(freshToken));

		if (balance > 0) {
			vm.prank(DEPLOYER);
			freshToken.transfer(address(partialFaucet), balance);
		}

		vm.prank(USER_C);
		vm.expectRevert(MiniDaoFaucet.FaucetEmpty.selector);
		partialFaucet.claim();
	}

	// --- TimeLock Fuzz ---

	function testFuzz_TimelockRevertsBeforeDelay(uint256 warpSeconds) public {
		warpSeconds = bound(warpSeconds, 0, MIN_DELAY - 1);

		address[] memory p   = new address[](0);
		address[] memory e   = new address[](0);
		MiniDaoTimeLock tl   = new MiniDaoTimeLock(MIN_DELAY, p, e, DEPLOYER);

		vm.startPrank(DEPLOYER);
		tl.grantRole(tl.PROPOSER_ROLE(), DEPLOYER);
		tl.grantRole(tl.EXECUTOR_ROLE(), DEPLOYER);
		vm.stopPrank();

		bytes32 salt = bytes32(uint256(999));
		vm.prank(DEPLOYER);
		tl.schedule(address(this), 0, "", bytes32(0), salt, MIN_DELAY);

		vm.warp(block.timestamp + warpSeconds);

		vm.prank(DEPLOYER);
		vm.expectRevert();
		tl.execute(address(this), 0, "", bytes32(0), salt);
	}

	function testFuzz_TimelockSucceedsAfterDelay(uint256 extraSeconds) public {
		extraSeconds = bound(extraSeconds, 0, 365 days);

		address[] memory p   = new address[](0);
		address[] memory e   = new address[](0);
		MiniDaoTimeLock tl   = new MiniDaoTimeLock(MIN_DELAY, p, e, DEPLOYER);
		TimelockNoopTarget noopTgt = new TimelockNoopTarget();

		vm.startPrank(DEPLOYER);
		tl.grantRole(tl.PROPOSER_ROLE(), DEPLOYER);
		tl.grantRole(tl.EXECUTOR_ROLE(), DEPLOYER);
		vm.stopPrank();

		bytes32 salt = bytes32(uint256(888));
		vm.prank(DEPLOYER);
		tl.schedule(address(noopTgt), 0, "", bytes32(0), salt, MIN_DELAY);

		vm.warp(block.timestamp + MIN_DELAY + extraSeconds);
		vm.prank(DEPLOYER);
		tl.execute(address(noopTgt), 0, "", bytes32(0), salt); // should not revert
	}

	// --- Governance Fuzz ---

	function testFuzz_ProposalIdDeterministic(
		string memory descA,
		string memory descB
	) public {
		vm.assume(keccak256(bytes(descA)) != keccak256(bytes(descB)));

		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldataArr,
		) = _buildProposal(address(voteBox), descA);

		vm.prank(USER_A);
		uint256 idA = governance.propose(targets, values, calldataArr, descA);

		(
			address[] memory targets2,
			uint256[] memory values2,
			bytes[] memory calldataArr2,
		) = _buildProposal(address(voteBox), descB);

		vm.prank(USER_A);
		uint256 idB = governance.propose(targets2, values2, calldataArr2, descB);

		assertFalse(idA == idB, "different descriptions must yield different proposalIds");
	}

	function testFuzz_VoteWeightBoundedByDelegation(uint256 delegateAmount) public {
		delegateAmount = bound(delegateAmount, 1, token.balanceOf(address(timelock)));

		address voter = makeAddr("FUZZ_VOTER");
		vm.prank(address(timelock));
		token.transfer(voter, delegateAmount);
		vm.prank(voter);
		token.delegate(voter);

		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldataArr,
		) = _buildProposal(address(voteBox), "Fuzz vote weight");

		vm.prank(voter);
		uint256 pid = governance.propose(targets, values, calldataArr, "Fuzz vote weight");
		uint256 snapshotBlock = governance.proposalSnapshot(pid);

		_passVotingDelay();

		vm.prank(voter);
		governance.castVote(pid, 1);

		(, uint256 forVotes,) = governance.proposalVotes(pid);
		assertLe(
			forVotes,
			token.getPastVotes(voter, snapshotBlock),
			"vote weight must not exceed past votes at snapshot"
		);
	}

	function testFuzz_QuorumBoundaryAroundThreeHundredTokens(uint256 voteWeight) public {
		voteWeight = bound(voteWeight, 0, governance.quorum(block.number) * 3);

		address[] memory p   = new address[](0);
		address[] memory e   = new address[](0);
		MiniDaoToken t       = new MiniDaoToken(DEPLOYER, makeAddr("QFUZZ"));
		MiniDaoTimeLock l    = new MiniDaoTimeLock(MIN_DELAY, p, e, DEPLOYER);
		MiniDaoGovernance g  = new MiniDaoGovernance(t, l);

		address voter = makeAddr("QFUZZ_V");

		if (voteWeight > 0) {
			vm.prank(DEPLOYER);
			t.transfer(voter, voteWeight);
			vm.prank(voter);
			t.delegate(voter);
		} else {
			// Delegate DEPLOYER so they have proposer power
			vm.prank(DEPLOYER);
			t.delegate(DEPLOYER);
		}

		address proposerAddr = voteWeight > 0 ? voter : DEPLOYER;

		vm.startPrank(DEPLOYER);
		l.grantRole(l.PROPOSER_ROLE(), proposerAddr);
		l.grantRole(l.EXECUTOR_ROLE(), address(0));
		vm.stopPrank();

		address[] memory targets   = new address[](1);
		uint256[] memory values    = new uint256[](1);
		bytes[]   memory calldatas = new bytes[](1);
		targets[0]   = address(this);
		calldatas[0] = "";

		vm.prank(proposerAddr);
		uint256 pid = g.propose(targets, values, calldatas, "Quorum boundary fuzz");

		vm.roll(block.number + g.votingDelay() + 1);
		vm.warp(block.timestamp + g.votingDelay() + 1);

		if (voteWeight > 0) {
			vm.prank(voter);
			g.castVote(pid, 1);
		}

		vm.roll(block.number + g.votingPeriod() + 1);
		vm.warp(block.timestamp + g.votingPeriod() + 1);

		uint256 quorum = g.quorum(block.number);
		if (voteWeight >= quorum && voteWeight > 0) {
			assertEq(uint256(g.state(pid)), 4, "Succeeded - at or above quorum");
		} else {
			assertEq(uint256(g.state(pid)), 3, "Defeated - below quorum or no votes");
		}
	}

	// --- VoteBox Fuzz ---

	function testFuzz_OnlyOwnerCanCallStoreVote(address caller) public {
		vm.assume(caller != voteBox.owner());
		vm.assume(caller != address(0));

		vm.prank(caller);
		vm.expectRevert();
		voteBox.storeVote();
	}

	function testFuzz_VoteCountNeverOverflows(uint256 callCount) public {
		callCount = bound(callCount, 0, 1000);

		for (uint256 i; i < callCount; i++) {
			vm.prank(address(timelock));
			voteBox.storeVote();
		}

		assertEq(voteBox.getVote(), callCount, "vote count must equal number of calls");
	}

	// --- Governance getVotes Fuzz ---

	/// @dev Verify that the public getVotes() normalisation threshold (>=10 tokens -> 1, else -> 0)
	/// holds for the full uint96 token-amount space.
	function testFuzz_GetVotesNormalisesToOneOrZero(uint96 rawTokens) public {
		rawTokens = uint96(bound(uint256(rawTokens), 0, 500e18));

		address holder = makeAddr("FUZZ_GET_VOTES_HOLDER");
		if (rawTokens > 0) {
			// timelock holds 70% of total supply — plenty of room for any fuzz input ≤500e18
			vm.prank(address(timelock));
			token.transfer(holder, rawTokens);
		}
		vm.prank(holder);
		token.delegate(holder);

		vm.roll(block.number + 1);
		uint256 votes = governance.getVotes(holder, block.number - 1);

		if (rawTokens >= 10e18) {
			assertEq(votes, 1, "should have 1 vote unit with >= 10 tokens");
		} else {
			assertEq(votes, 0, "should have 0 vote units with < 10 tokens");
		}
	}
}
