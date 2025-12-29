   //+------------------------------------------------------------------+
   //|                        EMA_Pullback_Pro_v4.0.mq5                 |
   //|                   模組化重構版本 (含陰符經濾網)                  |
   //+------------------------------------------------------------------+
   #property copyright "Gemini"
   #property version   "4.00"
   #property strict

   #include "Defines.mqh"
   #include "Signal.mqh"
   #include "Risk.mqh"
   #include "TradeManager.mqh"

   //+------------------------------------------------------------------+
   //| 輸入參數 (Inputs)                                                |
   //+------------------------------------------------------------------+
   input group "===== 陰符經: 天道與伏藏 (YinFu Logic) ====="
   input bool    InpUseYinFu_Trend = true;       // 啟用 [天道] 過濾 (EMA發散且向上)
   input bool    InpUseYinFu_Hidden= true;       // 啟用 [伏藏] 過濾 (縮量+低波動)
   input int     InpVol_AvgPeriod  = 20;         // [伏藏] 成交量均線週期
   input double  InpVol_Ratio      = 0.8;        // [伏藏] 縮量係數 (當前量 < 均量 * 0.8)
   input int     InpATR_Period     = 14;         // [伏藏] ATR 週期 (計算波動)
   input double  InpATR_CheckRatio = 0.8;        // [伏藏] 波動收縮係數 (K線範圍 < ATR * 0.8)

   input group "===== 均線與趨勢 (Trend) ====="
   input int     InpEMA_Fast       = 10;         // EMA Fast (極端出場/回踩TP)
   input int     InpEMA_Mid        = 20;         // EMA Mid (基準/一般出場)
   input int     InpEMA_Trend      = 200;        // EMA Trend (大趨勢過濾)

   input group "===== RSI 趨勢狀態 ====="
   input int     InpRSI_Period     = 14;         // RSI 週期
   input int     InpRSI_Enable     = 60;         // [本週期啟動] RSI 高於此值開啟多頭模式
   input int     InpRSI_Disable    = 52;         // [本週期關閉] RSI 低於此值關閉多頭模式
   input int     InpRSI_Max        = 70;         // RSI 進場上限 (過熱不追)
   input int     InpRSI_Extreme    = 75;         // RSI 極端值 (加速離場)

   input group "===== 多週期過濾 (MTF Filter) ====="
   input bool    InpUseMTF         = true;       // 啟用 M5/M15 過濾
   input int     InpMTF_RSI_Min    = 60;         // M5 & M15 RSI 必須大於此值

   input group "===== 進場與信號 (Signal) ====="
   input double  InpBufferPoints   = 10;         // 點數緩衝 (Points, 10=1pip)
   input double  InpMinHighDist    = 0.5;        // 離前高最小距離 (R倍數)

   input group "===== 資金管理 (Smart Money) ====="
   input double  InpFixedLots      = 1;        // 基礎手數
   input double  InpMinLots        = 0.04;       // 最小手數限制
   input bool    InpUseSmartLots   = true;       // 啟用 贏加/輸減
   input double  InpWinMult        = 1.3;        // 贏單加碼倍數
   input double  InpLossDiv        = 2.0;        // 輸單減碼除數
   input int     InpMaxWins        = 4;          // 連勝重置次數

   input group "===== 風控與加倉 (Risk & Pyramid) ====="
   input int     InpMaxPos         = 5;          // 最大同時持倉數
   input double  InpPyramid_R      = 1.0;        // 加倉門檻 (獲利 > ? R 解鎖)
   input int     InpMagicNum       = 20250401;   // Magic Number (Updated)
   input int     InpSlippage       = 20;         // 滑點 (Points)

   input group "===== 視覺標記 (Visual) ====="
   input bool    InpShowVisual     = true;           // 顯示視覺標記
   input color   InpArrowColor     = clrLime;        // 箭頭顏色
   input color   InpEntryLineColor = clrDodgerBlue;  // 進場線顏色 (藍)
   input color   InpSLLineColor    = clrRed;         // 止損線顏色 (紅)
   input color   InpHighLineColor  = clrGold;        // 前高線顏色 (金)
   input int     InpArrowSize      = 2;              // 箭頭大小 (1-5)
   input int     InpLineWidth      = 2;              // 線條寬度

   //+------------------------------------------------------------------+
   //| 全域物件                                                         |
   //+------------------------------------------------------------------+
   CSignalManager  g_signal;
   CRiskManager    g_risk;
   CTradeManager   g_trade;

   //+------------------------------------------------------------------+
   //| 初始化                                                           |
   //+------------------------------------------------------------------+
   int OnInit()
   {
      // 初始化信號模組 (更新 Init 調用，加入新參數)
      if(!g_signal.Init(InpEMA_Fast, InpEMA_Mid, InpEMA_Trend,
                        InpRSI_Period, InpRSI_Enable, InpRSI_Disable,
                        InpRSI_Max, InpRSI_Extreme,
                        InpUseMTF, InpMTF_RSI_Min,
                        InpBufferPoints, InpMinHighDist,
                        // 新增參數
                        InpUseYinFu_Trend, InpUseYinFu_Hidden,
                        InpVol_AvgPeriod, InpVol_Ratio,
                        InpATR_Period, InpATR_CheckRatio)) {
         Print("Failed to initialize Signal module");
         return INIT_FAILED;
      }
      
      // 初始化風控模組
      g_risk.Init(InpFixedLots, InpMinLots, InpUseSmartLots,
                  InpWinMult, InpLossDiv, InpMaxWins, InpMagicNum);
      
      // 初始化交易模組
      if(!g_trade.Init(&g_signal, &g_risk,
                     InpMagicNum, InpSlippage, InpMaxPos, InpPyramid_R,
                     InpShowVisual, InpArrowColor, InpEntryLineColor,
                     InpSLLineColor, InpHighLineColor, InpArrowSize, InpLineWidth)) {
         Print("Failed to initialize Trade module");
         return INIT_FAILED;
      }
      
      Print("EMA_Pullback_Pro v", DoubleToString(4.00, 2), " initialized successfully");
      return INIT_SUCCEEDED;
   }

   //+------------------------------------------------------------------+
   //| 釋放資源                                                         |
   //+------------------------------------------------------------------+
   void OnDeinit(const int reason)
   {
      g_signal.Deinit();
      g_trade.Deinit();
      
      Print("EMA_Pullback_Pro deinitialized. Reason: ", reason);
   }

   //+------------------------------------------------------------------+
   //| 主循環                                                           |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      // 更新指標
      if(!g_signal.UpdateIndicators()) return;
      
      // 更新趨勢狀態
      g_signal.UpdateTrendState();
      
      // 管理持倉
      g_trade.ManageOpenPositions();
      
      // 檢查掛單過期
      g_trade.CheckPendingExpiry();
      
      // 檢查是否可以加倉
      if(!g_trade.CheckPyramidingCondition()) return;
      
      // 檢查進場信號 (內部已包含陰符經過濾)
      SignalResult signal = g_signal.CheckEntrySignal();
      if(signal.is_valid) {
         g_trade.PlaceOrder(signal);
      }
   }

   //+------------------------------------------------------------------+
   //| 交易事件回調                                                     |
   //+------------------------------------------------------------------+
   void OnTradeTransaction(const MqlTradeTransaction& trans,
                           const MqlTradeRequest& request,
                           const MqlTradeResult& result)
   {
      if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
         g_trade.OnDealAdd(trans.deal);
      }
   }
   //+------------------------------------------------------------------+