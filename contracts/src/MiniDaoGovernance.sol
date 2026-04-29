// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.6.0
pragma solidity ^0.8.27;

import {console} from "forge-std/console.sol";
import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract MiniDaoGovernance is Governor, GovernorCountingSimple, GovernorVotes, GovernorTimelockControl {
    // WARN: Minimum number of 3 votes required for a proposal to pass, it is better use `QuorumFraction` instead of hardcode a fix number of votes
    uint256 public constant QUORUM_VOTES = 300 * 10 ** 18; // TEST: 300 tokens = 3 votes = 3 peoples/wallets

    constructor(IVotes _token, TimelockController _timelock)
        Governor("Mini Governor")
        GovernorVotes(_token)
        GovernorTimelockControl(_timelock)
    {}

    // COL: Governor Config
    function quorum(
        uint256 /* blockNumber */
    )
        public
        pure
        override
        returns (uint256)
    {
        return QUORUM_VOTES;
    }

    // WARN: It is tricky point, it actually representing the block , not the second
    // INFO: If running `anvil --block-time 2` = [1 block per 2 seconds] * 30 = 60 seconds
    // If running on eth mainnet or testnet , it should be [1 block per 12 seconds] * 30 = 360 seconds
    function votingDelay() public pure override returns (uint256) {
        return 30 seconds; // TEST: for test only, normally 1 day
    }

    // INFO: If running `anvil --block-time 2` = [1 block per 2 seconds] * 60(1min) = 120 seconds
    // If running on eth mainnet or testnet , it should be [1 block per 12 seconds] * 60(1min) = 720 seconds
    function votingPeriod() public pure override returns (uint256) {
        return 1 minutes; // TEST: for test only, normally 1 week
    }

    // COL: public view functions

    function countdownStartVoting(uint256 proposalId) public view returns (uint256) {
        uint256 currentTime = clock();
        uint256 proposalStartTime = proposalSnapshot(proposalId);
        if (currentTime >= proposalStartTime) {
            return 0; // Voting has already started
        } else {
            return proposalStartTime - currentTime; // Time remaining until voting starts
        }
    }

    // COL: public override functions

    function propose(address target) public returns (uint256 proposalId) {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Create New MiniDao Proposal";

        bytes memory encodedFunctionCall = abi.encodeWithSignature("storeVote()");

        targets[0] = target;
        values[0] = 0;
        calldatas[0] = encodedFunctionCall;

        proposalId = super.propose(targets, values, calldatas, description);
    }

    function castVote(uint256 proposalId, uint8 support) public override(Governor) returns (uint256) {
        return super.castVote(proposalId, support);
    }

    function getVotes(address account, uint256 blockNumber) public view override(Governor) returns (uint256) {
        // Get the actual token voted by the user
        uint256 actualTokenVotes = super.getVotes(account, blockNumber);

        // if greater than or equal to 10 tokens, return 1 vote, else return 0 votes (no voting power)
        if (actualTokenVotes >= 10 * 10 ** 18) {
            return 1;
        } else {
            return 0; // not enough 10 tokens, no voting power
        }
    }

    // WARN: The following functions are overrides required by Solidity.

    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }
}
