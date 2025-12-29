//+------------------------------------------------------------------+
//|                                                        Risk.mqh  |
//|                   資金管理模組                                    |
//+------------------------------------------------------------------+
#ifndef RISK_MQH
#define RISK_MQH

#include "Defines.mqh"

//+------------------------------------------------------------------+
//| 資金管理類                                                       |
//+------------------------------------------------------------------+
class CRiskManager {
private:
   double   m_fixedLots;
   double   m_minLots;
   bool     m_useSmartLots;
   double   m_winMult;
   double   m_lossDiv;
   int      m_maxWins;
   long     m_magicNumber;
   
   double   NormalizeVolume(double lots);
   int      CheckConsecutiveWins();
   
public:
   CRiskManager();
   ~CRiskManager();
   
   void     Init(double fixedLots, double minLots, bool useSmartLots,
                 double winMult, double lossDiv, int maxWins, long magicNumber);
   
   double   GetSmartLots();
   double   GetSafeCloseVolume(double totalVolume, double ratio);
};

//+------------------------------------------------------------------+
//| 建構函數                                                         |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager() {
   m_fixedLots = 0.1;
   m_minLots = 0.01;
   m_useSmartLots = false;
   m_winMult = 1.5;
   m_lossDiv = 2.0;
   m_maxWins = 4;
   m_magicNumber = 0;
}

//+------------------------------------------------------------------+
//| 解構函數                                                         |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager() {
}

//+------------------------------------------------------------------+
//| 初始化                                                           |
//+------------------------------------------------------------------+
void CRiskManager::Init(double fixedLots, double minLots, bool useSmartLots,
                        double winMult, double lossDiv, int maxWins, long magicNumber) {
   m_fixedLots = fixedLots;
   m_minLots = minLots;
   m_useSmartLots = useSmartLots;
   m_winMult = winMult;
   m_lossDiv = lossDiv;
   m_maxWins = maxWins;
   m_magicNumber = magicNumber;
}

//+------------------------------------------------------------------+
//| 智能倉位計算                                                     |
//+------------------------------------------------------------------+
double CRiskManager::GetSmartLots() {
   double baseLots = m_fixedLots;
   if(!m_useSmartLots) return NormalizeVolume(baseLots);
   if(!HistorySelect(0, TimeCurrent())) return NormalizeVolume(baseLots);
   
   double lastLots = 0;
   double lastProfit = 0;
   bool found = false;
   int total = HistoryDealsTotal();
   
   for(int i = total - 1; i >= 0; i--) {
      ulong t = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(t, DEAL_MAGIC) == m_magicNumber &&
         HistoryDealGetInteger(t, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         lastLots = HistoryDealGetDouble(t, DEAL_VOLUME);
         lastProfit = HistoryDealGetDouble(t, DEAL_PROFIT);
         found = true;
         break;
      }
   }
   
   if(!found) return NormalizeVolume(baseLots);
   
   double newLots = baseLots;
   
   if(lastProfit > 0) {
      if(CheckConsecutiveWins() >= m_maxWins) {
         newLots = baseLots;
      } else {
         if(lastLots < baseLots) newLots = baseLots;
         else newLots = lastLots * m_winMult;
      }
   } else {
      if(lastLots > baseLots) newLots = baseLots;
      else newLots = lastLots / m_lossDiv;
   }
   
   return NormalizeVolume(newLots);
}

//+------------------------------------------------------------------+
//| 計算安全平倉量                                                   |
//+------------------------------------------------------------------+
double CRiskManager::GetSafeCloseVolume(double totalVolume, double ratio) {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double closeVol = NormalizeVolume(totalVolume * ratio);
   double remainVol = totalVolume - closeVol;
   
   // 如果是全部平倉
   if(ratio >= 1.0) {
      return NormalizeVolume(totalVolume);
   }
   
   if(remainVol < minLot) return 0;
   if(closeVol < minLot) return 0;
   
   return closeVol;
}

//+------------------------------------------------------------------+
//| 標準化手數                                                       |
//+------------------------------------------------------------------+
double CRiskManager::NormalizeVolume(double lots) {
   double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(m_minLots > min) min = m_minLots;
   
   if(lots < min) lots = min;
   if(lots > max) lots = max;
   
   return MathFloor(lots / step) * step;
}

//+------------------------------------------------------------------+
//| 檢查連勝次數                                                     |
//+------------------------------------------------------------------+
int CRiskManager::CheckConsecutiveWins() {
   int wins = 0;
   if(!HistorySelect(0, TimeCurrent())) return 0;
   
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--) {
      ulong t = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(t, DEAL_MAGIC) == m_magicNumber &&
         HistoryDealGetInteger(t, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         if(HistoryDealGetDouble(t, DEAL_PROFIT) > 0) wins++;
         else break;
      }
   }
   return wins;
}

#endif // RISK_MQH