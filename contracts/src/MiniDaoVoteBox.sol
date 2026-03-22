// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MiniDaoVoteBox is Ownable {
    uint256 private vote_count = 0;

    event VoteCasted(uint256 vote_count);

    // WARN: initial owner is set to msg.sender, but eventually will transfer the ownership to the timelock contract and completely decentralize
    constructor() Ownable(msg.sender) {}

    function getVote() external view returns (uint256) {
        return vote_count;
    }

    function storeVote() external onlyOwner {
        vote_count ++;
        emit VoteCasted(vote_count);
    }
}
