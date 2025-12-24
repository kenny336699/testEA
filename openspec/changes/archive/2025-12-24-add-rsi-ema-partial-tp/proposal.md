# Proposal: Add RSI-EMA Partial Take Profit

## Summary

Add a new partial take profit mechanism that triggers when RSI crosses above 70 (overbought), then price returns to the 10 EMA. This provides an additional exit strategy capturing profit after RSI extremes, complementing the existing TP1/TP2 mechanisms.

## Why

**User Request**: "幫我加當 RSI 70 後回到 10 ema 就 tp 一半" (Add partial TP when RSI crosses 70 then returns to 10 EMA)

**Trading Rationale**:

- RSI > 70 indicates overbought conditions
- Price returning to 10 EMA after being overbought often signals short-term exhaustion
- This creates an opportunity to lock in profits before potential deeper retracements

**Risk Management**: Prevents giving back gains when momentum reverses after RSI extremes.

**Gap in Current System**: The EA has TP1 (R-based retracement) and TP2 (structure-based), but lacks a momentum-reversal exit that specifically targets RSI overbought → EMA pullback patterns.

## What Changes

- **PositionState Structure**: Add `has_hit_rsi_70` and `is_rsi_ema_tp_done` boolean fields to track RSI overbought state and TP execution status per position
- **ManageOpenPositions()**: Add RSI tracking logic to detect when RSI crosses 70 and partial TP logic to close 50% when price returns to EMA10
- **GetStateIndex()**: Initialize new state flags to false in both initialization blocks
- **Exit Management Spec**: New requirement defining RSI-EMA momentum reversal exit behavior with 9 detailed scenarios
- **Version Update**: Increment EA version to 3.8 and document the new feature in file header

## Context

Currently, the EA has two main partial TP mechanisms:

1. **TP1**: When `max_r_reached >= 0.5` and profit falls below `0.05R`, close 50%
2. **TP2/Structure TP**: When price reaches EMA200 or 20-bar high, close 50% and move to BE

However, there's no mechanism to capture profits specifically when RSI shows overbought conditions followed by a pullback to the 10 EMA—a common reversal signal in momentum trading.

## Motivation

**User Request**: "幫我加當 RSI 70 後回到 10 ema 就 tp 一半" (Add partial TP when RSI crosses 70 then returns to 10 EMA)

**Trading Rationale**:

- RSI > 70 indicates overbought conditions
- Price returning to 10 EMA after being overbought often signals short-term exhaustion
- This creates an opportunity to lock in profits before potential deeper retracements

**Risk Management**: Prevents giving back gains when momentum reverses after RSI extremes.

## Proposed Changes

### 1. Track RSI Overbought State

Add a new field to `PositionState` structure:

- `has_hit_rsi_70`: Boolean flag tracking if RSI has crossed above 70 for this position

### 2. Monitor RSI Crossing 70

In `ManageOpenPositions()`, add logic to:

- Check if `bufRSI[1] >= 70` (using closed bar data)
- Set `has_hit_rsi_70 = true` when condition is met
- Print log message for debugging

### 3. Partial TP on EMA10 Retouch

Add new TP condition:

- **Trigger**: `has_hit_rsi_70 == true` AND `Close[1] <= bufEMA10[1]`
- **Action**: Close 50% of position using `GetSafeCloseVolume()`
- **Flag**: Mark position as `is_rsi_ema_tp_done` to prevent re-triggering

### 4. State Management

- Add `is_rsi_ema_tp_done` flag to `PositionState` to prevent multiple triggers
- Reset flags in `GetStateIndex()` when initializing new position states

## Out of Scope

- Modifying the RSI period or threshold (remains at 70 as specified)
- Changing the EMA period for this feature (uses existing EMA10)
- Adjusting the partial close percentage (remains 50%)
- Adding user-configurable inputs for this feature (hardcoded for now)

## Dependencies

- Relies on existing `bufRSI[]` and `bufEMA10[]` indicator buffers
- Uses existing `GetSafeCloseVolume()` function
- Integrates into existing `ManageOpenPositions()` loop

## Success Criteria

1. Position state correctly tracks when RSI crosses 70
2. Partial TP executes when price touches EMA10 after RSI 70
3. No duplicate TP executions for the same position
4. Logging shows RSI state changes and TP triggers
5. Backtesting shows TP executions at expected points
6. No interference with existing TP1/TP2 mechanisms

## Risks and Mitigations

**Risk**: Multiple partial TPs could reduce position size too aggressively

- **Mitigation**: Add sequencing logic to ensure only one RSI-EMA TP per position

**Risk**: False signals when price whipsaws around EMA10

- **Mitigation**: Check closed bar data (index [1]) to avoid intra-bar noise

**Risk**: Conflict with existing TP mechanisms

- **Mitigation**: Use separate flag `is_rsi_ema_tp_done` and check state before executing

## Open Questions

None. Requirements are clear from user request.

## Alternatives Considered

1. **Use EMA20 instead of EMA10**: Rejected - user specifically requested EMA10
2. **Wait for RSI to fall below 70 before checking EMA**: Rejected - would delay exit and reduce effectiveness
3. **Make threshold configurable**: Deferred - can add input parameters in future iteration if needed
