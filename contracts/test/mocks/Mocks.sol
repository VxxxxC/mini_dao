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

/// @dev Callback interface used by MockCallbackToken to notify token recipients
interface ITokenReceiver {
	function onTokenReceived(address from, uint256 amount) external;
}

/// @dev Mock ERC20 that calls onTokenReceived on the recipient during transfer,
///      simulating an ERC777/ERC1363-style callback used to trigger re-entrancy.
contract MockCallbackToken is IERC20 {
	mapping(address => uint256) private _balances;
	uint256 private _totalSupply;

	constructor() {
		uint256 initialSupply = 1_000_000 * 10 ** 18;
		_balances[msg.sender] = initialSupply;
		_totalSupply = initialSupply;
	}

	function totalSupply() external view override returns (uint256) { return _totalSupply; }
	function balanceOf(address account) external view override returns (uint256) { return _balances[account]; }
	function allowance(address, address) external pure override returns (uint256) { return 0; }
	function approve(address, uint256) external pure override returns (bool) { return true; }
	function transferFrom(address, address, uint256) external pure override returns (bool) { return false; }

	function transfer(address to, uint256 amount) external override returns (bool) {
		require(_balances[msg.sender] >= amount, "MockCallbackToken: insufficient balance");
		_balances[msg.sender] -= amount;
		_balances[to] += amount;
		// Trigger re-entrancy callback if recipient is a contract (ERC1363-style)
		if (to.code.length > 0) {
			try ITokenReceiver(to).onTokenReceived(msg.sender, amount) {} catch {}
		}
		return true;
	}
}

/// @dev Re-entrancy attacker for the faucet.
///      Implements ITokenReceiver so that MockCallbackToken can trigger a re-entrant
///      claim() call on the faucet during the token transfer.
contract ReentrantFaucetAttack is ITokenReceiver {
	MiniDaoFaucet public faucet;

	constructor(address _faucet) {
		faucet = MiniDaoFaucet(_faucet);
	}

	/// @dev Entry point: initiates the first claim which may trigger a callback.
	function attack() external {
		faucet.claim();
	}

	/// @dev Called by MockCallbackToken during transfer to this contract.
	///      Attempts a second claim() – must revert with AlreadyClaimed due to CEI.
	function onTokenReceived(address /*from*/, uint256 /*amount*/) external override {
		faucet.claim();
	}

	receive() external payable {}
}

/// @dev Malicious timelock target for re-entrancy test.
///      When trigger() is called during timelock execution, it re-calls timelock.execute()
///      on the SAME operation. The inner execute() succeeds and marks the operation Done;
///      the outer _afterCall() then finds it no longer Ready and reverts —
///      proving the state-machine guards against double-execution.
contract ReentrantTimelockTarget {
	TimelockController public timelock;
	bytes32 public salt;
	bool private _triggered;

	function setReentryParams(address _t, bytes32 _salt) external {
		timelock = TimelockController(payable(_t));
		salt = _salt;
	}

	/// @dev Called by the timelock during execute(). Attempts a re-entrant execute()
	///      on the exact same operation to prove state-machine re-entrancy protection.
	function trigger() external {
		if (_triggered) return; // prevent infinite recursion
		_triggered = true;
		bytes memory callData = abi.encodeWithSignature("trigger()");
		// Inner execute() succeeds → marks op as Done.
		// Outer _afterCall() finds op is no longer Ready → reverts entire tx.
		try timelock.execute(address(this), 0, callData, bytes32(0), salt) {} catch {}
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
