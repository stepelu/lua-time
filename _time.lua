﻿--------------------------------------------------------------------------------
-- A library for the manipulation of dates and periods according to the
-- Gregorian calendar.
--
-- Credit: the Gregorian calendar routines contained in this library are 
-- ported from Claus Tøndering calendar algorithms:
-- http://www.tondering.dk/main/index.php/calendar-information .
--
-- Copyright (C) 2011-2014 Stefano Peluchetti. All rights reserved.
--
-- Features, documentation and more: http://www.scilua.org .
-- 
-- This file is part of the Time library, which is released under the MIT 
-- license: full text in file LICENSE.TXT in the library's root folder.
--------------------------------------------------------------------------------

-- TODO: Implement slep for all archs.
-- TODO: Implement nowutc, nowlocal for unix.

local ffi  = require "ffi"

local format = string.format
local abs, floor, min = math.abs, math.floor, math.min
local type, new, istype, tonumber = type, ffi.new, ffi.istype, tonumber

local int64_ct = ffi.typeof("int64_t")

local function T_int(x)
  if not (type(x) == "number" and x == floor(x)) then
    error("integer number expected")
  end
end

local function T_same(x, y)
  if not istype(x, y) then
    error("same type expected")
  end
end

-- Period ----------------------------------------------------------------------
-- Return string representation for a positive period.
local function posptostr(h, m, s, ms)
  return format("%02i:%02i:%02i.%06i", h, m, s, ms)
end

local p_ct

local function T_period(x)
  if not istype(p_ct, x) then
    error("period expected")
  end
end

local function p_64(ticks)
  return new(p_ct, ticks)
end

local function pfirst(x, y)
  if istype(p_ct, y) then
    return y, x
  else
    return x, y
  end
end

local p_mt = {
  __new = function(ct, h, m, s, ms)
    h = h or 0; m = m or 0; s = s or 0; ms = ms or 0;
    T_int(h); T_int(m); T_int(s); T_int(ms);
    return new(ct, h*(1e6*60*60LL)+m*(1e6*60LL)+s*(1e6*1LL)+ms)
  end,
  copy = function(self)
    return new(p_ct, self)
  end,
  __eq = function(self, rhs) T_same(self, rhs)
    return self._ticks == rhs._ticks
  end,
  __lt = function(self, rhs) T_same(self, rhs)
    return self._ticks < rhs._ticks
  end,
  __le = function(self, rhs) T_same(self, rhs)
    return self._ticks <= rhs._ticks
  end,
  __add = function(self, rhs) T_same(self, rhs) -- Commutative.
    return p_64(self._ticks + rhs._ticks) 
  end,
  __sub = function(self, rhs) T_same(self, rhs)
    return p_64(self._ticks - rhs._ticks)
  end,
  __unm = function(self)
    return p_64(-self._ticks)
  end,
  __mul = function(self, rhs) -- Commutative.
    local p, n = pfirst(self, rhs)
    T_int(n)
    return p_64(p._ticks*n)    
  end,
  -- Approximate ratio, non-reversible in both cases.
  __div = function(self, rhs)
    T_period(self) -- Disallow (not-a-period)/period.
    if type(rhs) == "number" then
      return p_64(self._ticks/rhs)
    elseif istype(p_ct, rhs) then
      return tonumber(self._ticks)/tonumber(rhs._ticks)
    else
      error("unexpected type")
    end
  end,
  __tostring = function(self)
    local h, m, s, ms = self:parts()
    if self._ticks >= 0 then
      return posptostr(h, m, s, ms)
    else
      return "-"..posptostr(-h, -m, -s, -ms)
    end
  end,
  ticks = function(self) -- Expose int64_t.
    return self._ticks 
  end,
  microseconds = function(self)
    return tonumber(self._ticks%1e6)
  end,
  seconds = function(self)
    return tonumber((self._ticks/1e6)%60)
  end,
  minutes = function(self)
    return tonumber((self._ticks/(1e6*60))%60)
  end,
  hours = function(self)
    return tonumber(self._ticks/(1e6*60*60))
  end,
  parts = function(self)
    return self:hours(), self:minutes(), self:seconds(), self:microseconds()
  end,
}
p_mt.__index = p_mt

p_ct = ffi.metatype("struct { int64_t _ticks; }", p_mt)

local function weeks(x)        T_int(x) return p_64(x*(1e6*60*60*24*7LL)) end
local function days(x)         T_int(x) return p_64(x*(1e6*60*60*24LL)) end
local function hours(x)        T_int(x) return p_64(x*(1e6*60*60LL)) end
local function minutes(x)      T_int(x) return p_64(x*(1e6*60LL)) end
local function seconds(x)      T_int(x) return p_64(x*(1e6*1LL)) end
local function milliseconds(x) T_int(x) return p_64(x*(1e3*1LL)) end
local function microseconds(x) T_int(x) return p_64(x*1LL) end

local function toperiod(x)
  if type(x) == "string" then
    local f1, l1, h, m, s, ms = x:find("(%d+):(%d+):(%d+).(%d+)")
    if h == nil or ms == nil or l1 ~= #x then
      error("'"..x.."' is not a string representation of a period")
    end
    local ton = tonumber
    return p_ct(ton(h), ton(m), ton(s), ton(ms))
  elseif istype(int64_ct, x) then
    return p_64(x)
  else
    error("unexpected type")
  end
end

-- Months ----------------------------------------------------------------------
local months_mt = {
  __new = function(ct, x) T_int(x)
    return new(ct, x)
  end,
}

local months_ct = ffi.metatype("struct { int32_t _m; }", months_mt)

-- Years -----------------------------------------------------------------------
local years_mt = {
  __new = function(ct, x) T_int(x)
    return new(ct, x)
  end,
}

local years_ct = ffi.metatype("struct { int32_t _y; }", years_mt)

-- Date ------------------------------------------------------------------------
-- It's date(1582, 1, 1):
local d_ticks_min = 198622713600000000LL 
-- It's date(9999,12,31) + period(23, 59, 59, 999999):
local d_ticks_max = 464269103999999999LL

local d_ct

local function T_date(x)
  if not istype(d_ct, x) then
    error("date expected")
  end
end

local function T_date_range(ticks)
  if not (d_ticks_min <= ticks and ticks <= d_ticks_max) then
    error("resulting date is outside the allowed range")
  end
end

local function d_64(ticks) T_date_range(ticks)
  return new(d_ct, ticks)
end

local function dfirst(x, y)
  if istype(d_ct, y) then
    return y, x
  else
    return x, y
  end
end

-- 1582 adoption, 9999 to keep 4 chars for years part:
local function T_year(year) T_int(year)
  if not (1582 <= year and year <= 9999) then
    error("year "..year.." outside the allowed range [1582, 9999]")
  end
end

local function T_month(month) T_int(month)
  if not (1 <= month and month <= 12) then
    error("month "..month.." outside the allowed range [1, 12]")
  end
end

local function isleapyear(year) T_year(year)
  return year%4 == 0 and (year%100 ~= 0 or year%400 == 0)
end

local eom = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

local function endofmonth(year, month) T_year(year) T_month(month)
  return (month == 2 and isleapyear(year)) and 29 or eom[month]
end

local function T_day(year, month, day)
  if not (1 <= day and day <= endofmonth(year, month)) then
    error(year.."-"..month.."-"..day.." is not a valid date")
  end
end

local function weekday(year, month, day) T_year(year) T_month(month) 
  T_day(year, month, day)
  local a = floor((14 - month)/12)
  local y = year - a
  local m = month + 12*a - 2
  local d = (day + y + floor(y/4) - floor(y/100) + floor(y/400) +
    floor((31*m)/12)) % 7
  return d == 0 and 7 or d -- Days of week from 1 = Monday to 7 = Sunday.
end

local function shift_months(y, m, deltam)
  local newm = (m - 1 + deltam) % 12 + 1
  local newy = y + floor((m - 1 + deltam)/12)
  T_year(newy)
  T_month(newm)
  return newy, newm
end

local function ymd_to_julian(year, month, day)
  -- Range of numbers suffices for this:
  local a = floor((14 - month)/12)
  local y = year + 4800 - a
  local m = month + 12*a - 3
  return day + floor((153*m + 2)/5) + 365*y + floor(y/4) - floor(y/100) +
    floor(y/400) - 32045
end

local function julian_to_ymd(julian)
  -- Range of numbers suffices for this:
  local a = julian + 32044
  local b = floor((4*a + 3)/146097)
  local c = a - floor((146097*b)/4)
  local d = floor((4*c + 3)/1461)
  local e = c - floor((1461*d)/4)
  local m = floor((5*e + 2)/153)
  local day = e - floor((153*m + 2)/5) + 1
  local month = m + 3 - 12*floor(m/10)
  local year = 100*b + d - 4800 + floor(m/10)
  return year, month, day
end

-- Assumes only violation of valid date may be in day outside of end of month
-- due to months and years shifts. Cap the day and returns a valid date.
local function valid_date_cap_day(year, month, day)
  day = min(day, endofmonth(year, month))
  return d_ct(year, month, day)
end

local d_mt = {
  __new = function(ct, year, month, day) T_year(year) T_month(month) 
    T_day(year, month, day)
    return new(ct, ymd_to_julian(year, month, day)*(86400LL*1e6))
  end,
  copy = function(self)
    return new(d_ct, self)
  end,
  __eq = p_mt.__eq,
  __lt = p_mt.__lt,
  __le = p_mt.__le,
  __add = function(self, rhs) -- Commutative.
    local d, s = dfirst(self, rhs)    
    if istype(p_ct, s) then 
      return d_64(d._ticks + s._ticks)
    elseif istype(months_ct, s) then
      local year, month, day = d:ymd()
      year, month = shift_months(year, month, s._m)
      return valid_date_cap_day(year, month, day) + d:period()
    elseif istype(years_ct, s) then
      local year, month, day = d:ymd()
      year = year + s._y
      return valid_date_cap_day(year, month, day) + d:period()
    else
      error("unexpected type")
    end
  end,
  __sub = function(self, rhs)
    T_date(self) -- Disallow (not-a-date)-date.
    if istype(p_ct, rhs) then 
      return d_64(self._ticks - rhs._ticks)
    elseif istype(months_ct, rhs) then
      local year, month, day = self:ymd()
      year, month = shift_months(year, month, -rhs._m)
      return valid_date_cap_day(year, month, day) + self:period()
    elseif istype(years_ct, rhs) then
      local year, month, day = self:ymd()
      year = year - rhs._y
      return valid_date_cap_day(year, month, day) + self:period()
    elseif istype(d_ct, rhs) then
      return p_64(self._ticks - rhs._ticks)
    else
      error("unexpected type")
    end
  end,
  __tostring = function(self)
    local year, month, day = self:ymd()
    local h, m, s, ms = self:period():parts()
    return format("%i-%02i-%02iT", year, month, day)..posptostr(h, m, s, ms)
  end,
  ticks = p_mt.ticks,
  ymd = function(self)
    local julian = tonumber(self._ticks/(86400LL*1e6))
    return julian_to_ymd(julian)
  end,
  year  = function(self) local y, m, d = self:ymd() return y end,
  month = function(self) local y, m, d = self:ymd() return m end,
  day   = function(self) local y, m, d = self:ymd() return d end,
  period = function(self)
    return p_64(self._ticks%(86400LL*1e6))
  end,
  isleapyear = function(self) 
    local y = self:ymd()
    return isleapyear(y) 
  end,
  endofmonth = function(self) 
    local y, m = self:ymd()
    return endofmonth(y, m)
  end,
  weekday = function(self)
    local y, m, d = self:ymd()
    return weekday(y, m, d)
  end,
}
d_mt.__index = d_mt

d_ct = ffi.metatype("struct { int64_t _ticks; }", d_mt)

local function todate(x)
  if type(x) == "string" then
    local f1, l1, year, month, day, h, m, s, ms = 
      x:find("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+).(%d+)")
    if year == nil or ms == nil or l1 ~= #x then
      error("'"..x.."' is not a string representation of a date")
    end
    local ton = tonumber
    return d_ct(ton(year), ton(month), ton(day)) + 
      p_ct(ton(h), ton(m), ton(s), ton(ms))
  elseif istype(int64_ct, x) then
    return d_64(x)
  else
    error("unexpected type")
  end
end

-- System-dependent functions --------------------------------------------------
local nowlocal, nowutc, sleep

if jit.os == "Windows" then
  ffi.cdef[[
  typedef unsigned long DWORD;
  typedef unsigned short WORD;
  typedef unsigned long long ULONGLONG;
  
  typedef struct {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
  } FILETIME, *PFILETIME;
  
  typedef struct {
    WORD wYear;
    WORD wMonth;
    WORD wDayOfWeek;
    WORD wDay;
    WORD wHour;
    WORD wMinute;
    WORD wSecond;
    WORD wMilliseconds;
  } SYSTEMTIME, *PSYSTEMTIME;
  
  typedef union _ULARGE_INTEGER {
    struct {
      DWORD LowPart;
      DWORD HighPart;
    };
    struct {
      DWORD LowPart;
      DWORD HighPart;
    } u;
    ULONGLONG QuadPart;
  } ULARGE_INTEGER, *PULARGE_INTEGER;
  
  void GetSystemTimeAsFileTime(PFILETIME lpSystemTimeAsFileTime);
  bool FileTimeToSystemTime(const FILETIME *lpFileTime,
    PSYSTEMTIME lpSystemTime);
  void GetLocalTime(PSYSTEMTIME lpSystemTime);
  ]]
  
  local ft_ct = ffi.typeof("FILETIME")
  local st_ct = ffi.typeof("SYSTEMTIME")
  local ul_ct = ffi.typeof("ULARGE_INTEGER")
  local C = ffi.C
  local ftoffset = 199222329599999000ULL
  
  local st = st_ct() -- Buffer.
  nowlocal = function()
    C.GetLocalTime(st)
    return d_ct(st.wYear, st.wMonth, st.wDay) + p_ct(st.wHour, st.wMinute,
      st.wSecond, st.wMilliseconds*1000)
  end
  
  local ul = ul_ct() -- Buffer.
  local function ft_to_int64(x)
    ul.LowPart = x.dwLowDateTime
    ul.HighPart = x.dwHighDateTime
    return ul.QuadPart
  end
  
  local ft = ft_ct() -- Buffer.
  -- No daylight adjustment, potentially faster and more precise.
  nowutc = function()
    C.GetSystemTimeAsFileTime(ft)
    return d_64(ft_to_int64(ft)/10 + ftoffset)
  end
end -- Windows.

return {
  period       = p_ct,   
  toperiod     = toperiod,
  
  weeks        = weeks,
  days         = days,
  hours        = hours,
  minutes      = minutes,
  seconds      = seconds,
  milliseconds = milliseconds,
  microseconds = microseconds,
  
  date         = d_ct,
  todate       = todate,
  
  isleapyear   = isleapyear,
  endofmonth   = endofmonth,
  weekday      = weekday,
  
  months       = months_ct,
  years        = years_ct,
  
  sleep        = sleep,
  nowlocal     = nowlocal,
  nowutc       = nowutc,
}