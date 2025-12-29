# Project Context

## Purpose

EMA Pullback Expert Advisor (EA) for MetaTrader 5 - An automated forex trading system that uses EMA crossovers, RSI filtering, and multi-timeframe analysis to identify and execute pullback trading opportunities.

### Key Features:

- EMA-based trend detection (Fast/Mid/Trend EMA)
- RSI multi-state filtering with bullish mode activation
- Multi-timeframe confirmation (M5 and M15)
- Smart money management with win/loss lot adjustment
- Pyramiding support with risk-based position sizing
- Multiple partial profit taking mechanisms:
  - RSI-EMA momentum reversal exit (RSI 70 → EMA10 pullback)
  - R-based retracement exit (TP1)
  - Structure-based exit (TP2 at EMA200/20-bar high)
- Trailing exit strategy

## Tech Stack

- **Language**: MQL5 (MetaQuotes Language 5)
- **Platform**: MetaTrader 5
- **Trading Library**: Trade.mqh
- **Version**: 3.93

## Project Conventions

### Code Style

- Use descriptive variable names with camelCase
- Global variables prefixed by type (h for handles, buf for buffers)
- Input parameters grouped by functionality
- Comments in Chinese for parameter descriptions
- Magic number for order identification: 20250304

### Architecture Patterns

- **Event-Driven**: OnInit(), OnTick(), OnDeinit(), OnTradeTransaction()
- **State Management**: PositionState struct to track position metadata and TP execution flags
- **Modular Design**: Separated into Signal, Risk, and TradeManager classes
- **Indicator Management**: Separate handles and buffers for each indicator
- **Visual Feedback**: Optional chart objects for signal visualization
- **Encapsulation**: Each module handles its own initialization, logic, and cleanup

### Testing Strategy

- Backtest on historical data in Strategy Tester
- Forward test on demo account before live deployment
- Monitor R multiples and partial close counts
- Track RSI hit 70 events and max R reached metrics
- Validate modular functionality independently
- Test edge cases like minimum lot sizes and volume validation

### Git Workflow

- Main branch: `main`
- Commit messages should describe strategy changes
- Test thoroughly before committing changes to production EA

## Domain Context

### Trading Strategy

**Pullback Trading System**:

1. **Trend Identification**: Price above EMA200, EMA20 > EMA200
2. **Entry Trigger**: Price pullback touches EMA20, RSI < 70
3. **Multi-Timeframe Filter**: M5 and M15 RSI >= 60 (optional)
4. **Entry**: Buy Stop order above pullback candle high
5. **Stop Loss**: Below pullback candle low
6. **Target**: Historical 20-bar high

**Exit Strategy**:

- **RSI-EMA TP** (first priority): When RSI crosses 70 and price returns to EMA10, close 50%
- **TP1** (R-based): When `max_r_reached >= 0.5` and profit falls below `0.05R`, close 50%
- **TP2** (structure-based): When price reaches EMA200 or 20-bar historical high, close 50% and move SL to breakeven
- **Final Exit**: RSI extreme (>75) + price below EMA10, OR price below EMA20
- Stop loss moved to breakeven after any partial TP execution

### Key Parameters

- **EMA Fast**: 10 (entry/exit reference)
- **EMA Mid**: 20 (pullback level)
- **EMA Trend**: 200 (trend filter)
- **RSI Period**: 14
- **RSI Enable**: 60 (bullish mode activation)
- **RSI Disable**: 52 (bullish mode deactivation)
- **RSI Max**: 70 (entry filter)
- **RSI Extreme**: 75 (aggressive exit)
- **Pyramiding R**: 1.0R (add positions when winning)
- **Max Positions**: 5

## Important Constraints

- **Broker Requirements**: Supports FOK/IOC filling modes
- **Minimum Lot**: Configurable via InpMinLots (default 0.04)
- **Slippage Tolerance**: 20 points default
- **Order Expiry**: Pending orders expire after 1 bar
- **Position Tracking**: Uses position state structure to store R distance, target high, RSI overbought flags, and TP execution status
- **Visual Objects**: Prefixed with "Signal*" and "Setup*"
- **Modular Architecture**: Code split into Defines.mqh, Signal.mqh, Risk.mqh, and TradeManager.mqh
- **State Management**: Each position maintains `has_hit_rsi_70` and TP execution flags to prevent duplicate exits

## External Dependencies

- MetaTrader 5 platform
- Trade.mqh library (standard MT5 library)
- Broker with symbol data and order execution capabilities
- Indicators: iMA (EMA), iRSI (RSI), iHigh (historical highs)

## Project Structure

```
EMA_Pullback/
├── EMA_Pullback_Pro_v3.93.mq5    # Main EA file with OnInit/OnTick/OnDeinit
├── Defines.mqh                    # Version constants and shared definitions
├── Signal.mqh                     # CSignalManager class - entry signals, MTF filter, indicator management
├── Risk.mqh                       # CRiskManager class - lot sizing, win/loss adjustment
├── TradeManager.mqh               # CTradeManager class - position management, TP logic, order placement
└── openspec/                      # Specification and design documentation
    ├── project.md                 # This file - project overview
    ├── AGENTS.md                  # AI agent guidelines
    └── specs/
        └── exit-management/
            └── spec.md            # Exit management requirements (RSI-EMA TP)
```

## Recent Changes

### v3.93 - Modular Refactoring and RSI-EMA TP

- **Modularization**: Split monolithic EA into Signal, Risk, and TradeManager classes
- **RSI-EMA Partial TP**: Added new exit mechanism triggering when RSI crosses 70 then price returns to EMA10
- **State Tracking**: Enhanced PositionState structure with `has_hit_rsi_70` flag
- **Code Organization**: Improved separation of concerns and maintainability
