# Exit Management

## Requirements

### Requirement: RSI-EMA momentum reversal exit

The system SHALL provide a partial take profit mechanism that triggers when RSI indicates overbought conditions followed by a price return to the fast EMA, capturing profits during momentum reversals.

#### Scenario: RSI crosses 70 then price returns to EMA10

**Given** an open long position  
**And** RSI (14-period) crosses above 70  
**When** the closing price touches or falls below EMA10  
**Then** the system shall close 50% of the position  
**And** mark the position state to prevent duplicate executions  
**And** log the partial close with RSI-EMA TP identifier

#### Scenario: Track RSI overbought state per position

**Given** an open long position  
**And** the position has not yet hit RSI 70  
**When** RSI (14-period, on closed bar) >= 70  
**Then** the system shall flag the position as "RSI overbought reached"  
**And** log the RSI state change with position ticket and RSI value

#### Scenario: Prevent duplicate RSI-EMA partial closes

**Given** an open long position  
**And** the position has already executed an RSI-EMA partial TP  
**When** the closing price touches EMA10 again  
**Then** the system shall NOT execute another RSI-EMA partial close  
**And** the position continues with existing TP mechanisms

#### Scenario: Initialize RSI-EMA state for new positions

**Given** a new position is opened or detected  
**When** initializing the position state structure  
**Then** the system shall set `has_hit_rsi_70` to false  
**And** set `is_rsi_ema_tp_done` to false  
**And** store the position entry price and R distance

#### Scenario: RSI-EMA TP executes before other TP mechanisms

**Given** an open long position  
**And** both RSI-EMA TP conditions and TP1 conditions are met  
**When** executing position management on the current tick  
**Then** the system shall check RSI-EMA TP first  
**And** skip other TP checks for that tick if RSI-EMA TP executes  
**And** allow other TP mechanisms to operate on subsequent ticks

#### Scenario: Validate safe volume before partial close

**Given** an open long position with volume 0.1 lots  
**And** RSI-EMA TP conditions are met  
**When** calculating the partial close volume (50%)  
**Then** the system shall verify the close volume >= minimum lot size  
**And** verify the remaining volume >= minimum lot size  
**And** execute the partial close only if both conditions are true  
**And** skip the TP if volume validation fails

#### Scenario: Use closed bar data for signal confirmation

**Given** an open long position with RSI overbought flag set  
**When** checking if price has returned to EMA10  
**Then** the system shall use the previous closed bar's closing price  
**And** compare against the previous closed bar's EMA10 value  
**And** avoid using current incomplete bar data

#### Scenario: RSI never reaches 70

**Given** an open long position  
**And** RSI remains below 70 throughout the position lifecycle  
**When** managing the position  
**Then** the system shall NOT trigger RSI-EMA partial TP  
**And** the position shall exit via existing TP1, TP2, or trailing stop mechanisms  
**And** no RSI-EMA related logs shall be generated

#### Scenario: Price never returns to EMA10 after RSI 70

**Given** an open long position  
**And** RSI has crossed above 70  
**And** price continues trending up without touching EMA10  
**When** the position reaches TP2 or trailing stop conditions  
**Then** the system shall execute the standard exit mechanism  
**And** the RSI-EMA TP remains un-triggered  
**And** no RSI-EMA partial close shall occur

## Relationships

- **Extends**: Position management core logic
- **Uses**: Existing `GetSafeCloseVolume()` function
- **Uses**: Existing RSI and EMA10 indicator buffers
- **Integrates with**: TP1 (R-based), TP2 (structure), and trailing stop mechanisms

## Technical Notes

- RSI threshold: 70 (hardcoded, matches existing `InpRSI_Extreme` parameter)
- EMA period: 10 (uses existing `bufEMA10[]` from `InpEMA_Fast`)
- Partial close percentage: 50% (consistent with existing TP mechanisms)
- Uses closed bar data (array index [1]) to avoid intra-bar repaints
- State flags prevent duplicate executions
- Execution order: RSI-EMA TP → TP1 → TP2 → Trailing

## Dependencies

- RSI indicator handle (`hRSI`) MUST be initialized
- EMA10 indicator handle (`hEMA10`) MUST be initialized
- `trade` object MUST be configured with magic number and slippage
- `PositionState` structure MUST support additional boolean fields

## Acceptance Criteria

1. Position state structure includes `has_hit_rsi_70` and `is_rsi_ema_tp_done` fields
2. System logs when RSI crosses 70 for a position
3. Partial close executes when price touches EMA10 after RSI 70
4. No duplicate partial closes occur for the same position
5. RSI-EMA TP integrates without interfering with existing TP mechanisms
6. Backtesting demonstrates TP executions at expected price levels
