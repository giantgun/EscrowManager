# EscrowManager: ERC20 MNEE based Escrow(mainnet-ready) 🚀

**Implemented by [Cuniro](https://Cuniro.vercel.app) on Sepolia testnet. [go to Cuniro Repository->](https://github.com/giantgun/Cuniro)**

**EscrowManager is a simple, non‑custodial escrow contract built to work seamlessly with the MNEE USD‑backed ERC20 (or any ERC20 token).** This repository includes mainnet-friendly scripts and facilities for working with MNEE in development, testing and production.

---

## TL;DR

- 🔒 Non‑custodial: buyer tokens are held in the EscrowManager contract until release/refund
- 💸 ERC20 compliant: designed for and uses **MNEE (ERC20)**, all flows operate in the configured ERC20
- 🧾 Fees enforced on‑chain: **platform fee = 0.1% (10 BPS)**, **arbiter fee = 1% (100 BPS)**
- 🧪 Developer-ready: includes `MockMNEE`, Foundry scripts, and Makefile helpers for forking, funding and deployment

---

## 2) Features

- ERC20-based escrow:  project integrates with MNEE (USD-backed ERC20), by passing MNEE ERC20 token address (constructor).
- Strong access control via specific role checks (buyer, seller, arbiter).
- Safe token transfers using `SafeERC20` and reentrancy protection via `ReentrancyGuard`.
- Compact, gas-friendly error handling with custom errors.
- Full test coverage (happy paths, edge cases, invariants).

---

## 3) Non-Custodial Architecture

EscrowManager is **non‑custodial**: the contract itself holds tokens for each escrow and enforces the rules that move funds (buyer release, seller auto‑release after timeout, or arbiter resolution on dispute).

Simple step‑by‑step flow:

1. Buyer approves `EscrowManager` to spend the token and calls `createEscrow(seller, arbiter, amount, timeout)`.
2. `EscrowManager` transfers tokens in via `safeTransferFrom` and records an `Escrow` entry (status = `AWAITING_DELIVERY`).
3. While `AWAITING_DELIVERY`, funds are locked in the contract and can only be moved by these actions:
   - Buyer calls `release` → platform fee (0.1%) to `I_OWNER`, remainder to seller → status `COMPLETED`.
   - Seller calls `autoRelease` after `timeout` → same effect as `release`.
   - Buyer calls `dispute` → status `DISPUTED` → arbiter calls `arbitrate(escrowId, releaseToSeller)` → platform fee (0.1%) to `I_OWNER`, arbiter fee (1%) to arbiter, remainder to winning party → status `COMPLETED` or `REFUNDED`.

Flow diagram (clear block view):

```text
+------------------+        approve & createEscrow        +--------------------+
|      Buyer       | ------------------------------------> |   EscrowManager    |
| (initiates flow) |                                       | (contract holds     |
+------------------+                                       |  escrowed tokens)   |
                                                             +---------+----------+
                                                                       |
                             ------------------------------------------+---------------------------------------------
                            |                                          |                                            |
                   release (buyer)                              autoRelease (seller, after timeout)        dispute (buyer)
                         |                                                     |                                     |
                         v                                                     v                                     v
                 +---------------+                                   +---------------+                       +----------------+
                 |   Seller      |                                   |   Seller      |                       |    Arbiter     |
                 | (receives     |                                   | (receives     |                       | (resolves dispute)
                 |  payout minus |                                   |  payout minus |                       +----------------+
                 |  platform fee) |                                   |  platform fee) |                               |
                 +---------------+                                   +---------------+                               v
                                                                                                                            |
                                                                                                     arbitrate(decision) |
                                                                                                                            v
                                                                                                            +---------------------+
                                                                                                            |  Seller OR Buyer    |
                                                                                                            | (receives remaining |
                                                                                                            |  after platform &   |
                                                                                                            |  arbiter fees)      |
                                                                                                            +---------------------+

Notes
- Platform fee (0.1%) always goes to I_OWNER when funds are released or arbitrated.
- If a dispute is arbitrated, the arbiter also receives an arbiter fee (1%).
- Tokens remain locked in `EscrowManager` until one of the above moves them.
```

Why this matters:

- ✅ **Non‑custodial**: funds are held in the smart contract, not by a central operator
- ✅ **Auditable & deterministic**: state transitions (events and status) are visible on‑chain
- ✅ **Defined resolution paths**: buyer release, seller auto‑release after timeout, or arbiter resolution ensure funds don't remain stuck



---

## 4) Tech Stack

- Smart Contracts: Solidity + OpenZeppelin
- Development & Testing: Foundry (forge, cast, anvil)
- Libraries: `SafeERC20`, `ReentrancyGuard`

---

## 5) Project Structure

```
├── src/
│   ├── EscrowManager.sol      # Core escrow contract
│   └── MockMNEE.sol           # Local mock ERC20 used in tests/deploy scripts
├── script/
│   ├── DeployEscrowManager.s.sol  # Deploy scripts (mainnet/testnet variants)
│   └── DeployMockMNEE.s.sol       # Deploys MockMNEE for testnets/dev
├── test/
│   └── EscrowManagerTest.t.sol    # Forge tests covering flows and invariants
├── Makefile      # high-level convenience tasks (forking, deploys, fund accounts)
├── foundry.toml  # Foundry config
├── .env          # env vars (RPC URLs, wallet names, token addresses) - not committed
├── LICENSE
└── README.md
```

---

## Deployment

Prereqs:

- Windows Subsystem for Linux(WSL), for windows users
- Foundry (forge, cast, anvil) see https://book.getfoundry.sh/
```bash
# run this in terminal after installing foundry tool chain
git clone https://github.com/giantgun/EscrowManager
cd EscrowManager
forge install
```
- A mainnet RPC (Infura/Alchemy) for forking; export as `ETH_MAINNET_RPC_URL`
- Make installed(You can copy commands directly from Makefile)


Wallet setup (secure deployments using `cast`/`forge`):
- Never store private keys or mnemonics holding real funds, as plain text in a .env file.
- To import a prefunded wallet and use the `SECURE_WALLET_NAME` .env variable, used by Makefile deploy targets run:
```bash 
cast wallet import <YOUR_SECURE_WALLET_NAME> --interactive
```

For Testnet deployment (`DeployEscrowManagerToTestnet`):

- Required `.env` variables:
  - `SEPOLIA_RPC_URL` : RPC endpoint for the testnet
  - `SECURE_WALLET_NAME` : the wallet identifier used by `cast`/`forge` (e.g., `PLATFORM_SECURE_WALLET`)
  - `SECURE_WALLET_PUBLIC_ADDRESS` : public address for the deployer/sender
  - `MNEE_TESTNET_ADDRESS` : (optional) testnet MNEE address or use `MockMNEE`


NOTE: Comment(#) the DEV_MNEMONIC .env variable to avoid errors before deployment

```bash
# deploy to Sepolia (uses MNEE_TESTNET_ADDRESS in .env file)
make deploy-escrow-to-testnet
```

For Mainnet deployment (`DeployEscrowManager`):

- Required `.env` variables:
  - `ETH_MAINNET_RPC_URL` : mainnet RPC for broadcasting/forking
  - `SECURE_WALLET_NAME` : wallet identifier for secure signing
  - `SECURE_WALLET_PUBLIC_ADDRESS` : public address for the deployer
  - `MNEE_MAINNET_ADDRESS` : (optional) set and confirm if you switch the script to env-driven addresses

NOTE: Comment(#) the DEV_MNEMONIC .env variable to avoid errors before deployment

```bash
# deploy to mainnet (Makefile calls DeployEscrowManager)
make deploy-escrow-to-mainnet
```



> Tip: The mainnet MNEE address is hard coded in `script/DeployEscrowManager.s.sol`, for explicit env-driven deployments, set `MNEE_MAINNET_ADDRESS` and modify the script to read from `vm.envAddress("MNEE_MAINNET_ADDRESS")`.


---

## Development

Prereqs:

- Windows Subsystem for Linux(WSL), for windows users
- Foundry (forge, cast, anvil), see https://book.getfoundry.sh/
```bash
# run this in terminal after installing foundry tool chain
git clone https://github.com/giantgun/EscrowManager
cd EscrowManager
forge install
```
- A mainnet RPC (Infura/Alchemy) for forking; export as `ETH_MAINNET_RPC_URL`
- Make installed(You can copy commands directly from Makefile)

Important `.env` variables used in Makefile/scripts (development & deployments):

- `ETH_MAINNET_RPC_URL` : mainnet RPC URL used for forking and mainnet broadcast (e.g. Infura/Alchemy)
- `SEPOLIA_RPC_URL` : Sepolia / testnet RPC URL used for testnet deploys
- `DEV_PLATFORM_PRIVATE_KEY` : (local dev) private key for the dev platform account (do NOT commit this)
- `DEV_MNEMONIC` : mnemonic used for anvil/fork account generation (local dev)
- `DEV_WHALE` : an address with large MNEE balance used for impersonation/funding on a fork
- `DEV_BUYER_PUBLIC_KEY` : public address used as the buyer in local tests
- `DEV_SELLER_PUBLIC_KEY` : public address used as the seller in local tests
- `DEV_ARBITER_PUBLIC_KEY` : public address used as the arbiter in local tests
- `DEV_PLATFORM_PUBLIC_KEY` : public platform owner key used in local testing (I_OWNER)
- `MNEE_TESTNET_ADDRESS` : testnet MNEE address (or set to `MockMNEE` deployment address)
- `MNEE_MAINNET_ADDRESS` : (optional) mainnet MNEE address (useful if you make the deploy script env-driven)
- `MNEE_ADDRESS` : used in Makefile example commands for `cast` funding (alias for the token address)
- `MOCK_MNEE_WHALE_ADDRESS` : whale address for `MockMNEE` funding when using the mock token
- `SECURE_WALLET_NAME` : name/identifier for the secure wallet registered with `cast`/`forge` (used as `--account`)
- `SECURE_WALLET_PUBLIC_ADDRESS` : public address for the secure deployer wallet (used as `--sender`)

Security notes:
- Never store private keys or mnemonics holding real funds, as plain text in a .env file.
- To import a prefunded wallet and use the `SECURE_WALLET_NAME` .env variable, used by Makefile deploy targets run:
```bash 
cast wallet import <YOUR_SECURE_WALLET_NAME> --interactive
```
 

Quick helpers:
- `make load-env` loads `.env` into your shell for the Makefile tasks (or use `export $(cat .env | xargs)`)
- `make setup-env-wsl`bsets up `.env` for wsl users, afterwards use `make load-env`.

Fast paths (Makefile targets):

```bash
# fork mainnet with saved state (state.json)
make setup-anvil-with-state

# impersonate the whale and fund dev accounts with MNEE
make impersonate-whale
make fund-dev-accounts

# run tests (runs test using the mainnet fork)
make run-tests
```

---

## MNEE integration

This project is **MNEE‑centric** (MNEE is a USD‑backed ERC20 used in our flows), but the contracts remain token-agnostic, any ERC20 will work when its address is passed into the constructor.

Key integration points:

- `EscrowManager(address _mnee)` : the contract stores `I_MNEE = IERC20(_mnee)` and all escrow flows are denominated in that token.
- `createEscrow` uses `I_MNEE.safeTransferFrom(msg.sender, address(this), amount)` : buyers must `approve` first.
- Fees and payouts are performed in the configured token (platform fee and arbiter fee are calculated using BPS constants in contract).

Canonical addresses referenced in repo:

- **Mainnet MNEE (used in tests/scripts):** 0x8ccedbAe4916b79da7F3F612EfB2EB93A2bFD6cF
- **Testnet sample / example:** 0xc387Eed7806EBaca48335d859aE8D2F122aEFD54

> For local/dev workflows use `MockMNEE` and `DeployMockMNEE.s.sol` to avoid using mainnet tokens.

---

## 8) Contract Behavior 🔎

Below is a concise reference for every externally visible function, storage, important events, errors, and fees in `EscrowManager.sol`.

### Constants & fees

- `PLATFORM_FEE_BPS = 10` : platform fee (0.1% of escrow amount).
- `ARBITER_FEE_BPS = 100` : arbiter fee (1% of escrow amount) paid on arbitration.
- `BPS_DENOMINATOR = 10_000` : denominator used to compute fees from BPS.

### Public storage

- `address public immutable I_OWNER` : deployer by default; receives platform fees (make this a multisig in prod).
- `IERC20 public immutable I_MNEE` : the ERC20 token used for escrows (commonly MNEE).
- `uint256 public escrowCount` : number of escrows created (monotonic counter).
- `mapping(uint256 => Escrow) public escrows` : stores `Escrow` structs with fields: `buyer`, `seller`, `arbiter`, `amount`, `createdAt`, `timeout`, `status`.

### Events

- `EscrowCreated(uint256 id, address buyer, address seller, address arbiter, uint256 amount, uint256 timeout)` : emitted when a buyer creates an escrow.
- `Released(uint256 indexed id)` : emitted when buyer explicitly releases funds to seller.
- `Disputed(uint256 indexed id)` : emitted when buyer opens a dispute.
- `Arbitrated(uint256 indexed id, bool releasedToSeller)` : emitted when arbiter resolves a dispute.
- `AutoReleased(uint256 indexed id)` : emitted when seller triggers an auto‑release after timeout.

### Errors (reverts)

- `NotBuyer()`, `NotSeller()`, `NotArbiter()` : access control reverts for the respective roles.
- `InvalidState()` : called when an operation is attempted in the wrong escrow state.
- `InvalidInput()` : invalid or missing input to `createEscrow`.
- `TimeoutNotReached()` : `autoRelease` attempted before timeout.
- `ArbiterCannotBeBuyerOrSeller()` : arbiter must be distinct from buyer and seller.

---

### Public functions & behavior (detailed)

- `constructor(address _mnee)`
  - Stores `I_MNEE = IERC20(_mnee)` and sets `I_OWNER = msg.sender`.
  - Use this to pin the token used for all later escrow flows.

- `createEscrow(address seller, address arbiter, uint256 amount, uint64 timeoutSeconds) external nonReentrant returns (uint256 id)`
  - Preconditions: `seller != address(0)`, `arbiter != address(0)`, `amount > 0`, `timeoutSeconds > 0`, `arbiter != seller`, `arbiter != msg.sender`.
  - Calls `I_MNEE.safeTransferFrom(msg.sender, address(this), amount)` : buyer must `approve` first.
  - Increments `escrowCount`, stores the `Escrow` struct (status = `AWAITING_DELIVERY`) and emits `EscrowCreated`.
  - Reverts with `InvalidInput()` or `ArbiterCannotBeBuyerOrSeller()` on bad inputs.

- `release(uint256 id) external nonReentrant onlyBuyer(id) inState(id, EscrowStatus.AWAITING_DELIVERY)`
  - Buyer finalizes the sale; internal `_releaseToSeller` is executed.
  - Fee behavior: platform fee (0.1%) is transferred to `I_OWNER`, remainder to the seller.
  - Sets status to `COMPLETED` and emits `Released`.

- `dispute(uint256 id) external nonReentrant onlyBuyer(id) inState(id, EscrowStatus.AWAITING_DELIVERY)`
  - Buyer opens a dispute; sets escrow status to `DISPUTED` and emits `Disputed`.
  - Prevents further `release` or `autoRelease` flows until arbiter resolves.

- `autoRelease(uint256 id) external nonReentrant onlySeller(id) inState(id, EscrowStatus.AWAITING_DELIVERY)`
  - Seller triggers release after `block.timestamp >= createdAt + timeout`.
  - Reverts `TimeoutNotReached()` if called too early.
  - Internally calls `_releaseToSeller` and emits `AutoReleased` when successful.

- `arbitrate(uint256 id, bool releaseToSeller) external nonReentrant onlyArbiter(id) inState(id, EscrowStatus.DISPUTED)`
  - Arbiter resolves a dispute. If `releaseToSeller == true` funds go to seller, otherwise refunded to buyer.
  - Fee handling: platform fee (0.1%) goes to `I_OWNER`, arbiter fee (1%) goes to `e.arbiter`, and the remaining amount is transferred to the deciding party.
  - Status set to `COMPLETED` (seller wins) or `REFUNDED` (buyer wins). Emits `Arbitrated`.

---

### Internal helper

- `_releaseToSeller(uint256 id) internal`
  - Sets status to `COMPLETED`, computes platform fee and payout, transfers the platform fee to `I_OWNER` and the payout to `e.seller`.

---

> Note: All transfers use `SafeERC20` (`safeTransfer` / `safeTransferFrom`) to handle non‑standard tokens safely, and `nonReentrant` is applied to state‑changing external functions for safety.

---

## Examples & common flows

CLI / Makefile convenience:

- `make setup-anvil-with-state` : start anvil fork with saved state
- `make impersonate-whale` + `make fund-dev-accounts` : fund local dev accounts with MNEE
- `make deploy-escrow-to-testnet` : deploy using `DeployEscrowManagerToTestnet`
- `make deploy-escrow-to-mainnet` : deploy using `DeployEscrowManager` (verify the token address before broadcast)

---

## Security & production notes 🔐

- **Set `I_OWNER` to a multisig** in production (it collects platform fees).
- Confirm MNEE decimals (18) and that the token is ERC20‑standard; be careful with non‑standard tokens.
- The contract uses `SafeERC20` and `ReentrancyGuard` to reduce common risks.
- Add on‑chain monitoring and consider circuit breakers for high‑value usage.

---

## License

This repository is licensed under the MIT License. See the `LICENSE` file for the full license text and attribution requirements. The source files include SPDX license headers (where applicable), please retain them when modifying or redistributing this code.

