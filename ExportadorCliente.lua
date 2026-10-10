-- Exportador de scripts visibles en el cliente, v2.
-- Requiere decompile, writefile y makefolder proporcionados por el executor.
-- Cada resultado va a un archivo .lua. No genera mapas ni archivos .rbxl.
-- Guarda el resultado del descompilador sin garantizar su fidelidad.
-- No descarga codigo, no ejecuta los scripts encontrados ni envia datos.

local TIMEOUT = 15 -- Limite por llamada si el descompilador permite ceder el hilo.
print("[Exportador] v2 iniciado. Preparando ventana...")

local function capability(name)
    local environments = {}
    if type(getfenv) == "function" then
        local ok, environment = pcall(function()
            return getfenv()
        end)
        if ok and type(environment) == "table" then
            environments[#environments + 1] = environment
        end
    end
    if type(getgenv) == "function" then
        local ok, environment = pcall(getgenv)
        if ok and type(environment) == "table" then
            environments[#environments + 1] = environment
        end
    end
    for _, environment in ipairs(environments) do
        if type(environment[name]) == "function" then
            return environment[name]
        end
    end
end

-- Primero usa los globales del script; algunos executors los exponen aqui.
local decompiler = type(decompile) == "function" and decompile or capability("decompile")
local writeFile = type(writefile) == "function" and writefile or capability("writefile")
local makeFolder = type(makefolder) == "function" and makefolder or capability("makefolder")

local http = game:GetService("HttpService")
local players = game:GetService("Players")
local folder = "ClienteScripts_" .. tostring(game.PlaceId) .. "_" .. http:GenerateGUID(false)
local reportPath = folder .. "/reporte.json"
local report = {
    version = 2,
    placeId = game.PlaceId,
    startedAt = os.time(),
    folder = folder,
    status = "running",
    total = 0,
    saved = 0,
    failed = 0,
    entries = {},
    scanErrors = {},
    notes = {
        "Solo scripts presentes en las ubicaciones del cliente revisadas al iniciar.",
        "Los archivos contienen el texto devuelto por decompile; no se ha verificado su funcionamiento.",
        "Sin scripts exclusivos del servidor, mapa, modelos ni interfaces exportadas.",
        "La cancelacion y el limite de tiempo requieren que el descompilador permita ceder el hilo.",
    },
}

local function saveReport()
    return pcall(function()
        writeFile(reportPath, http:JSONEncode(report))
    end)
end

local cancelled, finished = false, false
local screen, statusLabel, button
local function create(className, properties, parent)
    local instance = Instance.new(className)
    for key, value in pairs(properties) do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end

-- La exportacion puede continuar por consola aunque la interfaz no se cree.
local uiOk, uiError = pcall(function()
    local player = players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
    if not playerGui and player then
        playerGui = player:WaitForChild("PlayerGui", 5)
    end
    local guiParent = playerGui
    if type(gethui) == "function" then
        local found, container = pcall(gethui)
        if found and typeof(container) == "Instance" then
            guiParent = container
        end
    end
    if not guiParent then
        error("No hay un contenedor disponible para mostrar la ventana")
    end
    screen = create("ScreenGui", {
        Name = "ExportadorCliente_" .. http:GenerateGUID(false),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 10000,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, guiParent)
    local frame = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 0.97, 0),
        Size = UDim2.new(0.92, 0, 0, 195),
        BackgroundColor3 = Color3.fromRGB(20, 26, 22),
        BorderSizePixel = 0,
    }, screen)
    create("UISizeConstraint", {MaxSize = Vector2.new(470, 195)}, frame)
    create("UICorner", {CornerRadius = UDim.new(0, 12)}, frame)
    create("TextLabel", {
        Position = UDim2.new(0, 16, 0, 10),
        Size = UDim2.new(1, -32, 0, 28),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = Color3.fromRGB(110, 235, 147),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Exportador de scripts del cliente",
    }, frame)
    statusLabel = create("TextLabel", {
        Position = UDim2.new(0, 16, 0, 42),
        Size = UDim2.new(1, -32, 0, 90),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(235, 240, 237),
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = "Exportador v2 iniciado. Comprobando funciones...",
    }, frame)
    button = create("TextButton", {
        Position = UDim2.new(0, 16, 1, -48),
        Size = UDim2.new(1, -32, 0, 34),
        BackgroundColor3 = Color3.fromRGB(57, 96, 67),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Text = "Cancelar",
    }, frame)
    create("UICorner", {CornerRadius = UDim.new(0, 8)}, button)
    button.Activated:Connect(function()
        if finished then
            screen:Destroy()
        else
            cancelled = true
            button.Text = "Cancelando..."
        end
    end)
end)
if not uiOk then
    warn("[Exportador] Error al crear la ventana: " .. tostring(uiError))
    if screen then
        screen:Destroy()
        screen, statusLabel, button = nil, nil, nil
    end
end

local function status(message)
    print("[Exportador] " .. message)
    if statusLabel then
        pcall(function()
            statusLabel.Text = message
        end)
    else
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Exportador de scripts",
                Text = message,
                Duration = 15,
            })
        end)
    end
end

local function stop(message)
    finished = true
    status(message)
    warn("[Exportador] " .. message)
    if statusLabel then
        pcall(function()
            statusLabel.TextColor3 = Color3.fromRGB(255, 160, 150)
        end)
    end
    if button then
        pcall(function()
            button.Text = "Cerrar"
        end)
    end
end

local missing = {}
if type(decompiler) ~= "function" then missing[#missing + 1] = "decompile" end
if type(writeFile) ~= "function" then missing[#missing + 1] = "writefile" end
if type(makeFolder) ~= "function" then missing[#missing + 1] = "makefolder" end
status("Funciones detectadas:\ndecompile: " .. type(decompiler)
    .. " | writefile: " .. type(writeFile) .. " | makefolder: " .. type(makeFolder))
task.wait()
if #missing > 0 then
    stop("Faltan funciones del executor: " .. table.concat(missing, ", ")
        .. ".\nLa exportacion no ha iniciado.")
    return
end

status("Preparando la carpeta de salida...")
task.wait()
if cancelled then
    stop("Cancelado antes de comenzar.")
    return
end
local ok, problem = pcall(makeFolder, folder)
if not ok then
    stop("No se pudo crear la carpeta:\n" .. tostring(problem))
    return
end
ok, problem = saveReport()
if not ok then
    stop("No se pudo escribir el reporte:\n" .. tostring(problem))
    return
end

local function isClientScript(instance)
    if instance:IsA("LocalScript") or instance:IsA("ModuleScript") then
        return true
    end
    if instance:IsA("Script") then
        local readable, context = pcall(function()
            return instance.RunContext
        end)
        return readable and context == Enum.RunContext.Client
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
    while not complete and not cancelled and os.clock() < deadline do
        task.wait(0.05)
    end
    if not complete then
        pcall(task.cancel, worker)
        if cancelled then
            return false, "Cancelado por el usuario", "cancelled"
        end
        return false, "El descompilador supero el limite de tiempo", "timeout"
    end
    if not success then
        return false, tostring(result), "decompile_error"
    end
    if type(result) ~= "string" or not result:find("%S") then
        return false, "El descompilador no devolvio texto", "empty_result"
    end
    return true, result, "saved"
end

local function export()
    local roots = {}
    for _, serviceName in ipairs({
        "Workspace", "ReplicatedFirst", "ReplicatedStorage",
        "StarterGui", "StarterPlayer", "StarterPack",
    }) do
        roots[#roots + 1] = game:GetService(serviceName)
    end
    if players.LocalPlayer then
        roots[#roots + 1] = players.LocalPlayer
    end
    local candidates, seen = {}, {}
    for _, root in ipairs(roots) do
        local readOk, descendants = pcall(function()
            return root:GetDescendants()
        end)
        if readOk then
            for _, instance in ipairs(descendants) do
                if not seen[instance] and isClientScript(instance) then
                    seen[instance] = true
                    candidates[#candidates + 1] = {
                        instance = instance,
                        path = instance:GetFullName(),
                        name = instance.Name,
                        class = instance.ClassName,
                        scanIndex = #candidates + 1,
                    }
                end
            end
        else
            report.scanErrors[#report.scanErrors + 1] = {
                root = root.Name, message = tostring(descendants),
            }
        end
        task.wait()
        if cancelled then
            report.status = "cancelled"
            return
        end
    end
    table.sort(candidates, function(a, b)
        if a.path == b.path then
            return a.scanIndex < b.scanIndex
        end
        return a.path < b.path
    end)
    report.total = #candidates
    local checkpointOk, checkpointError = saveReport()
    if not checkpointOk then
        error("No se pudo guardar el inventario: " .. tostring(checkpointError))
    end

    for index, candidate in ipairs(candidates) do
        if cancelled then
            report.status = "cancelled"
            return
        end
        status(string.format("%d / %d: %s\nGuardados: %d | Fallos: %d",
            index, #candidates, candidate.name, report.saved, report.failed))
        task.wait() -- Permite actualizar la interfaz antes de llamar al descompilador.
        if cancelled then
            report.status = "cancelled"
            return
        end
        local recovered, result, outcome = decompileOne(candidate.instance)
        local entry = {
            path = candidate.path, class = candidate.class, status = outcome,
        }
        if recovered then
            local safeName = candidate.name:gsub("[^%w_-]", "_"):sub(1, 64)
            local filename = string.format("%05d_%s.lua", index, safeName)
            local filePath = folder .. "/" .. filename
            local written, writeError = pcall(writeFile, filePath,
                "-- Ruta original: " .. http:JSONEncode(candidate.path) .. "\n"
                .. "-- Texto devuelto por decompile; funcionamiento no verificado.\n\n"
                .. result)
            if written then
                entry.file = filename
                entry.bytes = #result
                report.saved = report.saved + 1
            else
                entry.status = "write_error"
                entry.message = tostring(writeError)
                report.failed = report.failed + 1
                report.status = "write_error"
            end
        else
            entry.message = result
            report.failed = report.failed + 1
        end
        report.entries[#report.entries + 1] = entry
        if outcome == "timeout" or outcome == "cancelled" then
            report.status = outcome
            return -- Evita acumular nuevas llamadas tras un bloqueo.
        end
        if report.status == "write_error" then
            return
        end
        if index % 10 == 0 then
            checkpointOk, checkpointError = saveReport()
            if not checkpointOk then
                error("No se pudo actualizar el reporte: " .. tostring(checkpointError))
            end
        end
        task.wait()
    end
    if report.total == 0 then
        report.status = "no_scripts"
    elseif #report.scanErrors > 0 or report.failed > 0 then
        report.status = "completed_with_errors"
    else
        report.status = "completed"
    end
end

local exported, exportError = pcall(export)
if not exported then
    report.status = "export_error"
    report.error = tostring(exportError)
end
report.finishedAt = os.time()
report.processed = #report.entries
report.remaining = math.max(0, report.total - report.processed)
local reportSaved, reportError = saveReport()
finished = true
if button then
    pcall(function()
        button.Text = "Cerrar"
    end)
end
status(string.format("Estado: %s\nGuardados: %d | Fallos: %d | Pendientes: %d\nCarpeta: %s",
    report.status, report.saved, report.failed, report.remaining, folder))
if not reportSaved then
    warn("[Exportador] El reporte final no pudo guardarse: " .. tostring(reportError))
end
if not exported then
    warn("[Exportador] " .. tostring(exportError))
end
