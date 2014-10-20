Time
====

This is a MIT licensed library for the manipulation of dates and periods according to the Gregorian calendar, i.e. the internationally accepted calendar for most uses. The library is built around two concepts:

+ **date**: a specific point in time, for example yesterday at 3:00 PM
+ **period**: a duration of time, for example three hours

with the following characteristics:

+ dates and periods have microsecond (1-millionth of a second) precision
+ leap years are taken into account
+ all years have the same number of seconds, i.e. there are no leap seconds

All of the date-related functionalities are based on Claus Tøndering's calendar algorithms and the corresponding C implementation.

The following example presents the main features of this library:

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
 
print(time.nowlocal()) --> Now, according to local clock.
print(time.nowutc())   --> Now, according to UTC clock.
 
time.sleep(time.seconds(1)) --> Sleep for 1 second.
```

Info: http://scilua.org/time.html
