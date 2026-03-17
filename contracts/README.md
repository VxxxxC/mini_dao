# Mini DAO — Contracts

Foundry-based Solidity smart contracts for the Mini DAO governance platform.

## Contracts

| Contract | File | Description |
|---|---|---|
| `MiniDaoToken` | `src/MiniDaoToken.sol` | ERC20 + ERC20Votes governance token (MDAO). 1B supply — 30% bootstrap, 70% treasury. |
| `MiniDaoTimeLock` | `src/MiniDaoTimeLock.sol` | `TimelockController`. 2-day default minDelay. Owns all governance targets. |
| `MiniDaoGovernance` | `src/MiniDaoGovernance.sol` | Governor with 1-day voting delay, 1-week voting period, 5-token quorum. |
| `MiniDaoFaucet` | `src/MiniDaoFaucet.sol` | 100 MDAO one-time claim per address. |
| `MiniDaoVoteBox` | `src/MiniDaoVoteBox.sol` | Governance-controlled on-chain vote store. Owned by timelock. |

### Deployment Order

```
Timelock → Token → Faucet → Governance → VoteBox
```

The deployment script (`DeployDao.s.sol`) follows this order, grants the Governor `PROPOSER_ROLE` + `CANCELLER_ROLE` on the timelock, sets `EXECUTOR_ROLE` to `address(0)` (open execution), then revokes `DEFAULT_ADMIN_ROLE` from the deployer.

---

## Foundry Usage

### Build

```sh
forge build
```

### Test

```sh
forge test -vvv
```

### Format

```sh
forge fmt
```

### Gas Snapshots

```sh
forge snapshot
```

### Deploy (local Anvil)

```sh
# start Anvil in another terminal
anvil

# deploy
forge script script/DeployDao.s.sol \
  --rpc-url http://localhost:8545 \
  --private-key <ANVIL_PRIVATE_KEY> \
  --broadcast
```

### Deploy (Sepolia)

```sh
forge script script/DeployDao.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### Anvil (local node)

```sh
anvil
```

### Cast

```sh
cast <subcommand>

# example — read VoteBox value
cast call <VOTEBOX_ADDRESS> "getVote()(uint256)" --rpc-url http://localhost:8545
```

### Help

```sh
forge --help
anvil --help
cast --help
```

---

## Test Coverage

Tests are in `test/MiniDaoTest.t.sol` and cover:

1. **`testDeployerTransferedTokenToFaucet`** — Verifies the deployer's 30% allocation was fully transferred to the faucet.
2. **`testCannotUpdateVoteBoxWithoutGovernance`** — Ensures direct calls to `VoteBox.storeVote()` revert without timelock authority.
3. **`testUpdateVoteBoxWithGovernanceProposal`** — Full end-to-end governance cycle: claim tokens → delegate → propose → vote → queue → execute → assert VoteBox updated.

---

## Network Config

`script/HelperConfig.s.sol` selects parameters by chain ID:

| Network | Chain ID | Deployer |
|---|---|---|
| Anvil (local) | 31337 | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` |
| Sepolia | 11155111 | `0x0406c906ad4214E97F80F706d4203e6d1cBF5E3E` |

Never hardcode addresses directly in scripts — use `HelperConfig` for all network-specific values.

---

## Dependencies

- [forge-std](https://github.com/foundry-rs/forge-std) — Foundry testing & scripting utilities
- [openzeppelin-contracts ^5.x](https://github.com/OpenZeppelin/openzeppelin-contracts) — Governor, ERC20Votes, TimelockController

See [Foundry docs](https://book.getfoundry.sh/) for full reference.

