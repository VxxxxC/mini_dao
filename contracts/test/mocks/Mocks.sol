// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MiniDaoFaucet}     from "../../src/MiniDaoFaucet.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IERC20}             from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// ============================================================
// Mock ERC20
// ============================================================

/// @dev Mock ERC20 whose transfer() always returns false - for TransferFailed coverage
contract MockFailToken is IERC20 {
	function totalSupply() external pure override returns (uint256) { return type(uint256).max; }
	function balanceOf(address) external pure override returns (uint256) { return type(uint256).max; }
	function transfer(address, uint256) external pure override returns (bool) { return false; }
	function allowance(address, address) external pure override returns (uint256) { return 0; }
	function approve(address, uint256) external pure override returns (bool) { return false; }
	function transferFrom(address, address, uint256) external pure override returns (bool) { return false; }
}

// ============================================================
// Re-entrancy Attack Contracts
// ============================================================

/// @dev Re-entrancy attacker for the faucet
contract ReentrantFaucetAttack {
	MiniDaoFaucet public faucet;
	bool private _attacking;

	constructor(address _faucet) {
		faucet = MiniDaoFaucet(_faucet);
	}

	function attack() external {
		faucet.claim();
	}

	// Called when tokens are transferred to this contract via any low-level hook
	fallback() external {
		if (!_attacking) {
			_attacking = true;
			faucet.claim(); // second claim must revert AlreadyClaimed
		}
	}

	receive() external payable {}
}

/// @dev Malicious timelock target for re-entrancy test
contract ReentrantTimelockTarget {
	TimelockController public timelock;
	bool private _entered;

	function setTimelock(address _t) external {
		timelock = TimelockController(payable(_t));
	}

	function trigger() external {
		// Re-entry attempt is blocked by timelock's operation-state guard
		if (!_entered) {
			_entered = true;
		}
	}
}

// ============================================================
// Generic Test Targets
// ============================================================

/// @dev No-op target for timelock execute tests — accepts any call silently
contract TimelockNoopTarget {
	fallback() external payable {}
	receive()  external payable {}
}
