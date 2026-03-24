// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats}  from "forge-std/StdCheats.sol";
import {StdUtils}   from "forge-std/StdUtils.sol";

import {MiniDaoToken}      from "../../src/MiniDaoToken.sol";
import {MiniDaoFaucet}     from "../../src/MiniDaoFaucet.sol";
import {MiniDaoGovernance} from "../../src/MiniDaoGovernance.sol";
import {MiniDaoTimeLock}   from "../../src/MiniDaoTimeLock.sol";
import {MiniDaoVoteBox}    from "../../src/MiniDaoVoteBox.sol";

contract MiniDaoHandler is CommonBase, StdCheats, StdUtils {
	MiniDaoToken      internal token;
	MiniDaoFaucet     internal faucet;
	MiniDaoGovernance internal governance;
	MiniDaoTimeLock   internal timelock;
	MiniDaoVoteBox    internal voteBox;

	// Ghost variables
	uint256 public ghost_totalClaims;
	uint256 public ghost_voteCount;
	mapping(address => bool) public ghost_hasClaimed;

	address[] internal _actors;

	constructor(
		address _token,
		address _faucet,
		address _governance,
		address _timelock,
		address _voteBox
	) {
		token      = MiniDaoToken(_token);
		faucet     = MiniDaoFaucet(_faucet);
		governance = MiniDaoGovernance(payable(_governance));
		timelock   = MiniDaoTimeLock(payable(_timelock));
		voteBox    = MiniDaoVoteBox(_voteBox);

		_actors.push(makeAddr("H_USER_A"));
		_actors.push(makeAddr("H_USER_B"));
		_actors.push(makeAddr("H_USER_C"));
		_actors.push(makeAddr("H_USER_D"));
		_actors.push(makeAddr("H_USER_E"));
	}

	function claim(uint256 actorSeed) external {
		address actor = _actors[actorSeed % _actors.length];
		if (faucet.hasClaimed(actor)) return;
		if (token.balanceOf(address(faucet)) < faucet.FAUCET_AMOUNT()) return;
		vm.prank(actor);
		faucet.claim();
		ghost_totalClaims++;
		ghost_hasClaimed[actor] = true;
	}

	function delegate(uint256 actorSeed, uint256 delegateeSeed) external {
		address actor     = _actors[actorSeed     % _actors.length];
		address delegatee = _actors[delegateeSeed % _actors.length];
		vm.prank(actor);
		token.delegate(delegatee);
	}

	function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
		address from = _actors[fromSeed % _actors.length];
		address to   = _actors[toSeed   % _actors.length];
		uint256 bal  = token.balanceOf(from);
		if (bal == 0) return;
		amount = bound(amount, 1, bal);
		vm.prank(from);
		token.transfer(to, amount);
	}

	function storeVoteAsOwner() external {
		vm.prank(address(timelock));
		voteBox.storeVote();
		ghost_voteCount++;
	}

	function warpTime(uint256 seconds_) external {
		seconds_ = bound(seconds_, 0, 7 days);
		vm.warp(block.timestamp + seconds_);
		vm.roll(block.number + 1);
	}

	function actors() external view returns (address[] memory) {
		return _actors;
	}
}
