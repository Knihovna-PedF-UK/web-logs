local h5tk = require "h5tk"

local records =  {}
local stats = {}

local unique_users = {}
local unique_visits = {}
local unique_visit_time = 2 * 60 * 60 -- unique visit is two hours after last visit

-- pase date string to timestamp
local function parse_time(time)
  local year, month, day, hour, minute, second = time:match("(.+)/(.+)/(.+)%s+(.+):(.+):(.+)")
  local timetbl = {day=day,month=month,year=year,hour=hour,min=minute,sec=second}
  -- return timestamp and table with time components
  return os.time(timetbl), timetbl
end

local function parse_line(line)
  local iphash, time, page, referer, agent, viewport, bot = line:match("(.*)\t(.*)\t(.*)\t(.*)\t(.*)\t(.*)\t(.*)")
  local timestamp, timetbl = parse_time(time)
  return {
    hash = iphash,
    time = time, timestamp = timestamp, timetbl=timetbl,
    page = page, referer = referer, agent = agent,
    viewport = viewport, bot = bot
  }
end

local function record_new_visit(user_id, record_no, record)
  table.insert(unique_visits, {
    user_id = user_id,
    record_no = record_no,
    record = record,
    timestamp = record.timestamp,
    timetbl = record.timetbl
  })
end

local function get_user_identifier(record)
  local hash, agent = record.hash, record.agent
  if not hash or not agent then return nil, "Incorrect record" end
  return hash .. agent
end

local function is_unique_visit(current_user, record)
  -- identify if this visit is a new sessio
  local last_visit = current_user[#current_user] or {}
  local last_timestamp = last_visit.timestamp or 0
  return record.timestamp - last_timestamp > unique_visit_time 
end



local function add_record(unique_users, record, line)
  local identifier, msg = get_user_identifier(record)
  if not identifier then return nil, msg end
  local current_user = unique_users[identifier] or {}
  local record_no = #current_user + 1
  if is_unique_visit(current_user, record) then
    record.new_visit = true
    record_new_visit(identifier, record_no, record)
  end
  current_user[record_no] =  record
  unique_users[identifier] = current_user
  return true
end



-- parse log file
for line in io.lines() do
  local record = parse_line(line)
  records[#records+1] = record
  local status, msg = add_record(unique_users, record, line)
  if not status then
    print(msg)
    print(line)
  end
end

print("Unique visits", #unique_visits)

for _, x in ipairs(unique_visits) do
  print(x.record.referer)
end



