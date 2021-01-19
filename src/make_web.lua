local h5tk = require "h5tk"

local records =  {}
local stats = {}

local unique_users = {}
local unique_visits = {}
local unique_visit_time = 2 * 60 * 60 -- unique visit is two hours after last visit

-- ignore my workstation
local ignored_ips = {
  a16d7cc7ae347f3a0306a20e6e0aa306=true,
  d82a89ef48b8c5935c6817d76b09ad43=true,
  ["0ce2a6aa13d1938a0e05d7a825accdd0"]=true
}

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
  -- ignore webmaster IP
  if ignored_ips[record.hash] then 
    return true 
  end
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

-- update counter for the current field
local function update_counter(tbl, field)
  local current = tbl[field] or 0
  current = current + 1
  tbl[field] = current
end

-- sort table with counters
local function sort_counter_table(tbl)
  local newtable = {}
  for k,v in pairs(tbl) do
    newtable[#newtable+1] = {name = k, count = v}
  end
  -- sort downwards
  table.sort(newtable, function(a,b) return a.count > b.count end)
  return newtable
end

-- normalize referers
local function clean_referer(referer)
  local referer = referer or ""
  -- cleanup referer
  referer = referer:gsub("^https?://", "")
  referer = referer:gsub("index.html$", ""):gsub("/$", "")
  if referer == "" then referer = "---" end
  return referer
end

-- add  web page host name to referrers in session
local function on_page_referer(referer)
  return clean_referer("knihovna.pedf.cuni.cz" .. referer)
end

local function count_referers(unique_visits)
  local referers = {}
  for _, x in ipairs(unique_visits) do
    local referer = clean_referer(x.record.referer)
    update_counter(referers, referer)
  end
  return sort_counter_table(referers)
end

local function get_visit_pages(unique_users, visit)
  print("++++++++++++++++++")
  local start = visit.record_no
  local id = visit.user_id
  local user = unique_users[id]
  local first = user[start]
  local referer = clean_referer(first.referer)
  print(first.time, first.agent)
  print(first.page, referer)
  -- process session only if it exists
  if #user > start then
    referer = on_page_referer(first.page)
    for i = start+1, #user do
      local current = user[i]
      -- stop on next visit
      if current.new_visit then break end
      if clean_referer(current.referer) == referer then
        print(">> " .. current.page)
      else
        print(current.page, current.referer, referer)
      end
      referer = on_page_referer(current.page)
    end
  end

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
print("Total visits", #records)

print "-----------"
print("# Referers")
for k,v in ipairs(count_referers(unique_visits)) do
  print(v.name, v.count)
end


print ""
print "-----------"
print "Visited pages in unique visits"

-- 
for _, visit in ipairs(unique_visits) do
  local pages = get_visit_pages(unique_users, visit)
end


