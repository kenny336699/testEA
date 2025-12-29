//+------------------------------------------------------------------+
//|                                                       Signal.mqh |
//|                   進場信號邏輯模組 (v4.0 陰符經完整版)             |
//|       包含: 天道過濾、伏藏過濾、急跌防禦(殺機過濾)、結構止損       |
//+------------------------------------------------------------------+
#ifndef SIGNAL_MQH
#define SIGNAL_MQH

#include "Defines.mqh"

//+------------------------------------------------------------------+
//| 信號結構                                                         |
//+------------------------------------------------------------------+
struct SignalResult {
   bool     is_valid;
   double   entry_price;
   double   stop_loss;
   double   r_value;
   double   target_high;
   datetime signal_time;
};

//+------------------------------------------------------------------+
//| 信號管理類                                                       |
//+------------------------------------------------------------------+
class CSignalManager {
private:
   // 指標句柄
   int      m_hEMA10;
   int      m_hEMA20;
   int      m_hEMA200;
   int      m_hRSI;
   int      m_hATR;         // [新增] ATR 句柄
   int      m_hRSI_M5;
   int      m_hRSI_M15;
   
   // 指標緩衝區
   double   m_bufEMA10[];
   double   m_bufEMA20[];
   double   m_bufEMA200[];
   double   m_bufRSI[];
   double   m_bufATR[];     // [新增] ATR 緩衝區
   double   m_bufRSI_M5[];
   double   m_bufRSI_M15[];
   
   // 趨勢狀態
   bool     m_isBullishMode;
   
   // 參數
   int      m_emaFast;
   int      m_emaMid;
   int      m_emaTrend;
   int      m_rsiPeriod;
   int      m_rsiEnable;
   int      m_rsiDisable;
   int      m_rsiMax;
   int      m_rsiExtreme;
   bool     m_useMTF;
   int      m_mtfRsiMin;
   double   m_bufferPoints;
   double   m_minHighDist;

   // [新增] 陰符經參數
   bool     m_useYinFuTrend;    // 天道過濾
   bool     m_useYinFuHidden;   // 伏藏過濾
   int      m_volAvgPeriod;     // 成交量均線週期
   double   m_volRatio;         // 縮量係數
   int      m_atrPeriod;        // ATR 週期
   double   m_atrCheckRatio;    // 波動收縮係數
   
   // 私有輔助函數: 計算平均成交量
   double   GetAvgVolume(int startIdx, int count);

public:
   CSignalManager();
   ~CSignalManager();
   
   // 初始化
   bool     Init(int emaFast, int emaMid, int emaTrend, 
                 int rsiPeriod, int rsiEnable, int rsiDisable,
                 int rsiMax, int rsiExtreme,
                 bool useMTF, int mtfRsiMin,
                 double bufferPoints, double minHighDist,
                 // 新增參數
                 bool useYinFuTrend, bool useYinFuHidden,
                 int volAvgPeriod, double volRatio,
                 int atrPeriod, double atrCheckRatio);

   void     Deinit();
   bool     UpdateIndicators();
   void     UpdateTrendState();
   
   bool     IsBullishMode() const { return m_isBullishMode; }
   SignalResult CheckEntrySignal();
   
   // Getter for indicator values (供 Trade 模組使用)
   double   GetEMA10(int shift)  const { return m_bufEMA10[shift]; }
   double   GetEMA20(int shift)  const { return m_bufEMA20[shift]; }
   double   GetEMA200(int shift) const { return m_bufEMA200[shift]; }
   double   GetRSI(int shift)    const { return m_bufRSI[shift]; }
   int      GetRSIExtreme()      const { return m_rsiExtreme; }
   double   GetATR(int shift)    const { return m_bufATR[shift]; } // [新增]
};

//+------------------------------------------------------------------+
//| 建構函數                                                         |
//+------------------------------------------------------------------+
CSignalManager::CSignalManager() {
   m_hEMA10 = INVALID_HANDLE;
   m_hEMA20 = INVALID_HANDLE;
   m_hEMA200 = INVALID_HANDLE;
   m_hRSI = INVALID_HANDLE;
   m_hATR = INVALID_HANDLE;      // [新增]
   m_hRSI_M5 = INVALID_HANDLE;
   m_hRSI_M15 = INVALID_HANDLE;
   m_isBullishMode = false;
}

//+------------------------------------------------------------------+
//| 解構函數                                                         |
//+------------------------------------------------------------------+
CSignalManager::~CSignalManager() {
   Deinit();
}

//+------------------------------------------------------------------+
//| 初始化                                                           |
//+------------------------------------------------------------------+
bool CSignalManager::Init(int emaFast, int emaMid, int emaTrend, 
                          int rsiPeriod, int rsiEnable, int rsiDisable,
                          int rsiMax, int rsiExtreme,
                          bool useMTF, int mtfRsiMin,
                          double bufferPoints, double minHighDist,
                          // 新增參數接收
                          bool useYinFuTrend, bool useYinFuHidden,
                          int volAvgPeriod, double volRatio,
                          int atrPeriod, double atrCheckRatio) {
   // 儲存參數
   m_emaFast = emaFast;
   m_emaMid = emaMid;
   m_emaTrend = emaTrend;
   m_rsiPeriod = rsiPeriod;
   m_rsiEnable = rsiEnable;
   m_rsiDisable = rsiDisable;
   m_rsiMax = rsiMax;
   m_rsiExtreme = rsiExtreme;
   m_useMTF = useMTF;
   m_mtfRsiMin = mtfRsiMin;
   m_bufferPoints = bufferPoints;
   m_minHighDist = minHighDist;
   
   // [新增] 儲存陰符經參數
   m_useYinFuTrend = useYinFuTrend;
   m_useYinFuHidden = useYinFuHidden;
   m_volAvgPeriod = volAvgPeriod;
   m_volRatio = volRatio;
   m_atrPeriod = atrPeriod;
   m_atrCheckRatio = atrCheckRatio;
   
   // 建立指標
   m_hEMA10  = iMA(_Symbol, PERIOD_CURRENT, m_emaFast, 0, MODE_EMA, PRICE_CLOSE);
   m_hEMA20  = iMA(_Symbol, PERIOD_CURRENT, m_emaMid, 0, MODE_EMA, PRICE_CLOSE);
   m_hEMA200 = iMA(_Symbol, PERIOD_CURRENT, m_emaTrend, 0, MODE_EMA, PRICE_CLOSE);
   m_hRSI    = iRSI(_Symbol, PERIOD_CURRENT, m_rsiPeriod, PRICE_CLOSE);
   m_hATR    = iATR(_Symbol, PERIOD_CURRENT, m_atrPeriod); // [新增] 建立 ATR
   
   m_hRSI_M5  = iRSI(_Symbol, PERIOD_M5,  m_rsiPeriod, PRICE_CLOSE);
   m_hRSI_M15 = iRSI(_Symbol, PERIOD_M15, m_rsiPeriod, PRICE_CLOSE);
   
   if(m_hEMA10 == INVALID_HANDLE || m_hEMA20 == INVALID_HANDLE || 
      m_hEMA200 == INVALID_HANDLE || m_hRSI == INVALID_HANDLE ||
      m_hATR == INVALID_HANDLE ||
      m_hRSI_M5 == INVALID_HANDLE || m_hRSI_M15 == INVALID_HANDLE) {
      Print("Error creating indicators in Signal module");
      return false;
   }
   
   // 設定陣列為序列
   ArraySetAsSeries(m_bufEMA10, true);
   ArraySetAsSeries(m_bufEMA20, true);
   ArraySetAsSeries(m_bufEMA200, true);
   ArraySetAsSeries(m_bufRSI, true);
   ArraySetAsSeries(m_bufATR, true); // [新增]
   ArraySetAsSeries(m_bufRSI_M5, true);
   ArraySetAsSeries(m_bufRSI_M15, true);
   
   return true;
}

//+------------------------------------------------------------------+
//| 釋放資源                                                         |
//+------------------------------------------------------------------+
void CSignalManager::Deinit() {
   if(m_hEMA10 != INVALID_HANDLE)  { IndicatorRelease(m_hEMA10);  m_hEMA10 = INVALID_HANDLE; }
   if(m_hEMA20 != INVALID_HANDLE)  { IndicatorRelease(m_hEMA20);  m_hEMA20 = INVALID_HANDLE; }
   if(m_hEMA200 != INVALID_HANDLE) { IndicatorRelease(m_hEMA200); m_hEMA200 = INVALID_HANDLE; }
   if(m_hRSI != INVALID_HANDLE)    { IndicatorRelease(m_hRSI);    m_hRSI = INVALID_HANDLE; }
   if(m_hATR != INVALID_HANDLE)    { IndicatorRelease(m_hATR);    m_hATR = INVALID_HANDLE; } // [新增]
   if(m_hRSI_M5 != INVALID_HANDLE) { IndicatorRelease(m_hRSI_M5); m_hRSI_M5 = INVALID_HANDLE; }
   if(m_hRSI_M15 != INVALID_HANDLE){ IndicatorRelease(m_hRSI_M15);m_hRSI_M15 = INVALID_HANDLE; }
}

//+------------------------------------------------------------------+
//| 更新指標數據                                                     |
//+------------------------------------------------------------------+
bool CSignalManager::UpdateIndicators() {
   if(CopyBuffer(m_hEMA10, 0, 0, 3, m_bufEMA10) < 3) return false;
   if(CopyBuffer(m_hEMA20, 0, 0, 3, m_bufEMA20) < 3) return false;
   if(CopyBuffer(m_hEMA200, 0, 0, 3, m_bufEMA200) < 3) return false;
   if(CopyBuffer(m_hRSI, 0, 0, 3, m_bufRSI) < 3) return false;
   if(CopyBuffer(m_hATR, 0, 0, 3, m_bufATR) < 3) return false; // [新增]
   if(CopyBuffer(m_hRSI_M5, 0, 0, 3, m_bufRSI_M5) < 3) return false;
   if(CopyBuffer(m_hRSI_M15, 0, 0, 3, m_bufRSI_M15) < 3) return false;
   return true;
}

//+------------------------------------------------------------------+
//| [新增] 輔助: 計算平均成交量                                      |
//+------------------------------------------------------------------+
double CSignalManager::GetAvgVolume(int startIdx, int count) {
   long totalVol = 0;
   // 注意: 在類內部這裡用 iVolume 需確保數據已準備好，
   // 但為了效率通常直接調用。若要最嚴謹可用 CopyTickVolume。
   for(int i = 0; i < count; i++) {
      totalVol += iVolume(_Symbol, PERIOD_CURRENT, startIdx + i);
   }
   return (double)totalVol / count;
}

//+------------------------------------------------------------------+
//| 更新趨勢狀態                                                     |
//+------------------------------------------------------------------+
void CSignalManager::UpdateTrendState() {
   double rsi = m_bufRSI[1];
   
   if(rsi >= m_rsiEnable) {
      if(!m_isBullishMode) 
         Print("Bullish Mode Activated (RSI >= ", m_rsiEnable, ")");
      m_isBullishMode = true;
   }
   else if(rsi <= m_rsiDisable) {
      if(m_isBullishMode) 
         Print("Bullish Mode Deactivated (RSI <= ", m_rsiDisable, ")");
      m_isBullishMode = false;
   }
}

//+------------------------------------------------------------------+
//| 檢查進場信號 (核心邏輯)                                          |
//+------------------------------------------------------------------+
SignalResult CSignalManager::CheckEntrySignal() {
   SignalResult result;
   result.is_valid = false;
   result.entry_price = 0;
   result.stop_loss = 0;
   result.r_value = 0;
   result.target_high = 0;
   result.signal_time = 0;
   
   // 1. 檢查 RSI 趨勢模式 (Bullish Mode)
   if(!m_isBullishMode) return result;
   
   // 2. 多週期過濾 (MTF Filter)
   if(m_useMTF) {
      if(m_bufRSI_M5[1] < m_mtfRsiMin) return result;
   }
   
   // 3. 基礎均線排列: EMA20 必須在 EMA200 之上
   if(m_bufEMA20[1] <= m_bufEMA200[1]) return result;

   // 4. [陰符經] 天道 (Trend) 過濾
   if(m_useYinFuTrend) {
      // 條件: EMA200 必須向上 (當前值 > 前值)
      if(m_bufEMA200[1] <= m_bufEMA200[2]) return result;
      
      // 條件: 均線發散 check (可選)
      // double diffCurrent = m_bufEMA20[1] - m_bufEMA200[1];
      // double diffPrev    = m_bufEMA20[2] - m_bufEMA200[2];
      // if (diffCurrent < diffPrev) return result; 
   }
   
   double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   
   // 5. 價格必須觸及 EMA20 (回踩)
   if(low1 > m_bufEMA20[1]) return result;
   
   // 6. RSI 不可過熱
   if(m_bufRSI[1] >= m_rsiMax) return result;

   // 7. [陰符經] 伏藏 (Hidden) 過濾 - 確保市場安靜
   if(m_useYinFuHidden) {
      // 條件A: 縮量 (Volume Contraction)
      long currVol = iVolume(_Symbol, PERIOD_CURRENT, 1);
      double avgVol = GetAvgVolume(2, m_volAvgPeriod); // 取前N根平均(避開當前這根)
      
      if(currVol > avgVol * m_volRatio) return result; // 量太大，不夠伏藏

      // 條件B: 波動收縮 (ATR Check)
      double candleRange = high1 - low1;
      double atrValue = m_bufATR[1];
      
      if(candleRange > atrValue * m_atrCheckRatio) return result; // K線太大，不夠伏藏
   }

   // 8. [陰符經] 急跌過濾 (Falling Knife Filter) - 新增
   // 原理：如果回踩的那根K線是實體巨大的陰線，或者連續大跌，代表空頭動能太強，不要接。
   double open1 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double bodySize = MathAbs(open1 - close1);
   double candleSize = high1 - low1;
   
   // 條件A: 巨大陰線 (Bearish Impact)
   bool isBearishCandle = (close1 < open1);
   if(isBearishCandle && bodySize > candleSize * 0.6 && candleSize > m_bufATR[1] * 1.2) {
      // Print("Skip: Huge Bearish Candle (Falling Knife)");
      return result;
   }
   
   // 條件B: 連續下跌動能 (Consecutive Drops)
   int bearishCount = 0;
   for(int i=1; i<=3; i++) {
      if(iClose(_Symbol, PERIOD_CURRENT, i) < iOpen(_Symbol, PERIOD_CURRENT, i)) {
         bearishCount++;
      }
   }
   if(bearishCount >= 2) { 
       // 簡單判斷：過去3根有2根陰線，且收盤價連續創新低
       if(iClose(_Symbol, PERIOD_CURRENT, 1) < iClose(_Symbol, PERIOD_CURRENT, 2) && 
          iClose(_Symbol, PERIOD_CURRENT, 2) < iClose(_Symbol, PERIOD_CURRENT, 3)) {
           return result;
       }
   }
   
   // 9. 計算進場位與止損 (優化版)
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double buffer = m_bufferPoints * point;
   
   double entryPrice = high1 + buffer;
   
   // --- 優化止損邏輯 ---
   // A. 結構止損：找最近 3 根 K 線的最低點 (避免被雙底掃盪)
   int lowestShift = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, 3, 1);
   double swingLow = iLow(_Symbol, PERIOD_CURRENT, lowestShift);
   double rawStopLoss = swingLow - buffer;
   
   // B. 波動率保護：止損距離至少要有 0.5 倍 ATR (避免十字星導致止損太窄被秒殺)
   double atrValue = m_bufATR[1]; 
   double minSlDistance = atrValue * 0.5; 
   
   // 如果結構止損太近，就強制用 ATR 擴大止損
   double finalStopLoss = rawStopLoss;
   if((entryPrice - rawStopLoss) < minSlDistance) {
      finalStopLoss = entryPrice - minSlDistance;
   }
   
   double stopLoss = finalStopLoss;
   double r_val    = entryPrice - stopLoss;
   
   if(r_val <= 0) return result;
   
   // 10. 計算前高並檢查距離
   double high20 = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, 20, 1));
   double distanceToHigh = high20 - entryPrice;
      
   if(distanceToHigh < r_val * m_minHighDist) return result;
   
   // 填充結果
   result.is_valid = true;
   result.entry_price = entryPrice;
   result.stop_loss = stopLoss;
   result.r_value = r_val;
   result.target_high = high20;
   result.signal_time = iTime(_Symbol, PERIOD_CURRENT, 1);
   
   return result;
}

#endif // SIGNAL_MQH