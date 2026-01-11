# EscrowManager 🚀

**Payment-safe, non-custodial escrow for ERC20 tokens** — built with Foundry and OpenZeppelin. EscrowManager lets buyers deposit ERC20 tokens into per-escrow contracts, designate a seller and an arbiter, and then resolve the trade via buyer release, seller auto-release after a timeout, or arbiter arbitration on dispute.

---

## 1) TL;DR

- 🔐 Non-Custodial Escrows — Tokens are held in the contract until a release/refund.
- 🧾 On-Chain Guarantees — Platform and arbiter fees enforced on-chain.
- ⏱ Timeout & Auto-Release — Sellers can trigger auto-release after timeout.
- 🛡️ Dispute Resolution — A designated arbiter resolves disputed escrows.
- ⚖️ Fee Model — Platform fee: 0.1% (10 BPS); Arbiter fee on disputes: 1% (100 BPS).

---

## 2) Features

- ERC20-based escrow: pass any ERC20 token address (constructor) — project commonly integrates with MNEE (USD-backed ERC20).
- Strong access control via specific role checks (buyer, seller, arbiter).
- Safe token transfers using `SafeERC20` and reentrancy protection via `ReentrancyGuard`.
- Compact, gas-friendly error handling with custom errors.
- Full test coverage (happy paths, edge cases, invariants).

---

## 3) Non-Custodial Architecture

Each escrow is a data entry in the `EscrowManager` contract that holds buyer funds until resolution.

┌─────────────────────────────────────────────────────────────┐
│                    Your Escrow (on-chain)                   │
│  ┌─────────────────┐  ┌─────────────────────────────────┐  │
│  │     Buyer       │  │        On-Chain Rules           │  │
│  │  (creates escrow)│  │ - Per-escrow timeout            │
│  │                  │  │ - Dispute arbitration           │
│  │  ✓ Deposit      │  │ - Platform + Arbiter fees       │
│  │  ✓ Release      │  │ - Auto-release after timeout    │
│  └─────────────────┘  └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

Why this matters:

- ✅ You own the funds until release — Escrow holds tokens, not the platform
- ✅ Transparent audit trail — Every action emits events and is verifiable on-chain
- ✅ Emergency controls — Arbiter & timeouts prevent stuck funds

---

## 4) Tech Stack

- Smart Contracts: Solidity + OpenZeppelin
- Development & Testing: Foundry (forge, cast, anvil)
- Libraries: `SafeERC20`, `ReentrancyGuard`

---

## 5) Project Structure

```
├── src/
│   └── EscrowManager.sol      # Core escrow contract
├── script/
│   └── DeployEscrowManager.s.sol  # Foundry deployment scripts (mainnet & testnet variants)
├── test/
│   └── EscrowManagerTest.t.sol # Forge tests
├── foundry.toml
├── Makefile
└── README.md
```

---

## 6) Getting Started

Prerequisites:

- Foundry (forge, cast, anvil) — https://book.getfoundry.sh/
- An Ethereum RPC URL (mainnet or testnet) or local Anvil
- A private key (for broadcasting deploy scripts)

Quick start:

```bash
# install foundry (if not already)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# run tests
forge test
```

Start a local dev node (Anvil):

```bash
# simple Anvil
make setup-anvil
```

Deploy with Forge (example):

```bash
# set env vars: MNEE_MAINNET_ADDRESS, PRIVATE_KEY, RPC_URL
forge script script/DeployEscrowManager.s.sol --broadcast --private-keys $PRIVATE_KEY --rpc-url $RPC_URL
```

Environment variables used by `script/DeployEscrowManager.s.sol`:

- `MNEE_MAINNET_ADDRESS` — mainnet MNEE ERC20 address
- `MNEE_TESTNET_ADDRESS` — testnet MNEE (or a test ERC20 you deployed)
- `PRIVATE_KEY` — deployer private key for broadcasting
- `RPC_URL` — RPC to use when broadcasting

Sample addresses (not hard-coded — set via env vars):

- Mainnet MNEE sample: `0x8ccedbAe4916b79da7F3F612EfB2EB93A2bFD6cF` (used in comments in the deploy script)
- Testnet MNEE sample: `0xc387Eed7806EBaca48335d859aE8D2F122aEFD54` (script comment)

---

## 7) MNEE Integration

This repository is frequently used with MNEE (USD-backed ERC20) but is token-agnostic — any ERC20-compatible token works. For local tests you can deploy a token fixture or point `MNEE_TESTNET_ADDRESS` at a locally deployed ERC20.

Key integration points:

- Constructor expects an `IERC20` token address (commonly MNEE)
- `createEscrow` collects tokens via `safeTransferFrom`
- Fees are paid out in the configured token

---

## 8) Contract Snapshot

`EscrowManager.sol` highlights:

- Roles: `buyer`, `seller`, `arbiter`, `I_OWNER` (fee recipient)
- Escrow lifecycle: `NONE → AWAITING_DELIVERY → (DISPUTED → ARBITRATED) → COMPLETED/REFUNDED`
- Fees: `PLATFORM_FEE_BPS = 10` (0.1%), `ARBITER_FEE_BPS = 100` (1%), denominator `10_000`
- Events: `EscrowCreated`, `Released`, `Disputed`, `Arbitrated`, `AutoReleased`
- Errors: `NotBuyer`, `NotSeller`, `NotArbiter`, `InvalidState`, `InvalidInput`, `TimeoutNotReached`, `ArbiterCannotBeBuyerOrSeller`

---

## 9) Usage Examples

JavaScript (ethers.js) example:

```js
// Create escrow (buyer)
await escrow.createEscrow(sellerAddr, arbiterAddr, amount, timeoutSeconds)

// Buyer releases
await escrow.release(escrowId)

// Buyer disputes
await escrow.dispute(escrowId)

// Seller auto-release after timeout
await escrow.autoRelease(escrowId)

// Arbiter resolves dispute
await escrow.arbitrate(escrowId, true)
```

`cast`/CLI examples can be added on demand for common flows.

---

## 10) Security & Production Notes

- Keep `I_OWNER` as a multisig in production (it receives platform fees).
- Review fee basis points for your economic model.
- Handle non-standard ERC20 tokens with caution.
- Tests are comprehensive; add more tests for any new feature.

---

## License

MIT — see SPDX headers and LICENSE file.

---

## Contributing

Contributions welcome — open issues and PRs. Please add tests for changes and keep the test suite green.

---

If you'd like, I can add a short `cast`/ethers script section or include a live example of deploying a test MNEE token for local development. 🔧
