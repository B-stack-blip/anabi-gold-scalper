Anabi Gold Scalper V1

Project Overview

An Expert Advisor (EA) for MetaTrader 5 designed to test a trend-following scalping strategy on Gold (XAUUSD).

Broker: Deriv
Platform: MetaTrader 5
Trading instrument: XAUUSD
Entry timeframe: M5
Trend confirmation: M15
Initial mode: Demo testing only

Strategy

The EA uses the following indicators:

* EMA 9 and EMA 21 for trend direction.
* RSI 14 for momentum confirmation.
* ADX 14 to filter weak trends.
* ATR 14 to calculate stop-loss distances.

Initial Risk Settings

* Risk per trade: 0.5% maximum intended risk.
* Reward-to-risk ratio: 1.5:1.
* Daily loss threshold: 2%.
* Maximum simultaneous positions for this EA: one per symbol.
* Maximum spread: configurable.

These settings are initial test parameters, not evidence of profitability.

Compilation Requirements

1. Obtain the source file AnabiGoldScalper.mq5.
2. Open it in MetaEditor supplied with MetaTrader 5.
3. Compile the source file.
4. Review all compiler errors and warnings.
5. Do not run the EA until compilation succeeds and its safety checks have been reviewed.

GitHub stores the source code but does not itself run an MT5 Expert Advisor.

Backtesting Procedure

1. Open the MT5 Strategy Tester on a compatible desktop environment.
2. Select AnabiGoldScalper.
3. Select the exact Gold symbol provided by the Deriv demo account.
4. Use the M5 entry timeframe.
5. Test a sufficiently long historical period.
6. Include realistic spreads, commissions and execution assumptions.
7. Record the total trades, net profit, profit factor, maximum drawdown and average trade result.
8. Repeat testing on a separate period that was not used to develop the strategy.

Demo Testing

Before considering live trading:

* Confirm that the EA initializes correctly.
* Confirm that entries follow the documented rules.
* Verify that every position has a valid stop-loss and take-profit.
* Check position sizing against actual account and instrument specifications.
* Confirm the daily loss protection behaves as intended.
* Monitor rejected orders, spread changes and execution errors.
* Run the strategy on demo for a meaningful period.

Important Limitations

A strategy can lose money even when it has automated risk controls.

The daily loss threshold in the initial source code blocks new entries after the threshold is reached; it does not automatically close existing positions. The daily baseline can also reset when the EA restarts. These behaviors must be reviewed before live use.

The source code must be compiled, reviewed and tested before deployment. No profit is guaranteed.

Never add passwords, API keys, account credentials or private wallet information to this repository.