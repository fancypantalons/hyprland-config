---
-- Utility Helper Functions
-- Provides common utility functions used across user-functions
--
-- @module utils.helpers
-- @author Brett
-- @license MIT

local helpers = {}

---Pause execution for a specified number of seconds
-- Uses os.execute to spawn a sleep command
-- Note: This blocks the current Lua execution context
--
-- @param seconds number The number of seconds to sleep (can be fractional, e.g., 0.5)
-- @function sleep
function helpers.sleep(seconds)
    -- Ensure seconds is a valid number
    local s = tonumber(seconds) or 1

    -- Use os.execute for the sleep (standard Lua approach)
    -- Supports fractional seconds (e.g., 0.1, 0.5)
    os.execute("sleep " .. s)
end

---Read the entire contents of a file.
-- Synchronous, no shell. Returns nil if the file doesn't exist or is unreadable.
--
-- @param path string Absolute path to the file
-- @return string|nil contents (or nil on error)
-- @return string|nil error message (or nil on success)
function helpers.read_file(path)
    local f, err = io.open(path, "r")
    if not f then
        return nil, err
    end
    local data = f:read("*a")
    f:close()
    return data
end

---Write contents to a file, replacing any existing content.
-- Synchronous, no shell, atomic from this process's view.
--
-- @param path string Absolute path to the file
-- @param contents string The content to write
-- @return boolean success
-- @return string|nil error message (or nil on success)
function helpers.write_file(path, contents)
    local f, err = io.open(path, "w")
    if not f then
        return false, err
    end
    f:write(contents or "")
    f:close()
    return true
end

---Check whether a path exists (file or directory).
-- @param path string
-- @return boolean
function helpers.path_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

---Run a shell command and capture its output synchronously.
-- hl.exec_cmd is fire-and-forget (async, returns nothing useful), so we use
-- io.popen here for any caller that needs stdout or an exit-status check.
--
-- @param cmd string Shell command to run (executed via /bin/sh -c through io.popen)
-- @return table { success = boolean, stdout = string, stderr = string }
--   stderr is always "" — io.popen doesn't separate streams. Callers that need
--   stderr should redirect inside `cmd` (e.g. "foo 2>&1").
function helpers.exec(cmd)
    local result = { success = false, stdout = "", stderr = "" }
    local p = io.popen(cmd, "r")

    if not p then
        return result
    end

    result.stdout = p:read("*a") or ""

    -- Lua 5.2+: close() returns ok, reason, code. Treat exit 0 (or true) as success.
    local ok, _, code = p:close()
    result.success = (ok == true) or (code == 0)

    return result
end

return helpers
