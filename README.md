# Mini DAO

A full-stack Web3 governance platform. Community members claim governance tokens, delegate voting power, create proposals, vote, and execute approved actions on-chain through a timelock.

---

## Project Structure

```
contracts/          Foundry — Solidity smart contracts, scripts, tests
src/                SvelteKit — frontend UI, wallet integration, API routes
```

### Contracts

| Contract | Description |
|---|---|
| `MiniDaoToken` | ERC20 governance token (MDAO, 1B supply). 30% → faucet, 70% → treasury (timelock). |
| `MiniDaoTimeLock` | `TimelockController`. 2-day minDelay gates all on-chain execution. |
| `MiniDaoGovernance` | Governor. 1-day voting delay, 1-week voting period, 5-token quorum. |
| `MiniDaoFaucet` | One-time claim of 100 MDAO per address. |
| `MiniDaoVoteBox` | Governance-controlled vote store. Owned by the timelock. |

Deployment order: **Timelock → Token → Faucet → Governance → VoteBox**

### Frontend Stack

| Layer | Technology |
|---|---|
| Framework | SvelteKit v2 + TypeScript strict |
| UI | Tailwind CSS v4 + Flowbite-Svelte |
| Web3 | Wagmi v3 + Viem v2 + Reown AppKit |
| Storage | Filebase SDK (IPFS) |
| Deploy | Vercel adapter |

---

## Architecture

```mermaid
graph TD
    subgraph Frontend["SvelteKit Frontend (src/)"]
        UI[Pages & Components]
        API[API Routes]
        WS[WalletStore]
    end

    subgraph Web3["Web3 Layer"]
        AppKit[Reown AppKit]
        Wagmi[Wagmi v3]
        Viem[Viem v2]
    end

    subgraph Contracts["Smart Contracts (EVM)"]
        GOV[MiniDaoGovernance]
        TL[MiniDaoTimeLock]
        TOK[MiniDaoToken]
        FAU[MiniDaoFaucet]
        VB[MiniDaoVoteBox]
    end

    IPFS[(Filebase / IPFS)]

    UI --> WS
    UI --> API
    WS --> AppKit
    AppKit --> Wagmi
    Wagmi --> Viem
    Viem --> Contracts
    API --> IPFS

    GOV -->|queues| TL
    TL -->|executes| VB
    TOK -->|votes| GOV
    FAU -->|distributes| TOK
```

---

## Governance Flow

```mermaid
sequenceDiagram
    actor User
    participant Faucet as MiniDaoFaucet
    participant Token as MiniDaoToken
    participant Gov as MiniDaoGovernance
    participant Timelock as MiniDaoTimeLock
    participant VoteBox as MiniDaoVoteBox

    User->>Faucet: claim()
    Faucet-->>Token: transfer(user, 100 MDAO)
    User->>Token: delegate(self)

    User->>Gov: propose(targets, calldatas, description)
    Note over Gov: Voting Delay — 1 day

    User->>Gov: castVote(proposalId, FOR)
    Note over Gov: Voting Period — 1 week

    User->>Gov: queue(proposalId)
    Gov->>Timelock: scheduleBatch(...)
    Note over Timelock: minDelay — 2 days

    User->>Gov: execute(proposalId)
    Timelock->>VoteBox: storeVote(value)
```

---

## Local Development

**Prerequisites**: [Bun](https://bun.sh/) · [Foundry](https://book.getfoundry.sh/getting-started/installation)

```sh
# 1. Start local EVM node
anvil

# 2. Deploy contracts
cd contracts
forge script script/DeployDao.s.sol --rpc-url http://localhost:8545 --private-key <ANVIL_KEY> --broadcast

# 3. Install & run frontend
bun install
bun run dev
```

**`.env`** (project root):

```env
VITE_APPKIT_PROJECT_ID=<your_reown_project_id>
VITE_SEPOLIA_RPC_URL=<your_sepolia_rpc_url>
```

---

## Contract Development

```sh
cd contracts
forge build        # compile
forge test -vvv    # run tests
forge fmt          # format
forge snapshot     # gas snapshot
```

See [contracts/README.md](contracts/README.md) for full reference.

---

## Building for Production

```sh
bun run build
bun run preview
```

> Update `appKitConfig.ts` and `src/lib/config/viem/client.ts` from Anvil to your target network before deploying.

---

## Code Audit

### Pros

- **Decentralized by design** — deployer revokes `DEFAULT_ADMIN_ROLE` post-deploy; all mutations flow through Governor → Timelock.
- **OpenZeppelin base** — uses audited `Governor`, `TimelockController`, `ERC20Votes`, `ERC20Permit`; minimal custom logic.
- **Custom errors** — gas-efficient reverts (`AlreadyClaimed`, `TransferFailed`, `FaucetEmpty`); no `require` strings.
- **Signature verification** — off-chain proposals verify wallet signature + 5-min expiry server-side before any IPFS write.
- **E2E test coverage** — `MiniDaoTest.t.sol` covers the full cycle: deploy → claim → delegate → propose → vote → queue → execute.
- **Network isolation** — `HelperConfig.s.sol` separates Anvil / Sepolia params; no hardcoded addresses in scripts.
- **Type-safe frontend** — strict TypeScript, `.t.ts` type files, ABI JSON with module resolution.

### Cons

- **Hardcoded quorum** — `QUORUM_VOTES = 5 tokens` is static; `GovernorVotesQuorumFraction` would scale with supply.
- **Mock data** — proposal pages use `src/lib/mock_data.ts`; live IPFS API calls not yet wired up.
- **Trivial governance target** — `VoteBox` demonstrates the flow but has no real-world impact.
- **No on-chain/off-chain linkage** — IPFS proposals are not cryptographically tied to an on-chain `proposalId`.
- **Dual hardcoded network** — both `appKitConfig.ts` and `viem/client.ts` must be changed for production separately.

### Tagged Findings

> ⚠️ **Critical** — items marked `BUG` or `FIX` affect live user experience and must be resolved before production.

#### 🔴 `BUG`
| File | Line | Description |
|---|---|---|
| [Navbar.svelte](src/lib/components/Navbar.svelte#L100) | 100 | Wallet modal overlay conflicts with hamburger dropdown (z-index / event propagation) |

#### 🟠 `FIX`
| File | Line | Description |
|---|---|---|
| [HomeProposalCard.svelte](src/lib/components/HomeProposalCard.svelte#L27) | 27 | Date/time formatting broken — replace with `Intl.DateTimeFormat` or `toLocaleDateString` |
| [ProposalCard.svelte](src/lib/components/ProposalCard.svelte#L43) | 43 | Same date/time formatting issue |

#### 🟡 `WARN`
| File | Line | Description |
|---|---|---|
| [MiniDaoGovernance.sol](contracts/src/MiniDaoGovernance.sol#L22) | 22 | `QUORUM_VOTES` hardcoded — replace with `GovernorVotesQuorumFraction` |
| [MiniDaoVoteBox.sol](contracts/src/MiniDaoVoteBox.sol#L12) | 12 | Initial owner is `msg.sender`; transfer to timelock post-deploy |
| [appKitConfig.ts](src/lib/config/appKitConfig.ts#L12) | 12, 20 | Network hardcoded to Anvil — switch before production |
| [viem/client.ts](src/lib/config/viem/client.ts#L5) | 5 | Network hardcoded to Anvil — switch before production |

#### 🔵 `IMPORTANT`
| File | Line | Description |
|---|---|---|
| [upload_to_ipfs.ts](src/routes/api/upload_proposal/upload_to_ipfs.ts#L17) | 17 | Signature expiry check — rejects requests older than 5 minutes |
| [upload_to_ipfs.ts](src/routes/api/upload_proposal/upload_to_ipfs.ts#L26) | 26 | Signature verification via `verifyMessage` |
| [upload_to_ipfs.ts](src/routes/api/upload_proposal/upload_to_ipfs.ts#L73) | 73 | IPFS CID extracted from Filebase response header |

