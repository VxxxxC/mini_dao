// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.6.0

pragma solidity ^0.8.24;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {ERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import {ERC20Votes} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol';
import {Nonces} from '@openzeppelin/contracts/utils/Nonces.sol';

contract MiniDaoToken is ERC20, ERC20Permit, ERC20Votes {
	error InvalidAddress();
	uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18; // Total supply MiniDaoToken is 1 billion tokens, with 18 decimals

	constructor(address initialDistributor, address treasury) ERC20('Mini Dao', 'MDAO') ERC20Permit('MiniDaoToken') {

		if (treasury == address(0) || initialDistributor == address(0)) {
			revert InvalidAddress();
		}

        uint256 initialCirculation = (TOTAL_SUPPLY * 30) / 100;
        _mint(initialDistributor, initialCirculation);

        uint256 treasuryAllocation = TOTAL_SUPPLY - initialCirculation;
        _mint(treasury, treasuryAllocation);
	}


	// WARN: The following functions are overrides required by Solidity.
	function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
		super._update(from, to, value);
	}

	function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
		return super.nonces(owner);
	}
}
