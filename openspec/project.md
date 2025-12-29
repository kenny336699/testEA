# Project Context

## Purpose

EMA Pullback Expert Advisor (EA) for MetaTrader 5 - An automated forex trading system that uses EMA crossovers, RSI filtering, and multi-timeframe analysis to identify and execute pullback trading opportunities.

### Key Features:

- EMA-based trend detection (Fast/Mid/Trend EMA)
- RSI multi-state filtering with bullish mode activation
- Multi-timeframe confirmation (M5 and M15)
- Smart money management with win/loss lot adjustment
- Pyramiding support with risk-based position sizing
- Partial profit taking at multiple levels
- Trailing exit strategy

## Tech Stack

- **Language**: MQL5 (MetaQuotes Language 5)
- **Platform**: MetaTrader 5
- **Trading Library**: Trade.mqh
- **Version**: 3.92

## Project Conventions

### Code Style

- Use descriptive variable names with camelCase
- Global variables prefixed by type (h for handles, buf for buffers)
- Input parameters grouped by functionality
- Comments in Chinese for parameter descriptions
- Magic number for order identification: 20250304

### Architecture Patterns

- **Event-Driven**: OnInit(), OnTick(), OnDeinit(), OnTradeTransaction()
- **State Management**: PositionState struct to track position metadata
- **Indicator Management**: Separate handles and buffers for each indicator
- **Visual Feedback**: Optional chart objects for signal visualization
- **Modular Functions**: Separate functions for entry signals, position management, lot sizing

### Testing Strategy

- Backtest on historical data in Strategy Tester
- Forward test on demo account before live deployment
- Monitor R multiples and partial close counts
- Track RSI hit 70 events and max R reached metrics

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

- First TP (50%): RSI hit 70 + pullback to EMA10, OR reached target high, OR reached EMA200, OR pullback protection
- Second TP (remaining): RSI extreme + below EMA10, OR below EMA20
- Stop loss moved to breakeven after first TP

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
- **Position Tracking**: Uses comment field to store R distance and target high
- **Visual Objects**: Prefixed with "Signal*" and "Setup*"

## External Dependencies

- MetaTrader 5 platform
- Trade.mqh library (standard MT5 library)
- Broker with symbol data and order execution capabilities
- Indicators: iMA (EMA), iRSI (RSI)
