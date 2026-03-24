// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {StdInvariant} from "forge-std/StdInvariant.sol";

import {MiniDaoTestBase} from "../base/MiniDaoTestBase.t.sol";
import {MiniDaoHandler}  from "./MiniDaoHandler.t.sol";

contract MiniDaoInvariantTest is StdInvariant, MiniDaoTestBase {
	MiniDaoHandler internal handler;

	uint256 internal constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;
	uint256 internal initialFaucetBalance;

	function setUp() public {
		_deployAll();

		handler = new MiniDaoHandler(
			address(token),
			address(faucet),
			address(governance),
			address(timelock),
			address(voteBox)
		);

		initialFaucetBalance = token.balanceOf(address(faucet));

		targetContract(address(handler));
	}

	function invariant_TotalSupplyIsConstant() public view {
		assertEq(token.totalSupply(), TOTAL_SUPPLY, "INVARIANT: total supply changed");
	}

	function invariant_FaucetClaimIsMonotonic() public view {
		address[] memory actors = handler.actors();
		for (uint256 i; i < actors.length; i++) {
			if (handler.ghost_hasClaimed(actors[i])) {
				assertTrue(
					faucet.hasClaimed(actors[i]),
					"INVARIANT: ghost claimed but contract disagrees"
				);
			}
		}
	}

	function invariant_FaucetNeverOverpays() public view {
		uint256 paid = initialFaucetBalance - token.balanceOf(address(faucet));
		assertEq(
			paid,
			handler.ghost_totalClaims() * faucet.FAUCET_AMOUNT(),
			"INVARIANT: faucet overpaid"
		);
	}

	function invariant_VoteCountNeverDecreases() public view {
		assertEq(
			voteBox.getVote(),
			handler.ghost_voteCount(),
			"INVARIANT: vote count diverged from ghost counter"
		);
	}

	function invariant_TokenBalanceSumEqualsSupply() public view {
		address[] memory actors = handler.actors();
		uint256 sum = token.balanceOf(address(faucet)) + token.balanceOf(address(timelock));
		for (uint256 i; i < actors.length; i++) {
			sum += token.balanceOf(actors[i]);
		}
		assertLe(sum, TOTAL_SUPPLY, "INVARIANT: tracked balances exceed total supply");
	}

	function invariant_TimelockMinDelayUnchangeable() public view {
		assertEq(timelock.getMinDelay(), MIN_DELAY, "INVARIANT: minDelay changed");
	}

	function invariant_VoteBoxOwnerIsTimelock() public view {
		assertEq(voteBox.owner(), address(timelock), "INVARIANT: voteBox owner changed");
	}

	function invariant_DeployerHasNoAdminRole() public view {
		assertFalse(
			timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), DEPLOYER),
			"INVARIANT: DEPLOYER re-gained admin role"
		);
	}
}
