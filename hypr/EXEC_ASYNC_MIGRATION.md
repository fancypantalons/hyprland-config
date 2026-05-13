# exec_async Migration Guide

This document tracks all known `helpers.exec` / `hl.exec_cmd` misuse in the Hyprland Lua
config and describes the required fixes.  It is intended as a work order for an agent
performing the migration.

---

## Background: the three execution primitives

### `helpers.exec(cmd)` — synchronous via `io.popen`

Runs the command in the calling Lua context, blocks until it exits, and returns
`{ success, stdout, stderr, exit_code }`.  Because Hyprland runs its Lua interpreter
**inside the compositor's main event loop**, anything that calls back into the compositor
(via Wayland protocols or the `hyprctl` IPC socket) while `helpers.exec` is blocking will
deadlock: the compositor is stuck waiting for Lua, while the command is stuck waiting for
the compositor to respond.

**Use only for** fast, side-effect-free commands that do not need compositor IPC and
return in well under ~100 ms: `pgrep`, `test -f`, `find` (small trees), `grep` on local
files, `readlink`, `qalc -t`, `pamixer --get-*`, `brightnessctl -m`, etc.

### `hl.exec_cmd(cmd)` — asynchronous fire-and-forget

Queues the command and returns immediately.  No output is available to the caller.  Safe
for compositor-interacting commands, but useless when you need the result.

**Use for** one-shot side-effecting commands whose success or output you don't care about.

### `helpers.exec_async(cmd, cb)` — asynchronous with callback

```lua
-- helpers.lua (the implementation)
function helpers.exec_async(cmd, cb)
    local id = tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
    callbacks[id] = cb

    local outfile = "/tmp/exec_" .. id .. ".out"
    hl.exec_cmd(string.format(
        "%s > %s 2>&1; hyprctl eval 'helpers.exec_callback(\"%s\", $?, \"%s\")'",
        cmd, outfile, id, outfile
    ))
end

-- Called by hyprctl eval when the command finishes:
function helpers.exec_callback(id, exit_code, outfile)
    local cb = callbacks[id]
    callbacks[id] = nil
    if not cb then return end
    local data = helpers.read_file(outfile) or ""
    hl.exec_cmd("rm -f " .. outfile)
    cb(exit_code, data)
end
```

The shell command is run asynchronously via `exec_cmd`.  On completion the shell calls
`hyprctl eval`, which re-enters the Lua interpreter on the next event-loop tick with the
exit code and captured stdout+stderr.

**Use for** any command that:
- takes a long time (rofi menus, notify-send with action buttons, yad dialogs),
- interacts with the compositor or its Wayland clients (`hyprctl`, `grim`, `wl-copy`,
  `hyprsunset`, `hypridle`), or
- whose result is needed before subsequent code can run (replacing `exec_cmd` +
  immediate `helpers.exec("test -f ...")` race patterns).

---

## Issue categories

### Category 1 — Deadlocks

The command communicates with the compositor via Wayland IPC.  Using `helpers.exec` here
will hang the compositor indefinitely.

### Category 2 — Race conditions

`hl.exec_cmd` fires an async command and the very next line checks for its output or a
file it produces, before the command can possibly have finished.

### Category 3 — Compositor freeze (long synchronous blocks)

`helpers.exec` is used to drive interactive programs (rofi, yad, notify-send -A), or
`helpers.sleep` is called to pace a sequence of async commands.  Either way, the
compositor event loop is blocked for the entire duration — no window events, animations,
or input is processed.

---

## File-by-file issues

---

### `hypr/user-functions/input.lua`

#### Issue I-1 — `get_keyboard_names` (Category 1: deadlock)

```lua
-- BROKEN
local function get_keyboard_names()
    local result = helpers.exec("hyprctl devices -j 2>/dev/null | jq -r '.keyboards[].name' 2>/dev/null || echo ''")
    ...
end
```

`hyprctl devices` opens the compositor IPC socket.  The compositor is blocked running
this Lua callback → deadlock.

**Fix:** Replace with `helpers.exec_async`.  The entire `switch_layout` function must be
restructured so that after fetching the keyboard list, the layout-switching loop and
notification happen inside the callback.

```lua
local function get_keyboard_names(cb)
    helpers.exec_async(
        "hyprctl devices -j 2>/dev/null | jq -r '.keyboards[].name' 2>/dev/null || echo ''",
        function(_, stdout)
            local keyboards = {}
            for line in stdout:gmatch("[^\r\n]+") do
                local name = line:gsub("%s+$", "")
                if name ~= "" and not is_ignored(name) then
                    table.insert(keyboards, name)
                end
            end
            cb(keyboards)
        end
    )
end
```

#### Issue I-2 — `hyprctl switchxkblayout` (Category 1: deadlock)

```lua
-- BROKEN (inside switch_layout loop)
local switch_result = helpers.exec(string.format(
    "hyprctl switchxkblayout '%s' %d", keyboard_name, next_index - 1))
```

Same IPC deadlock.  After `get_keyboard_names` is made async (above), each
`switchxkblayout` call can use `hl.exec_cmd` (fire-and-forget is fine; we don't need the
exit code per-keyboard).  If error detection is still desired, use `exec_async` for each
call and count failures in the callbacks.

---

### `hypr/user-functions/display.lua`

#### Issue D-1 — `hyprsunset -i` (Category 1: deadlock + Category 3: freeze)

```lua
-- BROKEN
local result = helpers.exec("hyprsunset -i")
helpers.sleep(0.3)
stop_hyprsunset()
```

`hyprsunset` uses the `wlr-gamma-control-unstable-v1` Wayland protocol to apply color
transforms.  Running it synchronously deadlocks.

**Fix:** Use `exec_async` for `hyprsunset -i`.  Chain `stop_hyprsunset` (which is already
an async `pkill`) inside the callback.  Remove `helpers.sleep(0.3)` — the callback fires
after `hyprsunset -i` exits so the sequencing is already correct.

```lua
-- in nightlight_toggle, "turning off" branch:
helpers.exec_async("hyprsunset -i", function(_, _)
    hl.exec_cmd("pkill -x hyprsunset 2>/dev/null || true")
    write_state("off")
    notify_nightlight(false)
end)
```

#### Issue D-2 — `helpers.sleep(0.2)` in `stop_hyprsunset` (Category 3: freeze)

```lua
local function stop_hyprsunset()
    hl.exec_cmd("pkill -x hyprsunset 2>/dev/null || true")
    helpers.sleep(0.2)   -- blocks compositor
end
```

The sleep is meant to give the process time to die before the caller continues.  With the
exec_async restructuring above, `stop_hyprsunset` is called from inside the callback
(after `hyprsunset -i` has already returned), so the pkill is sufficient.  Delete the
sleep and inline the `pkill` exec_cmd call.

---

### `hypr/user-functions/system.lua`

#### Issue S-1 — `wl-copy` inside `helpers.exec` (Category 1: deadlock)

```lua
-- BROKEN (clipboard_manager, exit_code == 0 branch)
local decode_cmd = string.format(
    "echo '%s' | cliphist decode | wl-copy",
    selection:gsub("'", "'\"'\"'"))
local decode_result = helpers.exec(decode_cmd)
```

`wl-copy` is a Wayland client — it connects to the compositor to set clipboard contents.
Running it inside `helpers.exec` deadlocks.

**Fix:** The entire `clipboard_manager` function must be async because rofi itself also
blocks (see S-2).  After rofi returns its selection via callback, the `cliphist decode |
wl-copy` step can use `hl.exec_cmd` (fire-and-forget; we don't need confirmation that the
clipboard was set).

#### Issue S-2 — `helpers.exec(rofi_cmd)` in `clipboard_manager` (Category 3: freeze)

```lua
-- BROKEN
local rofi_result = helpers.exec(rofi_cmd)
```

Rofi blocks until the user makes a selection.  The compositor is frozen for that entire
time.

**Fix:** Use `helpers.exec_async(rofi_cmd, cb)`.  All post-selection logic (decode,
wl-copy, delete, wipe) moves into the callback, keyed on `exit_code` and `stdout`.

#### Issue S-3 — `helpers.exec("hypridle")` (Category 1: deadlock)

```lua
-- BROKEN
local start_result = helpers.exec("hypridle")
```

`hypridle` is a daemon that uses the `ext-idle-notify-v1` Wayland protocol.  It never
exits normally.  Running it via `helpers.exec` will block the compositor forever.

**Fix:** Use `hl.exec_cmd("hypridle &")`.  Since we can't get an exit code from a daemon,
drop the `start_result.success` check.  Instead show the "enabled" notification
unconditionally (or use a short `exec_async("pgrep -x hypridle", ...)` check after a
brief delay to verify it started).

#### Issue S-4 — `helpers.sleep` in `start_portals` (Category 3: freeze)

```lua
hl.exec_cmd("killall xdg-desktop-portal-hyprland 2>/dev/null || true")
-- ... more kills ...
helpers.sleep(1)           -- blocks compositor
hl.exec_cmd("/usr/lib/xdg-desktop-portal-hyprland 2>/dev/null &")
hl.exec_cmd("/usr/libexec/xdg-desktop-portal-hyprland 2>/dev/null &")
helpers.sleep(2)           -- blocks compositor
hl.exec_cmd("/usr/lib/xdg-desktop-portal 2>/dev/null &")
```

**Fix:** Chain the two launch phases using `exec_async` on a no-op or the kill command
itself so the delays happen outside the compositor loop:

```lua
helpers.exec_async(
    "killall xdg-desktop-portal-hyprland 2>/dev/null; " ..
    "killall xdg-desktop-portal-wlr 2>/dev/null; " ..
    "killall xdg-desktop-portal-gnome 2>/dev/null; " ..
    "killall xdg-desktop-portal 2>/dev/null; " ..
    "sleep 1",
    function(_, _)
        hl.exec_cmd("/usr/lib/xdg-desktop-portal-hyprland 2>/dev/null &")
        hl.exec_cmd("/usr/libexec/xdg-desktop-portal-hyprland 2>/dev/null &")
        helpers.exec_async("sleep 2", function(_, _)
            hl.exec_cmd("/usr/lib/xdg-desktop-portal 2>/dev/null &")
            hl.exec_cmd("/usr/libexec/xdg-desktop-portal 2>/dev/null &")
        end)
    end
)
```

#### Issue S-5 — `helpers.sleep` in `animate_slide_down/up` (Category 3: freeze)

```lua
local function animate_slide_down(addr, target_x, target_y, width, height)
    ...
    move_window_to(addr, target_x, start_y)
    helpers.sleep(0.05)
    for i = 1, steps do
        move_window_to(addr, target_x, start_y + (step_y * i))
        helpers.sleep(0.03)
    end
    ...
end
```

Each iteration blocks the compositor (~30 ms × 5 = 150 ms + setup).

**Fix:** True per-frame animation is not straightforward without a timer API. The
pragmatic fix is to collapse the animation into a single `exec_async` that uses `sleep`
in the shell, or remove the animation entirely and just move the window to its final
position in one `hl.dispatch` call.  The simplest correct fix:

```lua
local function animate_slide_down(addr, target_x, target_y, width, height)
    move_window_to(addr, target_x, target_y)
end

local function animate_slide_up(addr, start_x, start_y, width, height)
    -- caller will move window to special workspace immediately after
end
```

---

### `hypr/user-functions/session.lua`

All four screenshot capture paths are broken.  The core problems are:

1. `grim` and `wl-copy` are Wayland clients — they must not be run via `helpers.exec`.
2. The area/swappy/window variants use `hl.exec_cmd` for capture but then race-check the
   output file immediately.
3. `notify-send -A …` (actionable notifications) blocks waiting for the user to click.
4. `helpers.sleep(2)` is used to paper over the race.

The fix for all screenshot variants is the same pattern: capture via `exec_async`, and
inside the callback check the file, play the sound, and send the notification (also via
`exec_async` if action buttons are needed).

#### Issue SS-1 — `screenshot_now` (Category 1 + 3)

```lua
-- BROKEN
local result = helpers.exec(string.format(
    "cd %s && grim - | tee %s | wl-copy", dir, filename))
helpers.sleep(2)
local check_result = helpers.exec("test -f " .. filepath)
```

**Fix:**

```lua
local function screenshot_now()
    local dir = ensure_screenshot_dir()
    local filename = generate_filename()
    local filepath = dir .. "/" .. filename

    helpers.exec_async(
        string.format("cd %s && grim - | tee %s | wl-copy", dir, filename),
        function(exit_code, _)
            if exit_code == 0 and helpers.path_exists(filepath) then
                play_screenshot_sound()
                notify_screenshot(filepath, "Screenshot Saved")
            else
                notify_screenshot_error("Screenshot NOT Saved")
            end
        end
    )
end
```

#### Issue SS-2 — `screenshot_timer` (Category 1 + 3)

```lua
-- BROKEN
show_countdown(seconds)   -- helpers.sleep loop
helpers.sleep(1)
local result = helpers.exec("cd %s && grim - | tee %s | wl-copy", ...)
helpers.sleep(1)
local check_result = helpers.exec("test -f " .. filepath)
```

`show_countdown` is a `for` loop of `notify.send` + `helpers.sleep(1)` calls.

**Fix:** Replace `show_countdown` with a recursive `exec_async`-based countdown, then
chain the capture step in the innermost callback.

```lua
local function countdown_then(seconds, cb)
    if seconds <= 0 then
        cb()
        return
    end
    notify.send({
        text = string.format("Taking shot in: %d secs", seconds),
        icon = ICON_TIMER,
        timeout = 1000
    })
    helpers.exec_async("sleep 1", function(_, _)
        countdown_then(seconds - 1, cb)
    end)
end

local function screenshot_timer(seconds)
    countdown_then(seconds, function()
        local dir = ensure_screenshot_dir()
        local filename = generate_filename()
        local filepath = dir .. "/" .. filename
        helpers.exec_async(
            string.format("cd %s && grim - | tee %s | wl-copy", dir, filename),
            function(exit_code, _)
                if exit_code == 0 and helpers.path_exists(filepath) then
                    play_screenshot_sound()
                    notify_screenshot(filepath, "Screenshot Saved")
                else
                    notify_screenshot_error("Screenshot NOT Saved")
                end
            end
        )
    end)
end
```

#### Issue SS-3 — `screenshot_window` (Category 1 + 2 + 3)

```lua
-- BROKEN
hl.exec_cmd(string.format("grim -g '%s' %s", geometry, filepath))
helpers.sleep(1)                              -- race paper-over
local check_result = helpers.exec("test -f " .. filepath)
if check_result.success then
    ...
    local result = helpers.exec(notify_cmd)   -- blocks for user click
```

**Fix:** Use `exec_async` for the `grim` call.  In the callback, check file existence
with `helpers.path_exists` (pure Lua, no shell), then use `exec_async` for the
actionable `notify-send`.

```lua
local function screenshot_window()
    local dir = ensure_screenshot_dir()
    local class = get_active_window_class()
    if not class then notify_screenshot_error("No active window found") return end

    local filename = generate_active_window_filename(class)
    local filepath = dir .. "/" .. filename
    local geometry = get_active_window_geometry()
    if not geometry then notify_screenshot_error("Failed to get window geometry") return end

    helpers.exec_async(
        string.format("grim -g '%s' %s && wl-copy < %s", geometry, filepath, filepath),
        function(exit_code, _)
            if exit_code ~= 0 or not helpers.path_exists(filepath) then
                hl.exec_cmd(string.format(
                    'notify-send -u low -i %s " Screenshot of:" " %s NOT Saved."',
                    ICON_NOTE, class))
                play_error_sound()
                return
            end
            play_screenshot_sound()
            local notify_cmd = string.format(
                'notify-send -t 10000 -A action1=Open -A action2=Delete ' ..
                '-h string:x-canonical-private-synchronous:shot-notify ' ..
                '-i %s " Screenshot of:" " %s Saved."',
                ICON_PICTURE, class)
            helpers.exec_async(notify_cmd, function(_, response)
                response = response:gsub("%s+$", "")
                if response == "action1" then
                    hl.exec_cmd("xdg-open '" .. filepath .. "' &")
                elseif response == "action2" then
                    hl.exec_cmd("rm '" .. filepath .. "'")
                end
            end)
        end
    )
end
```

#### Issue SS-4 — `screenshot_area` (Category 2)

```lua
-- BROKEN
hl.exec_cmd(string.format("grim -g \"$(slurp)\" - > %s", tmpfile))
local check_result = helpers.exec("test -s " .. tmpfile)   -- immediate race
```

**Fix:** Use `exec_async` for the `grim -g "$(slurp)"` command.  Everything after the
capture moves into the callback.  `slurp` is interactive and runs entirely in the shell
subprocess, so it is safe inside `exec_async`.

```lua
local function screenshot_area()
    local dir = ensure_screenshot_dir()
    local filename = generate_filename()
    local filepath = dir .. "/" .. filename
    local tmpfile = "/tmp/screenshot_area_" .. tostring(math.random(1000, 9999)) .. ".png"

    helpers.exec_async(
        string.format('grim -g "$(slurp)" - > %s', tmpfile),
        function(exit_code, _)
            if exit_code ~= 0 or not helpers.path_exists(tmpfile) then return end
            hl.exec_cmd("wl-copy < " .. tmpfile)
            hl.exec_cmd(string.format("mv %s %s", tmpfile, filepath))
            play_screenshot_sound()
            notify_screenshot(filepath, "Screenshot Saved")
        end
    )
end
```

Note: `notify_screenshot` itself calls `helpers.exec(notify_cmd)` with `-A` flags — see
Issue SS-6 below.

#### Issue SS-5 — `screenshot_swappy` (Category 2)

```lua
-- BROKEN
hl.exec_cmd(string.format("grim -g \"$(slurp)\" - > %s", tmpfile))
local check_result = helpers.exec("test -s " .. tmpfile)   -- immediate race
...
local result = helpers.exec(notify_cmd)   -- blocks for user click
```

**Fix:** Same `exec_async` pattern as SS-4.  Chain `notify_screenshot` (or its async
replacement) inside the callback.

#### Issue SS-6 — `notify_screenshot` (Category 3: freeze)

```lua
-- BROKEN
local function notify_screenshot(filepath, title)
    local notify_cmd = string.format(
        'notify-send -t 10000 -A action1=Open -A action2=Delete ...')
    local result = helpers.exec(notify_cmd)   -- blocks until user dismisses
    if result.success and result.stdout then
        local response = result.stdout:gsub("%s+$", "")
        if response == "action1" then hl.exec_cmd("xdg-open ...") end
        ...
    end
end
```

This freezes the compositor until the 10-second notification times out or the user clicks.

**Fix:** Rewrite as `exec_async`:

```lua
local function notify_screenshot(filepath, title)
    local notify_cmd = string.format(
        'notify-send -t 10000 -A action1=Open -A action2=Delete ' ..
        '-h string:x-canonical-private-synchronous:shot-notify -i %s "%s"',
        ICON_PICTURE, title or "Screenshot Saved")
    helpers.exec_async(notify_cmd, function(_, response)
        response = response:gsub("%s+$", "")
        if response == "action1" then
            hl.exec_cmd("xdg-open '" .. filepath .. "' &")
        elseif response == "action2" then
            hl.exec_cmd("rm '" .. filepath .. "'")
        end
    end)
end
```

All callers (`screenshot_now`, `screenshot_area`) already run inside their own `exec_async`
callbacks, so this composes cleanly.

#### Issue SS-7 — `generate_filename` / `generate_active_window_filename` (minor)

```lua
local time_result = helpers.exec("date '+%d-%b_%H-%M-%S'")
```

Not a compositor IPC issue, but shells out unnecessarily.  Replace with:

```lua
local time_str = os.date("%d-%b_%H-%M-%S")
```

#### Issue SS-8 — `get_screenshot_dir` (minor)

```lua
local result = helpers.exec("xdg-user-dir PICTURES")
```

`xdg-user-dir` is fast and doesn't touch the compositor, so this is not a deadlock.
However it spawns a process on every screenshot.  Can be cached at module load time or
replaced with an `XDG_PICTURES_DIR` env lookup if desired.  Not urgent.

#### Issue SS-9 — `session.lock` (borderline)

```lua
local result = helpers.exec("loginctl lock-session")
```

`loginctl lock-session` sends a D-Bus message to `systemd-logind`, which then signals the
compositor to lock.  In practice this can cause a deadlock if the compositor processes
the lock signal before `loginctl` returns.  Use `hl.exec_cmd` (fire-and-forget) or
`exec_async` if you want to detect failure:

```lua
hl.exec_cmd("loginctl lock-session")
notify.lock()
```

---

### `hypr/utils/refresh.lua`

#### Issue R-1 — `helpers.sleep` chains in `refresh_ui` (Category 3: freeze)

```lua
-- BROKEN
hl.exec_cmd("ags -q 2>/dev/null || true")
helpers.sleep(0.1)
hl.exec_cmd("ags &")

-- (signal loop using is_running which is fine, but then:)
helpers.sleep(1)
hl.exec_cmd("waybar &")

helpers.sleep(0.5)
hl.exec_cmd("swaync > /dev/null 2>&1 &")
helpers.sleep(0.2)
hl.exec_cmd("swaync-client --reload-config")

helpers.sleep(1)
if file_exists(...) then hl.exec_cmd("RainbowBorders.sh &") end
```

**Fix:** Chain using `exec_async` with `sleep` pushed into the shell:

```lua
function refresh.refresh_ui()
    local notify = require("utils.notify")
    local success, err = pcall(function()
        for _, proc in ipairs({"waybar","rofi","swaync","ags"}) do
            hl.exec_cmd("pkill " .. proc .. " 2>/dev/null || true")
        end
        hl.exec_cmd("killall -SIGUSR2 waybar 2>/dev/null || true")

        -- Restart ags, then sequence the rest via exec_async
        helpers.exec_async("ags -q 2>/dev/null || true; sleep 0.1", function(_, _)
            hl.exec_cmd("ags &")
            -- signal running procs
            for _, proc in ipairs({"waybar","rofi","swaync","ags","swaybg"}) do
                if is_running(proc) then signal_usr1(proc) end
            end
            helpers.exec_async("sleep 1", function(_, _)
                hl.exec_cmd("waybar &")
                helpers.exec_async("sleep 0.5", function(_, _)
                    hl.exec_cmd("swaync > /dev/null 2>&1 &")
                    helpers.exec_async("sleep 0.2", function(_, _)
                        hl.exec_cmd("swaync-client --reload-config")
                        helpers.exec_async("sleep 1", function(_, _)
                            if file_exists(USERSCRIPTS .. "/RainbowBorders.sh") then
                                hl.exec_cmd(USERSCRIPTS .. "/RainbowBorders.sh &")
                            end
                        end)
                    end)
                end)
            end)
        end)
    end)
    if not success then notify.error("Refresh failed", tostring(err)) end
end
```

Apply the same chaining pattern to `refresh_ui_no_waybar`.

**Important:** Because `refresh_ui` is now asynchronous, callers that chain work after it
(e.g. `wallpaper.lua:apply_image_wallpaper` which calls `refresh.refresh_ui()` then
`helpers.sleep(1)` then `offer_sddm_wallpaper`) must also be restructured.  `refresh_ui`
should accept an optional completion callback, or callers should be made fully async.

---

### `hypr/user-functions/wallpaper.lua`

#### Issue W-1 — `helpers.exec(rofi_cmd)` in `wallpaper.select` (Category 3: freeze)

```lua
local result = helpers.exec(rofi_cmd)   -- blocks while user browses wallpapers
```

**Fix:** Use `exec_async`.  All post-selection logic (video vs image branch, apply
calls) moves into the callback.

#### Issue W-2 — `helpers.exec(rofi_cmd)` in `wallpaper.effects` (Category 3: freeze)

Same pattern.  Post-selection effect application and the `swww img` command chain must
move into the callback.

#### Issue W-3 — `helpers.exec(yad_cmd)` in `offer_sddm_wallpaper` (Category 3: freeze)

```lua
local yad_result = helpers.exec(yad_cmd)   -- blocks until user clicks Yes/No/timeout
```

**Fix:** Use `exec_async`.  The `set_sddm_wallpaper` call moves into the callback,
conditioned on `exit_code == 0`.

#### Issue W-4 — `helpers.sleep` in `apply_image_wallpaper` (Category 3: freeze)

```lua
helpers.exec(swww_cmd)   -- also borderline; see W-5
helpers.sleep(2)
refresh.refresh_ui()
helpers.sleep(1)
offer_sddm_wallpaper(false)
```

**Fix:** Once `refresh_ui` accepts a callback (Issue R-1), rewrite as:

```lua
helpers.exec_async(swww_cmd, function(_, _)
    wallpaper.apply_wallust(image_path)
    refresh.refresh_ui(function()
        offer_sddm_wallpaper(false)
    end)
end)
```

#### Issue W-5 — `helpers.exec(swww_cmd)` in `apply_image_wallpaper` (borderline)

```lua
local result = helpers.exec(swww_cmd)
if not result.success then ... end
```

`swww img` communicates with `swww-daemon` via its own socket (not the compositor IPC),
so this probably does not deadlock.  However it is slow (~2 seconds for the transition).
Switching to `exec_async` here is consistent and allows removing `helpers.sleep(2)`.

#### Issue W-6 — `helpers.sleep` in `wallpaper.random` and `wallpaper.effects` (Category 3: freeze)

Same pattern as W-4.  After `hl.exec_cmd(swww_cmd)`, `helpers.sleep(2)` is called before
`refresh.refresh_ui()`.  Fix by chaining inside an `exec_async("sleep 2", ...)` or by
using `exec_async(swww_cmd, ...)` directly (swww exits after applying the wallpaper).

#### Issue W-7 — thumbnail generation race (Category 2)

```lua
local function generate_gif_thumbnail(gif_path)
    ...
    if not check_result.success then
        hl.exec_cmd("magick ...")   -- async: thumbnail may not exist yet
    end
    return cache_path               -- returned immediately, may not exist
end
```

The returned `cache_path` is used as a rofi icon.  If rofi runs before magick finishes
the thumbnail won't show.  Since `build_rofi_menu` (the caller) already runs inside a
`helpers.exec` for rofi, the fix is to generate thumbnails synchronously here:

```lua
-- Use helpers.exec instead of hl.exec_cmd for thumbnail generation
helpers.exec(string.format(
    "magick '%s[0]' -resize 1920x1080 '%s' 2>/dev/null || " ..
    "convert '%s[0]' -resize 1920x1080 '%s' 2>/dev/null",
    gif_path, cache_path, gif_path, cache_path
))
```

Once `wallpaper.select` is made async (W-1), the thumbnail generation will need to also
become async and the rofi launch must be deferred until all thumbnails are ready.

---

### `hypr/user-functions/audio.lua`

#### Issue A-1 — `helpers.sleep(0.1)` in `media_play`, `media_next`, `media_prev` (Category 3: minor freeze)

```lua
local result = helpers.exec("playerctl play-pause")
helpers.sleep(0.1)   -- wait for player state to update
local status_result = helpers.exec("playerctl status")
```

**Fix:** Use `exec_async` so the sleep happens outside the event loop:

```lua
helpers.exec_async("playerctl play-pause", function(_, _)
    helpers.exec_async("sleep 0.1; playerctl status", function(_, status_out)
        local status = status_out:gsub("%s+$", "")
        if status == "Playing" then
            helpers.exec_async("playerctl metadata title && playerctl metadata artist",
                function(_, meta)
                -- parse and notify
            end)
        elseif status == "Paused" then
            notify_media("Playback", "Paused")
        end
    end)
end)
```

Or more simply, combine into one shell invocation:

```lua
helpers.exec_async(
    "playerctl play-pause; sleep 0.1; " ..
    "echo \"$(playerctl status)\n$(playerctl metadata title)\n$(playerctl metadata artist)\"",
    function(_, out)
        -- parse lines and notify
    end
)
```

---

### `hypr/user-functions/window.lua`

#### Issue WIN-1 — `helpers.sleep` in `disable_game_mode` (Category 3: minor freeze)

```lua
hl.exec_cmd(string.format("swww-daemon --format xrgb && swww img '%s' &", WALLPAPER_PATH))
helpers.sleep(0.1)
wallpaper.apply_wallust()
helpers.sleep(0.5)
```

**Fix:** Chain with `exec_async`:

```lua
helpers.exec_async("swww-daemon --format xrgb", function(_, _)
    helpers.exec_async(string.format("swww img '%s'", WALLPAPER_PATH), function(_, _)
        wallpaper.apply_wallust()
        -- remove the sleep(0.5); apply_wallust is now async internally
        -- tear down opacity rule and restore config (move here)
    end)
end)
```

---

### `hypr/user-functions/waybar.lua`

#### Issue WB-1 — `helpers.exec(rofi_cmd)` in `select_style` / `select_layout` (Category 3: freeze)

```lua
local result = helpers.exec(rofi_cmd)   -- blocks while user picks
```

**Fix:** Use `exec_async` in both functions.  The `apply_style` / `apply_layout` calls
(which invoke `refresh.refresh_ui`) move into the callback.  Once `refresh_ui` is itself
async (Issue R-1) everything composes cleanly.

---

### `hypr/user-functions/rofi.lua`

All interactive rofi menus in this file use `helpers.exec` and freeze the compositor.

#### Issue RF-1 — `rofi.beats` (Category 3: freeze)

Three sequential `helpers.exec(rofi_cmd)` calls (main menu, station list, file list).
Each must become `exec_async`, with the next menu launched inside the previous callback.

#### Issue RF-2 — `rofi.calc` (Category 3: freeze)

`helpers.exec(rofi_cmd)` inside a `while true` loop.  Replace with a recursive
`exec_async` pattern where each iteration's callback either recurses (user entered
something) or exits (user cancelled).

#### Issue RF-3 — `rofi.emoji` (Category 1 + 3: deadlock + freeze)

```lua
local rofi_cmd = string.format(
    "cat %s | rofi ... | awk '{print $1}' | head -n 1 | tr -d '\\n' | wl-copy",
    tmpfile, ...)
local result = helpers.exec(rofi_cmd)
```

The pipeline ends in `wl-copy` (Wayland) **and** the whole thing blocks.  Use
`exec_async`; the pipeline itself can remain as-is since `wl-copy` runs in the
subprocess, not in the compositor event loop.

#### Issue RF-4 — `rofi.search` (Category 3: freeze)

`helpers.exec(rofi_cmd)` blocks until user types a query.  Use `exec_async`.

#### Issue RF-5 — `rofi.theme_selector` (Category 3: freeze)

`helpers.exec(rofi_cmd)` inside a `while running` loop.  Replace with a recursive
`exec_async` pattern matching the `calc` fix (RF-2).

#### Issue RF-6 — `helpers.sleep(0.5)` in `rofi.animations` (Category 3: minor freeze)

```lua
helpers.sleep(0.5)
refresh.refresh_ui_no_waybar()
```

**Fix:** Replace with `exec_async("sleep 0.5", function() refresh.refresh_ui_no_waybar() end)`.
Once `refresh_ui_no_waybar` is async (Issue R-1) the callback composes correctly.

---

## Priority order

1. **Category 1 deadlocks** — these make features completely non-functional and risk
   hanging the compositor:
   - `input.lua` I-1, I-2 (keyboard layout switching)
   - `display.lua` D-1 (night light toggle)
   - `system.lua` S-1, S-3 (clipboard wl-copy, hypridle)
   - `session.lua` SS-1, SS-2, SS-3 (screenshots that call grim/wl-copy)

2. **Category 2 races** — features appear to work but silently fail or produce empty
   results intermittently:
   - `session.lua` SS-3, SS-4, SS-5 (screenshot area / swappy / window file checks)
   - `wallpaper.lua` W-7 (thumbnail generation)

3. **Category 3 freezes** — user-visible compositor stutters and hangs on interactive
   menus:
   - `session.lua` SS-6 (actionable notify-send)
   - `refresh.lua` R-1 (refresh_ui sleep chain — unblocks all callers)
   - `wallpaper.lua` W-1 – W-6
   - `waybar.lua` WB-1
   - `rofi.lua` RF-1 – RF-6
   - `system.lua` S-2, S-4, S-5
   - `audio.lua` A-1
   - `window.lua` WIN-1

---

## General implementation notes

- **Error handling in callbacks:** wrap callback bodies in `pcall` if the original
  function did so; `exec_async` callbacks run on the next event-loop tick and any
  uncaught error will be silently swallowed by the Lua runtime.

- **Sequencing:** `exec_async` callbacks fire after the command exits, so `sleep N` in
  the shell command is the correct replacement for `helpers.sleep(N)` — it keeps the
  delay but moves it out of the compositor loop.

- **`helpers.path_exists`** is a pure-Lua `io.open` check and is safe to call anywhere;
  prefer it over `helpers.exec("test -f ...")` in callbacks that just need to confirm a
  file exists.

- **`os.date`** replaces `helpers.exec("date '+...'")` for timestamp generation.

- **`refresh_ui` callback parameter:** the cleanest way to handle callers that chain
  after a refresh is to add an optional `cb` parameter to `refresh_ui` and
  `refresh_ui_no_waybar` that is invoked at the end of the last `exec_async` chain step.
