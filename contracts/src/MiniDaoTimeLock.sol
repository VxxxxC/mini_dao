// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {TimelockController} from '@openzeppelin/contracts/governance/TimelockController.sol';

contract MiniDaoTimeLock is TimelockController {
	/**
	 * @param minDelay 提案通過後，最少要等幾耐先可以執行 (以秒計，例如 2 days = 172800)
	 * @param proposers 邊個有權將通過咗嘅提案放入 Timelock (稍後會設定為 Governor 合約)
	 * @param executors 邊個有權喺時間到咗之後撳「執行」 (通常設為 address(0) 代表任何人都可以撳)
	 * @param admin 邊個有權改 Timelock 嘅設定 (稍後會將 Admin 權限交畀 Timelock 自己，實現真正去中心化)
	 */
	constructor(
		uint256 minDelay,
		address[] memory proposers,
		address[] memory executors,
		address admin
	) TimelockController(minDelay, proposers, executors, admin) {}
}
