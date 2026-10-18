//+------------------------------------------------------------------+
//| Anabi Gold Scalper V2                                            |
//| MT5 Expert Advisor - DEMO TESTING ONLY                           |
//| EMA trend + RSI + ADX + ATR                                      |
//+------------------------------------------------------------------+
#property strict
#property version "2.00"
#property description "Anabi Gold Scalper V2 - Demo only"

#include <Trade/Trade.mqh>
CTrade trade;

input ENUM_TIMEFRAMES EntryTF = PERIOD_M5;
input ENUM_TIMEFRAMES TrendTF = PERIOD_M15;

input int FastEMA = 9;
input int SlowEMA = 21;
input int RSIPeriod = 14;
input double BuyRSI = 55.0;
input double SellRSI = 45.0;
input int ADXPeriod = 14;
input double MinimumADX = 20.0;
input int ATRPeriod = 14;

input double RiskPercent = 0.5;
input double RewardRiskRatio = 1.5;
input double MaximumDailyLossPercent = 2.0;
input int MaximumSpreadPoints = 100;
input ulong MagicNumber = 26101802;

int fastHandle = INVALID_HANDLE;
int slowHandle = INVALID_HANDLE;
int trendFastHandle = INVALID_HANDLE;
int trendSlowHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;
int adxHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;

datetime lastBarTime = 0;
int dayKey = -1;
double dayStartEquity = 0.0;
bool dailyLock = false;

//+------------------------------------------------------------------+
int DateKey()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.year * 1000 + dt.day_of_year;
}

//+------------------------------------------------------------------+
string DailyKeyName()
{
   return "AGSV2_" +
          IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) +
          "_" + _Symbol + "_" + IntegerToString((long)MagicNumber) +
          "_DAY";
}

string EquityKeyName()
{
   return DailyKeyName() + "_EQUITY";
}

string LockKeyName()
{
   return DailyKeyName() + "_LOCK";
}

//+------------------------------------------------------------------+
bool DemoAccountOnly()
{
   return AccountInfoInteger(ACCOUNT_TRADE_MODE) ==
          ACCOUNT_TRADE_MODE_DEMO;
}

//+------------------------------------------------------------------+
int OnInit()
{
   if(!DemoAccountOnly())
   {
      Print("SAFETY LOCK: This EA only runs on a DEMO account.");
      return INIT_FAILED;
   }

   if(RiskPercent <= 0.0 || RiskPercent > 0.5 ||
      MaximumDailyLossPercent <= 0.0 ||
      RewardRiskRatio <= 0.0 ||
      FastEMA <= 0 || SlowEMA <= FastEMA ||
      RSIPeriod <= 0 || ADXPeriod <= 0 || ATRPeriod <= 0 ||
      MaximumSpreadPoints <= 0)
   {
      Print("Invalid input settings.");
      return INIT_PARAMETERS_INCORRECT;
   }

   fastHandle = iMA(_Symbol, EntryTF, FastEMA, 0,
                    MODE_EMA, PRICE_CLOSE);
   slowHandle = iMA(_Symbol, EntryTF, SlowEMA, 0,
                    MODE_EMA, PRICE_CLOSE);
   trendFastHandle = iMA(_Symbol, TrendTF, FastEMA, 0,
                         MODE_EMA, PRICE_CLOSE);
   trendSlowHandle = iMA(_Symbol, TrendTF, SlowEMA, 0,
                         MODE_EMA, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, EntryTF, RSIPeriod, PRICE_CLOSE);
   adxHandle = iADX(_Symbol, EntryTF, ADXPeriod);
   atrHandle = iATR(_Symbol, EntryTF, ATRPeriod);

   if(fastHandle == INVALID_HANDLE ||
      slowHandle == INVALID_HANDLE ||
      trendFastHandle == INVALID_HANDLE ||
      trendSlowHandle == INVALID_HANDLE ||
      rsiHandle == INVALID_HANDLE ||
      adxHandle == INVALID_HANDLE ||
      atrHandle == INVALID_HANDLE)
   {
      Print("Indicator initialization failed.");
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(20);

   LoadDailyState();

   Print("Anabi Gold Scalper V2 initialized in DEMO mode.");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(fastHandle != INVALID_HANDLE) IndicatorRelease(fastHandle);
   if(slowHandle != INVALID_HANDLE) IndicatorRelease(slowHandle);
   if(trendFastHandle != INVALID_HANDLE)
      IndicatorRelease(trendFastHandle);
   if(trendSlowHandle != INVALID_HANDLE)
      IndicatorRelease(trendSlowHandle);
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if(adxHandle != INVALID_HANDLE) IndicatorRelease(adxHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
void LoadDailyState()
{
   int today = DateKey();

   if(GlobalVariableCheck(DailyKeyName()) &&
      GlobalVariableGet(DailyKeyName()) == today &&
      GlobalVariableCheck(EquityKeyName()))
   {
      dayKey = today;
      dayStartEquity = GlobalVariableGet(EquityKeyName());
      dailyLock = GlobalVariableCheck(LockKeyName()) &&
                  GlobalVariableGet(LockKeyName()) == today;
   }
   else
   {
      dayKey = today;
      dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      dailyLock = false;

      GlobalVariableSet(DailyKeyName(), (double)dayKey);
      GlobalVariableSet(EquityKeyName(), dayStartEquity);
      GlobalVariableDel(LockKeyName());
   }
}

//+------------------------------------------------------------------+
bool CheckDailyLoss()
{
   int today = DateKey();

   if(today != dayKey)
   {
      dayKey = today;
      dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      dailyLock = false;

      GlobalVariableSet(DailyKeyName(), (double)dayKey);
      GlobalVariableSet(EquityKeyName(), dayStartEquity);
      GlobalVariableDel(LockKeyName());
   }

   if(dailyLock)
      return false;

   if(dayStartEquity <= 0.0)
   {
      dailyLock = true;
      GlobalVariableSet(LockKeyName(), (double)dayKey);
      return false;
   }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double lossPercent =
      100.0 * (dayStartEquity - equity) / dayStartEquity;

   if(lossPercent >= MaximumDailyLossPercent)
   {
      dailyLock = true;
      GlobalVariableSet(LockKeyName(), (double)dayKey);
      Print("Daily loss lock reached. No more entries today.");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
bool NewBar()
{
   datetime current = iTime(_Symbol, EntryTF, 0);

   if(current == 0 || current == lastBarTime)
      return false;

   lastBarTime = current;
   return true;
}

//+------------------------------------------------------------------+
bool GetBufferValue(int handle, int buffer, double &value)
{
   double data[];
   ArraySetAsSeries(data, true);

   if(CopyBuffer(handle, buffer, 1, 1, data) != 1)
      return false;

   value = data[0];
   return MathIsValidNumber(value);
}

//+------------------------------------------------------------------+
bool HasOpenPosition()
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
double CalculateVolume(double entry, double stop)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * RiskPercent / 100.0;

   double tickSize =
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue =
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double minVolume =
      SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVolume =
      SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step =
      SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double distance = MathAbs(entry - stop);

   if(equity <= 0.0 || tickSize <= 0.0 ||
      tickValue <= 0.0 || distance <= 0.0 ||
      minVolume <= 0.0 || step <= 0.0)
      return 0.0;

   double lossPerLot = distance / tickSize * tickValue;

   if(lossPerLot <= 0.0)
      return 0.0;

   double rawVolume = riskMoney / lossPerLot;

   // Never round up or force the broker's minimum lot.
   double volume = MathFloor(rawVolume / step + 1e-9) * step;

   if(volume < minVolume)
   {
      Print("Trade skipped: minimum lot exceeds the risk budget.");
      return 0.0;
   }

   volume = MathMin(volume, maxVolume);

   int digits = 0;
   double scaledStep = step;

   while(digits < 8 &&
         MathAbs(scaledStep - MathRound(scaledStep)) > 1e-8)
   {
      scaledStep *= 10.0;
      digits++;
   }

   return NormalizeDouble(volume, digits);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(!NewBar())
      return;

   if(!CheckDailyLoss())
      return;

   if(HasOpenPosition())
      return;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) ||
      tick.ask <= 0.0 || tick.bid <= 0.0)
      return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   double spread = (tick.ask - tick.bid) / point;
   if(spread > MaximumSpreadPoints)
      return;

   double fast, slow, trendFast, trendSlow;
   double rsi, adx, atr;

   if(!GetBufferValue(fastHandle, 0, fast) ||
      !GetBufferValue(slowHandle, 0, slow) ||
      !GetBufferValue(trendFastHandle, 0, trendFast) ||
      !GetBufferValue(trendSlowHandle, 0, trendSlow) ||
      !GetBufferValue(rsiHandle, 0, rsi) ||
      !GetBufferValue(adxHandle, 0, adx) ||
      !GetBufferValue(atrHandle, 0, atr))
      return;

   if(atr <= 0.0 || adx < MinimumADX)
      return;

   bool buy =
      fast > slow && trendFast > trendSlow && rsi >= BuyRSI;

   bool sell =
      fast < slow && trendFast < trendSlow && rsi <= SellRSI;

   if(!buy && !sell)
      return;

   double stopDistance = 1.5 * atr;
   double targetDistance = stopDistance * RewardRiskRatio;

   double entry = buy ? tick.ask : tick.bid;
   double stop = buy ? entry - stopDistance : entry + stopDistance;
   double target = buy ? entry + targetDistance : entry - targetDistance;

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   stop = NormalizeDouble(stop, digits);
   target = NormalizeDouble(target, digits);

   long stopLevel =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minimumDistance = stopLevel * point;

   if((buy && (entry - stop < minimumDistance ||
               target - entry < minimumDistance)) ||
      (sell && (stop - entry < minimumDistance ||
                entry - target < minimumDistance)))
      return;

   double volume = CalculateVolume(entry, stop);
   if(volume <= 0.0)
      return;

   bool sent;

   if(buy)
      sent = trade.Buy(volume, _Symbol, 0.0, stop, target,
                       "Anabi V2 BUY");
   else
      sent = trade.Sell(volume, _Symbol, 0.0, stop, target,
                        "Anabi V2 SELL");

   if(!sent)
   {
      Print("Order failed: ", trade.ResultRetcodeDescription());
      return;
   }

   uint result = trade.ResultRetcode();

   if(result != TRADE_RETCODE_DONE &&
      result != TRADE_RETCODE_PLACED &&
      result != TRADE_RETCODE_DONE_PARTIAL)
   {
      Print("Trade not confirmed: ", trade.ResultRetcodeDescription());
      return;
   }

   Print("V2 order result: ", trade.ResultRetcodeDescription(),
         " | Volume: ", volume,
         " | SL: ", stop,
         " | TP: ", target);
}
//+------------------------------------------------------------------+