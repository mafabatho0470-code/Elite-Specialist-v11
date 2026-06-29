//+------------------------------------------------------------------+
//|                                  Elite_Specialist_V11_Vis.mq5    |
//|                               Copyright 2026, AI Collaborator    |
//|                                              https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      "https://www.mql5.com"
#property version   "11.03"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//--- Base Input Parameters (Will dynamically auto-adjust per asset)
input group "--- Core Risk Management ---"
input bool      InpUseDynamicLot     = true;       // Auto-size lots based on equity?
input double    InpRiskPercent       = 1.5;        // % Risk per trade based on ATR SL
input double    InpFixedLotSize      = 0.01;       // Fixed lot if dynamic is false
input int       InpMaxPositions      = 3;          // Max open positions per asset
input double    InpMaxDailyLossUSD   = 0.0;        // Set to 0 to completely disable circuit breaker

input group "--- Base Structural Mechanics ---"
input int       InpStructureLookback = 100;        // S/R Lookback window
input int       InpATRPeriod         = 14;         // Period for Volatility Math
input int       InpTimeoutBars       = 30;         // Max bars to wait for retest
input bool      InpUsePartialTP      = false;      // DISABLED: Scaling out logic turned off

input group "--- Base Macro Trend (H4 Only) ---"
input int       InpFastEMA           = 50;         
input int       InpSlowEMA           = 200;        

//--- Auto-Adjusting Profile Overrides (Determined at runtime)
double   activeMaxSpreadPips;
double   activeADXThreshold;
double   activeStopLossATRMultiplier;
double   activeTakeProfitATRMultiplier;
double   activePartialTPMultiplier;
double   activeRetestATRPercent;

//--- State Variables
enum ENUM_RETEST_STATE { STATE_NONE, STATE_BREAKOUT_BUY, STATE_BREAKOUT_SELL };
ENUM_RETEST_STATE currentRegimeState = STATE_NONE;
double   brokenLevel = 0.0;
datetime breakoutTime;

//--- Global Handles
int      h4FastEmaHandle, h4SlowEmaHandle;
int      adxHandle, atrHandle;
datetime lastBarTime;
ulong    magicNumber = 777777;
double   pipMultiplier;
double   dailyLossTracker = 0;
datetime lastDailyReset;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(magicNumber);
   
   if(_Digits == 3 || _Digits == 5 || _Digits == 2 || _Digits == 4) pipMultiplier = 10.0;
   else pipMultiplier = 1.0;

   //--- ASSET PROFILE SPECIFIC AUTO-DETECTION MATRIX
   string sym = StringSubstr(_Symbol, 0, 6);
   StringToUpper(sym);
   
   // Profile 1: Indices (US30 / NAS100)
   if(StringFind(_Symbol, "US30") >= 0 || StringFind(_Symbol, "NAS") >= 0 || StringFind(_Symbol, "USTEC") >= 0 || StringFind(_Symbol, "DJI") >= 0)
   {
      activeMaxSpreadPips           = 50.0; 
      activeADXThreshold            = 22.0; 
      activeStopLossATRMultiplier   = 2.2;  
      activeTakeProfitATRMultiplier = 4.5;  
      activePartialTPMultiplier     = 1.5;
      activeRetestATRPercent        = 0.20; 
      Print(">> PROFILE DETECTED: INDICES SPECIALIST ENGINE ACTIVE <<");
   }
   // Profile 2: Bitcoin (BTCUSD / BTC)
   else if(StringFind(_Symbol, "BTC") >= 0)
   {
      activeMaxSpreadPips           = 1500.0; 
      activeADXThreshold            = 15.0;   
      activeStopLossATRMultiplier   = 1.2;    
      activeTakeProfitATRMultiplier = 2.5;    
      activePartialTPMultiplier     = 1.0;    
      activeRetestATRPercent        = 0.12;   
      Print(">> PROFILE DETECTED: BITCOIN SPECIALIST ENGINE ACTIVE <<");
   }
   // Profile 3: Gold (XAUUSD / GOLD)
   else if(StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "GOLD") >= 0)
   {
      activeMaxSpreadPips           = 40.0;
      activeADXThreshold            = 20.0;
      activeStopLossATRMultiplier   = 2.0;
      activeTakeProfitATRMultiplier = 3.5;
      activePartialTPMultiplier     = 1.5;
      activeRetestATRPercent        = 0.15;
      Print(">> PROFILE DETECTED: GOLD SPECIALIST ENGINE ACTIVE <<");
   }
   else
   {
      activeMaxSpreadPips           = 30.0;
      activeADXThreshold            = 25.0;
      activeStopLossATRMultiplier   = 2.0;
      activeTakeProfitATRMultiplier = 3.0;
      activePartialTPMultiplier     = 1.5;
      activeRetestATRPercent        = 0.15;
      Print(">> UNKNOWN ASSET: USING GENERIC BASELINE PROFILE <<");
   }

   // Initialize Technical Matrix
   h4FastEmaHandle = iMA(_Symbol, PERIOD_H4, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   h4SlowEmaHandle = iMA(_Symbol, PERIOD_H4, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   adxHandle = iADX(_Symbol, _Period, InpATRPeriod);
   atrHandle = iATR(_Symbol, _Period, InpATRPeriod);

   if(h4FastEmaHandle == INVALID_HANDLE || h4SlowEmaHandle == INVALID_HANDLE || 
      adxHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE) return(INIT_FAILED);

   //----------------------------------------------------------------+
   // INSTITUTIONAL THEME DECORATION ENGINE                          |
   //----------------------------------------------------------------+
   long currentChartID = ChartID();
   
   // Apply Colors (Navy Blue Background, Light Blue Bullish, Grey Bearish)
   ChartSetInteger(currentChartID, CHART_COLOR_BACKGROUND, C'10,25,47');     // Deep Navy Blue
   ChartSetInteger(currentChartID, CHART_COLOR_FOREGROUND, clrWhite);       // White Text/Axes
   ChartSetInteger(currentChartID, CHART_COLOR_CANDLE_BULL, C'0,191,255');  // Light Blue (DeepSkyBlue)
   ChartSetInteger(currentChartID, CHART_COLOR_CANDLE_BEAR, C'128,128,128');// Grey
   
   // Adjust outlines for clean aesthetic continuity
   ChartSetInteger(currentChartID, CHART_COLOR_CHART_UP, C'0,191,255');     // Bullish Outline
   ChartSetInteger(currentChartID, CHART_COLOR_CHART_DOWN, C'128,128,128'); // Bearish Outline
   ChartSetInteger(currentChartID, CHART_COLOR_GRID, C'23,42,69');          // Subdued Dark Grid Lines

   // Force Candlestick view and bring to foreground
   ChartSetInteger(currentChartID, CHART_MODE, CHART_CANDLES);
   ChartSetInteger(currentChartID, CHART_FOREGROUND, false);
   
   //----------------------------------------------------------------+
   // WATERMARK: SCALPER KILLER BY KANANELO MAFABATHO               |
   //----------------------------------------------------------------+
   string labelName1 = "Watermark_Title";
   ObjectCreate(currentChartID, labelName1, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(currentChartID, labelName1, OBJPROP_XDISTANCE, 40);
   ObjectSetInteger(currentChartID, labelName1, OBJPROP_YDISTANCE, 60);
   ObjectSetInteger(currentChartID, labelName1, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(currentChartID, labelName1, OBJPROP_TEXT, "SCALPER KILLER");
   ObjectSetString(currentChartID, labelName1, OBJPROP_FONT, "Impact");
   ObjectSetInteger(currentChartID, labelName1, OBJPROP_FONTSIZE, 52);
   ObjectSetInteger(currentChartID, labelName1, OBJPROP_COLOR, C'18,53,91'); 
   ObjectSetInteger(currentChartID, labelName1, OBJPROP_BACK, true);         
   
   string labelName2 = "Watermark_Author";
   ObjectCreate(currentChartID, labelName2, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(currentChartID, labelName2, OBJPROP_XDISTANCE, 45);
   ObjectSetInteger(currentChartID, labelName2, OBJPROP_YDISTANCE, 140);
   ObjectSetInteger(currentChartID, labelName2, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(currentChartID, labelName2, OBJPROP_TEXT, "by Kananelo Mafabatho");
   ObjectSetString(currentChartID, labelName2, OBJPROP_FONT, "Century Gothic");
   ObjectSetInteger(currentChartID, labelName2, OBJPROP_FONTSIZE, 16);
   ObjectSetInteger(currentChartID, labelName2, OBJPROP_COLOR, C'0,191,255'); 
   ObjectSetInteger(currentChartID, labelName2, OBJPROP_BACK, true);

   ChartRedraw(currentChartID);

   lastBarTime = 0;
   lastDailyReset = iTime(_Symbol, PERIOD_D1, 0);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   IndicatorRelease(h4FastEmaHandle); IndicatorRelease(h4SlowEmaHandle);
   IndicatorRelease(adxHandle); IndicatorRelease(atrHandle);
   
   ObjectDelete(ChartID(), "Watermark_Title");
   ObjectDelete(ChartID(), "Watermark_Author");
   
   // Clean up all drawn structural zones using custom prefix matching
   ObjectsDeleteAll(ChartID(), "SR_Zone_");
   ChartRedraw(ChartID());
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Circuit Breakers (DISABLED: Daily Loss Tracker bypass)
   datetime currentDay = iTime(_Symbol, PERIOD_D1, 0);
   if(currentDay != lastDailyReset) { dailyLossTracker = 0; lastDailyReset = currentDay; }
   
   // Only apply circuit breaker if an input value greater than 0 is specified
   if(InpMaxDailyLossUSD > 0 && dailyLossTracker >= InpMaxDailyLossUSD) return;

   // Spread Safeguard via Profile parameters
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(((ask - bid) / (point * pipMultiplier)) > activeMaxSpreadPips) return;

   // Context Volatility Extraction
   double atrValues[]; ArraySetAsSeries(atrValues, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrValues) < 0) return;
   double currentAtr = atrValues[0];
   double retestTolerance = currentAtr * activeRetestATRPercent;

   // Active Partial Take Profit scaling manager
   if(InpUsePartialTP) HandlePartialProfits(currentAtr);

   // 2. Specialized Real-time Retest Scanning Engine
   double currentPrice = iClose(_Symbol, _Period, 0);
   int openPositionsCount = CountOpenPositions();

   if(currentRegimeState != STATE_NONE)
   {
      if(iBarShift(_Symbol, _Period, breakoutTime) > InpTimeoutBars) { currentRegimeState = STATE_NONE; brokenLevel = 0.0; }
      
      if(openPositionsCount == 0 || openPositionsCount < InpMaxPositions)
      {
         if(currentRegimeState == STATE_BREAKOUT_BUY && currentPrice <= brokenLevel + retestTolerance && currentPrice >= brokenLevel - retestTolerance)
         {
            if(iClose(_Symbol, _Period, 1) > iOpen(_Symbol, _Period, 1)) 
            {
               ExecuteOrder(POSITION_TYPE_BUY, currentAtr);
               currentRegimeState = STATE_NONE; 
            }
         }
         else if(currentRegimeState == STATE_BREAKOUT_SELL && currentPrice >= brokenLevel - retestTolerance && currentPrice <= brokenLevel + retestTolerance)
         {
            if(iClose(_Symbol, _Period, 1) < iOpen(_Symbol, _Period, 1)) 
            {
               ExecuteOrder(POSITION_TYPE_SELL, currentAtr);
               currentRegimeState = STATE_NONE;
            }
         }
      }
   }

   // 3. Structural Bar Verification Gating
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == lastBarTime) return;
   lastBarTime = currentBarTime;

   if(openPositionsCount >= InpMaxPositions) return;

   // ADX Filter
   double adxValues[]; ArraySetAsSeries(adxValues, true);
   if(CopyBuffer(adxHandle, 0, 0, 1, adxValues) < 0) return;
   if(adxValues[0] < activeADXThreshold) return; 

   // Trend Bias Filter (H4 Only)
   double h4Fast[], h4Slow[];
   ArraySetAsSeries(h4Fast, true); ArraySetAsSeries(h4Slow, true);
   if(CopyBuffer(h4FastEmaHandle, 0, 0, 1, h4Fast) < 0 || CopyBuffer(h4SlowEmaHandle, 0, 0, 1, h4Slow) < 0) return;

   bool macroBullish = (h4Fast[0] > h4Slow[0]);
   bool macroBearish = (h4Fast[0] < h4Slow[0]);

   // Major Anchor Level Multi-bar S/R Extraction
   int highestBar = iHighest(_Symbol, _Period, MODE_HIGH, InpStructureLookback, 2);
   int lowestBar  = iLowest(_Symbol, _Period, MODE_LOW, InpStructureLookback, 2);
   double strongResistance = iHigh(_Symbol, _Period, highestBar);
   double strongSupport    = iLow(_Symbol, _Period, lowestBar);

   // --- RENDER VISUAL PERSISTENT S/R RECTANGLES ---
   double zoneHeight = currentAtr * 0.15; 
   datetime dynamicEndTime = TimeCurrent() + PeriodSeconds(_Period) * 30; // Project forward
   
   datetime resBarTime = iTime(_Symbol, _Period, highestBar);
   datetime supBarTime = iTime(_Symbol, _Period, lowestBar);
   
   // Generate timestamp specific unique naming strings so history is preserved
   string resName = "SR_Zone_Res_" + IntegerToString((long)resBarTime);
   string supName = "SR_Zone_Sup_" + IntegerToString((long)supBarTime);

   DrawVisualLevel(resName, resBarTime, strongResistance, dynamicEndTime, strongResistance - zoneHeight, clrBlue, "Resistance");
   DrawVisualLevel(supName, supBarTime, strongSupport + zoneHeight, dynamicEndTime, strongSupport, clrRed, "Support");
   
   // Update the lengths of previous active lines to extend them to current chart time
   UpdateHistoricalLines(dynamicEndTime);
   
   ChartRedraw(ChartID());

   double prevClose = iClose(_Symbol, _Period, 1);

   // Breakout Detection Setup
   if(macroBullish && prevClose > strongResistance)
   {
      currentRegimeState = STATE_BREAKOUT_BUY;
      brokenLevel = strongResistance;
      breakoutTime = TimeCurrent();
   }
   else if(macroBearish && prevClose < strongSupport)
   {
      currentRegimeState = STATE_BREAKOUT_SELL;
      brokenLevel = strongSupport;
      breakoutTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Accurate Support/Resistance Zone Rectangle Rendering Block      |
//+------------------------------------------------------------------+
void DrawVisualLevel(string name, datetime t1, double p1, datetime t2, double p2, color zoneColor, string textDescription)
{
   long cid = ChartID();
   if(ObjectFind(cid, name) < 0)
   {
      ObjectCreate(cid, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
      ObjectSetInteger(cid, name, OBJPROP_FILL, true);
      ObjectSetInteger(cid, name, OBJPROP_BACK, true); 
      ObjectSetInteger(cid, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(cid, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(cid, name, OBJPROP_COLOR, zoneColor);
      ObjectSetString(cid, name, OBJPROP_TEXT, textDescription);
      ObjectSetString(cid, name, OBJPROP_TOOLTIP, textDescription + " Zone (" + DoubleToString(p1, _Digits) + ")");
   }
}

//+------------------------------------------------------------------+
//| Loop through old zones to extend their right border forward     |
//+------------------------------------------------------------------+
void UpdateHistoricalLines(datetime newEndTime)
{
   long cid = ChartID();
   int totalObjects = ObjectsTotal(cid, 0, OBJ_RECTANGLE);
   
   for(int i = totalObjects - 1; i >= 0; i--)
   {
      string objName = ObjectName(cid, i, 0, OBJ_RECTANGLE);
      if(StringFind(objName, "SR_Zone_") == 0)
      {
         // Update the 2nd time coordinate to pull the box forward
         ObjectSetInteger(cid, objName, OBJPROP_TIME, 1, newEndTime);
      }
   }
}

//+------------------------------------------------------------------+
//| Dynamic Sizing Matrix Engine Implementation with Alerts         |
//+------------------------------------------------------------------+
void ExecuteOrder(ENUM_POSITION_TYPE type, double currentAtr)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   double dynamicSLPoints = currentAtr * activeStopLossATRMultiplier;
   double dynamicTPPoints = currentAtr * activeTakeProfitATRMultiplier;

   double finalizedLot = InpFixedLotSize;
   if(InpUseDynamicLot)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskAmount = equity * (InpRiskPercent / 100.0);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(dynamicSLPoints > 0 && tickValue > 0) finalizedLot = (riskAmount / (dynamicSLPoints / tickSize * tickValue));
   }
   
   finalizedLot = CleanUpLotSize(finalizedLot);
   double minVolumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(InpUsePartialTP && finalizedLot < (2.0 * minVolumeStep)) finalizedLot = 2.0 * minVolumeStep; 

   string message = "";

   if(type == POSITION_TYPE_BUY)
   {
      double sl = ask - dynamicSLPoints;
      double tp = ask + dynamicTPPoints;
      if(trade.Buy(finalizedLot, _Symbol, ask, sl, tp, "Spec Elite Buy"))
      {
         message = "🚀 SCALPER KILLER: BUY Trade Executed on " + _Symbol + 
                   " | Lot: " + DoubleToString(finalizedLot, 2) + 
                   " | Price: " + DoubleToString(ask, _Digits);
      }
   }
   else if(type == POSITION_TYPE_SELL)
   {
      double sl = bid + dynamicSLPoints;
      double tp = bid - dynamicTPPoints;
      if(trade.Sell(finalizedLot, _Symbol, bid, sl, tp, "Spec Elite Sell"))
      {
         message = "📉 SCALPER KILLER: SELL Trade Executed on " + _Symbol + 
                   " | Lot: " + DoubleToString(finalizedLot, 2) + 
                   " | Price: " + DoubleToString(bid, _Digits);
      }
   }

   // Send mobile and desktop system messages if trade executes successfully
   if(message != "")
   {
      Alert(message);                  
      SendNotification(message);       
   }
}

//+------------------------------------------------------------------+
//| Profile Scale Partial Close Processing                            |
//+------------------------------------------------------------------+
void HandlePartialProfits(double currentAtr)
{
   // Partial scaling completely deactivated per instruction.
}

//+------------------------------------------------------------------+
//| Normalization Utilities                                          |
//+------------------------------------------------------------------+
double CleanUpLotSize(double lot)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0) return InpFixedLotSize;
   return MathMin(maxLot, MathMax(minLot, MathRound(lot / step) * step));
}

int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == magicNumber) count++;
   }
   return count;
}

void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD && HistoryDealSelect(trans.deal)) {
      if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) == magicNumber) {
         double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
         if(profit < 0) dailyLossTracker += MathAbs(profit);
      }
   }
}