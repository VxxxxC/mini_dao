// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract VoteBox is Ownable {
    uint256 private vote_count;

    event VoteCasted(uint256 vote_count);

// WARN: initial owner is set to msg.sender, but eventually will transfer the ownership to the timelock contract and completely decentralize 
    constructor() Ownable(msg.sender) {}

    function getVote() external view returns (uint256) {
        return vote_count;
    }

    function storeVote(uint256 _vote_count) external onlyOwner {
        vote_count = _vote_count;
        emit VoteCasted(_vote_count);
    }

}