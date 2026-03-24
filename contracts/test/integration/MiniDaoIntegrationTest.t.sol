// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MiniDaoTestBase} from "../base/MiniDaoTestBase.t.sol";
import {MiniDaoToken}    from "../../src/MiniDaoToken.sol";
import {MiniDaoTimeLock} from "../../src/MiniDaoTimeLock.sol";
import {MiniDaoGovernance} from "../../src/MiniDaoGovernance.sol";
import {MiniDaoFaucet}   from "../../src/MiniDaoFaucet.sol";

contract MiniDaoIntegrationTest is MiniDaoTestBase {
	function setUp() public {
		_deployAll();
	}

	function testFullGovernanceLifecycle_StoreVote() public {
		_claimAndDelegate(USER_A);
		_proposeVoteQueueExecute(USER_A, "Integration: single voter");
		assertEq(voteBox.getVote(), 1, "vote count should be 1 after execution");
	}

	function testFullGovernanceLifecycle_MultipleVoters() public {
		_claimAndDelegate(USER_A);
		_claimAndDelegate(USER_B);

		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldatas,
			bytes32 descriptionHash
		) = _buildProposal(address(voteBox), "Multi voter proposal");

		vm.prank(USER_A);
		uint256 id = governance.propose(targets, values, calldatas, "Multi voter proposal");

		_passVotingDelay();
		vm.prank(USER_A);
		governance.castVote(id, 1);
		vm.prank(USER_B);
		governance.castVote(id, 1);
		_passVotingPeriod();
		governance.queue(targets, values, calldatas, descriptionHash);
		_passTimelockDelay();
		governance.execute(targets, values, calldatas, descriptionHash);

		assertEq(voteBox.getVote(), 1, "vote count should be 1");
	}

	function testProposalDefeated_QuorumNotMet() public {
		address[] memory p   = new address[](0);
		address[] memory e   = new address[](0);
		MiniDaoToken t       = new MiniDaoToken(DEPLOYER, makeAddr("IT1"));
		MiniDaoTimeLock l    = new MiniDaoTimeLock(MIN_DELAY, p, e, DEPLOYER);
		MiniDaoGovernance g  = new MiniDaoGovernance(t, l);
		address voter        = makeAddr("SMALL");

		vm.prank(DEPLOYER);
		t.transfer(voter, 4e18); // 4 tokens < 5 quorum
		vm.prank(voter);
		t.delegate(voter);

		vm.startPrank(DEPLOYER);
		l.grantRole(l.PROPOSER_ROLE(), voter);
		l.grantRole(l.EXECUTOR_ROLE(), address(0));
		vm.stopPrank();

		address[] memory targets   = new address[](1);
		uint256[] memory values    = new uint256[](1);
		bytes[]   memory calldatas = new bytes[](1);
		targets[0]   = makeAddr("NOOP");
		calldatas[0] = abi.encodeWithSignature("noop()");

		vm.prank(voter);
		uint256 pid = g.propose(targets, values, calldatas, "Below quorum integration");
		vm.roll(block.number + g.votingDelay() + 1);
		vm.warp(block.timestamp + g.votingDelay() + 1);
		vm.prank(voter);
		g.castVote(pid, 1);
		vm.roll(block.number + g.votingPeriod() + 1);
		vm.warp(block.timestamp + g.votingPeriod() + 1);

		assertEq(uint256(g.state(pid)), 3, "should be Defeated");
	}

	function testProposalDefeated_MajorityAgainst() public {
		_claimAndDelegate(USER_A);
		_claimAndDelegate(USER_B);
		_claimAndDelegate(USER_C);

		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldatas,
			bytes32 descriptionHash
		) = _buildProposal(address(voteBox), "Against majority");

		vm.prank(USER_A);
		uint256 id = governance.propose(targets, values, calldatas, "Against majority");

		_passVotingDelay();
		vm.prank(USER_A);
		governance.castVote(id, 1); // For  100
		vm.prank(USER_B);
		governance.castVote(id, 0); // Against 100
		vm.prank(USER_C);
		governance.castVote(id, 0); // Against 100

		_passVotingPeriod();
		assertEq(uint256(governance.state(id)), 3, "should be Defeated");
		(descriptionHash); // silence unused warning
	}

	function testProposalFails_ExecuteBeforeTimelockDelay() public {
		_claimAndDelegate(USER_A);

		(
			address[] memory targets,
			uint256[] memory values,
			bytes[] memory calldatas,
			bytes32 descriptionHash
		) = _buildProposal(address(voteBox), "Early execute");

		vm.prank(USER_A);
		uint256 pid = governance.propose(targets, values, calldatas, "Early execute");
		_passVotingDelay();
		vm.prank(USER_A);
		governance.castVote(pid, 1);
		_passVotingPeriod();
		governance.queue(targets, values, calldatas, descriptionHash);

		vm.expectRevert();
		governance.execute(targets, values, calldatas, descriptionHash);
	}

	function testTwoProposalsExecutedSequentially() public {
		_claimAndDelegate(USER_A);

		_proposeVoteQueueExecute(USER_A, "First proposal");
		_proposeVoteQueueExecute(USER_A, "Second proposal");

		assertEq(voteBox.getVote(), 2, "vote count should be 2 after two executions");
	}

	function testDeployerHasNoAdminRoleAfterSetup() public view {
		assertFalse(
			timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), DEPLOYER),
			"deployer should have no admin role after setup"
		);
	}

	function testGovernanceHasProposerRole() public view {
		assertTrue(
			timelock.hasRole(timelock.PROPOSER_ROLE(), address(governance)),
			"governance should have PROPOSER_ROLE"
		);
	}

	function testOnlyTimelockCanCallVoteBox() public {
		vm.prank(USER_A);
		vm.expectRevert();
		voteBox.storeVote(); // non-owner should revert

		vm.prank(address(timelock));
		voteBox.storeVote(); // timelock is owner - should succeed
	}

	function testFaucetDepletedAfterAllClaims() public {
		// Use a small dedicated faucet to avoid millions of loop iterations
		MiniDaoToken freshToken   = new MiniDaoToken(DEPLOYER, makeAddr("DRAIN_TOKEN_T"));
		MiniDaoFaucet smallFaucet = new MiniDaoFaucet(address(freshToken));
		uint256 numClaims = 5;
		uint256 faucetAmt = faucet.FAUCET_AMOUNT();
		vm.prank(DEPLOYER);
		freshToken.transfer(address(smallFaucet), faucetAmt * numClaims);

		for (uint256 i; i < numClaims; i++) {
			address user = address(uint160(uint256(keccak256(abi.encode("drain", i)))));
			vm.prank(user);
			smallFaucet.claim();
		}

		address lastUser = makeAddr("LAST_USER_DRAIN");
		vm.prank(lastUser);
		vm.expectRevert(MiniDaoFaucet.FaucetEmpty.selector);
		smallFaucet.claim();
	}
}
