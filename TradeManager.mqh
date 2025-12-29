//+------------------------------------------------------------------+
//|                                                TradeManager.mqh  |
//|                   交易執行模組                                    |
//+------------------------------------------------------------------+
#ifndef TRADEMANAGER_MQH
#define TRADEMANAGER_MQH

#include <Trade\Trade.mqh>
#include "Defines.mqh"
#include "Signal.mqh"
#include "Risk.mqh"

//+------------------------------------------------------------------+
//| 倉位狀態結構                                                     |
//+------------------------------------------------------------------+
struct PositionState {
   ulong    ticket;
   bool     is_valid;
   double   entry_price;
   double   r_distance;
   double   target_high;
   double   max_r_reached;
   int      partial_close_count;
   bool     has_hit_rsi_70;
};

//+------------------------------------------------------------------+
//| 交易管理類                                                       |
//+------------------------------------------------------------------+
class CTradeManager {
private:
   CTrade         m_trade;
   CSignalManager* m_signal;
   CRiskManager*  m_risk;
   
   PositionState  m_posStates[];
   int            m_signalCounter;
   
   // 參數
   long           m_magicNumber;
   int            m_slippage;
   int            m_maxPos;
   double         m_pyramidR;
   bool           m_showVisual;
   color          m_arrowColor;
   color          m_entryLineColor;
   color          m_slLineColor;
   color          m_highLineColor;
   int            m_arrowSize;
   int            m_lineWidth;
   
   // 私有方法
   ENUM_ORDER_TYPE_FILLING GetSupportedFilling();
   double         ParseRFromComment(string comment);
   double         ParseHighFromComment(string comment);
   int            GetStateIndex(ulong ticket, double entry, double r, double targetHigh);
   bool           IsOrderExist(double price);
   void           CleanupPositionStates();
   void           LogClosedPosition(const PositionState &state);
   void           DrawSignalVisual(datetime time, double stopLoss, double entryPrice, double targetHigh);
   void           DrawFilledMark(datetime time, double price);
   
public:
   CTradeManager();
   ~CTradeManager();
   
   bool     Init(CSignalManager* signal, CRiskManager* risk,
                 long magicNumber, int slippage, int maxPos, double pyramidR,
                 bool showVisual, color arrowColor, color entryLineColor,
                 color slLineColor, color highLineColor, int arrowSize, int lineWidth);
   void     Deinit();
   
   bool     CheckPyramidingCondition();
   void     PlaceOrder(const SignalResult &signal);
   void     ManageOpenPositions();
   void     CheckPendingExpiry();
   void     OnDealAdd(ulong dealTicket);
};

//+------------------------------------------------------------------+
//| 建構函數                                                         |
//+------------------------------------------------------------------+
CTradeManager::CTradeManager() {
   m_signal = NULL;
   m_risk = NULL;
   m_signalCounter = 0;
   m_magicNumber = 0;
}

//+------------------------------------------------------------------+
//| 解構函數                                                         |
//+------------------------------------------------------------------+
CTradeManager::~CTradeManager() {
   Deinit();
}

//+------------------------------------------------------------------+
//| 初始化                                                           |
//+------------------------------------------------------------------+
bool CTradeManager::Init(CSignalManager* signal, CRiskManager* risk,
                         long magicNumber, int slippage, int maxPos, double pyramidR,
                         bool showVisual, color arrowColor, color entryLineColor,
                         color slLineColor, color highLineColor, int arrowSize, int lineWidth) {
   m_signal = signal;
   m_risk = risk;
   m_magicNumber = magicNumber;
   m_slippage = slippage;
   m_maxPos = maxPos;
   m_pyramidR = pyramidR;
   m_showVisual = showVisual;
   m_arrowColor = arrowColor;
   m_entryLineColor = entryLineColor;
   m_slLineColor = slLineColor;
   m_highLineColor = highLineColor;
   m_arrowSize = arrowSize;
   m_lineWidth = lineWidth;
   
   m_trade.SetExpertMagicNumber(m_magicNumber);
   m_trade.SetDeviationInPoints(m_slippage);
   m_trade.SetTypeFilling(GetSupportedFilling());
   
   return true;
}

//+------------------------------------------------------------------+
//| 釋放資源                                                         |
//+------------------------------------------------------------------+
void CTradeManager::Deinit() {
   ObjectsDeleteAll(0, "Setup_");
   ObjectsDeleteAll(0, "Signal_");
   ArrayFree(m_posStates);
}

//+------------------------------------------------------------------+
//| 取得支援的填充方式                                               |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING CTradeManager::GetSupportedFilling() {
   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   
   if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;
   if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
   
   return ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
//| 檢查金字塔加倉條件                                               |
//+------------------------------------------------------------------+
bool CTradeManager::CheckPyramidingCondition() {
   int totalPos = 0;
   int winningPos = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      
      if(PositionGetInteger(POSITION_MAGIC) == m_magicNumber) {
         totalPos++;
         double open = PositionGetDouble(POSITION_PRICE_OPEN);
         double curr = PositionGetDouble(POSITION_PRICE_CURRENT);
         string comm = PositionGetString(POSITION_COMMENT);
         double r = ParseRFromComment(comm);
         if(r <= 0) r = open * 0.005;
         if((curr - open) >= (r * m_pyramidR)) winningPos++;
      }
   }
   
   if(totalPos >= m_maxPos) return false;
   if(totalPos == 0) return true;
   if(totalPos > 0 && winningPos > 0) return true;
   return false;
}

//+------------------------------------------------------------------+
//| 下單                                                             |
//+------------------------------------------------------------------+
void CTradeManager::PlaceOrder(const SignalResult &signal) {
   if(!signal.is_valid) return;
   if(IsOrderExist(signal.entry_price)) return;
   
   double lots = m_risk.GetSmartLots();
   string comment = "R=" + DoubleToString(signal.r_value, _Digits) + 
                    "_H=" + DoubleToString(signal.target_high, _Digits);
   
   if(m_trade.BuyStop(lots, signal.entry_price, _Symbol, signal.stop_loss, 0, ORDER_TIME_GTC, 0, comment)) {
      if(m_showVisual) {
         DrawSignalVisual(signal.signal_time, signal.stop_loss, signal.entry_price, signal.target_high);
      }
      Print("Signal Found! RSI Mode: ON. Touch EMA20. Buy Stop @ ", signal.entry_price, 
            " | Target High: ", signal.target_high);
   }
}

//+------------------------------------------------------------------+
//| 管理持倉                                                         |
//+------------------------------------------------------------------+
void CTradeManager::ManageOpenPositions() {
   CleanupPositionStates();
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      
      if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double volume    = PositionGetDouble(POSITION_VOLUME);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      string comment   = PositionGetString(POSITION_COMMENT);
      
      double r_val = ParseRFromComment(comment);
      double target_high = ParseHighFromComment(comment);
      if(r_val <= 0) r_val = openPrice * 0.005;
      if(target_high <= 0) target_high = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, 20, 1));
      
      int stateIdx = GetStateIndex(ticket, openPrice, r_val, target_high);
      if(stateIdx < 0) continue;
      
      double profitR = (currentPrice - openPrice) / r_val;
      
      // 更新最高R
      if(profitR > m_posStates[stateIdx].max_r_reached)
         m_posStates[stateIdx].max_r_reached = profitR;
      
      // 追蹤 RSI 過熱狀態
      if(m_signal.GetRSI(1) >= 70 && !m_posStates[stateIdx].has_hit_rsi_70) {
         m_posStates[stateIdx].has_hit_rsi_70 = true;
         Print("Position #", ticket, " RSI hit 70 (RSI=", DoubleToString(m_signal.GetRSI(1), 1), ")");
      }
      
      double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
      
      //=== 第一次部分平倉 (50%) ===
      if(m_posStates[stateIdx].partial_close_count == 0) {
         bool triggerFirstTP = false;
         string tpReason = "";
         
         // 條件A: RSI曾達70，價格回落至EMA10
         if(m_posStates[stateIdx].has_hit_rsi_70 && close1 <= m_signal.GetEMA10(1)) {
            triggerFirstTP = true;
            tpReason = "RSI-EMA TP (RSI hit 70 -> back to EMA10)";
         }
         // 條件B: 達到目標前高
         else if(currentPrice >= m_posStates[stateIdx].target_high) {
            triggerFirstTP = true;
            tpReason = "Target High TP @ " + DoubleToString(m_posStates[stateIdx].target_high, _Digits);
         }
         // 條件C: 達到EMA200 (若在進場價上方)
         else if(m_signal.GetEMA200(0) > openPrice && currentPrice >= m_signal.GetEMA200(0)) {
            triggerFirstTP = true;
            tpReason = "EMA200 TP @ " + DoubleToString(m_signal.GetEMA200(0), _Digits);
         }
         // 條件D: 回撤保護 (曾達0.5R，回落至0.05R以下)
         else if(m_posStates[stateIdx].max_r_reached >= 0.5 && profitR < 0.05) {
            triggerFirstTP = true;
            tpReason = "Pullback Protection (MaxR=" + DoubleToString(m_posStates[stateIdx].max_r_reached, 2) + ")";
         }
         
         if(triggerFirstTP) {
            double closeVol = m_risk.GetSafeCloseVolume(volume, 0.5);
            if(closeVol > 0) {
               if(m_trade.PositionClosePartial(ticket, closeVol)) {
                  m_posStates[stateIdx].partial_close_count = 1;
                  // 移動止損至成本
                  m_trade.PositionModify(ticket, openPrice, 0);
                  Print("1st TP (50%): ", tpReason, " | MaxR: ", DoubleToString(m_posStates[stateIdx].max_r_reached, 2));
               }
            }
            continue;
         }
      }
      
      //=== 第二次部分平倉 (剩餘倉位) - Trailing Exit ===
      if(m_posStates[stateIdx].partial_close_count == 1) {
         bool triggerSecondTP = false;
         string tpReason = "";
         
         // 條件A: RSI極端 + 跌破EMA10
         if(m_signal.GetRSI(1) > m_signal.GetRSIExtreme() && close1 < m_signal.GetEMA10(1)) {
            triggerSecondTP = true;
            tpReason = "RSI Extreme (" + DoubleToString(m_signal.GetRSI(1), 1) + ") + Below EMA10";
         }
         // 條件B: 跌破EMA20
         else if(close1 < m_signal.GetEMA20(1)) {
            triggerSecondTP = true;
            tpReason = "Below EMA20";
         }
         
         if(triggerSecondTP) {
            double closeVol = m_risk.GetSafeCloseVolume(volume, 1.0);
            if(closeVol > 0) {
               if(m_trade.PositionClosePartial(ticket, closeVol)) {
                  m_posStates[stateIdx].partial_close_count = 2;
                  Print("2nd TP (Trailing): ", tpReason, " | MaxR: ", DoubleToString(m_posStates[stateIdx].max_r_reached, 2));
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 清理倉位狀態                                                     |
//+------------------------------------------------------------------+
void CTradeManager::CleanupPositionStates() {
   for(int i = ArraySize(m_posStates) - 1; i >= 0; i--) {
      if(!m_posStates[i].is_valid) continue;
      
      bool found = false;
      for(int j = PositionsTotal() - 1; j >= 0; j--) {
         ulong ticket = PositionGetTicket(j);
         if(ticket == m_posStates[i].ticket) {
            found = true;
            break;
         }
      }
      
      if(!found) {
         LogClosedPosition(m_posStates[i]);
         m_posStates[i].is_valid = false;
      }
   }
   
   // 壓縮陣列
   int validCount = 0;
   for(int i = 0; i < ArraySize(m_posStates); i++) {
      if(m_posStates[i].is_valid) {
         if(i != validCount) {
            m_posStates[validCount] = m_posStates[i];
         }
         validCount++;
      }
   }
   
   if(validCount < ArraySize(m_posStates)) {
      ArrayResize(m_posStates, validCount);
   }
}

//+------------------------------------------------------------------+
//| 記錄平倉資訊                                                     |
//+------------------------------------------------------------------+
void CTradeManager::LogClosedPosition(const PositionState &state) {
   Print("═══════════════════════════════════════════");
   Print("Position Closed #", state.ticket);
   Print("Entry: ", state.entry_price, " | R Distance: ", DoubleToString(state.r_distance, _Digits));
   Print("Target High: ", state.target_high);
   Print("Max R Reached: ", DoubleToString(state.max_r_reached, 2), " R");
   Print("Partial Closes: ", state.partial_close_count);
   Print("RSI Hit 70: ", state.has_hit_rsi_70 ? "Yes" : "No");
   Print("═══════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| 檢查掛單過期                                                     |
//+------------------------------------------------------------------+
void CTradeManager::CheckPendingExpiry() {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong t = OrderGetTicket(i);
      if(t > 0 && OrderSelect(t)) {
         if(OrderGetInteger(ORDER_MAGIC) == m_magicNumber) {
            datetime openTime = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
            if(TimeCurrent() - openTime > PeriodSeconds(PERIOD_CURRENT)) {
               m_trade.OrderDelete(t);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 交易回調處理                                                     |
//+------------------------------------------------------------------+
void CTradeManager::OnDealAdd(ulong dealTicket) {
   if(dealTicket == 0) return;
   
   if(HistoryDealSelect(dealTicket)) {
      long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      
      if(magic == m_magicNumber && entry == DEAL_ENTRY_IN) {
         if(m_showVisual) {
            double price = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            datetime time = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
            DrawFilledMark(time, price);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 繪製信號視覺元素                                                 |
//+------------------------------------------------------------------+
void CTradeManager::DrawSignalVisual(datetime time, double stopLoss, double entryPrice, double targetHigh) {
   m_signalCounter++;
   string arrowName    = "Signal_Arrow_" + IntegerToString(m_signalCounter);
   string lineName     = "Signal_Line_" + IntegerToString(m_signalCounter);
   string slLineName   = "Signal_SL_Line_" + IntegerToString(m_signalCounter);
   string highLineName = "Signal_High_Line_" + IntegerToString(m_signalCounter);
   
   // 箭頭
   double arrowPrice = stopLoss - (entryPrice - stopLoss) * 0.1;
   if(ObjectCreate(0, arrowName, OBJ_ARROW_UP, 0, time, arrowPrice)) {
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, m_arrowColor);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, m_arrowSize);
      ObjectSetInteger(0, arrowName, OBJPROP_ANCHOR, ANCHOR_TOP);
      ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, arrowName, OBJPROP_HIDDEN, true);
   }
   
   datetime lineEnd = time + PeriodSeconds(PERIOD_CURRENT) * 5;
   
   // 進場線 (藍色實線)
   if(ObjectCreate(0, lineName, OBJ_TREND, 0, time, entryPrice, lineEnd, entryPrice)) {
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, m_entryLineColor);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, m_lineWidth);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, true);
   }
   
   // 止損線 (紅色虛線)
   if(ObjectCreate(0, slLineName, OBJ_TREND, 0, time, stopLoss, lineEnd, stopLoss)) {
      ObjectSetInteger(0, slLineName, OBJPROP_COLOR, m_slLineColor);
      ObjectSetInteger(0, slLineName, OBJPROP_WIDTH, m_lineWidth);
      ObjectSetInteger(0, slLineName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, slLineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, slLineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, slLineName, OBJPROP_HIDDEN, true);
   }
   
   // 前高線 (金色虛線)
   if(ObjectCreate(0, highLineName, OBJ_TREND, 0, time, targetHigh, lineEnd, targetHigh)) {
      ObjectSetInteger(0, highLineName, OBJPROP_COLOR, m_highLineColor);
      ObjectSetInteger(0, highLineName, OBJPROP_WIDTH, m_lineWidth);
      ObjectSetInteger(0, highLineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, highLineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, highLineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, highLineName, OBJPROP_HIDDEN, true);
   }
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| 繪製成交標記                                                     |
//+------------------------------------------------------------------+
void CTradeManager::DrawFilledMark(datetime time, double price) {
   m_signalCounter++;
   string markName = "Signal_Filled_" + IntegerToString(m_signalCounter);
   
   if(ObjectCreate(0, markName, OBJ_ARROW_BUY, 0, time, price)) {
      ObjectSetInteger(0, markName, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, markName, OBJPROP_WIDTH, m_arrowSize);
      ObjectSetInteger(0, markName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, markName, OBJPROP_HIDDEN, true);
   }
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| 從 Comment 解析 R 值                                             |
//+------------------------------------------------------------------+
double CTradeManager::ParseRFromComment(string comment) {
   int pos = StringFind(comment, "R=");
   if(pos >= 0) {
      string sub = StringSubstr(comment, pos + 2);
      int endPos = StringFind(sub, "_");
      if(endPos > 0) sub = StringSubstr(sub, 0, endPos);
      return StringToDouble(sub);
   }
   return 0;
}

//+------------------------------------------------------------------+
//| 從 Comment 解析前高                                              |
//+------------------------------------------------------------------+
double CTradeManager::ParseHighFromComment(string comment) {
   int pos = StringFind(comment, "_H=");
   if(pos >= 0) {
      return StringToDouble(StringSubstr(comment, pos + 3));
   }
   return 0;
}

//+------------------------------------------------------------------+
//| 取得狀態索引                                                     |
//+------------------------------------------------------------------+
int CTradeManager::GetStateIndex(ulong ticket, double entry, double r, double targetHigh) {
   for(int i = 0; i < ArraySize(m_posStates); i++) {
      if(m_posStates[i].is_valid && m_posStates[i].ticket == ticket) return i;
   }
   
   for(int i = 0; i < ArraySize(m_posStates); i++) {
      if(!m_posStates[i].is_valid) {
         m_posStates[i].ticket = ticket;
         m_posStates[i].is_valid = true;
         m_posStates[i].entry_price = entry;
         m_posStates[i].r_distance = r;
         m_posStates[i].target_high = targetHigh;
         m_posStates[i].max_r_reached = 0;
         m_posStates[i].partial_close_count = 0;
         m_posStates[i].has_hit_rsi_70 = false;
         return i;
      }
   }
   
   int s = ArraySize(m_posStates);
   ArrayResize(m_posStates, s + 1);
   m_posStates[s].ticket = ticket;
   m_posStates[s].is_valid = true;
   m_posStates[s].entry_price = entry;
   m_posStates[s].r_distance = r;
   m_posStates[s].target_high = targetHigh;
   m_posStates[s].max_r_reached = 0;
   m_posStates[s].partial_close_count = 0;
   m_posStates[s].has_hit_rsi_70 = false;
   return s;
}

//+------------------------------------------------------------------+
//| 檢查訂單是否存在                                                 |
//+------------------------------------------------------------------+
bool CTradeManager::IsOrderExist(double price) {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong t = OrderGetTicket(i);
      if(t > 0 && OrderSelect(t)) {
         if(OrderGetInteger(ORDER_MAGIC) == m_magicNumber) {
            if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - price) < _Point)
               return true;
         }
      }
   }
   return false;
}

#endif // TRADEMANAGER_MQH