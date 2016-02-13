TIME - Dates and Periods in Lua
===============================

A module for the manipulation of dates and periods according to the [Gregorian calendar](http://en.wikipedia.org/wiki/Gregorian_calendar).

## Features:

-   microsecond (1-millionth of a second) precision
-   leap years are taken into account
-   leap seconds **not** taken into account
-   convenience utilities (day of week, leap years, end of month)
-   current time (local and UTC)
-   sleep
-   based on Claus Tøndering's [calendar algorithms](http://www.tondering.dk/main/index.php/calendar-information) and the corresponding C implementation

```lua
local time = require "time"

local d1 = time.date(2012, 4, 30) -- A date at 00:00 AM.

-- Arithmetic operators are supported:
local p1 = time.hours(13) + time.minutes(30) -- A period.
local d2 = d1 + p1 -- The same date above at 1:30 PM.
assert(d2 - d1 == p1)

-- To / from strings, same functionality for periods:
local datestr = "2012-04-30T13:30:00.000000"
local d3 = time.todate(datestr)
assert(d2 == d3)
assert(tostring(d2) == datestr)

-- Comparison operators are supported:
assert(time.minutes(1) == time.seconds(60))
assert(time.minutes(1) >  time.seconds(59))
assert(d2 > d1)

print(time.nowlocal()) -- Now, according to local clock.
print(time.nowutc())   -- Now, according to UTC clock.

time.sleep(time.seconds(1)) -- Sleep for 1 second.
```

## Install

This module is included in the [ULua](http://ulua.io) distribution, to install it use:
```
upkg add time
```

Alternatively, manually install this module making sure that all dependencies listed in the `require` section of [`__meta.lua`](__meta.lua) are installed as well.

## Documentation

Refer to the [official documentation](http://scilua.org/time.html).
