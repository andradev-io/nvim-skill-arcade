-- Optional sign-in, so a player can send results to the leaderboard. Nothing here runs unless you call :ArcadeLogin.
--
-- Sign-in is the OAuth device flow: the game shows a short code, you approve it in any browser (GitHub through the
-- site's login server), and the game keeps a token. The leaderboard only ever knows you by a derived player code.
-- Tokens live in <data_dir>/account.json (mode 0600) and are sent only to the score API. Requests go through curl,
-- with the headers on stdin, so a token never shows up in a process list.
local config = require("skill_arcade.config")

local M = {}

local function file()
  return config.options.data_dir .. "/account.json"
end

local function opts()
  return config.options.account or {}
end

-- ── storage ─────────────────────────────────────────────────────────────────
local function load()
  local f = io.open(file(), "r")
  if not f then
    return {}
  end
  local text = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, text)
  return ok and type(data) == "table" and data or {}
end

local function save(data)
  vim.fn.mkdir(config.options.data_dir, "p")
  local fd = vim.uv.fs_open(file(), "w", 384) -- 0600: only you can read the token
  if not fd then
    return false
  end
  vim.uv.fs_write(fd, vim.json.encode(data))
  vim.uv.fs_close(fd)
  return true
end

function M.logged_in()
  local d = load()
  return type(d.refresh) == "string" and d.refresh ~= ""
end

--- true when finished rounds are sent to the leaderboard (signed in and chosen)
function M.auto()
  return M.logged_in() and load().auto == true
end

function M.set_auto(on)
  local d = load()
  if d.refresh then
    d.auto = on and true or false
    save(d)
  end
end

function M.code()
  return load().code
end

-- ── http (curl, config on stdin) ────────────────────────────────────────────
local function quote(s)
  return '"' .. (tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")) .. '"'
end

local function urlencode(s)
  return (tostring(s):gsub("[^%w%-%._~]", function(c)
    return string.format("%%%02X", c:byte())
  end))
end

--- the curl config for a request (exposed for tests); the body of a form is url-encoded here
function M._curl_config(req)
  local lines = {
    "silent", "show-error", "max-time = 20", "max-filesize = 1000000",
    "url = " .. quote(req.url),
    "request = " .. quote(req.method or "GET"),
    "write-out = " .. quote("\n%{http_code}"),
  }
  for k, v in pairs(req.headers or {}) do
    lines[#lines + 1] = "header = " .. quote(k .. ": " .. v)
  end
  if req.form then
    local parts = {}
    for _, kv in ipairs(req.form) do
      parts[#parts + 1] = urlencode(kv[1]) .. "=" .. urlencode(kv[2])
    end
    lines[#lines + 1] = "data = " .. quote(table.concat(parts, "&"))
    lines[#lines + 1] = "header = " .. quote("Content-Type: application/x-www-form-urlencoded")
  elseif req.json then
    lines[#lines + 1] = "data = " .. quote(vim.json.encode(req.json))
    lines[#lines + 1] = "header = " .. quote("Content-Type: application/json")
  end
  return table.concat(lines, "\n")
end

--- cb({ status = n, json = table|nil, text = string } | nil, err)
function M._http(req, cb)
  if vim.fn.executable("curl") ~= 1 then
    return cb(nil, "curl not found")
  end
  vim.system({ "curl", "-K", "-" }, { text = true, stdin = M._curl_config(req) }, vim.schedule_wrap(function(res)
    if res.code ~= 0 then
      return cb(nil, "could not reach the server: " .. vim.trim(res.stderr or tostring(res.code)))
    end
    local out = res.stdout or ""
    local body, status = out:match("^(.*)\n(%d+)$")
    if not status then
      return cb(nil, "unexpected answer from the server")
    end
    local ok, json = pcall(vim.json.decode, body)
    cb({ status = tonumber(status), json = ok and type(json) == "table" and json or nil, text = body })
  end))
end

-- ── sign in (device flow) ───────────────────────────────────────────────────
local function https(url)
  return type(url) == "string" and url:match("^https://[%w%.%-:]+[/%w%-%._~%%%?&=]*$") ~= nil
end

local function notify(msg, level)
  vim.notify("SkillArcade: " .. msg, level or vim.log.levels.INFO)
end

local function oidc(issuer, name)
  return issuer:gsub("/+$", "") .. "/protocol/openid-connect/" .. name
end

local pending = 0 -- a new sign-in cancels the one still waiting

--- ask what to do with finished rounds once signed in (a vim.ui.select, so any picker UI works)
local function choose_auto(done)
  vim.ui.select({ "Send my finished rounds automatically", "Do not send anything for now" }, {
    prompt = "Leaderboard",
  }, function(choice)
    M.set_auto(choice ~= nil and choice:find("^Send") ~= nil)
    done()
  end)
end

local function finish_login(d, cb)
  d.auto = false
  save(d)
  M._http({ method = "GET", url = opts().api .. "/api/me", headers = { Authorization = "Bearer " .. d.access } }, function(res)
    if res and res.status == 200 and res.json and type(res.json.userCode) == "string" then
      d.code = res.json.userCode
      save(d)
      notify("signed in. Your player code is " .. d.code .. " (the only name the leaderboard shows).")
    else
      notify("signed in.")
    end
    choose_auto(function()
      cb(true)
    end)
  end)
end

--- cb(ok, err)
function M.login(cb)
  cb = cb or function() end
  local o = opts()
  if o.enabled == false then
    return cb(false, "account is disabled (account.enabled = false)")
  end
  if not https(o.api) then
    return cb(false, "account.api must be an https address")
  end
  pending = pending + 1
  local mine = pending
  M._http({ method = "GET", url = o.api .. "/api/config" }, function(cfg, err)
    if not cfg or cfg.status ~= 200 or not cfg.json or not https(cfg.json.issuer) then
      return cb(false, err or "the score service did not say where to sign in")
    end
    local issuer, client = cfg.json.issuer, tostring(cfg.json.deviceClient or "arcade-plugin")
    M._http({ method = "POST", url = oidc(issuer, "auth/device"), form = { { "client_id", client }, { "scope", "openid" } } }, function(dev, derr)
      if not dev or dev.status ~= 200 or not dev.json or not dev.json.device_code then
        return cb(false, derr or "the login server refused (is the device flow enabled for this client?)")
      end
      local j = dev.json
      local uri = j.verification_uri_complete or j.verification_uri
      if not https(uri) then
        return cb(false, "the login server sent an address that is not https")
      end
      pcall(vim.fn.setreg, "+", tostring(j.user_code))
      local host = uri:match("^https://([^/]+)")
      notify(string.format("to sign in, open %s and approve code %s (copied to your clipboard).", uri, tostring(j.user_code)))
      if o.open_browser ~= false then
        pcall(vim.ui.open, uri)
      end
      local interval = math.max(M._min_interval or 2, tonumber(j.interval) or 5)
      local deadline = os.time() + (tonumber(j.expires_in) or 600)
      local function poll()
        if mine ~= pending then
          return -- replaced by a newer sign-in
        end
        if os.time() > deadline then
          return cb(false, "the code expired, run :ArcadeLogin again")
        end
        M._http({
          method = "POST", url = oidc(issuer, "token"),
          form = {
            { "grant_type", "urn:ietf:params:oauth:grant-type:device_code" },
            { "device_code", j.device_code }, { "client_id", client },
          },
        }, function(tok, terr)
          if not tok then
            return cb(false, terr)
          end
          local t = tok.json or {}
          if tok.status == 200 and t.access_token and t.refresh_token then
            local now = os.time()
            return finish_login({
              issuer = issuer, client = client, access = t.access_token, refresh = t.refresh_token,
              expires_at = now + (tonumber(t.expires_in) or 60), host = host,
            }, cb)
          end
          if t.error == "authorization_pending" then
            return vim.defer_fn(poll, interval * 1000)
          elseif t.error == "slow_down" then
            interval = interval + 5
            return vim.defer_fn(poll, interval * 1000)
          elseif t.error == "access_denied" then
            return cb(false, "sign-in was denied")
          elseif t.error == "expired_token" then
            return cb(false, "the code expired, run :ArcadeLogin again")
          end
          cb(false, "sign-in failed" .. (t.error and (": " .. t.error) or ""))
        end)
      end
      vim.defer_fn(poll, interval * 1000)
    end)
  end)
end

-- ── tokens ──────────────────────────────────────────────────────────────────
--- cb(access_token|nil, err); refreshes when it is about to expire, forgets the account when the session is gone
function M.access_token(cb)
  local d = load()
  if not d.refresh or not d.issuer then
    return cb(nil, "not signed in (run :ArcadeLogin)")
  end
  if d.access and (d.expires_at or 0) - 30 > os.time() then
    return cb(d.access)
  end
  M._http({
    method = "POST", url = oidc(d.issuer, "token"),
    form = { { "grant_type", "refresh_token" }, { "refresh_token", d.refresh }, { "client_id", d.client or "arcade-plugin" } },
  }, function(res, err)
    if not res then
      return cb(nil, err)
    end
    local t = res.json or {}
    if res.status == 200 and t.access_token then
      d.access = t.access_token
      d.refresh = t.refresh_token or d.refresh
      d.expires_at = os.time() + (tonumber(t.expires_in) or 60)
      save(d)
      return cb(d.access)
    end
    if t.error == "invalid_grant" then
      os.remove(file())
      return cb(nil, "your session ended, run :ArcadeLogin again")
    end
    cb(nil, "could not renew the session")
  end)
end

function M.logout()
  local d = load()
  if d.refresh and d.issuer then
    -- best effort: end the session on the server too
    M._http({ method = "POST", url = oidc(d.issuer, "logout"), form = { { "client_id", d.client or "arcade-plugin" }, { "refresh_token", d.refresh } } }, function() end)
  end
  os.remove(file())
end

-- ── scores ──────────────────────────────────────────────────────────────────
--- a game challenge id as the score API wants it (lowercase, digits and dashes, at most 64), or nil
function M.api_id(id)
  id = tostring(id or ""):lower():gsub("^community%.", ""):gsub("[^a-z0-9]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
  id = id:sub(1, 64):gsub("%-+$", "")
  return id ~= "" and id or nil
end

--- cb(kept|nil, err)
function M.submit(id, nkeys, seconds, cb)
  cb = cb or function() end
  local aid = M.api_id(id)
  if not aid then
    return cb(nil, "this challenge cannot be ranked")
  end
  local body = {
    challenge = aid,
    keys = math.min(5000, math.max(1, math.floor(nkeys or 1))),
    ms = math.min(3600000, math.max(200, math.floor((seconds or 0) * 1000))),
  }
  M.access_token(function(token, err)
    if not token then
      return cb(nil, err)
    end
    M._http({ method = "POST", url = opts().api .. "/api/score", headers = { Authorization = "Bearer " .. token }, json = body }, function(res, herr)
      if not res then
        return cb(nil, herr)
      end
      if res.status ~= 200 then
        return cb(nil, "the score service answered " .. res.status)
      end
      cb(res.json and res.json.kept == true, nil, res.json and res.json.best)
    end)
  end)
end

local warned = false

--- called by the game after a cleared round: sends it when you chose to. Never blocks, never throws.
function M.maybe_submit(ch, nkeys, seconds)
  if not M.auto() then
    return
  end
  M.submit(ch.id, nkeys, seconds, function(kept, err, best)
    if err then
      if not warned then -- one warning per session, so a bad connection does not nag every round
        warned = true
        notify("could not send the score: " .. err, vim.log.levels.WARN)
      end
    elseif kept then
      notify(string.format("leaderboard: new best for %s (%s keys)", ch.title or ch.id, best and best.keys or nkeys))
    end
  end)
end

--- status line for :ArcadeAccount
function M.status(cb)
  if not M.logged_in() then
    return cb("Not signed in. :ArcadeLogin lets you send scores to the leaderboard (optional).")
  end
  local d = load()
  cb(string.format("Signed in as player %s. Sending rounds automatically: %s. (:ArcadeAccount on|off, :ArcadeLogout)",
    d.code or "(code unknown)", d.auto and "yes" or "no"))
end

return M
