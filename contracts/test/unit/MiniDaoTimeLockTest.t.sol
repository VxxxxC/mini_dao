// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MiniDaoTestBase}    from "../base/MiniDaoTestBase.t.sol";
import {TimelockNoopTarget} from "../mocks/Mocks.sol";
import {MiniDaoTimeLock}    from "../../src/MiniDaoTimeLock.sol";

contract MiniDaoTimeLockTest is MiniDaoTestBase {
	bytes32 internal PROPOSER_ROLE;
	bytes32 internal EXECUTOR_ROLE;
	bytes32 internal CANCELLER_ROLE;
	bytes32 internal DEFAULT_ADMIN_ROLE;

	TimelockNoopTarget internal noopTarget;

	function setUp() public {
		address[] memory proposers = new address[](0);
		address[] memory executors = new address[](0);
		timelock = new MiniDaoTimeLock(MIN_DELAY, proposers, executors, DEPLOYER);

		// Cache roles to avoid staticcall consuming vm.prank
		PROPOSER_ROLE      = timelock.PROPOSER_ROLE();
		EXECUTOR_ROLE      = timelock.EXECUTOR_ROLE();
		CANCELLER_ROLE     = timelock.CANCELLER_ROLE();
		DEFAULT_ADMIN_ROLE = timelock.DEFAULT_ADMIN_ROLE();

		noopTarget = new TimelockNoopTarget();
	}

	// --- Constructor & Roles ---

	function testMinDelayIsSetCorrectly() public view {
		assertEq(timelock.getMinDelay(), MIN_DELAY, "minDelay mismatch");
	}

	function testAdminHasDefaultAdminRole() public view {
		assertTrue(timelock.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER), "DEPLOYER should have admin role");
	}

	function testAdminCanGrantProposerRole() public {
		vm.startPrank(DEPLOYER);
		timelock.grantRole(PROPOSER_ROLE, USER_A);
		vm.stopPrank();
		assertTrue(timelock.hasRole(PROPOSER_ROLE, USER_A), "USER_A should have PROPOSER_ROLE");
	}

	function testAdminCanGrantExecutorRole() public {
		vm.startPrank(DEPLOYER);
		timelock.grantRole(EXECUTOR_ROLE, USER_A);
		vm.stopPrank();
		assertTrue(timelock.hasRole(EXECUTOR_ROLE, USER_A), "USER_A should have EXECUTOR_ROLE");
	}

	function testNonAdminCannotGrantRole() public {
		vm.startPrank(ATTACKER);
		vm.expectRevert();
		timelock.grantRole(PROPOSER_ROLE, ATTACKER);
		vm.stopPrank();
	}

	// --- minDelay Enforcement ---

	function testCannotExecuteBeforeMinDelay() public {
		vm.startPrank(DEPLOYER);
		timelock.grantRole(PROPOSER_ROLE, DEPLOYER);
		timelock.grantRole(EXECUTOR_ROLE, DEPLOYER);
		vm.stopPrank();

		bytes32 salt = bytes32(uint256(1));
		vm.startPrank(DEPLOYER);
		timelock.schedule(address(noopTarget), 0, "", bytes32(0), salt, MIN_DELAY);
		vm.stopPrank();

		vm.warp(block.timestamp + MIN_DELAY - 1);
		vm.expectRevert();
		vm.startPrank(DEPLOYER);
		timelock.execute(address(noopTarget), 0, "", bytes32(0), salt);
		vm.stopPrank();
	}

	function testCanExecuteAfterMinDelay() public {
		vm.startPrank(DEPLOYER);
		timelock.grantRole(PROPOSER_ROLE, DEPLOYER);
		timelock.grantRole(EXECUTOR_ROLE, DEPLOYER);
		vm.stopPrank();

		bytes32 salt = bytes32(uint256(2));
		vm.startPrank(DEPLOYER);
		timelock.schedule(address(noopTarget), 0, "", bytes32(0), salt, MIN_DELAY);
		vm.stopPrank();

		vm.warp(block.timestamp + MIN_DELAY + 1);
		vm.startPrank(DEPLOYER);
		timelock.execute(address(noopTarget), 0, "", bytes32(0), salt); // should not revert
		vm.stopPrank();
	}

	function testCanExecuteAtExactlyMinDelay() public {
		vm.startPrank(DEPLOYER);
		timelock.grantRole(PROPOSER_ROLE, DEPLOYER);
		timelock.grantRole(EXECUTOR_ROLE, DEPLOYER);
		vm.stopPrank();

		bytes32 salt      = bytes32(uint256(3));
		uint256 scheduled = block.timestamp;

		vm.startPrank(DEPLOYER);
		timelock.schedule(address(noopTarget), 0, "", bytes32(0), salt, MIN_DELAY);
		vm.stopPrank();

		vm.warp(scheduled + MIN_DELAY);
		vm.startPrank(DEPLOYER);
		timelock.execute(address(noopTarget), 0, "", bytes32(0), salt); // should not revert
		vm.stopPrank();
	}

	// --- Role Revocation & Decentralisation ---

	function testAdminCanRevokeItsOwnAdminRole() public {
		vm.startPrank(DEPLOYER);
		timelock.revokeRole(DEFAULT_ADMIN_ROLE, DEPLOYER);
		vm.stopPrank();

		assertFalse(timelock.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER), "admin role revoked");

		vm.startPrank(DEPLOYER);
		vm.expectRevert();
		timelock.grantRole(DEFAULT_ADMIN_ROLE, DEPLOYER);
		vm.stopPrank();
	}

	function testTimelockSelfAdmin() public {
		vm.startPrank(DEPLOYER);
		timelock.grantRole(DEFAULT_ADMIN_ROLE, address(timelock));
		vm.stopPrank();

		assertTrue(
			timelock.hasRole(DEFAULT_ADMIN_ROLE, address(timelock)),
			"timelock should have self-admin role"
		);
	}

	// --- Schedule & Cancel ---

	function testScheduleCreatesOperation() public {
		vm.startPrank(DEPLOYER);
		timelock.grantRole(PROPOSER_ROLE, DEPLOYER);
		timelock.schedule(address(noopTarget), 0, "", bytes32(0), bytes32(uint256(10)), MIN_DELAY);
		vm.stopPrank();

		bytes32 id = timelock.hashOperation(address(noopTarget), 0, "", bytes32(0), bytes32(uint256(10)));
		assertTrue(timelock.isOperation(id), "operation should exist");
	}

	function testCancelRemovesPendingOperation() public {
		vm.startPrank(DEPLOYER);
		timelock.grantRole(PROPOSER_ROLE, DEPLOYER);
		timelock.grantRole(CANCELLER_ROLE, DEPLOYER);
		timelock.schedule(address(noopTarget), 0, "", bytes32(0), bytes32(uint256(11)), MIN_DELAY);
		vm.stopPrank();

		bytes32 id = timelock.hashOperation(address(noopTarget), 0, "", bytes32(0), bytes32(uint256(11)));
		assertTrue(timelock.isOperation(id), "operation should exist before cancel");

		vm.startPrank(DEPLOYER);
		timelock.cancel(id);
		vm.stopPrank();

		assertFalse(timelock.isOperation(id), "operation should be removed after cancel");
	}

	function testCancelRevertsOnExecutedOperation() public {
		vm.startPrank(DEPLOYER);
		timelock.grantRole(PROPOSER_ROLE, DEPLOYER);
		timelock.grantRole(EXECUTOR_ROLE, DEPLOYER);
		timelock.grantRole(CANCELLER_ROLE, DEPLOYER);
		timelock.schedule(address(noopTarget), 0, "", bytes32(0), bytes32(uint256(12)), MIN_DELAY);
		vm.stopPrank();

		vm.warp(block.timestamp + MIN_DELAY + 1);
		vm.startPrank(DEPLOYER);
		timelock.execute(address(noopTarget), 0, "", bytes32(0), bytes32(uint256(12)));
		vm.stopPrank();

		bytes32 id = timelock.hashOperation(address(noopTarget), 0, "", bytes32(0), bytes32(uint256(12)));
		vm.startPrank(DEPLOYER);
		vm.expectRevert();
		timelock.cancel(id); // cannot cancel executed op
		vm.stopPrank();
	}
}
