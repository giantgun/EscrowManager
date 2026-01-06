# EscrowManager

A simple, audited-like Escrow contract for ERC20 tokens built with Foundry. The contract enables a buyer to deposit ERC20 tokens into an escrow, designate a seller and an arbiter, and resolve the trade either by buyer release, seller auto-release after timeout, or arbiter arbitration if disputed.

---

## 🔧 Project Structure

- `src/EscrowManager.sol` — Primary contract implementing escrow logic, fees, and dispute resolution.
- `script/DeployEscrowManager.s.sol` — Foundry script used to deploy `EscrowManager` (includes a sample token address).
- `test/EscrowManagerTest.t.sol` — Comprehensive Forge tests covering happy paths, edge cases, and invariants.
- `foundry.toml` — Foundry configuration (remappings and dependencies).
- `Makefile` — Convenience targets for running tests, starting Anvil, and deploying.

> Note: the repository ignores typical development artifacts such as `lib/`, `dependencies/`, `cache/`, `broadcast/`, and `coverage/` (see `.gitignore`).

---

## ⚙️ Contract Overview (`src/EscrowManager.sol`)

Key features:

- ERC20-based escrow: any ERC20 token can be used by passing its address to the constructor.
- Roles: **buyer**, **seller**, **arbiter**, **platform owner (I_OWNER)**.
- Escrow lifecycle statuses: `NONE`, `AWAITING_DELIVERY`, `DISPUTED`, `COMPLETED`, `REFUNDED`.
- Fees:
  - Platform fee: **0.1%** (10 BPS)
  - Arbiter fee (on dispute resolution): **1%** (100 BPS)
- Safety: uses `ReentrancyGuard` and `SafeERC20` for robust token interactions.

Important behaviors:

- `createEscrow(seller, arbiter, amount, timeoutSeconds)` — Buyer creates an escrow and transfers `amount` tokens into the contract.
  - Validations: no zero addresses, non-zero amount and timeout, arbiter cannot be buyer or seller.
- `release(id)` — Only buyer can release funds to seller; platform fee is taken and remainder sent to seller.
- `dispute(id)` — Only buyer can mark an escrow `DISPUTED` (prevents release/auto-release until resolved).
- `autoRelease(id)` — Only seller can call after the configured timeout has elapsed; behaves like `release`.
- `arbitrate(id, releaseToSeller)` — Only arbiter can resolve a `DISPUTED` escrow; distributes platform and arbiter fees, and remaining to buyer or seller based on `releaseToSeller`.

Events and Errors:

- Events: `EscrowCreated`, `Released`, `Disputed`, `Arbitrated`, `AutoReleased`.
- Custom errors provide gas-efficient reverts: `NotBuyer`, `NotSeller`, `NotArbiter`, `InvalidState`, `InvalidInput`, `TimeoutNotReached`, `ArbiterCannotBeBuyerOrSeller`.

---

## ✅ Test Coverage

All important flows are covered in `test/EscrowManagerTest.t.sol` including:

- Escrow creation and validation (inputs, balances).
- Access control checks for `release`, `dispute`, `autoRelease`, and `arbitrate`.
- Correct fee calculation and transfers (platform + arbiter fees).
- Timeout-based `autoRelease` behavior.
- State safety: ensuring no invalid state transitions or double actions.
- Account invariants (contract balance should be zero after payouts).

To run tests locally:

```bash
# run all tests
forge test

# or via the Makefile (requires .env with ETH_MAINNET_RPC_URL set for forking)
make run-tests
```

---

## 🚀 Local Development & Deployment

Prerequisites:

- Foundry (forge, cast, anvil) installed: https://book.getfoundry.sh/
- An Ethereum RPC URL (for mainnet forking) or a local Anvil instance.
- Optional: a funded private key for broadcasting transactions.

Quick start:

1. Start a local Anvil node (optionally fork mainnet):

```bash
# simple Anvil
make setup-anvil

# or fork with on-disk state from state.json
make setup-anvil-with-state
```

2. Run tests:

```bash
forge test
```

3. Deploy (example using Makefile target):

```bash
# configure .env with DEV_PLATFORM_PRIVATE_KEY and ETH_MAINNET_RPC_URL, then:
make deploy-escrow-manager
```

Or directly with Forge:

```bash
forge script script/DeployEscrowManager.s.sol --broadcast --private-keys <PRIVATE_KEY> --rpc-url <RPC_URL>
```

The `script/DeployEscrowManager.s.sol` uses a sample ERC20 address for MNEE; update the address in the script if you intend to deploy with a different token.

---

## 🛡️ Security Notes & Considerations

- Reentrancy protection: `ReentrancyGuard` is used on mutating external functions.
- Safe token handling: `SafeERC20` is used for token transfers.
- The contract assumes the ERC20 token behaves per the spec; non-standard tokens may cause issues.
- `I_OWNER` (platform fee receiver) is immutable and set to `msg.sender` at deployment — consider using a multisig for production.
- Arbiter is a centralized decision-maker in dispute flows; choose a trusted arbiter or an oracle-based mechanism for decentralization.
- Gas and economic considerations: fees are fixed BPS constants — review them for production suitability.

---

## 🧪 How to interact (examples)

Assuming a deployed `EscrowManager` at `0x...` and an ERC20 `MNEE` token with allowance set:

```js
// Create escrow (buyer)
escrow.createEscrow(sellerAddr, arbiterAddr, amount, timeoutSeconds)

// Buyer releases to seller
escrow.release(escrowId)

// Buyer opens a dispute
escrow.dispute(escrowId)

// Seller auto-release after timeout
escrow.autoRelease(escrowId)

// Arbiter resolves dispute
escrow.arbitrate(escrowId, true /* release to seller */)
```

---

## 📄 License

All code is licensed under **MIT** (see SPDX header in Solidity files).

---

## 🙋 Contributing

Contributions and improvements are welcome. Please open issues or pull requests. Keep tests green and add tests for new behaviors.

---

If you want, I can also add quick-code examples using `cast` or an ethers script demonstrating the most common flows. 🔧
