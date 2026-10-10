"""Regression checks for the Said wrapper with Roblox/executor and serializer stubs.

Requires a system Lua 5.4 shared library. This does not run Delta, Roblox,
or the upstream Luau serializer, and does not verify a real Studio place.
"""
from pathlib import Path
import ctypes
import ctypes.util

SOURCE = Path(__file__).with_name("ExportadorCliente.lua").read_text()
MOCK = r'''
local scenario = SCENARIO
local nativeprint = print
local logs, files, folders, workers = {}, {}, {}, {}
local now, nativeCalls, serializerCalls = 0, 0, 0
local finalReport, cancelButton, label, compiledSource
testSources = {}
print = function(...) logs[#logs + 1] = table.concat({...}, " ") end
warn = print
os.clock = function() return now end
os.time = function() return 1791662400 end
os.date = function() return "20261010_200000" end
Enum = {
    RunContext = {Client = "Client", Server = "Server", Legacy = "Legacy"},
    ZIndexBehavior = {Sibling = 1}, Font = {GothamBold = 1, Gotham = 2},
    TextXAlignment = {Left = 1}, TextYAlignment = {Top = 1},
}
Vector2 = {new = function(...) return {...} end}
UDim2 = {new = Vector2.new}
UDim = {new = Vector2.new}
Color3 = {fromRGB = Vector2.new}
local methods = {}
local function instance(class, name, parent)
    local item = setmetatable({ClassName = class, Name = name, Parent = parent}, {__index = methods})
    return item
end
function methods:IsA(class)
    return self.ClassName == class or class == "LuaSourceContainer"
        and (self.ClassName == "Script" or self.ClassName == "LocalScript" or self.ClassName == "ModuleScript")
end
function methods:GetFullName()
    if self.Parent and self.Parent.ClassName ~= "DataModel" then
        return self.Parent:GetFullName() .. "." .. self.Name
    end
    return self.Name
end
function methods:FindFirstChildOfClass(class)
    return class == "PlayerGui" and self.gui or nil
end
function methods:WaitForChild() return self.gui end
function methods:Destroy() self.destroyed = true end
Instance = {new = function(class)
    local item = instance(class, class)
    if class == "TextButton" then
        item.Activated = {Connect = function(_, fn) item.click = fn end}
        cancelButton = item
    elseif class == "TextLabel" then label = item end
    return item
end}
typeof = function(x) return type(x) == "table" and x.ClassName and "Instance" or type(x) end
game = instance("DataModel", "game")
game.PlaceId = 123456
workspace = instance("Workspace", "Workspace", game)
workspace.StreamingEnabled = true
local player = instance("Player", "Said", instance("Players", "Players", game))
player.gui = instance("PlayerGui", "PlayerGui", player)
local roots = {
    Workspace = workspace, Players = player.Parent,
    HttpService = {
        GenerateGUID = function() return "ab12cd34-5678" end,
        JSONEncode = function(_, value)
            if type(value) == "table" then
                if value.version == 3 then finalReport = value end
                return '{"mock_report":true}'
            end
            return string.format("%q", value)
        end,
    },
}
roots.Players.LocalPlayer = player
function game:GetService(name)
    if not roots[name] then roots[name] = instance(name, name, self) end
    return roots[name]
end
local left = instance("Folder", "A/B", workspace)
local right = instance("Folder", "A:B", workspace)
local good = instance("ModuleScript", "Config", left)
local duplicate = instance("LocalScript", "Config", right)
local con = instance("Folder", "CON", right)
duplicate.Parent = con
local server = instance("Script", "Private", workspace)
server.RunContext = Enum.RunContext.Server
local localServer = instance("LocalScript", "ServerContext", workspace)
localServer.RunContext = Enum.RunContext.Server
local core = instance("LocalScript", "RobloxCore", instance("CoreGui", "CoreGui", game))
local clientScripts = {good, duplicate}
local all = {good, duplicate, server, localServer, core}
if scenario == "timeout" then
    duplicate.stall = true
    local later = instance("ModuleScript", "ZZLater", right)
    all[#all + 1] = later
    clientScripts[#clientScripts + 1] = later
end
function game:GetDescendants()
    if scenario == "scan_error" then error("scan denied") end
    return all
end
task = {}
function task.spawn(fn)
    local worker = coroutine.create(fn)
    workers[#workers + 1] = worker
    local ok, problem = coroutine.resume(worker)
    assert(ok, problem)
    return worker
end
function task.cancel(worker)
    for i, other in pairs(workers) do if worker == other then workers[i] = nil end end
end
function task.wait(duration)
    local _, main = coroutine.running()
    if not main then coroutine.yield(); return end
    now = now + (duration or 0.01)
    for _, worker in pairs(workers) do
        if coroutine.status(worker) == "suspended" then
            local ok, problem = coroutine.resume(worker)
            assert(ok, problem)
        end
    end
    if scenario == "cancel_scripts" and nativeCalls >= 1 then cancelButton.click() end
end
local function nativeDecompile(obj)
    nativeCalls = nativeCalls + 1
    if obj.stall then while true do task.wait(0.1) end end
    if scenario == "decompile_error" and obj == duplicate then error("decompiler failed") end
    if scenario == "empty_source" and obj == duplicate then return "" end
    if obj == duplicate or scenario == "panic_all" then
        if scenario == "panic_line" or scenario == "panic_all" then return "-- decompilation panicked" end
        if scenario == "panic_header" then
            return "-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw\n\n-- decompilation panicked"
        end
        if scenario == "panic_block" then return "--[[ decompilation panicked\nstack trace ]] " end
        if scenario == "panic_long_comment" then return "--[==[ Failed to decompile. Reason:\ninternal error ]==]" end
        if scenario == "panic_crlf" then return "-- decompiler header\r\n\r\n-- decompilation panicked\r\n" end
        if scenario == "panic_bare" then return "decompilation panicked" end
        if scenario == "panic_literal_string" then return 'return "-- decompilation panicked"' end
        if scenario == "panic_comment_then_code" then return "-- decompilation panicked\nreturn {value = 42}" end
    end
    return "return {value = 42}"
end
local function write(path, data)
    if scenario == "initial_write_error" then error("storage denied") end
    if scenario == "script_write_error" and path:match("%.lua$") then error("Lua write denied") end
    if scenario == "binary_write_error" and path:match("%.rbxl$") then error("binary write denied") end
    if scenario == "all_place_write_error" and path:match("%.rbxlx?$") then error("place write denied") end
    if scenario == "truncated_write" and path:match("%.rbxl$") then data = data:sub(1, -2) end
    files[path] = data
end
local function mkdir(path) folders[path] = true end
local function read(path)
    if scenario == "read_error" and path:match("%.rbxl$") then error("read unavailable") end
    assert(files[path], "missing file")
    return files[path]
end
writefile, makefolder, readfile, decompile = write, mkdir, read, nativeDecompile
delfile = function(path) files[path] = nil end
isfolder = function(path) return folders[path] end
local nativeLoad = load
local function u32(n)
    return string.char(n % 256, math.floor(n / 256) % 256,
        math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end
local signature = "<roblox!" .. string.char(137, 255, 13, 10, 26, 10)
local binary = signature .. "\0\0" .. u32(0) .. u32(0) .. string.rep("\0", 8)
    .. "END\0" .. u32(0) .. u32(9) .. u32(0) .. "</roblox>"
local xml = '<!-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw --><roblox version="4"></roblox>'
if scenario == "xml_declaration" then
    xml = string.char(239, 187, 191) .. '<?xml version="1.0"?>\n' .. xml
end
local serializerStub = [[
return function(options)
    recordOptions(options)
    if options.Decompile then
        for _, script in ipairs(testScripts) do testSources[script] = decompile(script) end
    end
    if testScenario == "cancel_place" then clickCancel() end
    if testScenario == "no_callback" then return end
    if testScenario == "serializer_error" then error("serializer failed") end
    local data = options.Binary and testBinary or testXML
    if (testScenario == "wrong_binary_format" or testScenario == "xml_declaration") and options.Binary then data = testXML end
    if testScenario == "truncated_binary" and options.Binary then data = testBinary:sub(1, -2) end
    if testScenario == "bad_both" then data = "not a Roblox file" end
    if testScenario == "overlong_chunk" and options.Binary then
        data = testBinary:sub(1, 36) .. string.char(255,255,255,127) .. testBinary:sub(41)
    end
    if testScenario == "missing_end" and options.Binary then data = testBinary:sub(1, 32) end
    if testScenario == "trailing_bytes" and options.Binary then data = testBinary .. "extra" end
    options.Callback(data)
end
]]
testScenario, testScripts, testBinary, testXML = scenario, clientScripts, binary, xml
recordOptions = function(options)
    serializerCalls = serializerCalls + 1
    assert(options.Object == game and options.mode == "full" and not options.IsModel)
    assert(options.CompressionMode == false and not options.KillAllScripts
        and not options.SafeMode and not options.ShutdownWhenDone and not options.AntiIdle)
    assert(options.IsolateLocalPlayer and not options.IsolatePlayers and options.IgnoreNotArchivable)
    assert(options.FilePath:match("_said%.rbxlx?$"), options.FilePath)
end
clickCancel = function() cancelButton.click() end
local patchableSource = [[
-- https://raw.githubusercontent.com/luau/SomeHub/main/
-- https://raw.githubusercontent.com/luau/SomeHub/main/
-- https://raw.githubusercontent.com/daily3014/rbx-algorithms/refs/heads/main/
-- https://raw.githubusercontent.com/RiskoZS/llz4/refs/heads/main/
-- https://assetdelivery.roproxy.com/
]]
patchableSource = patchableSource .. string.rep("-- padding\n", 150) .. serializerStub
function game:HttpGet(url, fresh)
    assert(url:find("/089986506e7ab9c50d7065d48b36e3bfbd5f78d7/", 1, true))
    assert(fresh == true)
    if scenario == "download_error" then error("network denied") end
    if scenario == "revision_mismatch" then return patchableSource:gsub("SomeHub/main/", "Other/main/") end
    return patchableSource
end
loadstring = function(source, name)
    if scenario == "compile_error" and name == "UniversalSynSaveInstance_Said" then return nil, "bad code" end
    if name == "UniversalSynSaveInstance_Said" then
        compiledSource = source
        assert(not source:find("SomeHub/main/", 1, true))
        assert(not source:find("refs/heads/main/", 1, true))
        assert(not source:find("roproxy.com", 1, true))
    end
    return nativeLoad(source, name, "t", _G)
end
getfenv = function() return _G end
getgenv = function() return _G end
setfenv = function(fn, environment)
    local i = 1
    while true do
        local name = debug.getupvalue(fn, i)
        if not name then break end
        if name == "_ENV" then debug.setupvalue(fn, i, environment); break end
        i = i + 1
    end
    return fn
end
if scenario == "no_setfenv" then setfenv = nil end
if scenario == "missing_decompile" then decompile = nil end
if scenario == "missing_readfile" then readfile = nil end
if scenario == "missing_writefile" then writefile = nil end
if scenario == "different_environment" then
    local executor = {
        decompile = decompile, writefile = writefile, makefolder = makefolder,
        readfile = readfile, loadstring = loadstring, setfenv = setfenv,
    }
    decompile, writefile, makefolder, readfile, loadstring, setfenv = nil, nil, nil, nil, nil, nil
    getgenv = function() return executor end
end
'''
CHECKS = r'''
if scenario == "missing_writefile" or scenario == "initial_write_error" then
    assert(next(files) == nil)
    assert(cancelButton.Text == "Cerrar")
    return
end
assert(finalReport and finalReport.version == 3)
local r = finalReport
assert(r.place.requestedFormat == "rbxl")
assert(type(r.status) == "string")
assert(cancelButton.Text == "Cerrar")
local rejected = {
    no_callback = true, serializer_error = true, bad_both = true,
    all_place_write_error = true, download_error = true,
    compile_error = true, revision_mismatch = true,
}
if rejected[scenario] then
    assert(r.place.status == "failed", r.place.status)
    assert(not r.place.file)
    assert(r.saved == 2 and r.status == "partial")
    return
end
if scenario == "cancel_scripts" then
    assert(r.status == "cancelled" and r.place.status == "cancelled")
    assert(serializerCalls == 0 and nativeCalls == 1 and r.saved == 1)
    return
end
if scenario == "cancel_place" then
    assert(r.status == "cancelled" and r.place.status == "cancelled")
    assert(serializerCalls == 1 and not r.place.file and r.saved == 2)
    return
end
assert(r.place.status == "saved", r.place.error or "not saved")
assert(files[r.place.file] and r.place.file:match("_said%.rbxlx?$"))
local fallback = {
    binary_write_error = true, wrong_binary_format = true, truncated_binary = true,
    truncated_write = true, overlong_chunk = true, missing_end = true, trailing_bytes = true, xml_declaration = true,
}
if fallback[scenario] then
    assert(r.place.format == "rbxlx" and serializerCalls == 2)
    assert(r.place.attempts[1].status == "failed")
    assert(files[r.place.file] == xml)
else
    assert(r.place.format == "rbxl" and serializerCalls == 1)
    assert(files[r.place.file] == binary)
end
if scenario == "truncated_write" then assert(r.place.attempts[1].rejectedFileRemoved) end
if scenario == "timeout" then
    assert(nativeCalls == 2, nativeCalls)
    assert(r.scriptsStatus == "timeout" and r.saved == 1 and r.remaining == 1)
    assert(r.place.uncachedScripts == 1)
elseif scenario == "missing_decompile" then
    assert(nativeCalls == 0 and r.saved == 0 and r.failed == 2 and r.scriptsStatus == "unavailable")
elseif scenario == "no_setfenv" then
    assert(nativeCalls == 4 and r.place.sourceStrategy == "native_decompiler")
elseif scenario == "scan_error" then
    assert(nativeCalls == 0 and #r.scanErrors == 1 and r.place.uncachedScripts == 2)
elseif scenario == "script_write_error" then
    assert(nativeCalls == 1 and r.scriptsStatus == "write_error" and r.failed == 1 and r.remaining == 1)
elseif scenario == "decompile_error" or scenario == "empty_source" then
    assert(nativeCalls == 2 and r.saved == 1 and r.failed == 1)
elseif scenario:match("^panic_") and scenario ~= "panic_literal_string" and scenario ~= "panic_comment_then_code" then
    local count = scenario == "panic_all" and 2 or 1
    assert(nativeCalls == 2 and r.saved == 2 - count and r.failed == count, "diagnostics counted as recovered code")
    assert(r.diagnosticFailures == count)
    assert(r.scriptsStatus == "completed_with_errors" and r.status == "completed_with_errors")
    local entry = r.entries[#r.entries]
    assert(entry.status == "decompiler_diagnostic" and not entry.file)
    assert(entry.message:find("panicked", 1, true) or entry.message:find("Failed to decompile", 1, true))
    assert(testSources[duplicate]:find("-- Codigo no recuperado: decompiler_diagnostic", 1, true))
    assert(testSources[duplicate]:find("-- Diagnostico:", 1, true))
else
    assert(nativeCalls == 2 and r.saved == 2 and r.failed == 0, nativeCalls)
    assert(r.place.sourceStrategy == "initial_snapshot_cache")
    assert(r.entries[1].file ~= r.entries[2].file)
    assert(r.entries[1].file:find("/Workspace/A_B/", 1, true))
    assert(r.entries[2].file:find("/Workspace/A_B_2/_CON/", 1, true))
end
if scenario == "missing_readfile" or scenario == "read_error" then
    assert(r.place.verification == "serialized_structure")
else
    assert(r.place.verification == "readback_matches")
end
assert(r.total ~= 5, "server/core scripts were included")
'''
CASES = [
    "normal", "different_environment", "missing_decompile", "missing_writefile",
    "missing_readfile", "read_error", "no_setfenv", "decompile_error", "empty_source",
    "initial_write_error", "script_write_error", "binary_write_error", "all_place_write_error",
    "wrong_binary_format", "truncated_binary", "truncated_write", "overlong_chunk",
    "missing_end", "trailing_bytes", "bad_both", "no_callback", "serializer_error",
    "timeout", "cancel_scripts", "cancel_place", "download_error", "compile_error",
    "revision_mismatch", "scan_error", "xml_declaration",
    "panic_line", "panic_header", "panic_block", "panic_long_comment", "panic_crlf",
    "panic_bare", "panic_all", "panic_literal_string", "panic_comment_then_code",
]

def run():
    library = ctypes.util.find_library("lua5.4")
    if not library:
        raise SystemExit("Lua 5.4 shared library is required.")
    lua = ctypes.CDLL(library)
    lua.luaL_newstate.restype = ctypes.c_void_p
    lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
    lua.luaL_loadbufferx.argtypes = [
        ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p, ctypes.c_char_p,
    ]
    lua.luaL_loadbufferx.restype = ctypes.c_int
    lua.lua_pcallk.argtypes = [
        ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p,
    ]
    lua.lua_pcallk.restype = ctypes.c_int
    lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
    lua.lua_tolstring.restype = ctypes.c_char_p
    lua.lua_close.argtypes = [ctypes.c_void_p]
    failures = []
    for scenario in CASES:
        state = lua.luaL_newstate()
        lua.luaL_openlibs(state)
        text = (
            f'local SCENARIO = "{scenario}"\n' + MOCK
            + "\nlocal function runWrapper()\n" + SOURCE + "\nend\nrunWrapper()\n" + CHECKS
        ).encode()
        result = lua.luaL_loadbufferx(state, text, len(text), b"test_exporter", None)
        if result == 0:
            result = lua.lua_pcallk(state, 0, 0, 0, 0, None)
        if result:
            error = lua.lua_tolstring(state, -1, None).decode(errors="replace")
            failures.append((scenario, error))
            print(f"FAIL {scenario}: {error}")
        lua.lua_close(state)
    if failures:
        raise SystemExit(f"{len(failures)} of {len(CASES)} cases failed")
    print(f"PASS: {len(CASES)} simulated cases. Delta/Studio and upstream serializer were not executed.")

if __name__ == "__main__":
    run()
