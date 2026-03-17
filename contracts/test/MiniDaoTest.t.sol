// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MiniDaoToken} from "../src/MiniDaoToken.sol";
import {MiniDaoGovernance} from "../src/MiniDaoGovernance.sol";
import {MiniDaoTimeLock} from "../src/MiniDaoTimeLock.sol";
import {MiniDaoVoteBox} from "../src/MiniDaoVoteBox.sol";
import {MiniDaoFaucet} from "../src/MiniDaoFaucet.sol";

contract MiniDaoTest is Test {
    MiniDaoToken token;
    MiniDaoTimeLock timelock;
    MiniDaoGovernance governance;
    MiniDaoVoteBox voteBox;
    MiniDaoFaucet faucet;
    uint256 s_minDelay = 1 hours;
    address[] s_proposers = new address[](0);
    address[] s_executors = new address[](0);

    address public DEPLOYER = makeAddr("DEPLOYER");
    address public USER = makeAddr("USER");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;

    // NOTE: setUp() will initialize and deploy the contracts
    function setUp() public {

        // 1. Deploy token, timelock and governance contracts
        timelock = new MiniDaoTimeLock(s_minDelay, s_proposers, s_executors, USER);

        token = new MiniDaoToken(DEPLOYER, address(timelock));

        faucet = new MiniDaoFaucet(address(token));

        vm.startPrank(DEPLOYER);
        uint256 deployerBalance = token.balanceOf(DEPLOYER);
        token.transfer(address(faucet), deployerBalance);
        vm.stopPrank();
        
        vm.startPrank(USER);
        
        faucet.claim();

        token.delegate(USER);

        governance = new MiniDaoGovernance(token, timelock);

        // 2. Grant roles to the governance contract
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governance));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governance));


        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0)); // TEST: for testing purpose only, allow anyone to execute the proposal

        // 3. Revoke the timelock ownership from the deployer (USER)
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), USER);
        vm.stopPrank();

        voteBox = new MiniDaoVoteBox();
        voteBox.transferOwnership(address(timelock));
        vm.stopPrank();
    }

    function testDeployerTransferedTokenToFaucet() public view {
        uint256 deployerBalance = token.balanceOf(DEPLOYER);
        uint256 faucetBalance = token.balanceOf(address(faucet));
        uint256 expectedFaucetBalance = (token.TOTAL_SUPPLY() * 30) / 100 - MiniDaoFaucet(address(faucet)).FAUCET_AMOUNT(); // TEST: Because 'USER' claimed, so also need to minus the claimed amount
        assertEq(deployerBalance, 0);
        assertEq(faucetBalance, expectedFaucetBalance);
    }

    function testCannotUpdateVoteBoxWithoutGovernance() public {
        vm.expectRevert();
        voteBox.storeVote(1);
    }

    function testUpdateVoteBoxWithGovernanceProposal() public {
        vm.startPrank(USER);

        // 1. Create proposal to update the VoteBox
        uint256 valueToStore = 999;
        bytes memory encodedFunctionCall = abi.encodeWithSignature("storeVote(uint256)", valueToStore);
        string memory description = "Store vote 1 in VoteBox";

        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(voteBox));

        // 2. Propose to DAO
        uint256 proposalId = governance.propose(targets, values, calldatas, description);
        console.log("Initial Proposal state:", uint256(governance.state(proposalId))); // NOTE: reference to IGovernor contract, ProposalState enum

        vm.warp(block.timestamp + governance.votingDelay() + 1);
        vm.roll(block.number + governance.votingDelay() + 1);
        console.log("After 1 Day, Proposal state:", uint256(governance.state(proposalId)));

        // 3. Vote
        string memory reason = "I Vote Yes!!";
        uint8 votingWay = 1; // 0 = Against, 1 = For, 2 = Abstain
        governance.castVoteWithReason(proposalId, votingWay, reason);
        console.log("Vote casted, Proposal state:", uint256(governance.state(proposalId)));

        vm.warp(block.timestamp + governance.votingPeriod() + 1);
        vm.roll(block.number + governance.votingPeriod() + 1);
        console.log("After 1 Week, Proposal state:", uint256(governance.state(proposalId)));

        // 4. Queue the proposal
        bytes32 descriptionHash = keccak256(abi.encodePacked((description)));
        governance.queue(targets, values, calldatas, descriptionHash);

        // 5. Execute the proposal
        vm.warp(block.timestamp + s_minDelay + 1);
        vm.roll(block.number + s_minDelay + 1);
        governance.execute(targets, values, calldatas, descriptionHash);
        console.log("After execution, Proposal state:", uint256(governance.state(proposalId)));

        vm.stopPrank();

        // 6. Check if the VoteBox is updated
        assertEq(voteBox.getVote(), valueToStore);
        console.log("Expected value : ", valueToStore);
        console.log("VoteBox : ", voteBox.getVote());
    }
}
