-- convert our custom log format to combined log format
-- usage: lua src/create_combined_log.lua < logs/counter.txt > access_log

-- log format info:
--
-- This consists of the following space-separated fields:

-- Hostname or IP address of accesser of site. If a proxy server is between the end-user and the server, that might get logged here instead of the actual accesser's address.

-- RFC 1413 identity of client; this is noted by Apache as unreliable, and is usually blank (represented by a hyphen (-) in the file).

-- Username of user accessing document; will be a hyphen (-) for public web sites that have no user access controls.

-- Timestamp string surrounded by square brackets, e.g. [12/Dec/2012:12:12:12 -0500]

-- HTTP request surrounded by double quotes, e.g., "GET /stuff.html HTTP/1.1"

-- HTTP status code: 200 for successful access, 404 for not-found, and other codes.

-- Number of bytes transferred in requested object

-- Referer: URL where user came from to get to your site, if sent by client to server (surrounded by double quotes)

-- User agent string sent by client (surrounded by double quotes). Can be used to identify what browser was used, but can be misleading.

local function parse_time(time)
  local year, month, day, hour, minute, second = time:match("(.+)/(.+)/(.+)%s+(.+):(.+):(.+)")
  local timetbl = {day=day,month=month,year=year,hour=hour,min=minute,sec=second}
  -- return timestamp and table with time components
  return os.time(timetbl), timetbl
end

local function convert_time(time)
  local timestamp = parse_time(time)
  return os.date("%d/%b/%Y:%H:%M:%S %z", timestamp)
end

local hashes = {}
local random = math.random
local function get_ip(hash)
  -- I want to create a semi random ip adress
  local ip = hashes[hash]
  if ip then return ip end
  ip = string.format("%s.%s.%s.%s", random(255), random(255), random(255), random(255))
  hashes[hash] = ip
  return ip
end

for line in io.lines() do
  local fields = {}
  for f in line:gmatch("([^\t]*)") do
    fields[#fields+1] = f
  end
  local host = get_ip(fields[1])
  -- date in log file: 2021/01/12 12:38:23 -> 12/Dec/2012:12:12:12 -0500
  local date = string.format("[%s]", convert_time(fields[2]))
  local url = string.format('"GET %s HTTP/1.1"',fields[3])
  local referer = string.format('"%s"',fields[4])
  local user_agent = string.format('"%s"', fields[5]:gsub('"', '')) -- don't allow quotes here
  local bytes = "1111" -- size in bytes. this is just dummy value
  print(table.concat({host, "-", "-", date, url, "200", bytes, referer, user_agent}, " "))
end
