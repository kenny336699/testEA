Project Context: EMA Pullback Pro EA
Purpose
開發並維護一個用於 MetaTrader 5 (MT5) 的全自動智能交易系統 (Expert Advisor)。 該專案的目標是執行一個「趨勢跟隨 + 回調進場」策略 (Trend Following Pullback)，專注於捕捉強勢趨勢中的回檔機會。策略強調多週期確認、動態資金管理以及基於動量 (Momentum) 的出場機制。

Tech Stack
Language: MQL5 (MetaQuotes Language 5)

Platform: MetaTrader 5 Client Terminal

Libraries: Standard Library (Trade\Trade.mqh)

Project Conventions
Code Style
Naming:

輸入變數 (Inputs) 使用 Inp 前綴 (如 InpEMA_Fast)。

指標 Handle 使用 h 前綴 (如 hEMA20)。

指標 Buffer 使用 buf 前綴 (如 bufEMA20)。

全域變數/狀態使用 camelCase。

Formatting: - 使用 #property strict 確保嚴格編譯模式。

關鍵邏輯區塊需包含註解說明 (如 // TP1 Logic).

Structure: 所有的交易邏輯 (Entry, Exit, Management) 必須封裝在獨立的函數中，保持 OnTick 簡潔。

Architecture Patterns
Event-Driven: 主要邏輯掛載於 OnTick() 事件；訂單成交確認掛載於 OnTradeTransaction()。

State Management: 使用自定義結構體 struct PositionState 來追蹤 broker 端無法儲存的訂單狀態（例如：「此訂單是否曾經觸及 RSI 70」、「最大浮盈 R 倍數」）。

Signal Logic: 採用「過濾器 (Filters) -> 觸發器 (Triggers) -> 執行 (Execution)」的順序處理。

Testing Strategy
Backtesting: 必須在 MT5 策略測試器 (Strategy Tester) 中使用 "Every tick" 模式進行回測。

Visual Debugging: 啟用 InpShowVisual 參數，檢查圖表上的箭頭 (Signal Arrow) 與進場線 (Entry Line) 是否符合預期邏輯。

Logging: 關鍵狀態變化 (如 Bullish Mode 切換、TP 觸發) 需使用 Print() 輸出至日誌。

Git Workflow
由於 MQL5 通常為單一文件開發，版本控制採用文件名版本號管理 (e.g., \_v3.8).

Major changes (邏輯變更) 增加小數點第一位；Minor changes (參數/修復) 增加小數點第二位。

Domain Context
Trading Strategy Logic
Trend Definition: EMA 20 > EMA 200 (僅做多)。

Momentum Filter (Hysteresis):

RSI(14) > 60 啟動多頭模式。

RSI(14) < 52 關閉多頭模式。

MTF Confirmation: M5 與 M15 週期的 RSI 必須同時 > 60。

Entry Trigger: 價格回調觸碰 EMA 20 (Low <= EMA20)，且 RSI < 70 (不過熱)，在該 K 線高點掛 Buy Stop。

Exit Rules:

Dynamic TP: 當 RSI 衝高過 70 後，價格回落觸碰 EMA 10 時，平倉 50% 並設為損益兩平 (BE)。

Structure TP: 觸碰 EMA 200 或近期高點平倉 50%。

Trailing Stop: 基於 EMA 10 或 EMA 20 的移動止損。

Money Management
Smart Lots: 混合型資金管理。贏單加碼 (Martingale-like) 上限 4 次；輸單減碼 (Anti-Martingale)。

Pyramiding: 金字塔加倉，僅當現有持倉獲利 > 1R 時才允許新開倉。

Important Constraints
Order Type: 策略使用 Buy Stop 掛單，而非市價單 (Market Order)。

Expiration: 掛單僅在當前 K 線有效，未成交即刪除 (OnTick 中檢查)。

Magic Number: 必須固定為 20250304 以識別本策略的訂單，避免與其他 EA 衝突。

Broker Requirements: 需要經紀商支持 Hedging (對沖) 帳戶模式，以便同時持有多張單。

External Dependencies
Market Data: 依賴經紀商提供的即時 Tick 數據與歷史 K 線數據 (Current, M5, M15)。

Trade Execution: 依賴 CTrade 類別處理訂單發送與修改。
