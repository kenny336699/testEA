//+------------------------------------------------------------------+
//|                                                      Signal.mqh  |
//|                   進場信號邏輯模組                                |
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
   int      m_hRSI_M5;
   int      m_hRSI_M15;
   
   // 指標緩衝區
   double   m_bufEMA10[];
   double   m_bufEMA20[];
   double   m_bufEMA200[];
   double   m_bufRSI[];
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
   
public:
   CSignalManager();
   ~CSignalManager();
   
   bool     Init(int emaFast, int emaMid, int emaTrend, 
                 int rsiPeriod, int rsiEnable, int rsiDisable,
                 int rsiMax, int rsiExtreme,
                 bool useMTF, int mtfRsiMin,
                 double bufferPoints, double minHighDist);
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
};

//+------------------------------------------------------------------+
//| 建構函數                                                         |
//+------------------------------------------------------------------+
CSignalManager::CSignalManager() {
   m_hEMA10 = INVALID_HANDLE;
   m_hEMA20 = INVALID_HANDLE;
   m_hEMA200 = INVALID_HANDLE;
   m_hRSI = INVALID_HANDLE;
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
                          double bufferPoints, double minHighDist) {
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
   
   // 建立指標
   m_hEMA10  = iMA(_Symbol, PERIOD_CURRENT, m_emaFast, 0, MODE_EMA, PRICE_CLOSE);
   m_hEMA20  = iMA(_Symbol, PERIOD_CURRENT, m_emaMid, 0, MODE_EMA, PRICE_CLOSE);
   m_hEMA200 = iMA(_Symbol, PERIOD_CURRENT, m_emaTrend, 0, MODE_EMA, PRICE_CLOSE);
   m_hRSI    = iRSI(_Symbol, PERIOD_CURRENT, m_rsiPeriod, PRICE_CLOSE);
   m_hRSI_M5  = iRSI(_Symbol, PERIOD_M5,  m_rsiPeriod, PRICE_CLOSE);
   m_hRSI_M15 = iRSI(_Symbol, PERIOD_M15, m_rsiPeriod, PRICE_CLOSE);
   
   if(m_hEMA10 == INVALID_HANDLE || m_hEMA20 == INVALID_HANDLE || 
      m_hEMA200 == INVALID_HANDLE || m_hRSI == INVALID_HANDLE ||
      m_hRSI_M5 == INVALID_HANDLE || m_hRSI_M15 == INVALID_HANDLE) {
      Print("Error creating indicators in Signal module");
      return false;
   }
   
   // 設定陣列為序列
   ArraySetAsSeries(m_bufEMA10, true);
   ArraySetAsSeries(m_bufEMA20, true);
   ArraySetAsSeries(m_bufEMA200, true);
   ArraySetAsSeries(m_bufRSI, true);
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
   if(CopyBuffer(m_hRSI_M5, 0, 0, 3, m_bufRSI_M5) < 3) return false;
   if(CopyBuffer(m_hRSI_M15, 0, 0, 3, m_bufRSI_M15) < 3) return false;
   return true;
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
//| 檢查進場信號                                                     |
//+------------------------------------------------------------------+
SignalResult CSignalManager::CheckEntrySignal() {
   SignalResult result;
   result.is_valid = false;
   result.entry_price = 0;
   result.stop_loss = 0;
   result.r_value = 0;
   result.target_high = 0;
   result.signal_time = 0;
   
   // 檢查趨勢模式
   if(!m_isBullishMode) return result;
   
   // 多週期過濾
   if(m_useMTF) {
      if(m_bufRSI_M5[1] < m_mtfRsiMin) return result;
      if(m_bufRSI_M15[1] < m_mtfRsiMin) return result;
   }
   
   // EMA20 必須在 EMA200 之上
   if(m_bufEMA20[1] <= m_bufEMA200[1]) return result;
   
   double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   
   // 價格必須觸及 EMA20
   if(low1 > m_bufEMA20[1]) return result;
   
   // RSI 不可過熱
   if(m_bufRSI[1] >= m_rsiMax) return result;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double buffer = m_bufferPoints * point;
   
   double entryPrice = high1 + buffer;
   double stopLoss   = low1 - buffer;
   double r_val      = entryPrice - stopLoss;
   
   if(r_val <= 0) return result;
   
   // 計算前高並檢查距離
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