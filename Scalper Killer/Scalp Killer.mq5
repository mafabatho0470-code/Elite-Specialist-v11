//+------------------------------------------------------------------+
//|                                  Elite_Gold_Specialist_V11_5.mq5 |
//|                                                 Copyright 2026   |
//|                                              https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      "https://www.mql5.com"
#property version   "11.50"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//--- Core User Customization Inputs
input group "--- Core Risk Management ---"
input bool      InpUseDynamicLot     = true;       
input double    InpRiskPercent       = 1.5;         
input double    InpFixedLotSize      = 0.01;        
input int       InpMaxPositions      = 3;           
input bool      InpUsePartialTP      = true;        

input group "--- Pure Gold Mathematical Foundation ---"
input int       InpStructureLookback = 100;         // S/R Lookback window
input int       InpATRPeriod         = 14;          // Period for Volatility Math
input int       InpTimeoutBars       = 30;          // Max bars to wait for retest before stale

input group "--- Macro Trend Structural Filters ---"
input int       InpFastEMA           = 50;          // Base macro direction anchor
input int       InpSlowEMA           = 200;         // Base macro direction anchor

input group "--- Chart Visual Customization ---"
input string    InpCrocImageFile     = "crocodile.bmp"; // Name of your image in MQL5/Images/

//--- Step 2: Hardcoded High-Performance Gold Profile Parameters
const double   activeMaxSpreadPips           = 40.0;  // Shield against rollover/spread spikes
const double   activeADXThreshold            = 20.0;  // Ensure baseline volume momentum
const double   activeStopLossATRMultiplier   = 2.0;   // Restored V11 Profit Engine Matrix
const double   activeTakeProfitATRMultiplier = 3.5;   // Restored V11 Profit Engine Matrix
const double   activeRetestATRPercent        = 0.15;  // Zone cushion width

//--- State Logic
enum ENUM_RETEST_STATE { STATE_NONE, STATE_BREAKOUT_BUY, STATE_BREAKOUT_SELL };
ENUM_RETEST_STATE currentRegimeState = STATE_NONE;
double   brokenLevel = 0.0;
datetime breakoutTime;

//--- Technical Handles
int      h4FastEmaHandle, h4SlowEmaHandle;
int      adxHandle, atrHandle;
datetime lastBarTime;
ulong    magicNumber = 888777; // Dedicated Gold Magic Number
double   pipMultiplier;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Step 1: Strict Initialization Kill-Switch
   string sym = _Symbol;
   StringToUpper(sym);
   if(StringFind(sym, "XAU") < 0 && StringFind(sym, "GOLD") < 0)
   {
      Alert("❌ CRITICAL REJECTION: Elite Gold Specialist is designed for XAUUSD ONLY. Removing from non-gold asset.");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(magicNumber);
   
   if(_Digits == 3 || _Digits == 5 || _Digits == 2 || _Digits == 4) pipMultiplier = 10.0;
   else pipMultiplier = 1.0;

   // Setup Indicators
   h4FastEmaHandle = iMA(_Symbol, PERIOD_H4, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   h4SlowEmaHandle = iMA(_Symbol, PERIOD_H4, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   adxHandle = iADX(_Symbol, _Period, InpATRPeriod);
   atrHandle = iATR(_Symbol, _Period, InpATRPeriod);

   if(h4FastEmaHandle == INVALID_HANDLE || h4SlowEmaHandle == INVALID_HANDLE || 
      adxHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE) return(INIT_FAILED);

   //--- DRAW THE CHART VISUALS
   CreateChartVisuals();

   Print(">> 🟡 ELITE GOLD SPECIALIST V11.5 ACTIVE AND HARDCODED FOR XAUUSD <<");
   lastBarTime = 0;
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(h4FastEmaHandle); IndicatorRelease(h4SlowEmaHandle);
   IndicatorRelease(adxHandle); IndicatorRelease(atrHandle);
   
   ObjectDelete(0, "Watermark_Title");
   ObjectDelete(0, "Watermark_Author");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Environmental Spread Check
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(((ask - bid) / (point * pipMultiplier)) > activeMaxSpreadPips) return;

   double atrValues[]; ArraySetAsSeries(atrValues, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrValues) < 0) return;
   double currentAtr = atrValues[0];
   double retestTolerance = currentAtr * activeRetestATRPercent;

   double currentPrice = iClose(_Symbol, _Period, 0);
   int openPositionsCount = CountOpenPositions();

   //----------------------------------------------------------------+
   // CRITICAL V11 CORE: EVERY SINGLE TICK RETEST MONITORING         |
   //----------------------------------------------------------------+
   if(currentRegimeState != STATE_NONE)
   {
      if(iBarShift(_Symbol, _Period, breakoutTime) > InpTimeoutBars) { currentRegimeState = STATE_NONE; brokenLevel = 0.0; }
      
      if(openPositionsCount < InpMaxPositions)
      {
         double open1  = iOpen(_Symbol, _Period, 1);
         double close1 = iClose(_Symbol, _Period, 1);
         double high1  = iHigh(_Symbol, _Period, 1);
         double low1   = iLow(_Symbol, _Period, 1);
         
         double totalRange = high1 - low1;
         double bodySize   = MathAbs(close1 - open1);
         
         bool isValidBody = (totalRange > 0) && ((bodySize / totalRange) >= 0.50);

         if(currentRegimeState == STATE_BREAKOUT_BUY && currentPrice <= brokenLevel + retestTolerance && currentPrice >= brokenLevel - retestTolerance)
         {
            if(close1 > open1 && isValidBody) 
            {
               ExecuteOrder(POSITION_TYPE_BUY, currentAtr);
               currentRegimeState = STATE_NONE; 
            }
         }
         else if(currentRegimeState == STATE_BREAKOUT_SELL && currentPrice >= brokenLevel - retestTolerance && currentPrice <= brokenLevel + retestTolerance)
         {
            if(close1 < open1 && isValidBody) 
            {
               ExecuteOrder(POSITION_TYPE_SELL, currentAtr);
               currentRegimeState = STATE_NONE;
            }
         }
      }
   }

   // 3. Structural Level Arming Block
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == lastBarTime) return;
   lastBarTime = currentBarTime;

   if(openPositionsCount >= InpMaxPositions) return;

   double adxValues[]; ArraySetAsSeries(adxValues, true);
   if(CopyBuffer(adxHandle, 0, 0, 1, adxValues) < 0) return;
   if(adxValues[0] < activeADXThreshold) return; 

   double h4Fast[], h4Slow[];
   ArraySetAsSeries(h4Fast, true); ArraySetAsSeries(h4Slow, true);
   if(CopyBuffer(h4FastEmaHandle, 0, 0, 1, h4Fast) < 0 || CopyBuffer(h4SlowEmaHandle, 0, 0, 1, h4Slow) < 0) return;

   int highestBar = iHighest(_Symbol, _Period, MODE_HIGH, InpStructureLookback, 2);
   int lowestBar  = iLowest(_Symbol, _Period, MODE_LOW, InpStructureLookback, 2);
   double strongResistance = iHigh(_Symbol, _Period, highestBar);
   double strongSupport    = iLow(_Symbol, _Period, lowestBar);

   double prevClose = iClose(_Symbol, _Period, 1);

   if(h4Fast[0] > h4Slow[0] && prevClose > strongResistance)
   {
      currentRegimeState = STATE_BREAKOUT_BUY;
      brokenLevel = strongResistance;
      breakoutTime = TimeCurrent();
   }
   else if(h4Fast[0] < h4Slow[0] && prevClose < strongSupport)
   {
      currentRegimeState = STATE_BREAKOUT_SELL;
      brokenLevel = strongSupport;
      breakoutTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Dynamic Sizing Matrix Engine Implementation with Alerts           |
//+------------------------------------------------------------------+
void ExecuteOrder(ENUM_POSITION_TYPE type, double currentAtr)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

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
   
   // ✅ FIXED: InpUsePartialTP is now safely recognized by the compiler
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

   if(message != "")
   {
      Alert(message);                  
      SendNotification(message);       
   }
}

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

//+------------------------------------------------------------------+
//| Custom Function to Draw UI Branding on Chart Background          |
//+------------------------------------------------------------------+
void CreateChartVisuals()
{
   long currentChartID = ChartID();
   
   ChartSetInteger(currentChartID, CHART_COLOR_BACKGROUND, C'10,25,47');     
   ChartSetInteger(currentChartID, CHART_COLOR_FOREGROUND, clrWhite);       
   ChartSetInteger(currentChartID, CHART_COLOR_CANDLE_BULL, C'0,191,255');  
   ChartSetInteger(currentChartID, CHART_COLOR_CANDLE_BEAR, C'128,128,128');
   
   ChartSetInteger(currentChartID, CHART_COLOR_CHART_UP, C'0,191,255');     
   ChartSetInteger(currentChartID, CHART_COLOR_CHART_DOWN, C'128,128,128'); 
   ChartSetInteger(currentChartID, CHART_COLOR_GRID, C'23,42,69');          

   ChartSetInteger(currentChartID, CHART_MODE, CHART_CANDLES);
   ChartSetInteger(currentChartID, CHART_FOREGROUND, false);
   
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

   ChartRedraw();
}
