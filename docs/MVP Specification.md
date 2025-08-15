# MVP Build Spec — **Base Pies** (M1‑style portfolios on Base L2)

> **Objective:** Ship a non‑custodial, window‑rebalanced **pie/slice** portfolio vault on **Base** with ERC‑20/4626 semantics, async settlement, and social sharing. **Deposit/withdraw in USDC**, auto‑rebalance via allowed routers (Uniswap Universal Router; optional 0x aggregator). Target **M1‑like UX**: pies with target weights, fractional shares, batch trades 1×/day, clear activity feed.

---

## 0) Environment, Addresses & Standards

| Item                         | Value                                                                                                                                            |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Network**                  | Base Mainnet (`chainId=8453`) ([Base Documentation][1])                                                                                          |
| **USDC (native)**            | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` ([Circle Developers][2])                                                                            |
| **WETH9**                    | `0x4200000000000000000000000000000000000006` ([Uniswap Docs][3])                                                                                 |
| **Uniswap Universal Router** | `0x6fF5693b99212dA76Ad316178A184Ab56D299b43` (Base) ([Uniswap Docs][3])                                                                          |
| **Permit2**                  | `0x000000000022D473030F116dDEE9F6B43aC78BA3` (chain‑agnostic) ([Uniswap Docs][3])                                                                |
| **0x Swap API**              | Supported on Base (`chainId=8453`) (use returned `to` + `data`; allowlist target per governance) ([0x][4])                                       |
| **Chainlink Price Feeds**    | Use official feeds on Base; consult addresses registry; apply staleness/deviation guards ([Chainlink Documentation][5], [Base Documentation][6]) |
| **Gelato Automation**        | Network supported (Base Mainnet & Sepolia) for redundant keeper ([docs.gelato.network][7])                                                       |
| **Aerodrome AMM**            | Base’s central liquidity hub (secondary venue) ([Aerodrome Finance][8], [GitHub][9])                                                             |
| **Standards**                | ERC‑20, **ERC‑4626**, **ERC‑7540** (async vault requests), EIP‑2612, **Permit2** ([Ethereum Improvement Proposals][10])                          |

---

## 1) System Overview (MVP)

**Core idea:** Each **Pie** is an **async ERC‑4626 vault** with **USDC** as accounting/primary asset. Users **request** deposits/withdrawals; a daily **window** processes all requests at fair batch prices via DEX aggregation and mints/burns **Pie shares (ERC‑20)** at realized execution.

**Components**

1. **PieFactory** — deploys PieVaults; sets allowlists/params.
2. **PieVault (Async4626)** — holds assets; exposes request/claim flows; maintains target weights; mints/burns shares; tracks NAV.
3. **BatchRebalancer** — computes deltas, obtains quotes, executes swaps, settles requests, updates accounting.
4. **TradeAdapter** — allowlisted router calls (Uniswap UR; optional 0x EP target from quote).
5. **OracleModule** — Chainlink + TWAP sanity; staleness/deviation checks.
6. **KeeperGate** — Chainlink/Gelato triggers; anyone‑can‑exec fallback.
7. **Indexer/Subgraph** — Pies, slices, requests, fills, NAV, performance.
8. **Frontend** — Pies & Slices UI, activity feed, share/clone, Farcaster Frame.

---

## 2) Contract Suite (spec for agents)

### 2.1 Interfaces (Solidity signatures)

> **PieFactory**

```solidity
event PieCreated(address indexed pie, address indexed creator, string name);
function createPie(
  string calldata name,
  string calldata symbol,
  address[] calldata assets,          // ERC20 + ERC4626 tokens (allowlist)
  uint16[] calldata weightsBps,       // sum=10_000
  address feeReceiver,
  uint16 mgmtFeeBps,                  // MVP = 0
  uint32 rebalanceWindowStartSecUTC   // e.g., 15:00:00 UTC
) external returns (address pie);
function setGlobalAllowlist(address token, bool allowed) external;
```

> **PieVault (ERC‑20 + ERC‑4626 + ERC‑7540‑like async)**

```solidity
// --- Metadata/Accounting
function asset() external view returns (address);        // USDC
function totalAssets() public view returns (uint256);    // USDC-denominated NAV (see Oracle)
function convertToShares(uint256 assets) public view returns (uint256);
function convertToAssets(uint256 shares) public view returns (uint256);
function getSlices() external view returns (address[] memory tokens, uint16[] memory weightsBps);

// --- Async Requests (ERC-7540 style)
enum ReqStatus { None, Pending, Executed, Cancelled, Claimed }
struct Request { address owner; uint128 amt; uint128 shares; uint40 window; uint8 kind; ReqStatus status; }

event DepositRequested(uint256 indexed id, address indexed owner, uint256 assets);
event DepositExecuted(uint256 indexed id, uint256 assetsNet, uint256 sharesMinted);
event RedeemRequested(uint256 indexed id, address indexed owner, uint256 shares);
event RedeemExecuted(uint256 indexed id, uint256 sharesBurned, uint256 assetsOut);

function requestDeposit(uint256 assets, address receiver) external returns (uint256 reqId);
function requestRedeem(uint256 shares, address receiver) external returns (uint256 reqId);
function cancel(uint256 reqId) external;
function claim(uint256 reqId) external;

// --- Admin/Creator
event WeightsUpdated(address[] tokens, uint16[] weightsBps, uint40 effectiveWindow);
function scheduleWeights(address[] calldata tokens, uint16[] calldata weightsBps) external; // applies next window
function setParams(uint16 slippageBps, uint16 maxTradeBpsPerWindow) external;

// --- Settlement (only BatchRebalancer)
function settleWindow(uint40 windowId, bytes calldata settlementData) external;
```

> **BatchRebalancer**

```solidity
event WindowProcessed(uint40 indexed windowId, uint256 navPre, uint256 navPost, uint256 gasUsed);
function processWindow(address pie) external; // keeper entry
```

> **TradeAdapter**

```solidity
function execUniswap(bytes calldata universalRouterCommands, bytes[] calldata inputs) external;
function exec0x(address target, bytes calldata data, uint256 msgValue) external; // target must be allowlisted
```

> **OracleModule**

```solidity
function getUsdPrice(address token) external view returns (uint256 priceE18, uint256 lastUpdateSec, bool healthy);
```

> **KeeperGate**

```solidity
function openWindow(address pie) external;  // validates schedule, nonces
```

**Access/Roles**

* `DEFAULT_ADMIN`, `GOVERNOR`, `CREATOR`, `KEEPER`. Pausable; timelocked sensitive changes.

---

### 2.2 Storage (PieVault)

* `mapping(address token => uint256 balance)` — tracked holdings (pull from token balances for truth).
* `address[] sliceTokens`; `uint16[] weightsBps`.
* `uint40 currentWindowId`; `uint32 windowOpenTimeUTC`.
* `uint16 slippageBps`; `uint16 maxTradeBpsPerWindow`.
* `mapping(uint256 => Request)` requests; `uint256 reqNonce`.
* `uint256 mgmtFeeBps`; `address feeReceiver`.
* `uint256 lastNavUsdE18` (cached at last window for UI).

---

### 2.3 Invariants

* Weights sum = **10,000 bps** at effective window.
* `totalAssets()` (USD) uses **realized** post‑trade valuations; mint/burn share math uses **NAV\_pre** to avoid oracle‑only exploits.
* No share price dilution: `assetsIn/totalAssets_pre == sharesMinted/totalSupply_pre`.
* Requests immutable after execution; idempotent window settlement guarded by `windowId`.

---

## 3) Core Algorithms

### 3.1 NAV & Deltas (USD accounting)

* Prices: Chainlink USD feeds per token; fallback to AMM TWAP if stale (> `staleSec`) or deviation > `maxDeviationBps`. ([Chainlink Documentation][11], [Base Documentation][6])
* `NAV = Σ (qty_i * price_i)`
* Targets: `T_i = w_i * NAV`
* Deltas: `Δ_i = T_i – (qty_i * price_i)` → **Sell set** if Δ<0, **Buy set** if Δ>0.
* Enforce `|trade_i| ≤ maxTradeBpsPerWindow * NAV`.

### 3.2 Share Mint/Burn (batch fairness)

At settlement:

* **Mint**: let `D_net` = net USD from deposit requests after fills/fees.
  `sharesMinted = totalSupply_pre * D_net / NAV_pre`.
* **Burn**: `assetsOwed = totalAssets_pre * sharesToBurn / totalSupply_pre` (then convert to USDC via sells respecting caps).
* **Claim**: users receive shares (mint) or USDC (redeem).

### 3.3 Routing

* **Primary**: Uniswap **Universal Router**; multi‑hop, permit flows. ([Uniswap Docs][12])
* **Optional**: 0x **Swap API** quotes (AMMs+RFQ). Keeper fetches quote with `chainId=8453`; onchain calls the **returned** `to`/`data`, subject to **target allowlist**. ([0x][4])
* **Venues**: Uniswap v3, Aerodrome; RFQ when available to reduce MEV/price impact. ([Uniswap Docs][3], [Aerodrome Finance][8])

---

## 4) End‑to‑End Flows (UI ↔ Contracts)

### 4.1 Create Pie (creator)

1. UI collects name, symbol, **allowlisted** tokens, weights (sum=100%).
2. `PieFactory.createPie(...)` → emits `PieCreated`.
3. `scheduleWeights(...)` optional to defer changes to next window.
   **AC:** Weights validated; non‑allowlisted tokens rejected; events indexed.

### 4.2 Deposit (follower)

1. UI amount in **USDC** → **Permit2** signature (no prior approvals). ([Uniswap Docs][3])
2. `USDC.permit2(...)` then `PieVault.requestDeposit(assets, receiver)`.
3. Status shows **Pending(windowId)**; on settlement → **Executed** → user **claim()** or auto‑claim by executor.
   **AC:** Pending request visible; after window processed, `shares > 0` minted with batch price; activity feed shows fills.

### 4.3 Withdraw

1. `requestRedeem(shares, receiver)` → **Pending**.
2. On window settlement: pie sells overweight first, then pro‑rata; proceeds **USDC** earmarked.
3. User `claim(reqId)` to receive USDC.
   **AC:** User gets USDC within slippage bounds; pie remains within target caps.

### 4.4 Rebalance Window (keeper)

1. `KeeperGate.openWindow(pie)` verifies schedule/nonces.
2. Read balances & prices → compute deltas.
3. Build trades (sell set then buy set), request quotes (UR / 0x), enforce slippage caps, execute via **TradeAdapter**.
4. Settle all requests: compute `NAV_pre`, mint/burn via formulas, mark executed, emit events, update `lastNavUsdE18`.
   **AC:** Single atomic settlement; partial trade allowed if guardrails hit; leftover rolled to next window with reason codes.

---

## 5) Tasks for Autonomous Coding Agents

### Epic A — **Smart Contracts**

**A1. PieFactory (UUPS or non‑upgradeable for MVP)**

* Implement `createPie`, global allowlist, and minimal governance.
* **Tests:** weight sum check; allowlist enforcement; event emission.

**A2. PieVault (ERC‑20 + ERC‑4626 + Async‑Requests)**

* Implement request/claim lifecycle compatible with **ERC‑7540** semantics (async deposit/redeem). ([Ethereum Improvement Proposals][10])
* Implement share math, `totalAssets()` (USD via Oracle), slice config, params.
* **Events:** `DepositRequested/Executed`, `RedeemRequested/Executed`, `WeightsUpdated`.
* **Guards:** reentrancy, pausable, per‑window idempotence.
* **Tests:** property tests for mint/burn, rounding at 6/18 decimals, multi‑request fairness.

**A3. BatchRebalancer**

* Compute deltas, order of operations (sells then buys), cap per‑asset trade %, slippage guard.
* Settle requests with pre/post NAV calc; write settlement receipts.
* **Tests:** shock scenarios (±20% prices), partial executions, revert paths, idempotence.

**A4. TradeAdapter**

* `execUniswap(commands, inputs)` passthrough to **Universal Router**; validate `deadline`, `minOut`. ([Uniswap Docs][3])
* `exec0x(target,data,msg.value)`; **target allowlist** updated by governor; reject unlisted targets; enforce `minOut` via decoded calldata or pre‑check from quote.
* **Tests:** calldata fuzzing; ensure no ETH dust leaks; no arbitrary external calls.

**A5. OracleModule**

* Read Chainlink USD feeds; track `lastUpdate`, deviation vs previous; AMM TWAP fallback.
* **Tests:** stale feed, halted feed, large deviation; TWAP correctness windows. ([Chainlink Documentation][11])

**A6. KeeperGate**

* Enforce schedule (crontab‑like), prevent double open, expose emergency `anyoneCanExecute` after grace.
* **Tests:** timing, replay, access.

**A7. Libraries & Roles**

* OZ `SafeERC20`, `AccessControl`, `Pausable`, `ReentrancyGuard`.
* Roles: `GOVERNOR`, `CREATOR`, `KEEPER`.

---

### Epic B — **Keeper/Off‑Chain Agents**

**B1. Quote Planner**

* For each pie, compute delta book; for each asset:

  * Prefer RFQ (0x) then AMM (UR) given price impact & fees.
  * Batch small orders; TWAP if `|Δ|/NAV` > threshold.
* **AC:** JSON plan with routes, minOuts, router targets.

**B2. Executor**

* Submit `processWindow(pie)` calling `TradeAdapter` with built calldata.
* Use **Gelato** & **Chainlink Automation** redundancy; backoff + retry. ([docs.gelato.network][7])
* **AC:** Window processed ≤ N blocks from open; receipts stored; gas usage within budget.

**B3. Risk Sentinel**

* Live checks: Chainlink stale, price deviation, slippage fail; trigger circuit‑breaker → partial settlement or skip thin pairs.

---

### Epic C — **Indexing & Data**

**C1. Subgraph Schema**

* Entities: `Pie`, `Slice`, `Request`, `Trade`, `Window`, `NavSnapshot`, `UserPosition`.
* Index events; compute **TWR**, allocation history, drawdowns.

**C2. APIs**

* `/pies`, `/pies/:id/allocations`, `/users/:addr/positions`, `/windows/:id/report`.

---

### Epic D — **Frontend (UX parity with M1)**

**D1. Pie Builder**

* Drag weights (bps), form validation (sum=100%), allowlist picker, preview allocations vs \$ input.

**D2. Invest Flow**

* **Permit2** sign → `requestDeposit`; UI shows **Pending** with ETA (window time).
* Activity feed: “Queued \$X deposit”, “Rebalanced: Sold A, Bought B”, “Minted Y shares”.

**D3. Withdraw Flow**

* `requestRedeem`; display projected USDC out with range (minOut based on slippage).

**D4. Social**

* Shareable URL + Farcaster Frame (read‑only pie card) with “Copy Pie” → new Pie with same weights.

---

## 6) Verification Plan (ultra)

**Property/Invariants (Foundry/SMT)**

* **I1:** `weightsSum == 10_000`.
* **I2:** Mint/burn preserves value: `D_net / NAV_pre == sharesMinted / supply_pre` ± ε.
* **I3:** No value leak: `Σ user shares / totalSupply == 1` after any sequence.
* **I4:** Idempotent settlement: re‑execute same window ⇒ no state change.

**Fuzz**

* Random price paths (±50%), mixed 6/18‑decimals, batched requests, partial fills.

**Economic Sims**

* Backtest daily windows with Base historical prices; drift vs target, trade cost vs impact.

**Integration**

* Dry‑run on **Base Sepolia** with Circle test USDC; 0x/UR “simulate only” first; dual keeper. ([Circle Developers][2])

**Observability**

* Prometheus on keeper; subgraph health; per‑window NAV diff tolerance.

---

## 7) Security & Guardrails

* **Allowlists:** assets, routers, 0x targets.
* **Slippage defaults:** 30–80 bps; per‑asset override.
* **Caps:** per‑window trade bps, per‑asset concentration bps.
* **Oracles:** Chainlink primary; staleness/deviation (e.g., 30m/200 bps) → TWAP fallback or **skip** asset. ([Chainlink Documentation][11])
* **Pausable:** request intake pause; emergency withdraw queue.
* **Upgrade strategy:** MVP non‑upgradeable PieVault; upgradeable Factory/Adapters with timelock.

---

## 8) Acceptance Criteria (MVP)

* Create a pie with 5 allowlisted tokens; weights=100%.
* 3 users queue deposits; 1 window executes; each receives shares with **identical** price per share.
* NAV before/after consistent with executed trades and fees (epsilon < 1e‑9).
* Withdraw request settles to USDC within configured slippage.
* UI shows pie chart, allocation table, activity feed; shareable link & “Copy Pie”.
* Subgraph reports TWR and allocations accurately for ≥30 days of simulated windows.

---

## 9) Implementation Checklist (atomic subtasks)

**Contracts**

* [ ] Define interfaces & events (A1–A5).
* [ ] Implement PieFactory with allowlist.
* [ ] Implement PieVault (ERC‑20, ERC‑4626, async requests, share math).
* [ ] Implement BatchRebalancer (delta calc, settlement).
* [ ] Implement TradeAdapter (UR + optional 0x).
* [ ] Implement OracleModule (Chainlink + TWAP).
* [ ] Roles, Pausable, Reentrancy, Tests (unit/property/fuzz).
* [ ] Deploy to Base Sepolia; run invariant tests.

**Keepers**

* [ ] Planner (delta book → routes → calldata).
* [ ] Executors (Chainlink + Gelato jobs).
* [ ] Monitoring & alerting.

**Data**

* [ ] Subgraph entities & mappings.
* [ ] API endpoints.

**Frontend**

* [ ] Pie builder, invest, withdraw, activity feed.
* [ ] Permit2 flow; EIP‑2612 fallback.
* [ ] Frame card integration.

---

## 10) Key Formulas & Pseudocode

**sharesMinted**

```text
if totalSupply == 0: shares = assetsIn  // 1:1 bootstrap
else: shares = floor(totalSupply * D_net / NAV_pre)
```

**assetsOut on burn**

```text
assetsOut = floor(totalAssets_pre * sharesToBurn / totalSupply_pre)
```

**Delta book (USD)**

```text
NAV = Σ(q_i * p_i)
for each i: T_i = w_i * NAV; Δ_i = T_i - (q_i * p_i)
sells = { i | Δ_i < 0 }, buys = { i | Δ_i > 0 }
```

---

## 11) Constraints & Notes

* **USDC primary**; other deposit assets out‑of‑scope MVP (avoid router edge cases). ([Circle Developers][2])
* **Windowed** (daily 15:00 UTC default); not real‑time day trading (M1 parity).
* **Yield** via **ERC‑4626** slices allowed (allowlist only). (Accounting in USD; 4626 `preview*` used to value positions.)
* **MEV**: prefer RFQ/private routes (0x) when available; otherwise UR with tight slippage. ([0x][4])

---

## 12) Dev Ops & Config

* **Constants:** `staleSec=1800`, `maxDeviationBps=200`, `slippageBpsDefault=50`, `maxTradeBpsPerWindow=1500`.
* **Timings:** `windowId = floor((timestamp - t0)/86400)`.
* **Gas policy:** user pays for request tx; protocol pays keeper via sponsor (later).
* **Logging:** All state transitions emit events with windowId & reason codes.

---

## 13) Deliverables

* `/contracts`: `PieFactory.sol`, `PieVault.sol`, `BatchRebalancer.sol`, `TradeAdapter.sol`, `OracleModule.sol`, `KeeperGate.sol`, libs.
* `/script`: deployment scripts (Base Sepolia/Mainnet).
* `/keeper`: planner & executor (TypeScript/Go).
* `/subgraph`: schema + mappings.
* `/app`: web (Next.js) with **Pie** UI, **Permit2** deposit, activity feed.

---

## Reasoning

**Why this spec:** It reduces M1 features to **on‑chain primitives**: an **async ERC‑4626 pie vault** with **USDC accounting**, **windowed batch execution**, and **share‑based pro‑rata** economics. The approach matches Base’s infra (**USDC**, **Uniswap UR**, optional **0x** aggregation, **Chainlink** oracles, **Gelato/Chainlink** keepers), yielding an **M1‑like UX** without centralized brokerage. ([Circle Developers][2], [Uniswap Docs][3], [0x][4], [Chainlink Documentation][11], [docs.gelato.network][7])

**Verification (ultra):**

* Invariants on mint/burn and NAV conservation; async settlement idempotence; oracle staleness/deviation tests; routing guardrails with minOut; fuzz on decimals and partial executions.
* Dry‑run on Base Sepolia with Circle USDC; dual keeper; subgraph validation against on‑chain events. ([Circle Developers][2])

**Uncertainties:**

1. Depth/availability of **RFQ** on Base per asset (affects price impact). ([0x][4])
2. Token **allowlist** breadth vs. user demand at launch.
3. ERC‑4626 **async pattern** nuance across wallets/tools; we align with **EIP‑7540** semantics to standardize requests/claims. ([Ethereum Improvement Proposals][10])

**Confidence:** 0.78

[1]: https://docs.base.org/base-chain/quickstart/connecting-to-base "Connecting to Base - Base Documentation"
[2]: https://developers.circle.com/stablecoins/usdc-contract-addresses "USDC Contract Addresses"
[3]: https://docs.uniswap.org/contracts/v3/reference/deployments/base-deployments "Base Deployments | Uniswap"
[4]: https://0x.org/docs/developer-resources/supported-chains?utm_source=chatgpt.com "Chain Support"
[5]: https://docs.chain.link/data-feeds/price-feeds/addresses?utm_source=chatgpt.com "Price Feed Contract Addresses"
[6]: https://docs.base.org/learn/onchain-app-development/finance/access-real-world-data-chainlink?utm_source=chatgpt.com "Accessing real-world data using Chainlink Data Feeds"
[7]: https://docs.gelato.network/web3-services/web3-functions/supported-networks?utm_source=chatgpt.com "Supported Networks"
[8]: https://aerodrome.finance/docs?utm_source=chatgpt.com "Aerodrome Finance Docs."
[9]: https://github.com/aerodrome-finance/contracts?utm_source=chatgpt.com "Aerodrome Finance Smart Contracts"
[10]: https://eips.ethereum.org/EIPS/eip-7540?utm_source=chatgpt.com "ERC-7540: Asynchronous ERC-4626 Tokenized Vaults"
[11]: https://docs.chain.link/data-feeds/price-feeds?utm_source=chatgpt.com "Price Feeds"
[12]: https://docs.uniswap.org/contracts/universal-router/overview?utm_source=chatgpt.com "Overview"
