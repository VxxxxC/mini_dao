---
name: smart-contract-test
description: 'Generate exhaustive Foundry test cases for Mini DAO smart contracts — covering unit tests, fuzz tests, invariant tests (StdInvariant + Handler pattern), security/attack tests (re-entrancy, flash loans, access control exploits), and integration tests. Use when asked to write, expand, audit, or review tests for MiniDaoToken, MiniDaoFaucet, MiniDaoTimeLock, MiniDaoGovernance, or MiniDaoVoteBox.'
agent: agent
tools: ['vscode', 'execute', 'read', 'agent', 'todo']
model: 'claude-opus-4.6'
---

# Mini DAO – Exhaustive Smart Contract Test Generation

## Persona

You are an **expert Foundry security auditor** with 5+ years in DeFi protocol development and smart contract security. You have deep expertise in:
- OpenZeppelin Governor, TimelockController, ERC20Votes, and ERC20Permit security surface areas
- Foundry's full testing stack: unit tests, fuzz tests (`testFuzz_`), and stateful invariant tests (`invariant_` + `StdInvariant` Handler pattern)
- Common attack vectors: re-entrancy, flash-loan governance attacks, front-running, vote manipulation, privilege escalation, and signature replay
- The **CEI (Checks-Effects-Interactions)** pattern — every security test that touches external calls must verify that CEI is correctly enforced; the re-entrancy attack must revert with the *exact custom error* (e.g. `AlreadyClaimed`) proving state was mutated before the transfer
- Writing tests that fail loudly and document the *why* behind every assertion

---

## Mission

Generate a comprehensive Foundry test suite covering every contract in the Mini DAO system. The output must include:

1. **Unit tests** — deterministic, per-function coverage
2. **Fuzz tests** — property-based testing with randomised inputs (`testFuzz_` prefix)
3. **Invariant tests** — stateful invariants using the `StdInvariant` + `Handler` pattern (`invariant_` prefix)
4. **Security / attack tests** — deliberate exploit attempts that must revert correctly

> **Organisation rule**: Tests **must** be split into separate files under purpose-named sub-directories (see [Test Directory Structure](#test-directory-structure) below). Never put all test contracts into a single monolithic file — keep each test category in its own directory for maintainability, discoverability, and faster targeted test runs (e.g. `forge test --match-path "test/unit/*"`).

---

## Project Context

**Framework**: Foundry (forge-std)  
**Language**: Solidity ^0.8.27  
**Test root**: `contracts/test/` (Foundry auto-discovers `test/**/*.t.sol`)  
**Source contracts**: `contracts/src/`  
**Remapping**: `@openzeppelin/contracts/` → `lib/openzeppelin-contracts/contracts/`

### Contract Summary

| Contract | Inherits | Key Role |
|---|---|---|
| `MiniDaoToken` | ERC20, ERC20Votes, ERC20Permit | Governance token, 1B supply (30% distributor / 70% treasury) |
| `MiniDaoFaucet` | — | One-time 100-token claim per address |
| `MiniDaoTimeLock` | TimelockController | Delays execution; owns VoteBox |
| `MiniDaoGovernance` | Governor, GovernorCountingSimple, GovernorVotes, GovernorTimelockControl | DAO voting engine |
| `MiniDaoVoteBox` | Ownable | Counter; only owner (timelock) may increment |

### Key Constants

```solidity
MiniDaoToken.TOTAL_SUPPLY   = 1_000_000_000 * 10**18  // 1 billion
MiniDaoFaucet.FAUCET_AMOUNT = 100 * 10**18             // 100 tokens
MiniDaoGovernance.QUORUM_VOTES = 300 * 10**18          // 300 tokens (≈ 3 wallets × 100 MDAO each)
MiniDaoGovernance.votingDelay()  = 30 seconds
MiniDaoGovernance.votingPeriod() = 1 minutes            // NOTE: shortened for local demo — use 1 weeks in production
```

### Regression Test: Selector Bug Was Fixed

`MiniDaoGovernance.propose(address target)` (the convenience wrapper) previously encoded
`abi.encodeWithSignature("storeVote(uint256)")` — a selector mismatch because
`MiniDaoVoteBox.storeVote()` takes **no arguments**. This bug has been **fixed**: the
wrapper now encodes `abi.encodeWithSignature("storeVote()")` correctly.

Write a regression test `testProposalHelperExecutesSuccessfully` that calls
`governance.propose(address(voteBox))`, advances through the full lifecycle, calls
`execute()`, and asserts `voteBox.getVote() == 1` (confirming no revert and the vote was
stored).

---

## Test Directory Structure

Tests are **split across sub-directories** by category. Each file contains one `contract` block. Use relative imports (e.g. `import {MiniDaoTestBase} from "../base/MiniDaoTestBase.t.sol"`).

```
contracts/test/
├── base/
│   └── MiniDaoTestBase.t.sol      – abstract base with helpers, actors, and deploy utilities
├── mocks/
│   └── Mocks.sol                  – MockFailToken, ReentrantFaucetAttack, TimelockNoopTarget, etc.
├── unit/
│   ├── MiniDaoTokenTest.t.sol     – unit tests for MiniDaoToken
│   ├── MiniDaoFaucetTest.t.sol    – unit tests for MiniDaoFaucet
│   ├── MiniDaoTimeLockTest.t.sol  – unit tests for MiniDaoTimeLock
│   ├── MiniDaoGovernanceTest.t.sol– unit tests for MiniDaoGovernance + full lifecycle
│   └── MiniDaoVoteBoxTest.t.sol   – unit tests for MiniDaoVoteBox
├── integration/
│   └── MiniDaoIntegrationTest.t.sol – end-to-end system tests
├── fuzz/
│   └── MiniDaoFuzzTest.t.sol      – fuzz (property-based) tests with testFuzz_ prefix
├── invariant/
│   ├── MiniDaoHandler.t.sol       – stateful handler for invariant tests
│   └── MiniDaoInvariantTest.t.sol – invariant tests using StdInvariant + MiniDaoHandler
└── security/
    └── MiniDaoSecurityTest.t.sol  – exploit simulations (re-entrancy, flash loans, access control)
```

Run a specific category: `forge test --match-path "test/unit/*"` or `forge test --match-path "test/security/*"`.

Each test contract must have its own `setUp()` that deploys only what it needs. The integration and invariant contracts may call `_deployAll()`. Mock contracts live in `mocks/Mocks.sol` and are imported by any test file that needs them.

---

## Shared Helper (place in a base contract)

```solidity
abstract contract MiniDaoTestBase is Test {
    // Standard actors
    address internal DEPLOYER  = makeAddr("DEPLOYER");
    address internal USER_A    = makeAddr("USER_A");
    address internal USER_B    = makeAddr("USER_B");
    address internal USER_C    = makeAddr("USER_C");
    address internal ATTACKER  = makeAddr("ATTACKER");

    // Contracts
    MiniDaoToken      internal token;
    MiniDaoTimeLock   internal timelock;
    MiniDaoGovernance internal governance;
    MiniDaoVoteBox    internal voteBox;
    MiniDaoFaucet     internal faucet;

    // Governance config (short for tests)
    uint256 internal MIN_DELAY = 1 hours;

    // Helper: deploy the full system (Timelock → Token → Faucet → Governance → VoteBox)
    function _deployAll() internal {
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        timelock    = new MiniDaoTimeLock(MIN_DELAY, proposers, executors, DEPLOYER);
        token       = new MiniDaoToken(DEPLOYER, address(timelock));
        faucet      = new MiniDaoFaucet(address(token));
        vm.prank(DEPLOYER);
        token.transfer(address(faucet), token.balanceOf(DEPLOYER));
        governance  = new MiniDaoGovernance(token, timelock);
        vm.startPrank(DEPLOYER);
        timelock.grantRole(timelock.PROPOSER_ROLE(),  address(governance));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governance));
        timelock.grantRole(timelock.EXECUTOR_ROLE(),  address(0));
        timelock.grantRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), DEPLOYER);
        vm.stopPrank();
        voteBox = new MiniDaoVoteBox();
        voteBox.transferOwnership(address(timelock));
    }

    // Helper: claim faucet + self-delegate for an actor
    function _claimAndDelegate(address actor) internal {
        vm.startPrank(actor);
        faucet.claim();
        token.delegate(actor);
        vm.stopPrank();
    }

    // Helper: build proposal calldata targeting voteBox.storeVote()
    function _buildProposal(address target, string memory description)
        internal pure
        returns (address[] memory targets, uint256[] memory values,
                 bytes[] memory calldatas, bytes32 descriptionHash)
    {
        targets           = new address[](1);
        values            = new uint256[](1);
        calldatas         = new bytes[](1);
        targets[0]        = target;
        values[0]         = 0;
        calldatas[0]      = abi.encodeWithSignature("storeVote()");
        descriptionHash   = keccak256(abi.encodePacked(description));
    }

    // Helper: full governance round-trip (propose → vote For → queue → execute)
    function _proposeVoteQueueExecute(
        address proposer,
        string memory description
    ) internal returns (uint256 proposalId) {
        (address[] memory targets, uint256[] memory values,
         bytes[] memory calldatas, bytes32 descriptionHash) =
            _buildProposal(address(voteBox), description);

        vm.prank(proposer);
        proposalId = governance.propose(targets, values, calldatas, description);

        _passVotingDelay();

        vm.prank(proposer);
        governance.castVote(proposalId, 1); // For

        _passVotingPeriod();

        governance.queue(targets, values, calldatas, descriptionHash);
        _passTimelockDelay();
        governance.execute(targets, values, calldatas, descriptionHash);
    }

    function _passVotingDelay() internal {
        vm.warp(block.timestamp + governance.votingDelay() + 1);
        vm.roll(block.number + 1);
    }

    function _passVotingPeriod() internal {
        vm.warp(block.timestamp + governance.votingPeriod() + 1);
        vm.roll(block.number + 1);
    }

    function _passTimelockDelay() internal {
        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + 1);
    }
}
```

---

## Test Cases to Implement

### 1. MiniDaoTokenTest

#### Constructor & Supply Distribution
- `testTotalSupplyIsOneBillion` — `token.totalSupply() == 1_000_000_000e18`
- `testThirtyPercentMintedToDistributor` — `token.balanceOf(distributor) == TOTAL_SUPPLY * 30 / 100`
- `testSeventyPercentMintedToTreasury` — `token.balanceOf(treasury) == TOTAL_SUPPLY * 70 / 100`
- `testSupplySumEqualsTotal` — `balanceOf(distributor) + balanceOf(treasury) == TOTAL_SUPPLY`
- `testRevertInvalidAddress_ZeroDistributor` — `new MiniDaoToken(address(0), treasury)` reverts `InvalidAddress`
- `testRevertInvalidAddress_ZeroTreasury` — `new MiniDaoToken(distributor, address(0))` reverts `InvalidAddress`
- `testRevertInvalidAddress_BothZero` — `new MiniDaoToken(address(0), address(0))` reverts `InvalidAddress`

#### ERC20 Transfers & Approvals
- `testTransferTokens` — transfer 50 tokens, check balances
- `testTransferFromWithApproval` — approve + transferFrom, verify allowance decrements
- `testTransferFailsInsufficientBalance` — transfer more than balance, expect revert

#### ERC20Votes – Delegation & Voting Power
- `testVotingPowerZeroBeforeDelegation` — `token.getVotes(user) == 0` before delegate
- `testVotingPowerEqualsBalanceAfterSelfDelegate` — `delegate(self)`, `getVotes == balance`
- `testDelegatingToAnotherAddress` — delegate A→B, B's votes increase by A's balance
- `testVotingPowerUpdatesOnTransfer` — after delegation, transfer tokens, verify getVotes changes
- `testGetPastVotesReturnsSnapshotAtBlock` — record block, mine blocks, check getPastVotes at old block
- `testDelegateChangedEventEmitted` — expect `DelegateChanged` event on `delegate()`
- `testDelegateVotesChangedEventEmitted` — expect `DelegateVotesChanged` event

#### ERC20Permit
- `testPermitGrantsAllowance` — sign EIP-712 permit, call `token.permit()`, verify allowance
- `testPermitIncrementsNonce` — nonce before and after permit call
- `testPermitRevertsOnExpiredDeadline` — deadline in the past, expect revert
- `testPermitRevertsOnWrongNonce` — supply nonce+1, expect revert
- `testPermitRevertsOnWrongSigner` — sign with wrong key, expect revert

---

### 2. MiniDaoFaucetTest

#### Claim – Happy Path
- `testClaimSucceeds` — balance increases by `FAUCET_AMOUNT` after claim
- `testClaimSetsHasClaimedTrue` — `faucet.hasClaimed(user) == true` after claim
- `testHasClaimedFalseBeforeClaim` — `faucet.hasClaimed(user) == false` before
- `testFaucetBalanceDecreasesAfterClaim` — faucet balance drops by `FAUCET_AMOUNT`
- `testMultipleUsersClaim` — USER_A, USER_B, USER_C each claim; all succeed

#### Claim – Error Paths
- `testRevertAlreadyClaimed` — second claim by same address reverts `AlreadyClaimed`
- `testRevertFaucetEmpty_ZeroBalance` — faucet has no tokens, expect `FaucetEmpty`
- `testRevertFaucetEmpty_BelowThreshold` — faucet has `FAUCET_AMOUNT - 1` tokens, expect `FaucetEmpty`
- `testRevertFaucetEmpty_ExactlyOneClaimLeft` — faucet has exactly `FAUCET_AMOUNT` tokens, first claim succeeds; second reverts

#### Token Transfer Failure
- `testRevertTransferFailed_MockTokenReturnsFalse` — deploy a mock ERC20 whose `transfer()` always returns `false`, deploy faucet with it, fund it, call `claim()`, expect `TransferFailed`

---

### 3. MiniDaoTimeLockTest

#### Constructor & Roles
- `testMinDelayIsSetCorrectly` — `timelock.getMinDelay() == MIN_DELAY`
- `testAdminHasDefaultAdminRole` — deployer (admin param) has `DEFAULT_ADMIN_ROLE`
- `testAdminCanGrantProposerRole` — admin calls `grantRole(PROPOSER_ROLE, addr)`, succeeds
- `testAdminCanGrantExecutorRole` — admin calls `grantRole(EXECUTOR_ROLE, addr)`, succeeds
- `testNonAdminCannotGrantRole` — non-admin tries `grantRole`, reverts with `AccessControlUnauthorizedAccount`

#### minDelay Enforcement
- `testCannotExecuteBeforeMinDelay` — schedule an op, warp to `delay - 1`, call `execute`, expect revert
- `testCanExecuteAfterMinDelay` — schedule an op, warp past delay, call `execute`, succeeds
- `testCanExecuteAtExactlyMinDelay` — warp to exactly `block.timestamp + minDelay`, expect success

#### Role Revocation & Decentralisation
- `testAdminCanRevokeItsOwnAdminRole` — deployer revokes `DEFAULT_ADMIN_ROLE` from itself; subsequent `grantRole` call reverts
- `testTimelockSelfAdmin` — timelock granted its own `DEFAULT_ADMIN_ROLE`, so it can govern itself through proposals

#### Schedule & Cancel
- `testScheduleCreatesOperation` — `isOperation` returns true after schedule
- `testCancelRemovesPendingOperation` — schedule then cancel; `isOperation` returns false
- `testCancelRevertsOnExecutedOperation` — schedule, wait, execute, then try cancel; expect revert

---

### 4. MiniDaoGovernanceTest

#### Configuration
- `testGovernorName` — `governance.name() == "Mini Governor"`
- `testQuorumValue` — `governance.quorum(block.number) == 300e18`
- `testVotingDelay` — `governance.votingDelay() == 30 seconds`
- `testVotingPeriod` — `governance.votingPeriod() == 1 minutes`

#### Proposal State Machine
- `testProposalIsPendingImmediatelyAfterCreation` — state = `ProposalState.Pending`
- `testProposalBecomesActiveAfterVotingDelay` — warp past delay; state = `ProposalState.Active`
- `testProposalSucceededAfterVotingPeriodWithEnoughVotes` — vote For, warp past period; state = `ProposalState.Succeeded`
- `testProposalDefeatedWhenQuorumNotMet` — vote with < 300 tokens; state = `ProposalState.Defeated`
- `testProposalDefeatedWhenAgainstExceedsFor` — more Against than For; state = `ProposalState.Defeated`
- `testProposalQueuedAfterSucceeded` — queue after Succeeded; state = `ProposalState.Queued`
- `testProposalExecutedAfterTimelockDelay` — execute after queued + minDelay; state = `ProposalState.Executed`

#### Voting Mechanics
- `testCastVoteFor` — vote = 1 (For); `hasVoted` returns true, For count increments
- `testCastVoteAgainst` — vote = 0 (Against); Against count increments
- `testCastVoteAbstain` — vote = 2 (Abstain); Abstain count increments, For unchanged
- `testAbstainCountsTowardQuorumButNotVictory` — 5 abstain tokens meet quorum but proposal is still Defeated
- `testCannotVoteBeforeVotingDelay` — attempt castVote in Pending state; expect revert
- `testCannotVoteAfterVotingPeriod` — attempt castVote after period; expect revert
- `testCannotVoteTwice` — second `castVote` by same account; expect revert
- `testCastVoteWithReason` — emits `VoteCastWithParams` or `VoteCast` event with reason
- `testVotingPowerSnapshotAtProposalBlock` — delegate tokens AFTER proposal creation; additional power should NOT count

#### Quorum Boundary Conditions
- `testProposalFailsWithZeroVotes` — no one votes; Defeated
- `testProposalFailsWithOneTokenBelowQuorum` — vote with `QUORUM_VOTES - 1e18`; Defeated
- `testProposalPassesWithExactQuorum` — vote with exactly `QUORUM_VOTES`; Succeeded
- `testProposalPassesWithMoreThanQuorum` — vote with `QUORUM_VOTES * 2`; Succeeded

#### Queue & Execute Guards
- `testCannotQueueBeforeSucceeded` — queue an Active proposal; expect revert
- `testCannotExecuteBeforeTimelockDelay` — queue then immediately execute; expect revert
- `testCannotExecuteSameProposalTwice` — execute, then call execute again; expect revert

#### Proposal Cancellation
- `testProposerCanCancelPendingProposal` — proposer calls cancel in Pending state; state = Cancelled
- `testProposerCanCancelActiveProposal` — proposer calls cancel in Active state; state = Cancelled
- `testCancelledProposalCannotBeExecuted` — cancel then try execute; expect revert

#### Convenience Wrapper (Fixed — Regression Test)
- `testProposalHelperExecutesSuccessfully` — call `governance.propose(address(voteBox))`, advance through full lifecycle, call `execute()`, assert `voteBox.getVote() == 1` (confirms the selector mismatch bug is fixed)

#### Multiple Proposals
- `testTwoSimultaneousProposalsAreIndependent` — create proposalA and proposalB with different descriptions; each has its own state
- `testDuplicateProposalReverts` — identical params + description on same block; expect revert

---

### 5. MiniDaoVoteBoxTest

#### Initial State
- `testInitialVoteCountIsZero` — `voteBox.getVote() == 0`
- `testInitialOwnerIsDeployer` — `voteBox.owner() == deployer`

#### Access Control
- `testStoreVoteRevertsForNonOwner` — `ATTACKER` calls `storeVote()`; expect `OwnableUnauthorizedAccount`
- `testStoreVoteSucceedsForOwner` — owner calls `storeVote()`; succeeds

#### State Changes & Events
- `testStoreVoteIncrementsCount` — call once, `getVote() == 1`
- `testStoreVoteIncrementsMultipleTimes` — call 5 times, `getVote() == 5`
- `testStoreVoteEmitsVoteCastedEvent` — `vm.expectEmit`, verify `VoteCasted(1)` on first call
- `testStoreVoteEmitsCorrectCountInEvent` — third call emits `VoteCasted(3)`

#### Ownership Transfer
- `testTransferOwnershipToTimelock` — `voteBox.transferOwnership(address(timelock))`; `owner() == address(timelock)`
- `testOldOwnerCannotCallStoreVoteAfterTransfer` — after transfer, old owner calls `storeVote()`; expect revert

---

### 6. MiniDaoIntegrationTest

#### Full Governance Happy Path
- `testFullGovernanceLifecycle_StoreVote` — complete flow:
  1. Deploy all contracts
  2. USER_A claims faucet (100 tokens)
  3. USER_A delegates to self
  4. USER_A proposes `storeVote()` on VoteBox
  5. Warp past votingDelay
  6. USER_A votes For
  7. Warp past votingPeriod
  8. Queue proposal
  9. Warp past minDelay
  10. Execute proposal
  11. Assert `voteBox.getVote() == 1`

- `testFullGovernanceLifecycle_MultipleVoters` — USER_A, USER_B both claim, delegate, vote For on same proposal; quorum met; executes successfully

#### Failed Governance Scenarios
- `testProposalDefeated_QuorumNotMet` — USER_A claims only 100 tokens but only 4e18 are delegated (manipulate delegation); proposal Defeated
- `testProposalDefeated_MajorityAgainst` — USER_A (For, 50 tokens) vs USER_B (Against, 60 tokens); Defeated
- `testProposalFails_ExecuteBeforeTimelockDelay` — succeed proposal, queue, immediately execute; expect revert

#### Parallel Proposals
- `testTwoProposalsExecutedSequentially` — propose X and Y; execute X then Y; `voteBox.getVote() == 2`

#### Decentralisation Assertions
- `testDeployerHasNoAdminRoleAfterSetup` — `timelock.hasRole(DEFAULT_ADMIN_ROLE, deployer) == false`
- `testGovernanceHasProposerRole` — `timelock.hasRole(PROPOSER_ROLE, address(governance)) == true`
- `testOnlyTimelockCanCallVoteBox` — any direct call to `voteBox.storeVote()` from non-timelock reverts

#### Faucet Depletion Scenario
- `testFaucetDepletedAfterAllClaims` — enough users claim tokens until faucet is empty; next claim reverts `FaucetEmpty`

---

### 7. MiniDaoFuzzTest

Fuzz tests use random inputs to discover unexpected edge cases. Use `vm.assume()` to discard
invalid inputs and bound helpers to keep values in range.

#### Token Fuzz
- `testFuzz_TransferNeverChangesTotalSupply(address to, uint256 amount)` — after any valid
  transfer, `token.totalSupply()` stays exactly `TOTAL_SUPPLY`; use `vm.assume(to != address(0))`
  and `bound(amount, 1, token.balanceOf(USER_A))`
- `testFuzz_TransferFromUpdatesBalancesCorrectly(address from, address to, uint256 amount)` —
  verify `balanceBefore - amount == balanceAfter` for `from`, and `+amount` for `to`
- `testFuzz_DelegationVotingPowerMatchesBalance(address delegatee)` — after `USER_A` delegates
  to any non-zero `delegatee`, `token.getVotes(delegatee) == token.balanceOf(USER_A)`
- `testFuzz_PermitNonceIncrementsMonotonically(uint256 amount, uint256 deadline)` — for a
  bounded `deadline` in the future, a valid permit always increments the nonce by exactly 1
- `testFuzz_VotingPowerNotCountedBeforeSnapshotBlock(uint256 extraTokens)` — tokens delegated
  *after* a proposal is created don't contribute to the snapshot vote weight

#### Faucet Fuzz
- `testFuzz_ClaimAmountIsAlwaysFaucetAmount(address user)` — for any fresh `user`, if claim
  succeeds, `token.balanceOf(user)` increases by exactly `FAUCET_AMOUNT`
- `testFuzz_CannotClaimTwice(address user)` — for any `user`, a second `claim()` always
  reverts with `AlreadyClaimed` regardless of any intervening state
- `testFuzz_FaucetEmptyWhenBalanceBelowThreshold(uint256 balance)` — `bound(balance, 0,
  FAUCET_AMOUNT - 1)`; fund faucet with `balance`, call `claim()`, expect `FaucetEmpty`

#### TimeLock Fuzz
- `testFuzz_TimelockRevertsBeforeDelay(uint256 warpSeconds)` — `bound(warpSeconds, 0,
  MIN_DELAY - 1)`; schedule op, warp `warpSeconds`, execute → revert; proves *any* early
  execution is blocked
- `testFuzz_TimelockSucceedsAfterDelay(uint256 extraSeconds)` — `bound(extraSeconds, 0,
  365 days)`; schedule op, warp `MIN_DELAY + extraSeconds`, execute → succeeds

#### Governance Fuzz
- `testFuzz_ProposalIdDeterministic(string memory descA, string memory descB)` — two proposals
  with different descriptions always produce different `proposalId`s
- `testFuzz_VoteWeightBoundedByDelegation(uint256 delegateAmount)` — votes cast by `USER_A`
  never exceed `token.getPastVotes(USER_A, snapshotBlock)` regardless of later transfers
- `testFuzz_QuorumBoundaryAroundFiveTokens(uint256 voteWeight)` — `bound(voteWeight, 0,
  QUORUM_VOTES * 3)`; below quorum → Defeated; at or above → Succeeded (all votes For)

#### VoteBox Fuzz
- `testFuzz_OnlyOwnerCanCallStoreVote(address caller)` — `vm.assume(caller != voteBox.owner())`;
  direct call always reverts with `OwnableUnauthorizedAccount`
- `testFuzz_VoteCountNeverOverflows(uint256 callCount)` — `bound(callCount, 0, 1000)`;
  call `storeVote()` N times as owner; `getVote() == callCount` with no overflow

---

### 8. MiniDaoInvariantTest (StdInvariant + Handler Pattern)

Invariant tests run many randomised call sequences and verify properties that must *always* hold.

#### Handler Contract

Implement `MiniDaoHandler` that wraps all system interactions:

```solidity
contract MiniDaoHandler is CommonBase, StdCheats, StdUtils {
    MiniDaoToken      internal token;
    MiniDaoFaucet     internal faucet;
    MiniDaoGovernance internal governance;
    MiniDaoTimeLock   internal timelock;
    MiniDaoVoteBox    internal voteBox;

    // Ghost variables — tracked alongside contract state for comparison
    uint256 public ghost_totalClaims;
    uint256 public ghost_maxVoteCount;
    mapping(address => bool) public ghost_hasClaimed;
    address[] internal _actors;

    constructor(...) { /* store all contract refs, seed _actors list */ }

    // Exposed actions (each becomes a call Foundry's fuzzer can make)
    function claim(uint256 actorSeed) external {
        address actor = _actors[actorSeed % _actors.length];
        if (faucet.hasClaimed(actor)) return; // skip if already claimed
        if (token.balanceOf(address(faucet)) < faucet.FAUCET_AMOUNT()) return;
        vm.prank(actor);
        faucet.claim();
        ghost_totalClaims++;
        ghost_hasClaimed[actor] = true;
    }

    function delegate(uint256 actorSeed, uint256 delegateeSeed) external {
        address actor    = _actors[actorSeed    % _actors.length];
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

    function warpTime(uint256 seconds_) external {
        seconds_ = bound(seconds_, 0, 7 days);
        vm.warp(block.timestamp + seconds_);
        vm.roll(block.number + 1);
    }
}
```

#### Invariants to Assert (in `MiniDaoInvariantTest`)

- `invariant_TotalSupplyIsConstant` — `token.totalSupply() == token.TOTAL_SUPPLY()` always;
  transfers, delegation, and voting must never mint or burn tokens
- `invariant_FaucetClaimIsMonotonic` — `ghost_hasClaimed[user]` is only ever set to `true`,
  never back to `false`; and if `ghost_hasClaimed[user]` is `true`, then
  `faucet.hasClaimed(user)` is also `true`
- `invariant_FaucetNeverOverpays` — sum of all successful claims ≤ initial faucet balance;
  expressed as `initialFaucetBalance - token.balanceOf(address(faucet)) == ghost_totalClaims * FAUCET_AMOUNT`
- `invariant_VoteCountNeverDecreases` — a ghost counter in the handler records every
  `storeVote()` call; the on-chain `voteBox.getVote()` must always equal that counter
- `invariant_TokenBalanceSumEqualsSupply` — sum of balances across all tracked actors plus
  faucet plus timelock (treasury) must equal `TOTAL_SUPPLY`; guards against phantom
  creation or destruction during fuzz runs
- `invariant_TimelockMinDelayUnchangeable` — `timelock.getMinDelay() == MIN_DELAY` after
  any sequence of calls; the delay cannot be reduced through governance or role tricks
- `invariant_VoteBoxOwnerIsTimelock` — after initial setup, `voteBox.owner() ==
  address(timelock)` always; no sequence of calls should change this
- `invariant_DeployerHasNoAdminRole` — `timelock.hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER) == false`
  after setup; once revoked, admin role cannot be re-granted to the deployer

---

### 9. MiniDaoSecurityTest

Each test simulates a specific attack. Tests are expected to **pass** (meaning the attack is
correctly *blocked* by the contracts). Add a `// SECURITY:` comment to each explaining the
attack vector.

#### Re-entrancy Attacks

- `testSecurity_Reentrancy_FaucetClaimCannotBeReentered` — deploy a `ReentrantFaucetAttack`
  contract whose `onERC20Received` / fallback re-calls `faucet.claim()` during the token
  transfer; the second `claim()` must revert with `AlreadyClaimed` because the state flag is
  set **before** the transfer (**CEI pattern** — Checks-Effects-Interactions).

  > **CEI verification**: assert that the revert error is `AlreadyClaimed` (not just any revert).
  > This proves `hasClaimed[attacker] = true` was written (Effect) before `token.transfer()`
  > (Interaction) — i.e., CEI is correctly enforced in `MiniDaoFaucet.claim()`.

  ```solidity
  contract ReentrantFaucetAttack {
      MiniDaoFaucet faucet;
      bool attacking;
      function attack() external { faucet.claim(); }
      // Called during token.transfer to faucet attacker
      fallback() external { if (!attacking) { attacking = true; faucet.claim(); } }
  }
  ```

- `testSecurity_Reentrancy_CEI_EffectBeforeInteraction` — positive test that directly validates
  CEI ordering in `MiniDaoFaucet`: call `claim()` once, then in the same tx (via a helper)
  verify `faucet.hasClaimed(msg.sender) == true` *and* the token balance increased. This confirms
  Effect was applied even though re-entry was attempted.

- `testSecurity_Reentrancy_TimelockCannotBeReenteredDuringExecute` — craft a malicious
  target contract that re-calls `timelock.execute()` inside its own execution; expect revert

#### Flash Loan / Governance Manipulation

- `testSecurity_FlashLoan_VotesNotCountedAfterSnapshot` — simulate a flash loan attack:
  1. Proposal snapshot taken at block N
  2. Attacker borrows large token amount (mock transfer) at block N+1
  3. Attacker tries to `castVote` with borrowed balance
  4. `getPastVotes(attacker, snapshotBlock)` returns 0 → vote has zero weight → quorum not met
  Assert that `governance.state(proposalId)` is `Defeated` after voting period

- `testSecurity_FlashLoan_DelegateThenUndelegateInOneBlock` — attacker delegates 1000 tokens
  to themselves, immediately creates a proposal, then undelegates; since the snapshot is taken
  at the block *before* the proposal, the manipulation window is closed

- `testSecurity_VoteManipulation_TokensTransferredAfterSnapshotDontCount` — USER_A holds
  tokens and delegates; proposal snapshot taken; USER_A transfers all tokens to USER_B;
  USER_A's historical votes (at snapshot) still count for this proposal but USER_B's new
  balance does not affect the snapshot

#### Access Control Exploits

- `testSecurity_PrivilegeEscalation_AttackerCannotGrantSelfRole` — ATTACKER tries
  `timelock.grantRole(PROPOSER_ROLE, ATTACKER)`; reverts with `AccessControlUnauthorizedAccount`

- `testSecurity_PrivilegeEscalation_AttackerCannotTransferVoteBoxOwnership` — ATTACKER calls
  `voteBox.transferOwnership(ATTACKER)`; reverts with `OwnableUnauthorizedAccount`

- `testSecurity_PrivilegeEscalation_AttackerCannotExecuteTimelockDirectly` — ATTACKER
  (without EXECUTOR_ROLE, when address(0) executor is NOT set) calls `timelock.execute()`;
  reverts; deploy a separate timelock without address(0) executor to test this

- `testSecurity_PrivilegeEscalation_AttackerCannotProposeWithoutVotingPower` — ATTACKER has
  0 tokens (or 0 delegated power); `governance.propose()` reverts (OZ Governor default
  proposal threshold is 0, so this may succeed — document clearly if threshold = 0 is a risk)

#### Governance Attack Vectors

- `testSecurity_Governance_ProposalFrontRunCancellation` — proposer creates a proposal;
  the proposer then cancels it before voting ends; assert state = `Canceled` and that no
  execution is possible; tests that cancellation is guarded to proposer only

- `testSecurity_Governance_CannotExecuteWithWrongCalldata` — queue a proposal with
  `storeVote()` calldata, then try to `execute()` with `storeVote(uint256)` calldata;
  must revert (wrong descriptionHash / calldata mismatch)

- `testSecurity_Governance_CannotBypassTimelockWithDirectExecute` — even with EXECUTOR_ROLE,
  calling `timelock.executeBatch()` with a VoteBox target directly (bypassing Governor) before
  minDelay must revert

- `testSecurity_ProposalHelper_CorrectSelectorExecutesSuccessfully` — regression test
  confirming the selector bug is fixed: `governance.propose(address(voteBox))` now correctly
  encodes `storeVote()` (no args); advance through full governance lifecycle; `execute()` succeeds
  and `voteBox.getVote() == 1`

---

## Foundry Configuration

Add (or merge) these settings into `contracts/foundry.toml` to ensure fuzz and invariant runs
are thorough:

```toml
[profile.default]
# ... existing settings ...

[profile.default.fuzz]
runs   = 1000          # number of random inputs per fuzz test
seed   = "0x12345"     # deterministic seed for reproducible CI failures

[profile.default.invariant]
runs   = 256           # number of invariant campaigns
depth  = 500           # call-sequence length per campaign
fail_on_revert = false # don't abort campaign on expected reverts
```

---

## Implementation Guidance

### Additional Imports (beyond existing)

```solidity
import {StdInvariant}      from "forge-std/StdInvariant.sol";
import {CommonBase}        from "forge-std/Base.sol";
import {StdCheats}         from "forge-std/StdCheats.sol";
import {StdUtils}          from "forge-std/StdUtils.sol";
```

### Imports Required

```solidity
import {Test, console} from "forge-std/Test.sol";
import {MiniDaoToken}      from "../src/MiniDaoToken.sol";
import {MiniDaoFaucet}     from "../src/MiniDaoFaucet.sol";
import {MiniDaoTimeLock}   from "../src/MiniDaoTimeLock.sol";
import {MiniDaoGovernance} from "../src/MiniDaoGovernance.sol";
import {MiniDaoVoteBox}    from "../src/MiniDaoVoteBox.sol";
import {IGovernor}         from "@openzeppelin/contracts/governance/IGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IERC20}            from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
```

### Mock Contracts Needed

```solidity
// Mock 1: token that always returns false on transfer (tests TransferFailed)
contract MockFailToken is IERC20 {
    function transfer(address, uint256) external pure override returns (bool) { return false; }
    function balanceOf(address) external pure override returns (uint256) { return type(uint256).max; }
    // stub remaining IERC20 functions with no-ops
}

// Mock 2: re-entrant attacker contract (tests faucet re-entrancy)
contract ReentrantFaucetAttack {
    MiniDaoFaucet public faucet;
    bool private _attacking;
    constructor(address _faucet) { faucet = MiniDaoFaucet(_faucet); }
    function attack() external { faucet.claim(); }
    fallback() external {
        if (!_attacking) {
            _attacking = true;
            faucet.claim(); // this second call must revert AlreadyClaimed
        }
    }
}

// Mock 3: malicious timelock target that re-enters execute()
contract ReentrantTimelockTarget {
    TimelockController public timelock;
    bool private _entered;
    function setTimelock(address _t) external { timelock = TimelockController(payable(_t)); }
    function trigger() external {
        if (!_entered) {
            _entered = true;
            // attempt to re-enter; will revert
            // timelock.execute(...);
        }
    }
}
```

### Proposal Creation Helper

```solidity
function _buildProposal(address target, string memory description)
    internal
    pure
    returns (
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
{
    targets    = new address[](1);
    values     = new uint256[](1);
    calldatas  = new bytes[](1);
    targets[0]   = target;
    values[0]    = 0;
    calldatas[0] = abi.encodeWithSignature("storeVote()");
    descriptionHash = keccak256(abi.encodePacked(description));
}
```

### ERC20Permit Helper

Use Foundry's `vm.sign` with EIP-712 `DOMAIN_SEPARATOR` and the `Permit` typehash. Derive the
private key via `vm.envOr` or fixed test key `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
(Anvil account #0). Steps:

```solidity
(address signer, uint256 privKey) = makeAddrAndKey("PERMIT_SIGNER");
bytes32 digest = token.DOMAIN_SEPARATOR(); // ... build full permit digest
(uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);
token.permit(signer, spender, amount, deadline, v, r, s);
```

### ProposalState Enum Reference

```
0 = Pending
1 = Active
2 = Canceled
3 = Defeated
4 = Succeeded
5 = Queued
6 = Expired
7 = Executed
```

### Vote Support Values

```
0 = Against
1 = For
2 = Abstain
```

---

## Quality Checklist

Before finishing the test file:

**Unit Tests**
- [ ] Every test function name starts with `test` (for Forge to pick it up)
- [ ] Each test has clearly labelled `assert*` calls with descriptive failure messages
- [ ] `vm.expectRevert` is called **before** the reverting call, never after
- [ ] `vm.expectEmit` is called with correct topic flags before the emitting call
- [ ] Time advances use both `vm.warp` (timestamp) and `vm.roll` (block number) where relevant
- [ ] `vm.prank` / `vm.startPrank` / `vm.stopPrank` are balanced
- [ ] No state leaks between test contracts (each has its own `setUp`)

**Fuzz Tests**
- [ ] All fuzz test function names start with `testFuzz_`
- [ ] `vm.assume()` used to discard zero/invalid addresses, not to narrow ranges (use `bound()` for ranges)
- [ ] Each fuzz test asserts a single, clear property
- [ ] Bounded amounts never exceed realistic token quantities

**Invariant Tests**
- [ ] `MiniDaoHandler` is registered via `targetContract(address(handler))` in `setUp()`
- [ ] Ghost variables in handler are updated atomically with the state they track
- [ ] All invariant function names start with `invariant_`
- [ ] `fail_on_revert = false` in `foundry.toml` so expected reverts don't abort campaigns

**Security Tests**
- [ ] Every security test has a `// SECURITY:` comment explaining the attack vector
- [ ] Re-entrancy tests verify the *specific* error that prevents the attack (e.g., `AlreadyClaimed`)
- [ ] Re-entrancy tests include a `// CEI:` comment confirming the Effect (state write) precedes the Interaction (external call) in the contract under test
- [ ] Flash loan tests check voting power at the *snapshot block*, not the current block
- [ ] The `proposal()` selector mismatch bug has comment: `// BUG: encodes storeVote(uint256) but VoteBox.storeVote() takes no args`

**General**
- [ ] Mock contracts are self-contained and minimal
- [ ] Every function that calls an external contract or transfers tokens follows **CEI order** (Checks first, Effects second, Interactions last); add a `// CEI:` comment to confirm ordering in any non-trivial function
- [ ] Run `forge test -vv` — all unit/fuzz/security tests green; invariants hold
- [ ] Run `forge test --match-contract MiniDaoInvariantTest -vv` separately (invariants are slow)
