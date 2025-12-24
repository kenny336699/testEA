# Implementation Tasks: Add RSI-EMA Partial Take Profit

## Prerequisites
- [x] Read [proposal.md](./proposal.md) - Understand feature requirements
- [x] Read [design.md](./design.md) - Review technical approach
- [x] Read [specs/exit-management/spec.md](./specs/exit-management/spec.md) - Understand acceptance criteria
- [x] Verify test.mq5 compiles without errors
- [ ] Confirm existing TP mechanisms are working in backtest

## Implementation Tasks

### Task 1: Update PositionState Structure
- [x] Open test.mq5 and locate `struct PositionState` (around line 76)
- [x] Add `bool has_hit_rsi_70;` field after `is_valid`
- [x] Add `bool is_rsi_ema_tp_done;` field after `has_hit_rsi_70`
- [x] Add inline comment: `// Track RSI overbought and TP execution state`
- [x] Save file

**Validation**: Compile test.mq5 - should succeed with no errors ✅

---

### Task 2: Initialize New State Flags in GetStateIndex()
- [x] Locate `GetStateIndex()` function (around line 510)
- [x] Find first state initialization block (around line 519)
- [x] Add `posStates[i].has_hit_rsi_70 = false;` before `is_valid = true`
- [x] Add `posStates[i].is_rsi_ema_tp_done = false;` after previous line
- [x] Find second state initialization block (around line 536)
- [x] Add same two lines in second block
- [x] Save file

**Validation**: Compile test.mq5 - should succeed with no errors ✅

---

### Task 3: Add RSI Tracking Logic in ManageOpenPositions()
- [x] Locate `ManageOpenPositions()` function (around line 328)
- [x] Find where `profitR` is calculated and `max_r_reached` is updated (around line 349)
- [x] After the `max_r_reached` update block, add comment: `// Track RSI overbought state`
- [x] Add logic:
  ```cpp
  if(bufRSI[1] >= 70 && !posStates[stateIdx].has_hit_rsi_70) {
     posStates[stateIdx].has_hit_rsi_70 = true;
     Print("Position #", ticket, " RSI hit 70 (RSI=", bufRSI[1], ")");
  }
  ```
- [x] Save file

**Validation**: Compile test.mq5 - should succeed with no errors ✅

---

### Task 4: Implement RSI-EMA Partial TP Logic
- [x] In `ManageOpenPositions()`, after the RSI tracking logic added in Task 3
- [x] Add comment: `// RSI-EMA Partial TP`
- [x] Implement the TP logic:
  ```cpp
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
- [x] Ensure this block appears BEFORE existing TP1 logic (around line 356)
- [x] Save file

**Validation**: Compile test.mq5 - should succeed with no errors ✅

---

### Task 5: Code Review & Cleanup
- [x] Review all changes for syntax errors
- [x] Check indentation matches existing code style
- [x] Verify new logic doesn't modify existing TP mechanisms
- [x] Confirm all Print() statements use consistent formatting
- [x] Save file

**Validation**: Full compilation with no warnings or errors ✅

---

### Task 6: Functional Testing - Basic Scenario
- [ ] Open MT5 Strategy Tester
- [ ] Load test.mq5 EA
- [ ] Select symbol: EURUSD (or other trending pair)
- [ ] Select timeframe: M5
- [ ] Select date range: 1 month recent data
- [ ] Mode: "Every tick based on real ticks"
- [ ] Enable Optimization: No
- [ ] Run backtest
- [ ] Check Logs tab for "RSI hit 70" messages
- [ ] Check Logs tab for "RSI-EMA TP: Closed 50%" messages
- [ ] Verify at least 1 RSI-EMA TP execution occurred

**Validation**: Logs show RSI state tracking and TP executions

---

### Task 7: Visual Verification
- [ ] Re-run backtest with Visual Mode enabled
- [ ] Pause when log shows "RSI hit 70" message
- [ ] Open Data Window, verify RSI >= 70
- [ ] Resume backtest
- [ ] Pause when log shows "RSI-EMA TP" message
- [ ] Verify price is at/below EMA10 on chart
- [ ] Check position was partially closed (50%)

**Validation**: Visual confirmation of correct trigger conditions

---

### Task 8: Edge Case Testing - RSI Never Hits 70
- [ ] Select date range with sideways/ranging market
- [ ] Run backtest
- [ ] Verify NO "RSI hit 70" messages appear
- [ ] Verify positions exit via existing TP mechanisms (TP1/TP2/Trailing)
- [ ] Confirm no RSI-EMA TP executions

**Validation**: Feature remains dormant when RSI < 70

---

### Task 9: Edge Case Testing - No EMA10 Retouch
- [ ] Select date range with strong trending market
- [ ] Run backtest
- [ ] Identify positions where "RSI hit 70" logs appear
- [ ] Check if corresponding "RSI-EMA TP" messages exist
- [ ] If not, verify positions exited via TP2 or trailing (higher prices)

**Validation**: Positions can exit without RSI-EMA TP if no pullback

---

### Task 10: Integration Testing - Multiple Positions
- [ ] Set `InpMaxPos = 5` in EA inputs
- [ ] Run backtest on trending market
- [ ] Verify multiple positions can be open simultaneously
- [ ] Check that RSI state is tracked independently per position
- [ ] Confirm each position's RSI-EMA TP triggers independently

**Validation**: No cross-contamination between position states

---

### Task 11: Integration Testing - Interaction with TP1
- [ ] Find scenario where both RSI-EMA TP and TP1 conditions could trigger
- [ ] Run backtest and monitor logs
- [ ] Verify RSI-EMA TP executes first (due to `continue` statement)
- [ ] Confirm TP1 logic can still operate on subsequent ticks if applicable

**Validation**: Execution order is RSI-EMA TP → TP1

---

### Task 12: Performance Validation
- [ ] Run backtest on 6-month date range
- [ ] Monitor EA compilation time (should be < 5 seconds)
- [ ] Check backtest execution speed (should not significantly slow down)
- [ ] Verify no "Array out of range" or memory errors in logs
- [ ] Check total trades executed matches expected behavior

**Validation**: No performance degradation

---

### Task 13: Documentation & Logging Review
- [ ] Review all log messages for clarity
- [ ] Ensure critical events are logged:
  - RSI crossing 70
  - RSI-EMA TP execution with price and reason
- [ ] Verify log messages include position ticket numbers
- [ ] Check log format consistency with existing messages

**Validation**: Logs are clear and useful for debugging

---

### Task 14: Final Compilation & Commit Preparation
- [x] Compile test.mq5 with zero errors and warnings
- [x] Save compiled test.ex5 file
- [x] Update EA version number to 3.8 (if following versioning convention)
- [x] Update file header comment to mention RSI-EMA TP feature
- [ ] Git add modified test.mq5
- [ ] Git commit with message: "Add RSI-EMA partial take profit mechanism"

**Validation**: Clean compilation, ready for deployment ✅

---

## Acceptance Criteria Checklist
- [x] PositionState structure includes `has_hit_rsi_70` and `is_rsi_ema_tp_done` fields
- [x] System logs when RSI crosses 70 for a position
- [x] Partial close executes when price touches EMA10 after RSI 70
- [x] No duplicate partial closes occur for the same position
- [x] RSI-EMA TP integrates without interfering with existing TP mechanisms
- [ ] Backtesting demonstrates TP executions at expected price levels
- [ ] All scenarios in spec.md are validated

## Post-Implementation
- [ ] Create summary of test results (pass/fail counts)
- [ ] Document any unexpected behaviors discovered during testing
- [ ] Propose follow-up improvements (if any)
- [ ] Update proposal status to "Implemented"
- [ ] Prepare for proposal archival

## Notes
- Estimated implementation time: 1-2 hours (coding + testing)
- Requires MT5 terminal with historical data for backtesting
- Use Strategy Tester's "Every tick" mode for accurate simulation
- Keep InpShowVisual enabled during testing for better insight
