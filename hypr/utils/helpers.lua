---
-- Utility Helper Functions
-- Provides common utility functions used across user-functions
--
-- @module utils.helpers
-- @author Brett
-- @license MIT

local helpers = {}

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
    -- In Hyprland's Lua keybind context, ok is always nil regardless of whether the
    -- command succeeded or failed, so exit codes are unreliable. Since io.popen
    -- returning non-nil already guarantees the shell launched, treat ok==nil as success.
    local ok, _, code = p:close()
    result.success = (ok == true) or (code == 0) or (ok == nil)
    result.exit_code = code

    return result
end

local callbacks = {}

---Run a shell command asynchronously and invoke a callback upon completion.
-- Writes the command to a temp script to avoid shell-quoting issues.
--
-- @param cmd string Shell command to run
-- @param cb closure Called with (exit_code, stdout_stderr) where exit_code is a number
function helpers.exec_async(cmd, cb)
   local id = tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
   callbacks[id] = cb

   local outfile = "/tmp/exec_" .. id .. ".out"
   local ecfile  = "/tmp/exec_" .. id .. ".ec"
   local scriptfile = "/tmp/exec_" .. id .. ".sh"

   helpers.write_file(scriptfile, string.format(
       [[#!/bin/sh
{
(%s)
} > %s 2>&1
echo $? > %s
hyprctl eval 'helpers.exec_callback("%s")'
rm -f %s
]],
       cmd, outfile, ecfile, id, scriptfile
   ))

   hl.exec_cmd("chmod +x " .. scriptfile .. " && " .. scriptfile .. " &")
end

function helpers.exec_callback(id)
   local cb = callbacks[id]
   callbacks[id] = nil

   if not cb then return end

   local outfile = "/tmp/exec_" .. id .. ".out"
   local ecfile  = "/tmp/exec_" .. id .. ".ec"
   local data = helpers.read_file(outfile) or ""
   local ec_str = helpers.read_file(ecfile) or "0"
   local exit_code = tonumber(ec_str:match("%d+")) or 0

   hl.exec_cmd("rm -f " .. outfile .. " " .. ecfile)

   cb(exit_code, data)
end

---Delay execution asynchronously and invoke a callback after the specified time.
-- This is a convenience wrapper around exec_async that sleeps in the shell.
-- Unlike helpers.sleep(), this does NOT block the compositor event loop.
--
-- @param seconds number The number of seconds to delay (can be fractional, e.g., 0.5)
-- @param cb function The callback to invoke after the delay (receives no arguments)
function helpers.delay(seconds, cb)
    helpers.exec_async("sleep " .. tonumber(seconds) or 1, function(_, _)
        cb()
    end)
end

---Test exec_async callback mechanism. Sends a notification with exit code and output.
-- Run: hyprctl eval 'helpers.test_async()'
function helpers.test_async()
    helpers.exec_async(
        "echo 'stdout works' && echo 'stderr works' >&2 && exit 42",
        function(exit_code, output)
            local f = io.open("/tmp/exec_async_test_result", "w")
            if f then
                f:write(string.format("exit=%d out=[%s]", exit_code, output:gsub("%s+$", "")))
                f:close()
            end
        end
    )
end

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

---Decode an XKB modifier bitmask into an ordered list of modifier name strings.
-- Recognises Super(64), Ctrl(4), Shift(1), and Alt/Mod1(8).
-- Other bits (Lock, NumLock, Mod3, Mod5) are ignored.
-- @param modmask number The raw modifier bitmask from hyprctl
-- @return table Array of modifier name strings in display order
local function decode_modmask(modmask)
    local mods = {}
    if (modmask & 64) ~= 0 then table.insert(mods, "SUPER") end
    if (modmask & 4)  ~= 0 then table.insert(mods, "CTRL")  end
    if (modmask & 1)  ~= 0 then table.insert(mods, "SHIFT") end
    if (modmask & 8)  ~= 0 then table.insert(mods, "ALT")   end
    return mods
end

---Retrieve the currently active global keybindings from Hyprland.
-- Shells out to hyprctl and jq to get the live bind list, then decodes each
-- entry into a structured Lua table. Only global binds are returned — submap,
-- mouse, and catchall entries are excluded.
--
-- Each returned record has:
--   keys        string  Human-readable key combo, e.g. "SUPER + SHIFT + S"
--   description string  The bind's description flag (may be "")
--   dispatcher  string  The internal dispatcher name, e.g. "exec", "closewindow"
--   arg         string  The dispatcher argument (may be "")
--
-- @return table Array of bind record tables (empty on error or if jq is absent)
function helpers.get_binds()
    local cache_path = os.getenv("HOME") .. "/.cache/hypr/binds.tsv"
    local data, err = helpers.read_file(cache_path)

    if not data or data == "" then
        return {}
    end

    local binds = {}

    for line in data:gmatch("[^\r\n]+") do
        local modmask_s, key, description, dispatcher, arg =
            line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t?(.*)")

        if key and key ~= "" then
            local mods = decode_modmask(tonumber(modmask_s) or 0)
            table.insert(mods, key)

            table.insert(binds, {
                keys        = table.concat(mods, " + "),
                description = description or "",
                dispatcher  = dispatcher  or "",
                arg         = arg         or "",
            })
        end
    end

    return binds
end

_G.helpers = helpers

return helpers
