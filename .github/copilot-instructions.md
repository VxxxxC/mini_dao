---
applyTo: "**"
---

# Mini DAO – Copilot Instructions

## Project Overview

Mini DAO is a full-stack Web3 governance platform. The **contracts/** directory contains Foundry-based Solidity smart contracts, and the **src/** directory contains a SvelteKit frontend. Both sides must stay in sync (ABI files in `src/lib/contracts_abi/` must mirror deployed contract interfaces).

---

## Solidity Conventions (`contracts/`)

### Pragmas & License
- Every contract starts with `// SPDX-License-Identifier: MIT` then a blank line, then `pragma solidity ^0.8.24;` (or higher — match existing pragma in the file being modified).
- Never downgrade an existing pragma.

### Imports
- Always use named imports with `{}`: `import {Governor} from '@openzeppelin/contracts/governance/Governor.sol';`
- Multiple names from the same path go on separate lines inside `{}`.
- Preserve `@openzeppelin/contracts/...` alias (mapped in `remappings.txt`).

### Errors & Reverts
- Use **custom errors** — never `require(cond, "string")`.
- Declare errors at the top of the contract, before state variables.
- Custom error names are `PascalCase` (e.g., `AlreadyClaimed`, `TransferFailed`).

### CEI Pattern (Checks-Effects-Interactions)

Every state-changing function **must** follow CEI order. This is the primary defence against re-entrancy.

1. **Checks** — validate all conditions first (permissions, balances, flags). Revert with a custom error if any check fails.
2. **Effects** — update all contract state (flags, counters, balances, emit events) before any external call.
3. **Interactions** — call external contracts or transfer ETH/tokens **last**.

```solidity
// ✅ CORRECT — CEI order (MiniDaoFaucet.claim pattern)
function claim() external {
    // 1. Checks
    if (hasClaimed[msg.sender]) revert AlreadyClaimed();
    if (token.balanceOf(address(this)) < FAUCET_AMOUNT) revert FaucetEmpty();
    // 2. Effects
    hasClaimed[msg.sender] = true;          // state updated before external call
    // 3. Interactions
    bool success = token.transfer(msg.sender, FAUCET_AMOUNT);
    if (!success) revert TransferFailed();
}

// ❌ WRONG — Interaction before Effect (re-entrancy risk)
function claim() external {
    if (hasClaimed[msg.sender]) revert AlreadyClaimed();
    bool success = token.transfer(msg.sender, FAUCET_AMOUNT); // ← external call first!
    hasClaimed[msg.sender] = true;  // too late — re-entrant call sees false flag
    if (!success) revert TransferFailed();
}
```

- **Events count as effects** — always emit before external calls.
- Use OpenZeppelin `ReentrancyGuard` as an additional safety net for complex flows where CEI alone is insufficient.
- In security tests, always verify CEI is enforced: the re-entrancy attack must revert with the *exact custom error* (e.g., `AlreadyClaimed`), proving the state flag was set before the transfer.

### Naming
- Constants: `UPPER_SNAKE_CASE` with explicit units (`100 * 10 ** 18`).
- State variables: `camelCase`.
- Events: `PascalCase` past tense (`VoteCasted`).
- Functions: `camelCase`.

### Indentation
- Use **tabs** (not spaces) — match the existing tab-indented style.

### Section Comments
- Use `// COL:`, `// NOTE:`, and `// WARN:` inline comments for important sections, consistent with the existing codebase style.

### Testing (Foundry)
- Tests live in `contracts/test/` and extend `Test` from `forge-std`.
- Test function names: `test<Description>()` (camelCase description).
- Use `vm.prank`, `vm.warp`, `vm.roll` for state manipulation.
- Always import via `forge-std/Test.sol`.

### Deployment Scripts
- Scripts live in `contracts/script/` and extend `Script` from `forge-std`.
- Use `HelperConfig.s.sol` to provide network-specific parameters (never hardcode addresses in scripts).
- Deployment order matters: **Timelock → Token → Faucet → Governance → VoteBox**.
- After deploying, always revoke `DEFAULT_ADMIN_ROLE` from the deployer to fully decentralize.

---

## Frontend Conventions (`src/`)

### Stack
- **SvelteKit** (v2) with TypeScript strict mode + Vite.
- **Tailwind CSS v4** (via `@tailwindcss/vite`) + **Flowbite-Svelte** for UI components.
- **Wagmi v3 + Viem v2** for EVM interaction; **Reown AppKit** for wallet connection.
- **Filebase SDK / AWS S3** for off-chain proposal storage.

### File Naming
- Svelte components: `PascalCase.svelte` (e.g., `ProposalCard.svelte`).
- Svelte reactive stores/utilities: `PascalCase.svelte.ts` (e.g., `WalletStore.svelte.ts`).
- Plain TypeScript modules: `camelCase.ts`.
- Route files follow SvelteKit convention: `+page.svelte`, `+layout.svelte`.
- Type definition files: `<Name>.t.ts` (e.g., `ProposalCard.t.ts`, `StatusCard.t.ts`).

### Imports
- Use the `$lib/` alias for all imports from `src/lib/`.
- Auto-imported globals (e.g., `breakpoint`) are declared in `src/lib/auto-import/global-lib.ts` — do not import them manually.

### Wallet / Web3
- All contract reads use `viem` `publicClient` from `$lib/config/viem/`.
- All contract writes use Wagmi `writeContract` + `waitForTransactionReceipt`.
- ABI files are JSON in `src/lib/contracts_abi/` — import them directly (TypeScript JSON module resolution is enabled).
- Wallet state (`address`, `status`) comes from `WalletStore.svelte.ts` — never re-implement wallet tracking.
- AppKit initialization is **browser-only** (guard with `if (typeof window !== 'undefined')`).
- Current default network is **Anvil (chain 31337)** for local development; switch to Sepolia or mainnet in `appKitConfig.ts` and `viem/client` before production deployment.

### Responsive Design
- Custom Tailwind breakpoints: `tablet` (640px), `laptop` (1024px), `desktop` (1280px).
- Use the `breakpoint` auto-import for programmatic breakpoint checks.
- Dark mode is class-based — always provide `dark:` variants for background/text colors.

### State & Types
- Status card data: `StatusCardInfoType` from `$lib/types/StatusCard.t.ts`.
- Proposal card data: `ProposalCardInfoType` from `$lib/types/ProposalCard.t.ts`.
- API shapes live under `$lib/types/api/`.

### Environment Variables
- Accessed via `$lib/config/dotenv.ts` — never use `import.meta.env` directly in components.
- All Vite env vars must be prefixed with `VITE_`.

---

## Architecture Rules

- **Off-chain proposals**: User signs a message (timestamp included) and POSTs to `/api/upload_proposal`, which stores the proposal on IPFS via Filebase. The proposal is then surfaced through `/api/get_proposals_list`.
- **On-chain governance**: Proposals created off-chain reference on-chain calls via the governance contract. Execution is gated by the TimelockController (2-day default minDelay after passing).
- **Do not bypass the timelock**: Any contract mutation that should be governance-controlled must go through `MiniDaoGovernance` → `MiniDaoTimeLock` → target contract.
- **VoteBox** is the canonical on-chain target for governance demonstration. Ownership is held by the timelock.

---

## Known Issues / TODOs (do not regress)

- `MiniDaoGovernance`: `QUORUM_VOTES` is hardcoded to 3 tokens (as of April 2026); future improvement is `GovernorVotesQuorumFraction`.
- `appKitConfig.ts` and `viem/client`: Hardcoded to Anvil (chain 31337) — must be updated for any non-local deployment.
- Date/time formatting in proposal cards (HomeProposalCard.svelte, ProposalCard.svelte) needs `Intl.DateTimeFormat` correction.
- Wallet modal z-index issue (Navbar.svelte line 100) — conflicts with hamburger dropdown on mobile.

---

## Implementation Checklist: State & Navigation

When adding new data-fetching pages to the app:

- [ ] Use `afterNavigate()` from `$app/navigation` for page-level fetches, NOT `onMount()`
- [ ] If there's a success callback (e.g., `onVoteSuccess`), **re-assign** the result to state: `data = await fetch()`
- [ ] All contract **reads** use `publicClient.readContract()` from `$lib/config/viem/client`
- [ ] All contract **writes** use `writeContract()` + `wagmiConfig` from `@wagmi/core`
- [ ] Contract return types: `uint256` → use `Number()` to convert bigint; never use `as number` as the only conversion
- [ ] Timers/intervals: wrap in `$effect` with cleanup function (`return () => clearInterval(...)`)
- [ ] Live displays: use `$derived` with guards (e.g., `countdown > 0`) to hide stale state
- [ ] Optimistic updates: use local `$state` + `$derived` fallback to props, not direct prop mutation
- [ ] Async on-chain reads in child components: use `onMount` with `.then()/.catch()` — NEVER `$effect` (causes white screen if any synchronous `$state` write occurs)

---

## Frontend State Management & Navigation (Critical Patterns)

### 1. Page-Level Data Fetching with `afterNavigate`

**Problem:** Using `onMount()` for data fetching only fires once when the page initially mounts. In SvelteKit client-side navigation, switching away and back to a page (e.g., Home → Proposals → Home) does NOT re-mount; the component is reused. This causes stale data.

**Solution:** Use `afterNavigate()` from `$app/navigation` instead. It fires on **every navigation** that lands on the page, including tab switches.

```typescript
// ❌ WRONG - data only fetches once
import { onMount } from 'svelte';
onMount(async () => {
  proposals = await fetchProposals();
});

// ✅ CORRECT - data re-fetches on every tab switch back
import { afterNavigate } from '$app/navigation';
afterNavigate(async () => {
  proposals = await fetchProposals();
});
```

**Files:** `src/routes/proposals/+page.svelte` (line 9)

---

### 2. Callback State Re-assignment

**Problem:** Callback functions like `onVoteSuccess` that trigger data re-fetch must **explicitly re-assign** the result to component state. Simply calling the async function without capturing the result discards the data.

**Solution:** Always assign the result back to state in the callback.

```typescript
// ❌ WRONG - result is discarded
onVoteSuccess={async () => await fetchProposals()}

// ✅ CORRECT - result is assigned back to state
onVoteSuccess={async () => {
  proposals = await fetchProposals();
}}
```

**Impact:** Without this, voting triggers the fetch but cards don't update — only an F5 refresh displays new data.

---

### 3. Contract Reads: Standalone Viem Client vs Wagmi

**Problem:** Wagmi's `getPublicClient(wagmiConfig)` and `readContract(wagmiConfig, ...)` rely on wagmi's internal connector state. During client-side navigation, this state can become stale or unavailable, causing these functions to return `undefined` or fail silently.

**Solution:** Use the standalone viem `publicClient` from `$lib/config/viem/client` for **all read-only contract calls**. Reserve `wagmiConfig` for write operations (signing/voting) where the wallet signer is needed.

```typescript
// ❌ WRONG - unreliable on tab navigation
import { readContract, getPublicClient } from '@wagmi/core';
const client = getPublicClient(wagmiConfig);
const result = await readContract(wagmiConfig, { ... });

// ✅ CORRECT - always available
import { publicClient } from '$lib/config/viem/client';
const result = await publicClient.readContract({ ... });
```

**When to use each:**
- **`publicClient.readContract()`**: Querying contract state (voting weights, proposal status, countdown timers)
- **`wagmiConfig` + `writeContract()`**: Voting, submitting transactions that require a wallet signer

**Files:**
- `src/lib/components/FetchProposals.svelte.ts` (all contract event reads + state queries)
- `src/lib/components/ProposalCard.svelte` (checkVotingWeight, checkStartVoteSnapshot, checkUserVoteStatus)

---

### 4. TypeScript Type Casting vs Runtime Conversion

**Problem:** TypeScript's `as X` syntax is **type-only** — it doesn't convert the value at runtime. If a contract returns `uint256` (which viem converts to `bigint`), `result as number` still leaves `result` as `bigint`, causing runtime arithmetic errors.

**Solution:** Use runtime conversion functions: `Number()`, `String()`, `BigInt()`.

```typescript
// ❌ WRONG - still bigint at runtime
const countdown = result as number;
countdown - 1;  // TypeError: can't mix bigint and number

// ✅ CORRECT - actual runtime conversion
const countdown = Number(result);
countdown - 1;  // Works ✓
```

**When you see `as number` in contract reads:** Always verify the actual return type. If viem returns `bigint` for `uint256`, use `Number(result)`.

**Files:** `src/lib/components/ProposalCard.svelte` (line 128: `startToVote = Number(result)`)

---

### 5. Live Countdown Timer Pattern

**Problem:** Displaying a countdown that ticks down every second requires:
- Fetching the initial seconds from the contract
- Starting a `setInterval` that decrements every 1000ms
- Stopping the interval when the countdown ends (or component unmounts)
- Formatting the display without showing "00s" after it ends

**Solution:** Use `$effect` to manage the interval lifecycle, with proper cleanup.

```typescript
let startToVote = $state<number>(0);
let countdown = $state<number>(0);

// Re-run whenever startToVote changes (after contract fetch)
$effect(() => {
  countdown = startToVote;
  if (startToVote <= 0) return;  // Don't start interval if already 0

  const interval = setInterval(() => {
    const next = Math.max(0, countdown - 1);
    countdown = next;
    if (next === 0) {
      clearInterval(interval);  // Stop at zero
      // Optionally trigger state update here
    }
  }, 1000);

  // Cleanup: automatically runs when effect re-runs or component unmounts
  return () => clearInterval(interval);
});

// Guard display to hide when countdown ends
let countdownDisplay = $derived(countdown > 0 ? formatCountdown(countdown) : '');
```

**Key points:**
- `$effect` cleanup function (return) is **always called** on re-run or unmount
- `Math.max(0, countdown - 1)` prevents negative countdown
- Guard the display with `countdown > 0` to hide "00s"
- Don't use `let interval; interval = setInterval(...)` — scope issues make cleanup fragile

**Files:** `src/lib/components/ProposalCard.svelte` (lines 81–102)

---

### 6. Optimistic State Updates with `$derived`

**Problem:** When a countdown ends and you want to update the proposal status UI immediately before the parent re-fetches from chain, you need to override the prop temporarily.

**Solution:** Use a local `$state` override that falls back to the prop via `$derived`.

```typescript
let localState = $state<ProposalStatus | undefined>(undefined);
// Always sync localState back if parent re-fetches a new state
let displayState = $derived(localState !== undefined ? localState : proposalData.state);

// In countdown interval:
if (next === 0) {
  localState = ProposalStatus.Active;  // Show "Active" immediately
  onVoteSuccess();  // Re-fetch from chain to confirm
}
```

**Why not just mutate `proposalData.state` directly?**
- Props are read-only in Svelte 5
- Props will be re-passed from parent on re-fetch anyway
- The local override is temporary — `localState` resets to `undefined` when parent updates `proposalData`

**Files:** `src/lib/components/ProposalCard.svelte` (lines 82–84, 96)

---

### 7. Svelte 5 Reactivity: `$state` vs `$derived` vs `let`

**Rule of thumb:**
- **`let` (no prefix)**: One-time snapshots; changes don't reactively update dependents
- **`$state`**: Mutable state; changes trigger reactivity (listeners, effects, derived)
- **`$derived`**: Read-only computed value; auto-updates when deps change
- **`$effect`**: Side effects; runs when deps change

**Anti-pattern:** Destructuring from `$props()` into a `let` is a one-time snapshot:

```typescript
// ❌ WRONG - voteWeight is frozen at initial value
const { voteWeight } = $props();
let chart = let data: [voteWeight.forVotes] };  // Snapshot, never updates

// ✅ CORRECT - re-computes whenever voteWeight changes
const { voteWeight } = $props();
let chart = $derived({ data: [voteWeight.forVotes] });
```

**Files:** `src/lib/components/ApexChart.svelte` (lines with `$derived` for voteYes, voteNo, etc.)

---

### 8. ⚠️ Do NOT Use `$effect` for Blockchain / On-Chain Reads in Svelte 5

**This is a hard rule learned through production breakage. `$effect` is fundamentally incompatible with async blockchain component patterns in Svelte 5.**

#### Why `$effect` Breaks Blockchain Components

Svelte 5's `$effect` runs synchronously and tracks reactive dependencies eagerly. When you use it for async on-chain reads, several failure modes arise:

**Failure Mode A — White screen / infinite loop:**
```typescript
// ❌ CRASHES THE PAGE — synchronous $state write inside $effect
$effect(() => {
  isCheckingVote = true;  // ← synchronous $state write → Svelte detects loop → white screen
  publicClient.readContract({ ... }).then(result => {
    userHasVoted = result as boolean;
    isCheckingVote = false;
  });
});
```
The synchronous `isCheckingVote = true` write inside `$effect` triggers Svelte 5's infinite reactivity loop detection → the entire page goes blank, nothing renders.

**Failure Mode B — Stale data / silent re-trigger:**
Even if you avoid synchronous writes, `$effect` re-runs on ANY reactive dependency change. Blockchain reads are expensive and asynchronous — re-triggering them on every prop change causes race conditions, duplicate requests, and unpredictable UI states.

**Failure Mode C — Countdown timer works, but on-chain reads don't:**
The countdown `$effect` pattern only works because all `$state` writes happen inside the `setInterval` callback (deferred/async), never synchronously. This is the ONE safe use of `$effect` with state. But trying to apply this same pattern to on-chain reads (which involve async network calls + synchronous loading flags) will crash.

#### ✅ Correct Pattern: `onMount` for Child-Level Blockchain Reads

```typescript
// ✅ SAFE — use onMount for async on-chain reads in child components
import { onMount } from 'svelte';

let userHasVoted = $state<boolean>(false);
let isCheckingVote = $state<boolean>(false);

onMount(() => {
  const addr = userAddress;
  if (!addr || !addr.startsWith('0x')) return;  // guard against 'Not connected'

  isCheckingVote = true;
  publicClient.readContract({
    functionName: 'hasVoted',
    args: [proposalData.proposalId, addr as `0x${string}`]
  }).then((result) => {
    userHasVoted = result as boolean;
  }).catch((error) => {
    console.error('Failed to check vote status:', error);
  }).finally(() => {
    isCheckingVote = false;
  });
});
```

**Why `onMount` works:**
- Runs once after the component mounts — no reactive dependency tracking
- Async `.then()/.catch()` writes to `$state` are deferred — Svelte does NOT detect these as synchronous loops
- No white screen risk
- Stable and predictable

#### ⚠️ Known Limitation of `onMount` — Solved with `watchAccount`

`onMount` only fires **once** on initial mount. This means after switching MetaMask accounts, `hasVoted` would show the old wallet's cached value until F5 refresh.

**Solution: Use `watchAccount` from `@wagmi/core` inside `onMount`** — subscribe to account changes and re-run the check on every wallet switch. This avoids `$effect` (white-screen risk) while staying reactive to address changes.

```typescript
import { watchAccount } from '@wagmi/core';

// Version counter prevents stale in-flight results from old wallet overwriting new wallet's result
let checkVersion = 0;

function checkHasVoted(addr: string) {
  if (!addr || !addr.startsWith('0x')) {
    userHasVoted = false;
    isCheckingVote = false;
    return;
  }
  const version = ++checkVersion;
  isCheckingVote = true;
  publicClient.readContract({ functionName: 'hasVoted', args: [pid, addr] })
    .then((result) => { if (version === checkVersion) userHasVoted = result as boolean; })
    .catch((error) => { console.error(error); })
    .finally(() => { if (version === checkVersion) isCheckingVote = false; });
}

onMount(() => {
  checkHasVoted(userAddress); // initial check

  const unwatch = watchAccount(wagmiConfig, {
    onChange(account) {
      const addr = account.address ?? '';
      userHasVoted = false; // reset immediately — never show stale state
      checkHasVoted(addr);
    }
  });

  return () => unwatch(); // cleanup on component unmount
});
```

**Why not `$effect`?** See Failure Mode A above — synchronous `$state` writes (like `isCheckingVote = true`) inside `$effect` cause white screens. `watchAccount` inside `onMount` gives the same reactivity without the risk.

**Why the version counter?** When the user switches quickly between two wallets, both checks are in-flight simultaneously. Without the version guard, the older (slower) request could resolve last and overwrite the correct result.

**`watchConnection` vs `watchAccount`:** Use `watchConnection` (wagmi v3 rename of the deprecated `watchAccount`) for address-change reactivity in components. `WalletStore.svelte.ts` also uses `watchConnection` globally. Both receive a callback with `{ address, status, ... }` — the rename is cosmetic only.

#### Address Validation (Critical)

`WalletStore` sets `address = 'Not connected'` when wallet disconnects — this is a **truthy non-address string**. Always validate before passing to contract calls:

```typescript
// ✅ Always guard address before blockchain calls
const isValidAddress = userAddress && userAddress.startsWith('0x');
if (!isValidAddress) return;
```

#### Summary: `$effect` Rules for Blockchain Components

| Use Case | Use |
|---|---|
| Countdown timer (writes only in `setInterval`) | `$effect` ✅ |
| Any `$state` write SYNCHRONOUSLY inside `$effect` | NEVER — white screen |
| Async on-chain reads (`readContract`, `getContractEvents`) | `onMount` ✅ |
| Wallet address change reactivity in a component | `watchConnection` inside `onMount` ✅ (wagmi v3; `watchAccount` is deprecated) |
| Derived/computed values from props | `$derived` ✅ |
| Wallet writes (`writeContract`) | event handler functions ✅ |

**Files:** `src/lib/components/ProposalCard.svelte` (onMount for hasVoted + countdown)

---

## Testing Conventions

### Directory Layout

All tests live in a **dedicated `tests/` directory at the project root** — never co-located with source files.

```
tests/
  components/           ← mirrors src/lib/components/
    ProposalStatus.svelte.test.ts   (browser – vitest-browser-svelte)
    ProposalCard.svelte.test.ts     (browser)
    FetchProposals.test.ts          (server – node environment)
    WalletStore.test.ts             (server)
  routes/               ← mirrors src/routes/
    create-proposal/
      submitButtonUnable.test.ts    (server)

contracts/test/         ← Foundry tests stay here (separate tool chain)
  unit/
  integration/
  security/
```

### Vitest Setup (`vite.config.ts`)

Two Vitest projects are configured:

| Project | Pattern | Environment | Use for |
|---------|---------|-------------|---------|
| `client` | `tests/**/*.svelte.{test,spec}.{js,ts}` | Browser (Playwright/Firefox headless) | Svelte component rendering tests |
| `server` | `tests/**/*.{test,spec}.{js,ts}` (excl. `*.svelte.*`) | Node | Pure logic, fetch mocks, utility functions |

Run all tests: `npm run test`
Watch mode: `npm run test:unit`

### File Naming

- **Browser component test**: `ComponentName.svelte.test.ts` — picked up by the `client` project
- **Server/logic test**: `moduleName.test.ts` — picked up by the `server` project
- Must always be placed inside `tests/`, mirroring the source directory structure

### Required Imports per Test Type

**Browser tests** (`*.svelte.test.ts`):
```typescript
import { render } from 'vitest-browser-svelte';
import { expect, test, describe, vi } from 'vitest';
import { page } from '@vitest/browser/context';
```

**Server tests** (`*.test.ts`):
```typescript
import { describe, test, expect, vi, beforeEach } from 'vitest';
```

### Standard Mock Patterns

```typescript
// publicClient (all on-chain reads)
vi.mock('$lib/config/viem/client', () => ({
  publicClient: { readContract: vi.fn(), getContractEvents: vi.fn() }
}));

// WalletStore (wallet state)
vi.mock('$lib/components/WalletStore.svelte.ts', () => ({
  walletStatus: { address: '', status: 'disconnected' }
}));

// wagmi (writes only)
vi.mock('@wagmi/core', () => ({
  writeContract: vi.fn(),
  waitForTransactionReceipt: vi.fn(),
  getTransactionCount: vi.fn()
}));

// Stub heavy Svelte sub-components (e.g. ApexChart)
vi.mock('$lib/components/ApexChart.svelte', () => ({ default: {} }));
```

### `expect: { requireAssertions: true }`

Every test must include **at least one assertion**. Tests with no `expect(...)` call will fail.

### Fuzz Testing

Add fuzz/boundary tests alongside unit tests in the same file:
- Use `for` loops over boundary value arrays (e.g., `n = 0..10` for length boundaries)
- Test out-of-range enum values, zero counts, empty strings, unicode inputs, extreme `bigint` values
- Fuzz tests are grouped in a `describe('... – fuzz: ...')` block

---

## Project Audit Rule

When asked to review, screen, or audit the project, always:

1. **Scan all source files** (both `contracts/src/` and `src/`) for inline comment tags: `FIX`, `BUG`, `ISSUE`, `WARN`, `IMPORTANT`, `TEST`.
2. **Catalogue every finding** with its file path, line number, tag type, and the comment text.
3. **Assess Pros and Cons** of the current architecture and implementation:
   - Pros: What the project does well (security patterns, decentralization, code clarity, test coverage, stack choices).
   - Cons: What is incomplete, fragile, hardcoded, or a known risk.
4. **Update `README.md`** — add or refresh an "## Code Audit" section that lists every tagged finding, grouped by tag type, with file links and a brief description of the action required.
5. **Do not silently fix** a `BUG`/`FIX`/`ISSUE` tag during an audit pass — document it first; only fix if the user confirms.
6. **Highlight vulnerabilities** Highlight the critical issues in `README.md` when screening all the files 

## `README.md` pattern
1. As simple as possible, be clear, clean and tidy
2. Describe the project directories and structure
3. Provide markdown mermaid diagrams for understanding the architecture and flow of the project

### Current Tagged Findings (as of last audit)

#### `FIX`
| File | Line | Note |
|---|---|---|
| `src/lib/components/HomeProposalCard.svelte` | 27 | Date/time formatting broken — needs a correct Intl/`toLocaleDateString` approach |
| `src/lib/components/ProposalCard.svelte` | 43 | Same date/time formatting issue as above |

#### `BUG`
| File | Line | Note |
|---|---|---|
| `src/lib/components/Navbar.svelte` | 100 | Wallet modal overlay conflicts with hamburger dropdown (z-index / event propagation) |

#### `TEST` (contracts — demo/local only, NEVER use in production)

> ⚠️ The following `TEST:` values in `MiniDaoGovernance.sol` are intentionally shortened for local development and demonstration. Deploying these values to any public network (Sepolia, mainnet) creates extreme governance risks — proposals can be created, voted on, queued, and executed in under 2 minutes with virtually no quorum resistance.

| File | Line | Current (TEST) value | Production value |
|---|---|---|---|
| `contracts/src/MiniDaoGovernance.sol` | 15 | `QUORUM_VOTES = 300 * 10^18` (≈ 3 wallets each holding ≥10 MDAO) | Use `GovernorVotesQuorumFraction` (e.g. 4%) |
| `contracts/src/MiniDaoGovernance.sol` | 36 | `votingDelay = 30 seconds` | `1 days` minimum |
| `contracts/src/MiniDaoGovernance.sol` | 40 | `votingPeriod = 1 minutes` | `1 weeks` minimum |

Before any non-local deployment, replace all three values and switch `QUORUM_VOTES` to a fraction-based quorum.

#### `WARN` (contracts)
| File | Line | Note |
|---|---|---|
| `contracts/src/MiniDaoGovernance.sol` | 14 | `QUORUM_VOTES` hardcoded — replace with `GovernorVotesQuorumFraction` for production |
| `contracts/src/MiniDaoVoteBox.sol` | 12 | Initial owner is `msg.sender`; ownership must be transferred to timelock post-deploy |
| `contracts/src/MiniDaoToken.sol` | 30 | Override required by Solidity (informational — no action needed) |

#### `WARN` (frontend)
| File | Line | Note |
|---|---|---|
| `src/lib/config/appKitConfig.ts` | 12, 20 | Hardcoded to Anvil — switch to mainnet/Sepolia for production |
| `src/lib/config/viem/client.ts` | 5 | Hardcoded to Anvil — switch to mainnet/Sepolia for production |

#### `IMPORTANT`
| File | Line | Note |
|---|---|---|
| `src/routes/api/upload_proposal/upload_to_ipfs.ts` | 17 | Signature expiry check — rejects requests older than 5 minutes |
| `src/routes/api/upload_proposal/upload_to_ipfs.ts` | 26 | Signature verification — ensures request authenticity via `verifyMessage` |
| `src/routes/api/upload_proposal/upload_to_ipfs.ts` | 73 | IPFS CID extracted from response header after Filebase upload |
