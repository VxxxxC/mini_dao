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

- `MiniDaoGovernance`: `QUORUM_VOTES` is hardcoded to 5 tokens; future improvement is `GovernorVotesQuorumFraction`.
- `appKitConfig.ts` and `viem/client`: Hardcoded to Anvil — must be updated for any non-local deployment.
- Proposal pages currently use mock data (`src/lib/mock_data.ts`) — replace with real API calls when the backend is ready.

---

## Project Audit Rule

When asked to review, screen, or audit the project, always:

1. **Scan all source files** (both `contracts/src/` and `src/`) for inline comment tags: `FIX`, `BUG`, `ISSUE`, `WARN`, `IMPORTANT`.
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

#### `WARN` (contracts)
| File | Line | Note |
|---|---|---|
| `contracts/src/MiniDaoGovernance.sol` | 22 | `QUORUM_VOTES` hardcoded to 5 tokens — replace with `GovernorVotesQuorumFraction` |
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
