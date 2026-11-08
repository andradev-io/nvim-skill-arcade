-- Optional model access: Anthropic API or any OpenAI-compatible /chat/completions endpoint (Ollama, LM Studio, ...).
local config = require("skill_arcade.config")

local M = {}

local function run_curl(args, body, cb, parse)
  if vim.fn.executable("curl") ~= 1 then
    return cb(nil, "curl not found")
  end
  vim.system(args, { stdin = body, text = true }, vim.schedule_wrap(function(res)
    if res.code ~= 0 then
      return cb(nil, "curl failed: " .. (res.stderr or res.code))
    end
    local ok, data = pcall(vim.json.decode, res.stdout)
    if not ok or type(data) ~= "table" then
      return cb(nil, "bad API response")
    end
    if data.error then
      local e = data.error
      return cb(nil, "API error: " .. (type(e) == "table" and e.message or tostring(e)))
    end
    parse(data)
  end))
end

--- cb(text|nil, err|nil)
function M.request(prompt, cb)
  local kind = config.options.provider
  if kind == "anthropic" then
    local o = config.options.anthropic
    local key = os.getenv(o.api_key_env)
    if not key or key == "" then
      return cb(nil, o.api_key_env .. " not set")
    end
    local body = vim.json.encode({
      model = o.model, max_tokens = o.max_tokens, messages = { { role = "user", content = prompt } },
    })
    return run_curl({
      "curl", "-sS", "--max-time", tostring(o.timeout), "https://api.anthropic.com/v1/messages",
      "-H", "content-type: application/json", "-H", "anthropic-version: 2023-06-01",
      "-H", "x-api-key: " .. key, "--data-binary", "@-",
    }, body, cb, function(data)
      local parts = {}
      for _, block in ipairs(data.content or {}) do
        if block.type == "text" then
          parts[#parts + 1] = block.text
        end
      end
      if data.stop_reason == "max_tokens" then
        return cb(nil, "reply truncated: raise anthropic.max_tokens")
      end
      cb(table.concat(parts))
    end)
  elseif kind == "openai" then
    local o = config.options.openai
    if not o.model or o.model == "" then
      return cb(nil, "openai.model not set")
    end
    local args = {
      "curl", "-sS", "--max-time", tostring(o.timeout), (o.base_url:gsub("/+$", "")) .. "/chat/completions",
      "-H", "content-type: application/json",
    }
    if o.api_key_env then
      local key = os.getenv(o.api_key_env)
      if not key or key == "" then
        return cb(nil, o.api_key_env .. " not set")
      end
      vim.list_extend(args, { "-H", "authorization: Bearer " .. key })
    end
    vim.list_extend(args, { "--data-binary", "@-" })
    local body = vim.json.encode({
      model = o.model, max_tokens = o.max_tokens, messages = { { role = "user", content = prompt } },
    })
    return run_curl(args, body, cb, function(data)
      local msg = data.choices and data.choices[1] and data.choices[1].message
      if not msg or type(msg.content) ~= "string" then
        return cb(nil, "API returned no content")
      end
      if data.choices[1].finish_reason == "length" then
        return cb(nil, "reply truncated: raise openai.max_tokens / the server context size")
      end
      cb(msg.content)
    end)
  end
  cb(nil, 'provider is "none" - set provider = "anthropic" or "openai" in setup()')
end

return M
