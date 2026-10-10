-- Exportador de lugar y scripts visibles en el cliente, v3 (Said).
-- Solo recupera contenido que existe en el cliente; no recupera codigo exclusivo del servidor.
-- Serializador: UniversalSynSaveInstance https://discord.gg/wx4ThpAsmw
-- USSI se descarga de una revision fija. Licencia y modificaciones: USSI_LICENSE.txt y README.md.

local TIMEOUT = 15
local USSI_COMMIT = "089986506e7ab9c50d7065d48b36e3bfbd5f78d7"
local HELPERS_COMMIT = "beabe12be11b007777cfef0bffbe68dfb3f8b3b9"
local BASE64_COMMIT = "468dde82bdba89176157dcec90ba503b7046f5b3"
local LZ4_COMMIT = "57d869215b7a061121f5492ecff245989638816a"
print("[Exportador Said] v3 iniciado. Preparando ventana...")

local environments = {}
if type(getfenv) == "function" then
    local ok, env = pcall(function() return getfenv() end)
    if ok and type(env) == "table" then environments[#environments + 1] = env end
end
if type(getgenv) == "function" then
    local ok, env = pcall(getgenv)
    if ok and type(env) == "table" then environments[#environments + 1] = env end
end
local function capability(name)
    for _, env in ipairs(environments) do
        if type(env[name]) == "function" then return env[name] end
    end
end
local decompiler = type(decompile) == "function" and decompile or capability("decompile")
local writeFile = type(writefile) == "function" and writefile or capability("writefile")
local readFile = type(readfile) == "function" and readfile or capability("readfile")
local deleteFile = type(delfile) == "function" and delfile or capability("delfile")
local makeFolder = type(makefolder) == "function" and makefolder or capability("makefolder")
local isFolder = type(isfolder) == "function" and isfolder or capability("isfolder")
local compile = type(loadstring) == "function" and loadstring or capability("loadstring")
local setEnvironment = type(setfenv) == "function" and setfenv or capability("setfenv")

local http = game:GetService("HttpService")
local players = game:GetService("Players")
local unique = http:GenerateGUID(false):gsub("[^%w]", ""):sub(1, 8)
local stamp = os.date("!%Y%m%d_%H%M%S")
local basename = "Lugar_" .. tostring(game.PlaceId) .. "_" .. stamp .. "_" .. unique .. "_said"
local folder = "Exportacion_" .. tostring(game.PlaceId) .. "_" .. unique .. "_said"
local reportPath = folder .. "/reporte.json"
local report = {
    version = 3, placeId = game.PlaceId, startedAt = os.time(), folder = folder,
    status = "running", total = 0, saved = 0, failed = 0, entries = {}, scanErrors = {},
    scriptsStatus = "pending",
    place = {status = "pending", requestedFormat = "rbxl", attempts = {}, uncachedScripts = 0},
    dependencies = {
        serializer = USSI_COMMIT, helpers = HELPERS_COMMIT,
        base64 = BASE64_COMMIT, lz4 = LZ4_COMMIT,
    },
    notes = {
        "Se conserva la jerarquia del contenido visible en el cliente.",
        "El codigo recuperado depende de decompile; su funcionamiento no esta verificado.",
        "ServerScriptService y ServerStorage no replican su codigo al cliente.",
        "Con StreamingEnabled solo se puede guardar lo que se haya cargado.",
        "Los recursos externos se conservan como referencias; no se garantizan sus permisos.",
        "Cancelar durante la serializacion espera a que esta devuelva el control.",
    },
}
pcall(function() report.streamingEnabled = game:GetService("Workspace").StreamingEnabled end)
local function saveReport()
    return pcall(function() writeFile(reportPath, http:JSONEncode(report)) end)
end

local cancelled, finished, phase = false, false, "preparing"
local screen, statusLabel, button
local function create(className, properties, parent)
    local instance = Instance.new(className)
    for key, value in pairs(properties) do instance[key] = value end
    instance.Parent = parent
    return instance
end
local uiOk, uiError = pcall(function()
    local player = players.LocalPlayer
    local guiParent = player and player:FindFirstChildOfClass("PlayerGui")
    if not guiParent and player then guiParent = player:WaitForChild("PlayerGui", 5) end
    if type(gethui) == "function" then
        local ok, container = pcall(gethui)
        if ok and typeof(container) == "Instance" then guiParent = container end
    end
    if not guiParent then error("No hay un contenedor para mostrar la ventana") end
    screen = create("ScreenGui", {
        Name = "ExportadorSaid_" .. unique, ResetOnSpawn = false,
        IgnoreGuiInset = true, DisplayOrder = 10000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, guiParent)
    local frame = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.97, 0),
        Size = UDim2.new(0.94, 0, 0, 230),
        BackgroundColor3 = Color3.fromRGB(20, 26, 22), BorderSizePixel = 0,
    }, screen)
    create("UISizeConstraint", {MaxSize = Vector2.new(510, 230)}, frame)
    create("UICorner", {CornerRadius = UDim.new(0, 12)}, frame)
    create("TextLabel", {
        Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(1, -32, 0, 28),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 18,
        TextColor3 = Color3.fromRGB(110, 235, 147), TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Exportador de lugar · Said v3",
    }, frame)
    statusLabel = create("TextLabel", {
        Position = UDim2.new(0, 16, 0, 43), Size = UDim2.new(1, -32, 0, 128),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = Color3.fromRGB(235, 240, 237), TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        Text = "Preparando exportacion...",
    }, frame)
    button = create("TextButton", {
        Position = UDim2.new(0, 16, 1, -48), Size = UDim2.new(1, -32, 0, 34),
        BackgroundColor3 = Color3.fromRGB(57, 96, 67), BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(255, 255, 255),
        Text = "Cancelar",
    }, frame)
    create("UICorner", {CornerRadius = UDim.new(0, 8)}, button)
    button.Activated:Connect(function()
        if finished then
            screen:Destroy()
        else
            cancelled = true
            button.Text = phase == "place" and "Esperando al serializador..." or "Cancelando..."
            if phase == "place" then
                statusLabel.Text = "Cancelacion solicitada. Se descartara el resultado pendiente cuando el serializador devuelva el control."
            end
        end
    end)
end)
if not uiOk then
    warn("[Exportador Said] Ventana: " .. tostring(uiError))
    if screen then
        pcall(function() screen:Destroy() end)
        screen, statusLabel, button = nil, nil, nil
    end
end
local function status(message)
    print("[Exportador Said] " .. message)
    if statusLabel then pcall(function() statusLabel.Text = message end) end
end
local function finish(message, problem)
    finished = true
    status(message)
    if problem then
        warn("[Exportador Said] " .. message)
        if statusLabel then
            pcall(function() statusLabel.TextColor3 = Color3.fromRGB(255, 180, 150) end)
        end
    end
    if button then pcall(function() button.Text = "Cerrar" end) end
end

if not writeFile or not makeFolder then
    finish("Faltan writefile o makefolder en el executor. No se puede guardar.", true)
    return
end
local createdFolders = {}
local function ensureFolder(path)
    if createdFolders[path] then return end
    local ok, problem = pcall(makeFolder, path)
    if not ok then
        local exists, value = false, false
        if isFolder then exists, value = pcall(isFolder, path) end
        if not exists or not value then error("Carpeta " .. path .. ": " .. tostring(problem)) end
    end
    createdFolders[path] = true
end
local prepared, prepareError = pcall(function()
    ensureFolder(folder)
    local ok, problem = saveReport()
    if not ok then error(problem) end
end)
if not prepared then
    finish("No se pudo preparar la salida:\n" .. tostring(prepareError), true)
    return
end

local sourceCache = {}
local function isClientScript(instance)
    if instance:IsA("LocalScript") then
        local ok, context = pcall(function() return instance.RunContext end)
        return not ok or context ~= Enum.RunContext.Server
    end
    if instance:IsA("ModuleScript") then return true end
    if instance:IsA("Script") then
        local ok, context = pcall(function() return instance.RunContext end)
        return ok and context == Enum.RunContext.Client
    end
    return false
end
local function excluded(instance)
    local parent = instance
    while parent and parent ~= game do
        if parent == screen or parent.ClassName == "CoreGui" or parent.ClassName == "CorePackages" then
            return true
        end
        parent = parent.Parent
    end
    return false
end
local function decompileOne(instance)
    local complete, success, result = false, false, nil
    local deadline = os.clock() + TIMEOUT
    local worker = task.spawn(function()
        success, result = pcall(decompiler, instance)
        complete = true
    end)
    while not complete and not cancelled and os.clock() < deadline do task.wait(0.05) end
    if not complete then
        pcall(task.cancel, worker)
        return false, cancelled and "Cancelado por el usuario" or "Descompilador: limite de tiempo",
            cancelled and "cancelled" or "timeout"
    end
    if not success then return false, tostring(result), "decompile_error" end
    if type(result) ~= "string" or not result:find("%S") then
        return false, "El descompilador no devolvio texto", "empty_result"
    end
    return true, (result:gsub("%z", "\\0")), "saved"
end
local function safeName(value)
    local name = tostring(value):gsub("[^%w_-]", "_"):sub(1, 20)
    if name == "" then name = "SinNombre" end
    local upper = name:upper()
    if upper == "CON" or upper == "PRN" or upper == "AUX" or upper == "NUL"
        or upper:match("^COM%d$") or upper:match("^LPT%d$") then name = "_" .. name end
    return name
end
local directoryFor, namesUsed = {}, {}
local function scriptDirectory(instance)
    local parents, current = {}, instance.Parent
    while current and current ~= game do
        table.insert(parents, 1, current)
        current = current.Parent
    end
    local truncated = #parents > 6
    if truncated then
        parents = {parents[1], parents[2], parents[3],
            parents[#parents - 2], parents[#parents - 1], parents[#parents]}
    end
    local directory = folder .. "/scripts"
    ensureFolder(directory)
    for _, parent in ipairs(parents) do
        directoryFor[parent] = directoryFor[parent] or {}
        local assigned = directoryFor[parent][directory]
        if not assigned then
            local name = safeName(parent.Name)
            namesUsed[directory] = namesUsed[directory] or {}
            local used = namesUsed[directory]
            local original, number = name, 1
            while used[name:lower()] do
                number = number + 1
                name = original:sub(1, 14) .. "_" .. tostring(number)
            end
            used[name:lower()] = true
            assigned = directory .. "/" .. name
            directoryFor[parent][directory] = assigned
        end
        directory = assigned
        ensureFolder(directory)
    end
    return directory, truncated
end
local function exportScripts()
    phase, report.scriptsStatus = "scripts", "running"
    status("Revisando los scripts presentes en el cliente...")
    task.wait()
    local ok, descendants = pcall(function() return game:GetDescendants() end)
    if not ok then
        report.scanErrors[1] = {root = "game", message = tostring(descendants)}
        report.scriptsStatus = "scan_error"
        return
    end
    local candidates = {}
    for _, instance in ipairs(descendants) do
        if isClientScript(instance) and not excluded(instance) then
            local found, path = pcall(function() return instance:GetFullName() end)
            candidates[#candidates + 1] = {
                instance = instance, path = found and path or instance.Name,
                name = instance.Name, class = instance.ClassName, scanIndex = #candidates + 1,
            }
        end
    end
    table.sort(candidates, function(a, b)
        if a.path == b.path then return a.scanIndex < b.scanIndex end
        return a.path < b.path
    end)
    report.total = #candidates
    local saved, problem = saveReport()
    if not saved then error("Inventario: " .. tostring(problem)) end
    for index, candidate in ipairs(candidates) do
        if cancelled then report.scriptsStatus = "cancelled"; return end
        status(string.format("Scripts %d / %d: %s\nGuardados: %d | Fallos: %d\nDespues se guardara el lugar.",
            index, #candidates, candidate.name, report.saved, report.failed))
        task.wait()
        if cancelled then report.scriptsStatus = "cancelled"; return end
        local recovered, result, outcome
        if decompiler then
            recovered, result, outcome = decompileOne(candidate.instance)
        else
            recovered, result, outcome = false, "El executor no dispone de decompile", "unavailable"
        end
        local entry = {path = candidate.path, class = candidate.class, status = outcome}
        if recovered then
            sourceCache[candidate.instance] = result
            local written, writeError = pcall(function()
                local directory, shortened = scriptDirectory(candidate.instance)
                local path = directory .. "/" .. string.format("%05d_%s.lua", index, safeName(candidate.name))
                writeFile(path, "-- Ruta original: " .. http:JSONEncode(candidate.path)
                    .. "\n-- Resultado de decompile; funcionamiento no verificado.\n\n" .. result)
                entry.file = path:sub(#folder + 2)
                entry.shortenedDirectory = shortened
                entry.bytes = #result
            end)
            if written then
                report.saved = report.saved + 1
            else
                entry.status, entry.message = "write_error", tostring(writeError)
                report.failed = report.failed + 1
                report.scriptsStatus = "write_error"
            end
        else
            sourceCache[candidate.instance] = "-- Codigo no recuperado: " .. outcome .. "\n"
            entry.message = result
            report.failed = report.failed + 1
        end
        report.entries[#report.entries + 1] = entry
        if outcome == "timeout" or outcome == "cancelled" then
            report.scriptsStatus = outcome
            return -- No acumula nuevas llamadas a un descompilador bloqueado.
        end
        if report.scriptsStatus == "write_error" then return end
        if index % 10 == 0 then
            saved, problem = saveReport()
            if not saved then error("Reporte: " .. tostring(problem)) end
        end
    end
    report.scriptsStatus = not decompiler and "unavailable"
        or report.failed > 0 and "completed_with_errors" or "completed"
end

local function replaceLiteral(source, search, replacement, expected)
    local parts, offset, count = {}, 1, 0
    while true do
        local first, last = source:find(search, offset, true)
        if not first then parts[#parts + 1] = source:sub(offset); break end
        parts[#parts + 1] = source:sub(offset, first - 1)
        parts[#parts + 1] = replacement
        offset, count = last + 1, count + 1
    end
    if count ~= expected then error("La dependencia no coincide con la revision revisada: " .. search) end
    return table.concat(parts)
end
local function loadSerializer()
    if not compile then error("Falta loadstring para iniciar el serializador") end
    local url = "https://raw.githubusercontent.com/luau/UniversalSynSaveInstance/" .. USSI_COMMIT .. "/saveinstance.luau"
    local source = game:HttpGet(url, true)
    if type(source) ~= "string" or #source < 1000 then error("Descarga del serializador incompleta") end
    source = replaceLiteral(source, "https://raw.githubusercontent.com/luau/SomeHub/main/",
        "https://raw.githubusercontent.com/luau/SomeHub/" .. HELPERS_COMMIT .. "/", 2)
    source = replaceLiteral(source, "https://raw.githubusercontent.com/daily3014/rbx-algorithms/refs/heads/main/",
        "https://raw.githubusercontent.com/daily3014/rbx-algorithms/" .. BASE64_COMMIT .. "/", 1)
    source = replaceLiteral(source, "https://raw.githubusercontent.com/RiskoZS/llz4/refs/heads/main/",
        "https://raw.githubusercontent.com/RiskoZS/llz4/" .. LZ4_COMMIT .. "/", 1)
    source = replaceLiteral(source, "https://assetdelivery.roproxy.com/",
        "https://assetdelivery.roblox.com/", 1)

    -- Entorno privado: reutiliza el codigo recuperado sin cambiar los globales de Delta.
    local env = {}
    for _, original in ipairs(environments) do
        for key, value in pairs(original) do
            if env[key] == nil then env[key] = value end
        end
    end
    if environments[1] then setmetatable(env, {__index = environments[1]}) end
    env.game, env.workspace = game, workspace
    env.writefile, env.readfile, env.makefolder = writeFile, readFile, makeFolder
    env.globalcontainer = {}
    env._G = env
    env.getgenv = function() return env end
    env.decompile = function(instance)
        if sourceCache[instance] then return sourceCache[instance] end
        report.place.uncachedScripts = report.place.uncachedScripts + 1
        return "-- Sin codigo en la captura de scripts inicial.\n"
    end

    local bridged = false
    if setEnvironment then
        local probe = compile("return true", "SaidEnvProbe")
        bridged = type(probe) == "function" and pcall(setEnvironment, probe, env) or false
    end
    local function dependencyCompile(text, name)
        local chunk, problem = compile(text, name)
        if not chunk then return nil, problem end
        if bridged then setEnvironment(chunk, env) end
        return chunk
    end
    env.loadstring = dependencyCompile
    local chunk, compileError = dependencyCompile(source, "UniversalSynSaveInstance_Said")
    if not chunk then error("Serializador: " .. tostring(compileError)) end
    local serializer = chunk()
    if type(serializer) ~= "function" then error("El serializador no devolvio una funcion") end
    report.place.sourceStrategy = bridged and "initial_snapshot_cache" or "native_decompiler"
    return serializer, bridged
end

local BINARY_SIGNATURE = "<roblox!" .. string.char(137, 255, 13, 10, 26, 10)
local function u32(data, position)
    local a, b, c, d = data:byte(position, position + 3)
    if not d then error("Cabecera de bloque incompleta") end
    return a + b * 256 + c * 65536 + d * 16777216
end
local function validatePlace(data, binary)
    if type(data) ~= "string" then error("El serializador no devolvio datos") end
    if not binary then
        local opening = data:gsub("^\239\187\191", ""):gsub("^%s*<%?xml.-%?>", "", 1)
        while true do
            local _, last = opening:find("^%s*<!%-%-.-%-%->")
            if not last then break end
            opening = opening:sub(last + 1)
        end
        if not opening:match("^%s*<roblox[%s>]") or not data:match("</roblox>%s*$") then
            error("La salida no es un lugar XML de Roblox")
        end
        return
    end
    if #data < 32 or data:sub(1, 14) ~= BINARY_SIGNATURE or data:sub(15, 16) ~= "\0\0" then
        error("La salida no tiene cabecera binaria .rbxl valida")
    end
    local position, ended = 33, false
    while position <= #data do
        if position + 15 > #data then error("Bloque binario truncado") end
        local tag = data:sub(position, position + 3)
        local compressed, uncompressed = u32(data, position + 4), u32(data, position + 8)
        local length = compressed > 0 and compressed or uncompressed
        local last = position + 15 + length
        if last > #data then error("Contenido de bloque binario truncado") end
        if tag == "END\0" then
            if compressed ~= 0 or uncompressed ~= 9
                or data:sub(position + 16, last) ~= "</roblox>" or last ~= #data then
                error("Final binario incorrecto")
            end
            ended = true
            break
        end
        position = last + 1
    end
    if not ended then error("Falta el bloque final del lugar binario") end
end
local function savePlace(serializer, bridged, binary)
    local extension = binary and "rbxl" or "rbxlx"
    local filePath = folder .. "/" .. basename .. "." .. extension
    local attempt = {format = extension, file = filePath, status = "running"}
    report.place.attempts[#report.place.attempts + 1] = attempt
    local emitted, accepted = false, false
    local ignore = {"CoreGui", "CorePackages", Packages = false}
    if screen then ignore[#ignore + 1] = screen end
    local mayDecompile = bridged or (decompiler and report.scriptsStatus ~= "timeout"
        and report.scriptsStatus ~= "cancelled" and report.scriptsStatus ~= "export_error")
    local callOk, callError = pcall(serializer, {
        Object = game, mode = "full", IsModel = false,
        Binary = binary, CompressionMode = false,
        Decompile = mayDecompile and true or false, DecompileTimeout = TIMEOUT, scriptcache = false,
        FilePath = filePath, Callback = function(data)
            emitted = true
            if cancelled then
                attempt.status = "cancelled"
                error("Exportacion cancelada por el usuario")
            end
            local touched = false
            local ok, problem = pcall(function()
                validatePlace(data, binary)
                touched = true
                writeFile(filePath, data)
                attempt.bytes = #data
                attempt.verification = "serialized_structure"
                if readFile then
                    local readable, stored = pcall(readFile, filePath)
                    if readable then
                        if stored ~= data then error("El archivo escrito no coincide con la salida completa") end
                        attempt.verification = "readback_matches"
                    else
                        attempt.readbackError = tostring(stored)
                    end
                end
            end)
            if not ok then
                attempt.status, attempt.message = "failed", tostring(problem)
                if touched and deleteFile then
                    local deleted, deleteError = pcall(deleteFile, filePath)
                    attempt.rejectedFileRemoved = deleted
                    if not deleted then attempt.cleanupError = tostring(deleteError) end
                end
                error(problem)
            end
            accepted, attempt.status = true, "saved"
            report.place.file, report.place.format, report.place.bytes = filePath, extension, #data
            report.place.verification = attempt.verification
        end,
        IgnoreList = ignore, IgnoreDefaultProperties = false, IgnoreNotArchivable = true,
        IsolateLocalPlayer = true, IsolatePlayers = false, IsolateStarterPlayer = false,
        SavePlayerCharacters = false, SaveNotCreatable = true,
        ReadMe = true, ShowStatus = true, AlternativeWritefile = false,
        SafeMode = false, KillAllScripts = false, BoostFPS = false,
        ShutdownWhenDone = false, AntiIdle = false, CopyToClipboard = false,
    })
    if not callOk then
        if accepted then
            attempt.warning = tostring(callError)
        else
            attempt.status = cancelled and "cancelled" or "failed"
            attempt.message = attempt.message or tostring(callError)
        end
    end
    if not emitted then
        attempt.status = cancelled and "cancelled" or "failed"
        attempt.message = attempt.message or "El serializador termino sin entregar un archivo; revisa su aviso en consola."
    end
    return accepted
end
local function exportPlace()
    phase, report.place.status = "place", "running"
    if cancelled then report.place.status = "cancelled"; return end
    status("Preparando el guardado del lugar .rbxl...\nCarpeta: " .. folder)
    task.wait()
    if cancelled then report.place.status = "cancelled"; return end
    local loaded, serializer, bridged = pcall(loadSerializer)
    if not loaded then
        report.place.status, report.place.error = "failed", tostring(serializer)
        return
    end
    if cancelled then report.place.status = "cancelled"; return end
    status("Guardando mapa, jerarquia, interfaces y scripts visibles...\nArchivo: " .. basename .. ".rbxl")
    local accepted = savePlace(serializer, bridged, true)
    if not accepted and not cancelled then
        status("No se pudo guardar el binario. Intentando .rbxlx...\nLos scripts guardados se conservan.")
        task.wait()
        if not cancelled then accepted = savePlace(serializer, bridged, false) end
    end
    report.place.status = accepted and "saved" or cancelled and "cancelled" or "failed"
end

local scriptsOk, scriptsError = pcall(exportScripts)
if not scriptsOk then report.scriptsStatus, report.scriptsError = "export_error", tostring(scriptsError) end
if not cancelled then
    local placeOk, placeError = pcall(exportPlace)
    if not placeOk then report.place.status, report.place.error = "failed", tostring(placeError) end
else
    report.place.status = "cancelled"
end
report.processed = #report.entries
report.remaining = math.max(0, report.total - report.processed)
report.finishedAt = os.time()
if cancelled then
    report.status = "cancelled"
elseif report.place.status == "saved" then
    local incomplete = report.failed > 0 or report.remaining > 0 or not scriptsOk or #report.scanErrors > 0
        or report.place.uncachedScripts > 0 or report.place.format ~= "rbxl"
        or report.place.verification ~= "readback_matches"
    report.status = incomplete and "completed_with_errors" or "completed"
else
    report.status = report.saved > 0 and "partial" or "failed"
end
local reportSaved, reportError = saveReport()
local message
if report.place.status == "saved" then
    message = "Lugar guardado: " .. basename .. "." .. report.place.format
        .. "\nScripts: " .. report.saved .. " | Fallos: " .. report.failed .. " | Pendientes: " .. report.remaining
        .. "\nCarpeta: " .. folder
elseif cancelled then
    message = "Cancelado. Scripts conservados: " .. report.saved .. "\nCarpeta: " .. folder
else
    local detail = report.place.error
    local last = report.place.attempts[#report.place.attempts]
    if not detail and last then detail = last.message end
    message = "No se pudo guardar el lugar.\nScripts conservados: " .. report.saved
        .. "\n" .. tostring(detail or "Revisa reporte.json y la consola")
        .. "\nCarpeta: " .. folder
end
if not reportSaved then message = message .. "\nNo se pudo actualizar reporte.json: " .. tostring(reportError) end
finish(message, report.place.status ~= "saved" or not reportSaved)
