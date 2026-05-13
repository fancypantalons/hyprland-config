-- Process management primitives.
-- Replaces duplicated pkill/pgrep/killall/command-v patterns across the codebase.

local proc    = {}
local helpers = require("utils.helpers")

---Kill processes matching an exact name (pkill -x).
-- Fire-and-forget; never errors.
-- @param name string Process name
function proc.kill(name)
    hl.exec_cmd("pkill -x " .. helpers.shquote(name) .. " 2>/dev/null || true")
end

---Kill all processes matching a substring / pattern (pkill -f).
-- @param pattern string Pattern passed to pkill -f
function proc.kill_pat(pattern)
    hl.exec_cmd("pkill -f " .. helpers.shquote(pattern) .. " 2>/dev/null || true")
end

---Return true if at least one process with this exact name is running.
-- @param name string Process name
-- @return boolean
function proc.running(name)
    local r = helpers.exec("pgrep -x " .. helpers.shquote(name) .. " >/dev/null 2>&1 && echo y")
    return r.success and helpers.trim(r.stdout) == "y"
end

---Send a signal to all processes with this name (killall -SIG).
-- @param name string Process name
-- @param sig  string Signal name or number, e.g. "SIGUSR1", "9"
function proc.signal(name, sig)
    hl.exec_cmd("killall -" .. sig .. " " .. helpers.shquote(name) .. " 2>/dev/null || true")
end

---Return true if a command is available on PATH.
-- @param cmd string Command name (no arguments)
-- @return boolean
function proc.have(cmd)
    local r = helpers.exec("command -v " .. helpers.shquote(cmd) .. " >/dev/null 2>&1 && echo y")
    return r.success and helpers.trim(r.stdout) == "y"
end

return proc
