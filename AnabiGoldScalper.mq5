//+------------------------------------------------------------------+
//| Anabi Gold Scalper V1                                            |
//| Deriv MT5 - XAUUSD - DEMO TESTING FIRST                          |
//| Strategy: EMA trend + RSI + ADX + ATR risk management            |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"
#property description "Anabi Gold Scalper - Demo testing EA"
#include <Trade/Trade.mqh>
CTrade trade;
//---- Strategy settings
input ENUM_TIMEFRAMES EntryTimeframe = PERIOD_M5;
input ENUM_TIMEFRAMES TrendTimeframe = PERIOD_M15;
input int FastEMA = 9;
input int SlowEMA = 21;
input int RSIPeriod = 14;
input double BuyRSI = 55.0;
input double SellRSI = 45.0;
input int ADXPeriod = 14;
input double MinimumADX = 20.0;
input int ATRPeriod = 14;
//---- Risk controls
input double RiskPercent = 0.5;
input double RewardRiskRatio = 1.5;
input double MaximumDailyLossPercent = 2.0;
input int MaximumSpreadPoints = 100;
input ulong MagicNumber = 26101801;
//---- Indicator handles
int fastHandle = INVALID_HANDLE;
int slowHandle = INVALID_HANDLE;
int trendFastHandle = INVALID_HANDLE;
int trendSlowHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;
int adxHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;
datetime lastBarTime = 0;
int dayOfYear = -1;
double dayStartingEquity = 0.0;
//+------------------------------------------------------------------+
int OnInit()
{
   if(RiskPercent <= 0 || RiskPercent > 0.5 ||
      RewardRiskRatio <= 0 ||
      MaximumDailyLossPercent <= 0 ||
      FastEMA <= 0 || SlowEMA <= FastEMA)
   {
      Print("Invalid settings. Check risk and indicator inputs.");
      return INIT_PARAMETERS_INCORRECT;
   }
   fastHandle = iMA(_Symbol, EntryTimeframe, FastEMA, 0,
                    MODE_EMA, PRICE_CLOSE);
   slowHandle = iMA(_Symbol, EntryTimeframe, SlowEMA, 0,
                    MODE_EMA, PRICE_CLOSE);
   trendFastHandle = iMA(_Symbol, TrendTimeframe, FastEMA, 0,
                         MODE_EMA, PRICE_CLOSE);
   trendSlowHandle = iMA(_Symbol, TrendTimeframe, SlowEMA, 0,
                         MODE_EMA, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, EntryTimeframe, RSIPeriod, PRICE_CLOSE);
   adxHandle = iADX(_Symbol, EntryTimeframe, ADXPeriod);
   atrHandle = iATR(_Symbol, EntryTimeframe, ATRPeriod);
   if(fastHandle == INVALID_HANDLE ||
      slowHandle == INVALID_HANDLE ||
      trendFastHandle == INVALID_HANDLE ||
      trendSlowHandle == INVALID_HANDLE ||
      rsiHandle == INVALID_HANDLE ||
      adxHandle == INVALID_HANDLE ||
      atrHandle == INVALID_HANDLE)
   {
      Print("Could not initialize indicators.");
      return INIT_FAILED;
   }
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(20);
   ResetDailyBaseline();
   Print("Anabi Gold Scalper initialized. Test on DEMO only.");
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(fastHandle != INVALID_HANDLE) IndicatorRelease(fastHandle);
   if(slowHandle != INVALID_HANDLE) IndicatorRelease(slowHandle);
   if(trendFastHandle != INVALID_HANDLE) IndicatorRelease(trendFastHandle);
   if(trendSlowHandle != INVALID_HANDLE) IndicatorRelease(trendSlowHandle);
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if(adxHandle != INVALID_HANDLE) IndicatorRelease(adxHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
}
//+------------------------------------------------------------------+
void ResetDailyBaseline()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dayOfYear = dt.day_of_year;
   dayStartingEquity = AccountInfoDouble(ACCOUNT_EQUITY);
}
//+------------------------------------------------------------------+
bool DailyLossLimitReached()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_year != dayOfYear)
      ResetDailyBaseline();
   if(dayStartingEquity <= 0)
      return true;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double lossPercent =
      100.0 * (dayStartingEquity - equity) / dayStartingEquity;
   if(lossPercent >= MaximumDailyLossPercent)
   {
      Print("Daily loss limit reached. No new trades today.");
      return true;
   }
   return false;
}
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime barTime = iTime(_Symbol, EntryTimeframe, 0);
   if(barTime == 0 || barTime == lastBarTime)
      return false;
   lastBarTime = barTime;
   return true;
}
//+------------------------------------------------------------------+
bool ReadValue(int handle, int buffer, int shift, double &value)
{
   double data[];
   ArraySetAsSeries(data, true);
   if(CopyBuffer(handle, buffer, shift, 1, data) != 1)
      return false;
   value = data[0];
   return MathIsValidNumber(value);
}
//+------------------------------------------------------------------+
double CalculateVolume(double entry, double stop)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * RiskPercent / 100.0;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double distance = MathAbs(entry - stop);
   if(equity <= 0 || tickSize <= 0 || tickValue <= 0 ||
      distance <= 0 || volumeStep <= 0 || minVolume <= 0)
      return 0.0;
   double lossPerLot = (distance / tickSize) * tickValue;
   if(lossPerLot <= 0)
      return 0.0;
   double rawVolume = riskMoney / lossPerLot;
   // Never round upward beyond the intended risk.
   double volume = MathFloor(rawVolume / volumeStep) * volumeStep;
   if(volume < minVolume)
   {
      Print("Minimum lot exceeds calculated risk. Skipping trade.");
      return 0.0;
   }
   volume = MathMin(volume, maxVolume);
   int volumeDigits = 0;
   double stepCheck = volumeStep;
   while(volumeDigits < 8 &&
         MathAbs(stepCheck - MathRound(stepCheck)) > 0.00000001)
   {
      stepCheck *= 10.0;
      volumeDigits++;
   }
   return NormalizeDouble(volume, volumeDigits);
}
//+------------------------------------------------------------------+
bool HasOurPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return true;
   }
   return false;
}
//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsNewBar())
      return;
   if(DailyLossLimitReached())
      return;
   if(HasOurPosition())
      return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0 || tick.bid <= 0)
      return;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0)
      return;
   double spreadPoints = (tick.ask - tick.bid) / point;
   if(spreadPoints > MaximumSpreadPoints)
   {
      Print("Spread too high. Skipping setup.");
      return;
   }
   // Use the last fully closed candle (shift 1).
   double fast, slow, trendFast, trendSlow;
   double rsi, adx, atr;
   if(!ReadValue(fastHandle, 0, 1, fast) ||
      !ReadValue(slowHandle, 0, 1, slow) ||
      !ReadValue(trendFastHandle, 0, 1, trendFast) ||
      !ReadValue(trendSlowHandle, 0, 1, trendSlow) ||
      !ReadValue(rsiHandle, 0, 1, rsi) ||
      !ReadValue(adxHandle, 0, 1, adx) ||
      !ReadValue(atrHandle, 0, 1, atr))
      return;
   if(atr <= 0 || adx < MinimumADX)
      return;
   bool buySignal =
      fast > slow &&
      trendFast > trendSlow &&
      rsi >= BuyRSI;
   bool sellSignal =
      fast < slow &&
      trendFast < trendSlow &&
      rsi <= SellRSI;
   if(!buySignal && !sellSignal)
      return;
   double stopDistance = 1.5 * atr;
   double takeDistance = stopDistance * RewardRiskRatio;
   double entry, stop, target, volume;
   if(buySignal)
   {
      entry = tick.ask;
      stop = entry - stopDistance;
      target = entry + takeDistance;
   }
   else
   {
      entry = tick.bid;
      stop = entry + stopDistance;
      target = entry - takeDistance;
   }
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   stop = NormalizeDouble(stop, digits);
   target = NormalizeDouble(target, digits);
   // Check broker minimum stop distances.
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDistance = stopsLevel * point;
   if((buySignal &&
       (entry - stop < minStopDistance ||
        target - entry < minStopDistance)) ||
      (sellSignal &&
       (stop - entry < minStopDistance ||
        entry - target < minStopDistance)))
      return;
   volume = CalculateVolume(entry, stop);
   if(volume <= 0)
      return;
   bool sent = false;
   if(buySignal)
      sent = trade.Buy(volume, _Symbol, 0.0, stop, target,
                       "Anabi Gold Scalper BUY");
   else
      sent = trade.Sell(volume, _Symbol, 0.0, stop, target,
                        "Anabi Gold Scalper SELL");
   if(!sent)
   {
      Print("Order failed: ", trade.ResultRetcodeDescription());
      return;
   }
   Print("Order request processed. Retcode: ",
         trade.ResultRetcodeDescription(),
         " | Volume: ", volume,
         " | SL: ", stop,
         " | TP: ", target);
}
//+------------------------------------------------------------------+