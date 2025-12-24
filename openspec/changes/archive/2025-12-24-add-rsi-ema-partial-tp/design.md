# Design: RSI-EMA Partial Take Profit

## Architecture

### Data Flow

```
OnTick()
  ↓
UpdateIndicators() → bufRSI[], bufEMA10[]
  ↓
ManageOpenPositions()
  ↓
[For each open position]
  ↓
  ├─→ Check RSI >= 70 → Set has_hit_rsi_70 = true
  ↓
  ├─→ Check (has_hit_rsi_70 && Close <= EMA10)
  ↓
  └─→ Execute partial close (50%) → Set is_rsi_ema_tp_done = true
```

### State Machine

```
Position Lifecycle (RSI-EMA TP Path):

  [New Position]
    has_hit_rsi_70 = false
    is_rsi_ema_tp_done = false
    ↓
  [RSI crosses 70]
    has_hit_rsi_70 = true
    is_rsi_ema_tp_done = false
    ↓
  [Price touches EMA10]
    Execute 50% partial close
    is_rsi_ema_tp_done = true
    ↓
  [Position continues with 50% remaining]
    No further RSI-EMA TP actions
```

## Component Changes

### 1. PositionState Structure (Line 76-84)

**Current**:

```cpp
struct PositionState {
   ulong  ticket;
   double max_r_reached;
   bool   is_tp1_done;
   bool   is_trailed;
   double entry_price;
   double r_distance;
   bool   is_valid;
};
```

**Modified**:

```cpp
struct PositionState {
   ulong  ticket;
   double max_r_reached;
   bool   is_tp1_done;
   bool   is_trailed;
   double entry_price;
   double r_distance;
   bool   is_valid;
   bool   has_hit_rsi_70;       // NEW: Track RSI overbought state
   bool   is_rsi_ema_tp_done;   // NEW: Prevent duplicate TP
};
```

### 2. ManageOpenPositions() Function (Line 328-397)

**Integration Point**: After calculating `profitR` and updating `max_r_reached` (around line 349)

**New Logic Block**:

```cpp
// Track RSI overbought state
if(bufRSI[1] >= 70 && !posStates[stateIdx].has_hit_rsi_70) {
   posStates[stateIdx].has_hit_rsi_70 = true;
   Print("Position #", ticket, " RSI hit 70 (RSI=", bufRSI[1], ")");
}

// RSI-EMA Partial TP
if(posStates[stateIdx].has_hit_rsi_70 &&
   !posStates[stateIdx].is_rsi_ema_tp_done) {

   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);

   if(close1 <= bufEMA10[1]) {
      double closeVol = GetSafeCloseVolume(volume, 0.5);
      if(closeVol > 0) {
         if(trade.PositionClosePartial(ticket, closeVol)) {
            posStates[stateIdx].is_rsi_ema_tp_done = true;
            Print("RSI-EMA TP: Closed 50% @ ", close1,
                  " (RSI hit 70 → returned to EMA10)");
         }
      }
      continue; // Skip other checks this tick
   }
}
```

### 3. GetStateIndex() Function (Line 510-543)

**Current Initialization** (around line 519-526):

```cpp
posStates[i].ticket = ticket;
posStates[i].max_r_reached = 0;
posStates[i].is_tp1_done = false;
posStates[i].is_trailed = false;
posStates[i].entry_price = entry;
posStates[i].r_distance = r;
posStates[i].is_valid = true;
```

**Modified Initialization**:

```cpp
posStates[i].ticket = ticket;
posStates[i].max_r_reached = 0;
posStates[i].is_tp1_done = false;
posStates[i].is_trailed = false;
posStates[i].entry_price = entry;
posStates[i].r_distance = r;
posStates[i].is_valid = true;
posStates[i].has_hit_rsi_70 = false;      // NEW
posStates[i].is_rsi_ema_tp_done = false;  // NEW
```

**Note**: Update both initialization blocks (lines ~519 and ~536)

## Execution Order & Sequencing

The RSI-EMA TP should execute **before** existing TP mechanisms to prioritize early profit-taking:

```
ManageOpenPositions() execution order:
1. Update max_r_reached
2. **NEW: RSI-EMA TP check** → continue if triggered
3. Existing TP1 (R-based)
4. Existing TP2 (Structure)
5. Trailing Stop
```

Using `continue` after RSI-EMA TP prevents conflicts and ensures clean execution.

## Error Handling

### Volume Validation

- Use existing `GetSafeCloseVolume()` to ensure valid lot sizes
- Check `closeVol > 0` before executing partial close
- If volume invalid, skip TP (protects remaining position)

### Indicator Data

- Already validated in `UpdateIndicators()` - assumes bufRSI[1] and bufEMA10[1] are valid
- Use closed bar data (index [1]) to avoid intra-bar repaints

### State Consistency

- `is_rsi_ema_tp_done` flag prevents re-triggering even if price re-touches EMA10
- State cleanup handled by existing `CleanupPositionStates()` function

## Performance Considerations

- **Minimal overhead**: 2 additional boolean checks per position per tick
- **Memory**: +2 bytes per PositionState (2 bools)
- **No new indicator handles**: Uses existing bufRSI[] and bufEMA10[]
- **Logging**: Only on state changes, not every tick

## Testing Strategy

### Manual Testing (Strategy Tester)

1. Run backtest on trending pair (e.g., EURUSD M5)
2. Enable visual mode + logging
3. Look for scenarios where:
   - RSI crosses 70 → verify log message
   - Price returns to EMA10 → verify 50% close + log
4. Confirm position continues with 50% remaining

### Validation Checklist

- [ ] Position state initializes with false flags
- [ ] RSI 70 cross detected and logged
- [ ] Partial close executes on EMA10 touch
- [ ] No duplicate closes on same position
- [ ] Remaining position continues with other TP logic
- [ ] No errors in logs during backtest

## Edge Cases

### 1. RSI Never Hits 70

- `has_hit_rsi_70` remains false
- RSI-EMA TP never triggers
- Position exits via existing TP mechanisms
- **Behavior**: Correct - feature only activates if RSI confirms overbought

### 2. Price Never Returns to EMA10

- `has_hit_rsi_70` = true but TP condition never met
- Position continues trending up
- Exits via existing TP2 or trailing stop
- **Behavior**: Correct - user accepts trade-off

### 3. Multiple Positions Open

- Each has independent state tracking
- RSI state is per-position, not global
- **Behavior**: Correct - positions managed independently

### 4. Partial Close Fails (Broker Rejection)

- `PositionClosePartial()` returns false
- Flag `is_rsi_ema_tp_done` NOT set
- Will retry next tick if conditions still met
- **Behavior**: Correct - retry logic implicit

### 5. Whipsaw Around EMA10

- First touch triggers TP (if RSI condition met)
- Flag set to true → subsequent touches ignored
- **Behavior**: Correct - protects against over-trading

## Integration with Existing Features

### Interaction with TP1 (R-based)

- **No conflict**: Different trigger conditions
- RSI-EMA TP: Momentum reversal signal
- TP1: Profit retracement signal
- Both can trigger on same position (at different times)
- Each closes 50% → position gradually reduced

### Interaction with TP2 (Structure)

- **Complementary**: RSI-EMA TP typically triggers earlier
- If RSI-EMA TP triggers first → TP2 operates on remaining 50%
- If TP2 triggers first → RSI-EMA TP operates on remaining 50%

### Interaction with Trailing Stop

- Trailing Stop is final exit mechanism
- Operates on whatever position size remains after partial TPs
- **No changes needed** to trailing logic

## Future Enhancements (Out of Scope)

- Make RSI threshold configurable (input parameter)
- Make EMA period configurable
- Make partial close percentage configurable
- Add statistics tracking (how often RSI-EMA TP triggers)
- Add visual markers on chart for RSI-EMA TP executions
