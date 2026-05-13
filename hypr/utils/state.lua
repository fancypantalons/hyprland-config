-- Lightweight key-value state persistence.
-- Values are stored as plain text files under $XDG_RUNTIME_DIR/hypr-state/.
-- Replaces four ad-hoc state files: hyprsunset_state, kb_layout,
-- touchpad.status, dropdown_terminal_addr.

local state   = {}
local helpers = require("utils.helpers")

local STATE_DIR = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hypr-state"

local function path(key)
    return STATE_DIR .. "/" .. key
end

local function ensure_dir()
    helpers.mkdir_p(STATE_DIR)
end

---Read a state value.
-- @param key     string State key (used as filename)
-- @param default any    Returned when the key doesn't exist
-- @return string|any
function state.get(key, default)
    ensure_dir()
    local data = helpers.read_file(path(key))
    if not data then return default end
    local v = helpers.trim(data)
    return v ~= "" and v or default
end

---Write a state value.
-- @param key   string State key
-- @param value any    Coerced to string before writing
function state.set(key, value)
    ensure_dir()
    helpers.write_file(path(key), tostring(value))
end

---Delete a state key (silently ignores missing keys).
-- @param key string
function state.delete(key)
    os.remove(path(key))
end

return state
