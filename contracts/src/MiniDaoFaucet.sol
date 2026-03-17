// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract MiniDaoFaucet {
	error AlreadyClaimed();
	error TransferFailed();
	error FaucetEmpty();

	uint256 public constant FAUCET_AMOUNT = 100 * 10 ** 18;

	mapping(address => bool) public hasClaimedFaucet;
	IERC20 public immutable token;
	constructor(address _tokenAddress) {
		token = IERC20(_tokenAddress);
	}

	function claim() external {

		if (hasClaimedFaucet[msg.sender]) {
			revert AlreadyClaimed();
		}

		if (token.balanceOf(address(this)) < FAUCET_AMOUNT) {
            revert FaucetEmpty();
        }

		hasClaimedFaucet[msg.sender] = true;


		bool success = token.transfer(msg.sender, FAUCET_AMOUNT);
        if (!success) {
            revert TransferFailed();
        }
	}

	function hasClaimed(address user) external view returns (bool) {
		return hasClaimedFaucet[user];
	}
}
