# Elite Specialist V11 (Visual Pro Edition) — "SCALPER KILLER"
### Developed by Kananelo Mafabatho 

An institutional-grade, multi-asset algorithmic trading system designed natively for MetaTrader 5 (MQL5). This Expert Advisor (EA) targets high-probability **Breakout-Retest** structures across major global financial indices (**NAS100, US30, GER40**), digital assets (**Bitcoin**), and commodities (**XAUUSD/Gold**). 

The underlying architecture shifts the core system away from traditional retail breakout chasing ("candle chasing") toward institutional order-block retests, structural overextensions, volatility-adjusted corridors, and runtime multi-asset profile auto-configuration.

---

## 🧭 Evolution & Technical Development Journey

The system underwent aggressive structural iterations to overcome typical retail trading system vulnerabilities, evolving from a simple breakout bot to an asset-specialized, institutional execution machine.

### 1. Traditional Breakout Failures (V1.0 - V8.0)
* **The Mechanism:** Focused on classical mechanical breakout trading across simple support and resistance lines.
* **The Flaws:** High vulnerability to institutional stop-hunts ("fakeouts"). The system constantly chased aggressive momentum spikes at market opens (e.g., NY opening bell), resulting in entering positions at the absolute peak or floor right before a sharp trend reversal occurred. 

### 2. High-Probability & Asymmetric Shifts (V9.0 - V9.5)
* **The Breakout-Retest Paradigm Split:** Quantitative observation proved that top-tier indices heavily favor retesting broken structural key areas before launching primary expansion legs. 
* **The Asymmetric Scaling Phase:** To target a high mechanical win-rate (~80%), an asymmetric risk-engine was coded. This took a heavy partial close (70% of position volume) early at a 1:1 or 1:1.2 risk-to-reward ratio, instantly moving the stop loss to a +5 point risk-free profit cushion.

### 3. Deep Architectural Vulnerability Fixes (V9.5 Critical Transition)
Rigorous optimization exposed several critical edge cases where the core state machine could freeze or experience silent logic degradation. A complete rewrite of the entry and level-selection logic was implemented:

* **Eliminating Perpetual State-Locking (The Timeout Engine):** Early versions set a boolean state `breakoutPhaseBullish = true` upon a level break but had no expiration date. If price continued flying upward without an immediate pullback, the state stayed locked in memory for hours or days. When a completely random pullback occurred much later, the EA executed a trade on a completely dead, invalid setup. We engineered a strict candle-based time-out algorithm (`InpTimeoutBars`) that clears the state automatically if a retest fails to materialize inside a hyper-focused window.
* **Fixing Migrating Levels (Level-Locking):** Early versions checked for a retest against `freshResistance` dynamically on every bar. However, because resistance levels update dynamically as new candles print, the reference level would move *during* the retest phase. We fixed this by introducing dedicated variables (`brokenLevel`, `brokenResistance`, `brokenSupport`) that freeze the exact breakout price coordinate in memory the moment a structural breach is confirmed.
* **Symmetric Retest Corridors vs. Fixed Points:** Early models looked for a rigid fixed-point buffer (e.g., `100 points`). This was highly restrictive and completely blind to cross-asset volatility—100 points is massive on GER40, completely invisible on US30, and easily missed on NAS100. We replaced this with a dynamic, volatility-adjusted corridor calculated as a percentage of the current ATR (`activeRetestATRPercent`). This creates an invisible, proportional channel (`brokenLevel ± retestTolerance`) allowing price to wick slightly past or turn around marginally short of the absolute line while still executing cleanly.
* **Reversal Momentum Wick Traps:** The original candle reversal validation accepted any candle where the lower wick was larger than the body. This allowed large, aggressive bearish momentum candles with extended lower shadows to trigger a BUY order, forcing the system to catch a falling knife. The logic was hardened to enforce that a bullish reversal candle *must* print a net-positive close over its open (`prevClose > prevOpen`) while maintaining a dominant lower wick rejection.
* **The Continuous OnTick Recalculation Loop:** To optimize memory usage, the `iTime()` new-bar gate was moved to wrap around the entire structural scanning layout. This prevents the EA from burning CPU cycles recalculating major high/low levels on every individual price tick, while leaving the execution tracking logic to monitor price changes in real-time.

### 4. Full Profile Specialization & Visual Masterclass (V11.0 - Present)
* **Dynamic Asset Profiles:** Removed rigid user input bottlenecks. The EA now reads the broker's underlying asset string name during `OnInit()` and dynamically injects specialized risk, threshold, and spread profiles matching that specific asset class at runtime.
* **Netting & Single-Execution Handlers:** Fixed silent order rejection bugs on prop-firm netting environments by introducing the `setupTraded` sentinel, ensuring exactly one pristine execution sequence is allowed per distinct breakout event.
* **Deactivation of Partial Closures:** To fulfill specific prop-firm risk criteria and avoid partial execution failures on strict zero-hedging broker engines, scaling-out parameters have been entirely bypassed, routing the asset to pure, unadulterated risk-to-reward targets.
* **UX/UI Branding Overlay:** Transforms standard MT5 charts into a premium workspace using an automatic institutional UI skin (Navy background, custom Sky Blue and Slate Gray candlestick schemes, unique timestamp-mapped S/R zone boxes, and a crisp background watermark banner).

---

## 🛠️ Core Strategy Architecture

The automated execution loop operates within a highly disciplined, multi-layered filtration process:

```text
[H4 HIGHER TIMEFRAME FILTER] -> Fast EMA (50) vs. Slow EMA (200) Trend Alignment
               |
               v
[ADX MOMENTUM VERIFICATION] -> Filters out low-volume, choppy consolidation ranges
               |
               v
[STRUCTURAL GEOMETRY SCAN]  -> Extracts absolute Anchor Highs/Lows via Lookback window
               |
               v
[BREAKOUT EVENT DETECTED]   -> Identifies structural breach; locks Level & Time coordinates
               |
               v
[PULLBACK RETEST CORRIDOR]  -> Monitors price retracement into ATR-buffered channel
               |
               v
[CANDLESTICK REJECTION]     -> Enforces directional validation -> EXECUTE TRADE ORDER


1. **Macro Trend Gating:** Evaluates systemic market direction on the H4 timeframe. The system will strictly reject buy signals if price is drifting under the 200 EMA, keeping you aligned with the dominant institutional trend direction.
2. **ADX Momentum Threshold:** Verifies structural expansion velocity. If the market is moving sideways with an ADX reading below the asset profile requirement, the system goes entirely flat, avoiding choppy ranges.
3. **Anchor Extraction:** Searches the user-defined `InpStructureLookback` window to determine core support and resistance blocks. It projects active visual rectangles forward into future chart space.
4. **The Retest Validation Sequence:** When a candle closes completely past a visual level, the state machine switches into observation mode. It calculates a dynamic tolerance channel using the ATR. If price pulls back into this zone within the allotted time (`InpTimeoutBars`) and prints an explicit rejection candle, the market order is fired instantly.

---

## ⚙️ Comprehensive Input Parameter Reference

### Core Risk Management
* `InpUseDynamicLot` (`bool`): Toggle between fixed lot allocation and advanced equity risk calculation.
* `InpRiskPercent` (`double`): Percentage of account equity risked per position based on the distance between your entry price and the calculated ATR Stop Loss.
* `InpFixedLotSize` (`double`): Default lot size applied if dynamic lot sizing is deactivated.
* `InpMaxPositions` (`int`): Maximum concurrent open trades allowed for the running asset to maintain strict margin distribution.
* `InpMaxDailyLossUSD` (`double`): Absolute equity circuit breaker. If the closed daily loss meets this cash value, the EA locks itself out until the next daily rollover. Set to `0.0` to disable.

### Base Structural Mechanics
* `InpStructureLookback` (`int`): The historical candle count scanned on the operational timeframe to identify valid peak resistance and valley support anchors.
* `InpATRPeriod` (`int`): The mathematical evaluation frame for the Average True Range indicator used across all volatility metrics.
* `InpTimeoutBars` (`int`): The strict lifespan of a setup. Represents the maximum number of candles allowed for price to return and execute a retest before the setup is discarded.
* `InpUsePartialTP` (`bool`): Global switch for scaling-out logic (natively set to `false` to enforce single-target risk metrics).

### Base Macro Trend (H4 Only)
* `InpFastEMA` (`int`): Period of the short-term Exponential Moving Average applied to identify immediate H4 macro structural shifts.
* `InpSlowEMA` (`int`): Period of the long-term institutional Exponential Moving Average used to isolate absolute macro trend direction.

---

## 📊 Asset Profile Auto-Detection Matrix

The internal engine automatically handles parameter variations across volatile index environments, crypto trends, and commodity wicks. Upon loading on a chart, the EA automatically self-configures to one of the following dynamic profiles:

### 1. Indices Profile (`US30`, `NAS100`, `GER40`)
Optimized for the explosive expansion bursts and technical level respect characteristic of global equity indices.
* **Max Spread Allowance:** 50.0 Pips
* **ADX Trend Intensity Floor:** 22.0
* **Stop Loss Multiplier:** 2.2x ATR
* **Take Profit Multiplier:** 4.5x ATR
* **Retest Corridor Depth:** 20% of current ATR (`0.20`)

### 2. Digital Assets Profile (`BTCUSD`)
Designed for wide crypto spreads, high-volatility deviations, and deep retest pullbacks.
* **Max Spread Allowance:** 1500.0 Pips
* **ADX Trend Intensity Floor:** 15.0
* **Stop Loss Multiplier:** 1.2x ATR
* **Take Profit Multiplier:** 2.5x ATR
* **Retest Corridor Depth:** 12% of current ATR (`0.12`)

### 3. Precious Metals Profile (`XAUUSD / Gold`)
Custom-tailored to withstand the typical liquidity sweeps and deep wick rejections common in commodity markets.
* **Max Spread Allowance:** 40.0 Pips
* **ADX Trend Intensity Floor:** 20.0
* **Stop Loss Multiplier:** 2.0x ATR
* **Take Profit Multiplier:** 3.5x ATR
* **Retest Corridor Depth:** 15% of current ATR (`0.15`)

### 4. Generic Currency Profile (Fallback Baseline)
Applied automatically if the host asset string does not match any of the high-impact specialist profiles above.
* **Max Spread Allowance:** 30.0 Pips
* **ADX Trend Intensity Floor:** 25.0
* **Stop Loss Multiplier:** 2.0x ATR
* **Take Profit Multiplier:** 3.0x ATR
* **Retest Corridor Depth:** 15% of current ATR (`0.15`)

---

## 🖥️ Graphic Interface & Custom Theme Personalization

The EA overwrites the default MetaTrader presentation with a highly readable, high-contrast visual layer:

* **Institutional Deep Navy Skin:** Shifts chart properties to an elegant dark interface palette (`RGB 10, 25, 47`), removing grid noise and adding a clean layout designed for long trading sessions.
* **Dynamic Candlestick Mapping:** Custom overrides force bullish candles to render in bright Deep Sky Blue (`RGB 0, 191, 255`) and bearish structures to render in clean Slate Gray (`RGB 128, 128, 128`).
* **Extended Structural Rectangles:** Dynamically renders historical support blocks (Red) and resistance blocks (Blue). The EA manages these object parameters automatically, extending them forward across time until a clear breakout event alters the structural landscape.
* **Background Watermark Stamp:** Applies an institutional background title component directly onto the chart's background layer, featuring **"SCALPER KILLER by Kananelo Mafabatho"** styled in ultra-bold Impact typography.

---

## 🚀 Deployment & Installation Protocol

1. Launch your **MetaTrader 5** terminal environment.
2. Select **File** from the main navigation bar -> click **Open Data Folder**.
3. Inside the file directory, navigate to **MQL5** -> opening the **Experts** folder.
4. Copy your `Elite_Specialist_V11_Vis.mq5` source file and paste it directly into this directory.
5. Return to MetaTrader 5. Expand the **Navigator** menu block, right-click **Experts**, and choose **Refresh**.
6. Open your desired workspace asset (e.g., `NAS100`, `US30`, or `XAUUSD`) on either the **M15** or **M30** timeframe.
7. Click and drag the Expert Advisor from the Navigator list directly onto the chart layout.
8. Under the **Common** properties tab panel, ensure that the checkbox for **"Allow Algo Trading"** is explicitly marked **True**.
9. Click the global **Algo Trading** execution button at the top menu of your terminal window to activate automated order routing.

---
## ⚠️ Risk & Operational Disclaimer
Automated trading across leveraged financial instruments (including stock indices, spot metals, and decentralized crypto-assets) carries a very high level of capital risk. This trading robot is an automated utility designed for statistical modeling and execution assistance. Always perform extensive demo trading and historical evaluation over varying market conditions before deploying live investment capital.
