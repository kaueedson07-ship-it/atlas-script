-- Egg Atlas 1.0 | cliente Luau | interface PT-BR
-- Execute o arquivo inteiro no contexto do cliente.
-- Detectores de ovos são heurísticos; ajuste CONFIG ou o campo de busca.
-- Sem dependências remotas, offsets, hooks ou chamadas a RemoteEvents.
local CONFIG = {
    Keywords = {"egg", "ovo"},
    Tags = {"Egg", "CollectibleEgg", "StealableEgg"},
    MaxMarkers = 16,
    MaxCandidates = 250,
    ScanSeconds = 12,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
assert(player, "Egg Atlas precisa executar no cliente, não no servidor.")
local playerGui = player:WaitForChild("PlayerGui", 15)
assert(playerGui, "PlayerGui indisponível. Aguarde o jogo carregar.")
local GUI_NAME = "EggAtlasClient_v1"
local previous = playerGui:FindFirstChild(GUI_NAME)
if previous then
    local shutdown = previous:FindFirstChild("Shutdown")
    if shutdown and shutdown:IsA("BindableEvent") then shutdown:Fire() end
    previous:Destroy()
end

local C = {
    bg = Color3.fromRGB(15, 18, 27), panel = Color3.fromRGB(23, 28, 40),
    card = Color3.fromRGB(30, 36, 50), border = Color3.fromRGB(47, 56, 73),
    text = Color3.fromRGB(237, 242, 250), muted = Color3.fromRGB(147, 160, 183),
    accent = Color3.fromRGB(112, 228, 187), gold = Color3.fromRGB(255, 205, 109),
    red = Color3.fromRGB(255, 126, 142),
}
local state = {
    alive = true, eggs = false, players = false, labels = true, autoScan = false,
    speed = false, speedValue = 32, jump = false, jumpValue = 75,
    extraJump = false, noclip = false, fly = false, flySpeed = 45,
    bright = false, noFog = false, lowFX = false, fov = false, fovValue = 85,
    range = 1200, selected = nil, walking = false, spectating = false,
    filter = "", sortRare = false,
}
local connections, markers, playerMarkers, waypoints = {}, {}, {}, {}
local candidates, words, scanBusy, lastScan, scanCount = {}, CONFIG.Keywords, false, 0, 0
local scansGeneration = 0
local humanoidSaved = setmetatable({}, {__mode = "k"})
local collisionSaved = setmetatable({}, {__mode = "k"})
local effectSaved = setmetatable({}, {__mode = "k"})
local atmosphereSaved = setmetatable({}, {__mode = "k"})
local cameraSaved = setmetatable({}, {__mode = "k"})
local function connect(signal, callback)
    local conn = signal:Connect(callback)
    table.insert(connections, conn)
    return conn
end
local function new(className, props, parent)
    local obj = Instance.new(className)
    for key, value in pairs(props or {}) do obj[key] = value end
    obj.Parent = parent
    return obj
end
local function corner(obj, radius) new("UICorner", {CornerRadius = UDim.new(0, radius or 10)}, obj) end
local function stroke(obj, color) new("UIStroke", {Color = color or C.border, Thickness = 1}, obj) end
local function text(parent, value, size, color, props)
    local properties = {Text = value, TextSize = size or 14, TextColor3 = color or C.text,
        Font = Enum.Font.Gotham, BackgroundTransparency = 1, BorderSizePixel = 0,
        TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 24)}
    for k, v in pairs(props or {}) do properties[k] = v end
    return new("TextLabel", properties, parent)
end
local function button(parent, title, props)
    local properties = {Text = title, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = C.text, BackgroundColor3 = C.card, BorderSizePixel = 0,
        AutoButtonColor = true, Size = UDim2.new(1, 0, 0, 36)}
    for k, v in pairs(props or {}) do properties[k] = v end
    local b = new("TextButton", properties, parent)
    corner(b, 8)
    return b
end
local gui = new("ScreenGui", {Name = GUI_NAME, ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, playerGui)
local shutdown = new("BindableEvent", {Name = "Shutdown"}, gui)
local worldUI = new("Folder", {Name = "EggAtlasLocal_" .. player.UserId}, workspace)
local main = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(780, 530), BackgroundColor3 = C.bg, BorderSizePixel = 0}, gui)
corner(main, 16); stroke(main)
local uiScale = new("UIScale", {}, main)
local header = new("Frame", {Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1, Active = true}, main)
text(header, "EGG ATLAS", 24, C.text, {Position = UDim2.fromOffset(24, 12), Size = UDim2.fromOffset(290, 30), Font = Enum.Font.GothamBold})
text(header, "STEAL AN EGG  /  CLIENT TOOLS", 10, C.accent, {Position = UDim2.fromOffset(25, 43), Size = UDim2.fromOffset(340, 18)})
local minimize = button(header, "—", {Position = UDim2.new(1, -89, 0, 20), Size = UDim2.fromOffset(30, 30)})
local close = button(header, "×", {Position = UDim2.new(1, -50, 0, 20), Size = UDim2.fromOffset(30, 30), TextColor3 = C.red})
local sidebar = new("Frame", {Position = UDim2.fromOffset(14, 80), Size = UDim2.new(0, 157, 1, -126), BackgroundTransparency = 1}, main)
new("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, sidebar)
local content = new("Frame", {Position = UDim2.fromOffset(186, 80), Size = UDim2.new(1, -202, 1, -126), BackgroundTransparency = 1}, main)
local status = text(main, "Pronto. Abra Ovos e faça uma busca.", 11, C.muted,
    {Position = UDim2.new(0, 24, 1, -32), Size = UDim2.new(1, -48, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd})
local launcher = button(gui, "EA  ·  MENU", {Position = UDim2.new(0, 20, 1, -65), Size = UDim2.fromOffset(132, 38), BackgroundColor3 = C.panel, TextColor3 = C.accent})
stroke(launcher)
local function notify(message, bad)
    if not state.alive then return end
    status.Text = message
    status.TextColor3 = bad and C.red or C.muted
end
local function guarded(callback)
    return function(...)
        if not state.alive then return end
        local ok, err = pcall(callback, ...)
        if not ok then notify("Falha: " .. tostring(err):sub(1, 130), true); warn("[Egg Atlas]", err) end
    end
end
local pages, tabs = {}, {}
local function page(name, index)
    local p = new("ScrollingFrame", {Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = index == 1}, content)
    new("UIPadding", {PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 14)}, p)
    new("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, p)
    local tab = button(sidebar, name, {LayoutOrder = index, TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundColor3 = index == 1 and C.card or C.bg, TextColor3 = index == 1 and C.accent or C.muted})
    new("UIPadding", {PaddingLeft = UDim.new(0, 13)}, tab)
    pages[name], tabs[name] = p, tab
    connect(tab.Activated, function()
        for key, panel in pairs(pages) do
            panel.Visible = key == name
            tabs[key].BackgroundColor3 = key == name and C.card or C.bg
            tabs[key].TextColor3 = key == name and C.accent or C.muted
        end
    end)
    return p
end
local function section(parent, title, subtitle)
    local f = new("Frame", {Size = UDim2.new(1, -1, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.panel, BorderSizePixel = 0}, parent)
    corner(f, 10)
    new("UIPadding", {PaddingTop = UDim.new(0, 13), PaddingBottom = UDim.new(0, 13),
        PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)}, f)
    new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, f)
    text(f, title, 15, C.text, {Font = Enum.Font.GothamBold})
    if subtitle then text(f, subtitle, 12, C.muted, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true}) end
    return f
end
local toggles = {}
local function toggle(parent, label, key, callback)
    local b = button(parent, "", {BackgroundColor3 = C.card, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 38)})
    new("UIPadding", {PaddingLeft = UDim.new(0, 12)}, b)
    local function refresh()
        b.Text = (state[key] and "●  " or "○  ") .. label
        b.TextColor3 = state[key] and C.accent or C.muted
    end
    toggles[key] = refresh
    connect(b.Activated, guarded(function()
        state[key] = not state[key]
        if callback then callback(state[key]) end
        refresh()
    end))
    refresh()
    return b
end
local function action(parent, label, callback)
    local b = button(parent, label)
    connect(b.Activated, guarded(callback))
    return b
end
local function input(parent, hint, initial, callback)
    local box = new("TextBox", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.card,
        TextColor3 = C.text, PlaceholderColor3 = C.muted, PlaceholderText = hint,
        Font = Enum.Font.Gotham, TextSize = 13, Text = initial or "", ClearTextOnFocus = false,
        BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left}, parent)
    corner(box, 8); new("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)}, box)
    if callback then connect(box.FocusLost, guarded(function() callback(box.Text, box) end)) end
    return box
end
local function numberInput(parent, label, key, low, high)
    text(parent, label .. "  [" .. low .. "–" .. high .. "]", 11, C.muted)
    return input(parent, label, tostring(state[key]), function(value, box)
        local number = tonumber(value)
        if number and number == number then state[key] = math.clamp(number, low, high) else notify("Informe um número válido.", true) end
        box.Text = tostring(state[key])
    end)
end
local home = page("Visão geral", 1)
local eggsPage = page("Ovos", 2)
local movePage = page("Movimento", 3)
local placesPage = page("Pontos salvos", 4)
local visualPage = page("Visual", 5)
local settingsPage = page("Configurações", 6)
local intro = section(home, "Seu mapa de possibilidades", "Busque objetos, escolha um alvo e personalize o cliente. Os detectores usam nomes, tags e atributos disponíveis no seu jogo.")
local overview = text(intro, "Aguardando primeira busca…", 13, C.accent, {TextWrapped = true, Size = UDim2.new(1, 0, 0, 56)})
local session = section(home, "Sessão", "RightShift abre ou esconde o menu. O botão EA também funciona no toque. Arraste pela área do título.")
text(session, "PlaceId: " .. tostring(game.PlaceId), 12, C.muted)
text(session, "Jogador: " .. player.DisplayName, 12, C.muted)
text(session, "Alterações de movimento podem ser corrigidas pelo servidor.", 12, C.gold, {TextWrapped = true, Size = UDim2.new(1, 0, 0, 34)})

local function character()
    local model = player.Character
    if not model then return nil, nil, nil end
    return model, model:FindFirstChildOfClass("Humanoid"), model:FindFirstChild("HumanoidRootPart")
end
local function rememberHumanoid(h)
    if h and not humanoidSaved[h] then
        humanoidSaved[h] = {WalkSpeed = h.WalkSpeed, JumpPower = h.JumpPower,
            JumpHeight = h.JumpHeight, PlatformStand = h.PlatformStand, AutoRotate = h.AutoRotate}
    end
end
local function partOf(obj)
    if not obj or not obj:IsDescendantOf(workspace) then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true) end
    return nil
end
local function underCharacter(obj)
    local current = obj
    while current and current ~= workspace do
        if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then return true end
        current = current.Parent
    end
    return false
end
local function nameMatches(name)
    local lower = string.lower(name)
    for _, word in ipairs(words) do if string.find(lower, word, 1, true) then return true end end
    return false
end
local function eggRoot(obj, forced)
    if not (obj:IsA("BasePart") or obj:IsA("Model")) or underCharacter(obj) then return nil end
    local tagged = false
    for _, tag in ipairs(CONFIG.Tags) do if CollectionService:HasTag(obj, tag) then tagged = true; break end end
    if not forced and not tagged and not nameMatches(obj.Name) and obj:GetAttribute("EggId") == nil and obj:GetAttribute("EggType") == nil then return nil end
    local root, ancestor = obj, obj.Parent
    for _ = 1, 4 do
        if not ancestor or ancestor == workspace then break end
        if ancestor:IsA("Model") and nameMatches(ancestor.Name) and partOf(ancestor) then root = ancestor end
        ancestor = ancestor.Parent
    end
    return partOf(root) and root or nil
end
local rank = {common = 1, comum = 1, uncommon = 2, incomum = 2, rare = 3, raro = 3,
    epic = 4, epico = 4, legendary = 5, lendario = 5, mythic = 6, mythical = 6,
    secret = 7, secreto = 7, divine = 8, divino = 8}
local function rarity(obj)
    local value = obj:GetAttribute("Rarity") or obj:GetAttribute("Tier") or obj:GetAttribute("Rareza")
    local child = obj:FindFirstChild("Rarity")
    if value == nil and child and child:IsA("StringValue") then value = child.Value end
    if value == nil then return "?", 0 end
    return tostring(value), rank[string.lower(tostring(value))] or tonumber(value) or 0
end
local function sortedCandidates()
    local _, _, root = character()
    local origin = root and root.Position or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position) or Vector3.zero
    local list = {}
    for _, obj in ipairs(candidates) do
        local p = partOf(obj)
        if p and (state.filter == "" or string.find(string.lower(obj.Name), state.filter, 1, true)) then
            local dist = (p.Position - origin).Magnitude
            local label, score = rarity(obj)
            table.insert(list, {obj = obj, part = p, distance = dist, rarity = label, score = score})
        end
    end
    table.sort(list, function(a, b)
        if state.sortRare and a.score ~= b.score then return a.score > b.score end
        return a.distance < b.distance
    end)
    return list
end
local eggList, targetInfo, refreshList
local function scan()
    if scanBusy then notify("Uma busca já está em andamento."); return end
    scanBusy = true; scansGeneration = scansGeneration + 1
    local generation = scansGeneration
    notify("Buscando objetos carregados no cliente…")
    task.spawn(function()
        local ok, err = pcall(function()
            local found, seen = {}, {}
            local function consider(obj, forced)
                if #found >= CONFIG.MaxCandidates then return end
                local root = eggRoot(obj, forced)
                if root and not seen[root] then seen[root] = true; table.insert(found, root) end
            end
            for _, tag in ipairs(CONFIG.Tags) do for _, obj in ipairs(CollectionService:GetTagged(tag)) do consider(obj, true) end end
            for index, obj in ipairs(workspace:GetDescendants()) do
                if not state.alive or generation ~= scansGeneration then return end
                consider(obj, false)
                if index % 350 == 0 then task.wait() end
            end
            if not state.alive or generation ~= scansGeneration then return end
            candidates, scanCount, lastScan = found, scanCount + 1, os.clock()
            if refreshList then refreshList() end
            notify(string.format("%d candidato(s). Confira os nomes; a detecção é heurística.", #found))
        end)
        scanBusy = false
        if not ok then notify("Busca falhou: " .. tostring(err):sub(1, 100), true) end
    end)
end
local function stopSpectate()
    if state.spectating then
        local camera = workspace.CurrentCamera
        local _, h = character()
        if camera then camera.CameraSubject = h or state.oldSubject end
        state.spectating = false
    end
end
local function stopWalk()
    state.walking = false
    local _, h, root = character()
    if h and root then h:MoveTo(root.Position) end
end
local function teleport(cf)
    local model, h, root = character()
    if not model or not root or not h or h.Health <= 0 then notify("Personagem indisponível.", true); return end
    stopWalk(); stopSpectate()
    model:PivotTo(cf)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    notify("Posição local alterada. O servidor pode corrigir o movimento.")
end
local findSection = section(eggsPage, "Radar de ovos", "Nomes padrão: egg / ovo. A busca inclui apenas objetos já carregados; recipientes e decorações podem aparecer.")
action(findSection, "Buscar / atualizar lista", scan)
toggle(findSection, "Atualizar busca a cada 12 segundos", "autoScan")
toggle(findSection, "Marcar ovos no mundo", "eggs")
toggle(findSection, "Mostrar nome e distância", "labels")
toggle(findSection, "Priorizar raridade informada", "sortRare", function() if refreshList then refreshList() end end)
input(findSection, "Filtrar lista pelo nome", "", function(value) state.filter = string.lower(value); if refreshList then refreshList() end end)
numberInput(findSection, "Alcance das marcações (studs)", "range", 50, 5000)
local targetSection = section(eggsPage, "Alvo selecionado")
targetInfo = text(targetSection, "Nenhum alvo selecionado.", 12, C.accent, {TextWrapped = true, Size = UDim2.new(1, 0, 0, 48)})
action(targetSection, "Selecionar candidato mais próximo", function()
    local list = sortedCandidates()
    local nearest = nil
    for _, item in ipairs(list) do if not nearest or item.distance < nearest.distance then nearest = item end end
    state.selected = nearest and nearest.obj or nil
    if refreshList then refreshList() end
    notify(nearest and ("Selecionado: " .. nearest.obj.Name) or "Nenhum candidato encontrado.")
end)
action(targetSection, "Caminhar até o alvo", function()
    local p = partOf(state.selected)
    local _, h = character()
    if not p or not h then notify("Selecione um alvo válido.", true); return end
    if state.fly then notify("Desative o voo antes de caminhar.", true); return end
    state.walking = true; notify("Caminhando em linha direta. Obstáculos podem impedir a chegada.")
end)
action(targetSection, "Parar caminhada", stopWalk)
action(targetSection, "Teleportar perto do alvo", function()
    local p = partOf(state.selected)
    if p then teleport(p.CFrame * CFrame.new(0, 3, 5)) else notify("Selecione um alvo válido.", true) end
end)
action(targetSection, "Observar alvo / voltar câmera", function()
    if state.spectating then stopSpectate(); return end
    local p = partOf(state.selected)
    local camera = workspace.CurrentCamera
    if not p or not camera then notify("Selecione um alvo válido.", true); return end
    state.oldSubject = camera.CameraSubject
    camera.CameraSubject = p; state.spectating = true
end)
eggList = section(eggsPage, "Candidatos encontrados", "Até 40 resultados na lista; clique em um nome para selecionar.")
local listBody = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1}, eggList)
new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, listBody)
refreshList = function()
    for _, child in ipairs(listBody:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
    local list = sortedCandidates()
    if #list == 0 then text(listBody, "Nenhum resultado. Busque ou ajuste as palavras-chave.", 12, C.muted, {TextWrapped = true, Size = UDim2.new(1, 0, 0, 36)}) end
    for i = 1, math.min(40, #list) do
        local item = list[i]
        local b = button(listBody, string.format("%s  %s  ·  %.0f studs  ·  %s", state.selected == item.obj and "●" or "○", item.obj.Name, item.distance, item.rarity),
            {TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                TextColor3 = state.selected == item.obj and C.accent or C.text})
        new("UIPadding", {PaddingLeft = UDim.new(0, 9)}, b)
        b.Activated:Connect(function() state.selected = item.obj; refreshList() end)
    end
end
refreshList()

local movement = section(movePage, "Velocidade e salto", "Ajustes locais. Não alteram dinheiro, inventário ou permissões do servidor.")
numberInput(movement, "Velocidade de caminhada", "speedValue", 8, 120)
toggle(movement, "Aplicar velocidade personalizada", "speed", function(on)
    local _, h = character(); rememberHumanoid(h)
    if h and not on and humanoidSaved[h] then h.WalkSpeed = humanoidSaved[h].WalkSpeed end
end)
numberInput(movement, "Força de salto (JumpPower)", "jumpValue", 20, 150)
toggle(movement, "Aplicar salto personalizado", "jump", function(on)
    local _, h = character(); rememberHumanoid(h)
    if h and not on and humanoidSaved[h] then h.JumpPower = humanoidSaved[h].JumpPower; h.JumpHeight = humanoidSaved[h].JumpHeight end
end)
toggle(movement, "Permitir saltos no ar", "extraJump")
local function restoreCollisions()
    for part, value in pairs(collisionSaved) do pcall(function() part.CanCollide = value end) end
    table.clear(collisionSaved)
end
local function stopFly()
    state.fly = false
    for h, saved in pairs(humanoidSaved) do pcall(function() h.PlatformStand = saved.PlatformStand; h.AutoRotate = saved.AutoRotate end) end
    local _, _, root = character()
    if root then root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero end
    if toggles.fly then toggles.fly() end
end
local special = section(movePage, "Movimento livre", "Voo: WASD, Espaço sobe, Ctrl esquerdo desce. No toque, use o direcional padrão; voo vertical requer teclado.")
toggle(special, "Atravessar colisões locais", "noclip", function(on) if not on then restoreCollisions() end end)
numberInput(special, "Velocidade de voo", "flySpeed", 10, 100)
toggle(special, "Voo", "fly", function(on)
    if on then stopWalk(); local _, h = character(); rememberHumanoid(h) else stopFly() end
end)
action(special, "Restaurar movimento original", function()
    stopWalk(); stopFly(); restoreCollisions()
    state.speed, state.jump, state.noclip, state.extraJump = false, false, false, false
    for h, saved in pairs(humanoidSaved) do for prop, value in pairs(saved) do pcall(function() h[prop] = value end) end end
    for _, key in ipairs({"speed", "jump", "noclip", "extraJump"}) do toggles[key]() end
    notify("Movimento restaurado.")
end)

local savedSection = section(placesPage, "Seus pontos", "Salve sua base ou qualquer posição atual. Pontos ficam apenas nesta execução e neste servidor.")
local pointName = input(savedSection, "Nome do ponto, ex.: Minha base", "Minha base")
local pointsBody
local function renderPoints()
    for _, child in ipairs(pointsBody:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
    for i, point in ipairs(waypoints) do
        local row = new("Frame", {Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1}, pointsBody)
        local go = button(row, "Ir: " .. point.name, {Size = UDim2.new(1, -46, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd})
        local remove = button(row, "×", {Position = UDim2.new(1, -38, 0, 0), Size = UDim2.fromOffset(38, 38), TextColor3 = C.red})
        go.Activated:Connect(guarded(function() teleport(point.cf) end))
        remove.Activated:Connect(function() table.remove(waypoints, i); renderPoints() end)
    end
end
action(savedSection, "Salvar posição atual", function()
    local _, _, root = character()
    if not root then notify("Personagem indisponível.", true); return end
    local name = pointName.Text:sub(1, 48)
    if name:match("^%s*$") then name = "Ponto " .. (#waypoints + 1) end
    for _, point in ipairs(waypoints) do if point.name == name then point.cf = root.CFrame; renderPoints(); notify("Ponto atualizado."); return end end
    if #waypoints >= 12 then notify("Limite de 12 pontos. Remova um para salvar outro.", true); return end
    table.insert(waypoints, {name = name, cf = root.CFrame}); renderPoints(); notify("Ponto salvo: " .. name)
end)
pointsBody = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1}, savedSection)
new("UIListLayout", {Padding = UDim.new(0, 6)}, pointsBody)

local function applyEffect(obj)
    if obj:IsA("PostEffect") or obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
        if effectSaved[obj] == nil then effectSaved[obj] = obj.Enabled end
        obj.Enabled = false
    end
end
local function restoreEffects()
    for obj, enabled in pairs(effectSaved) do pcall(function() obj.Enabled = enabled end) end
    table.clear(effectSaved)
end
local lightSaved = {}
local function lightOverride(key, value, enabled)
    if enabled then
        if lightSaved[key] == nil then lightSaved[key] = Lighting[key] end
        Lighting[key] = value
    elseif lightSaved[key] ~= nil then
        Lighting[key] = lightSaved[key]; lightSaved[key] = nil
    end
end
local function applyLighting()
    lightOverride("Brightness", 2, state.bright)
    lightOverride("ClockTime", 14, state.bright)
    lightOverride("GlobalShadows", false, state.bright)
    lightOverride("Ambient", Color3.fromRGB(180, 180, 180), state.bright)
    lightOverride("OutdoorAmbient", Color3.fromRGB(180, 180, 180), state.bright)
    lightOverride("FogStart", 100000, state.noFog)
    lightOverride("FogEnd", 1000000, state.noFog)
    if state.noFog then
        for _, obj in ipairs(Lighting:GetChildren()) do
            if obj:IsA("Atmosphere") then
                if not atmosphereSaved[obj] then atmosphereSaved[obj] = {Density = obj.Density, Haze = obj.Haze} end
                obj.Density, obj.Haze = 0, 0
            end
        end
    else
        for obj, saved in pairs(atmosphereSaved) do pcall(function() obj.Density = saved.Density; obj.Haze = saved.Haze end) end
        table.clear(atmosphereSaved)
    end
end

local v = section(visualPage, "Visibilidade")
toggle(v, "Iluminação clara", "bright", applyLighting)
toggle(v, "Reduzir neblina", "noFog", applyLighting)
toggle(v, "Reduzir partículas e pós-efeitos", "lowFX", function(on)
    if on then
        task.spawn(function()
            for index, obj in ipairs(game:GetDescendants()) do
                if not state.alive or not state.lowFX then break end
                if obj:IsDescendantOf(workspace) or obj:IsDescendantOf(Lighting) then pcall(applyEffect, obj) end
                if index % 350 == 0 then task.wait() end
            end
        end)
    else restoreEffects() end
end)
toggle(v, "Nome e distância dos jogadores", "players")
local cameraSection = section(visualPage, "Câmera")
numberInput(cameraSection, "Campo de visão", "fovValue", 40, 110)
toggle(cameraSection, "Aplicar campo de visão", "fov", function(on)
    if not on then for camera, value in pairs(cameraSaved) do pcall(function() camera.FieldOfView = value end) end; table.clear(cameraSaved) end
end)
action(cameraSection, "Voltar câmera ao personagem", stopSpectate)

local detector = section(settingsPage, "Ajustar detecção", "Palavras separadas por vírgula. Atributos EggId/EggType e tags de CONFIG também são considerados. Raridade só aparece quando existe no objeto.")
input(detector, "egg,ovo", table.concat(CONFIG.Keywords, ","), function(value)
    local updated = {}
    for word in value:gmatch("[^,]+") do
        word = string.lower(word):match("^%s*(.-)%s*$")
        if #word > 0 then table.insert(updated, word) end
    end
    if #updated == 0 then notify("Informe ao menos uma palavra-chave.", true); return end
    words = updated; scan()
end)
local reportSection = section(settingsPage, "Diagnóstico local", "Gera um relatório com PlaceId, nomes e caminhos dos candidatos. O relatório não é enviado pela rede.")
local reportBox = new("TextBox", {Text = "Clique em Gerar relatório.", ClearTextOnFocus = false,
    MultiLine = true, TextEditable = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, TextSize = 11, Font = Enum.Font.Code,
    BackgroundColor3 = C.card, TextColor3 = C.muted, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 115)}, reportSection)
corner(reportBox, 6)
action(reportSection, "Gerar relatório / copiar se disponível", function()
    local report = {version = "1.0", placeId = game.PlaceId, gameId = game.GameId,
        keywords = words, scans = scanCount, candidates = {}, workspaceRoots = {}}
    for _, obj in ipairs(workspace:GetChildren()) do table.insert(report.workspaceRoots, {name = obj.Name, class = obj.ClassName}) end
    for _, item in ipairs(sortedCandidates()) do
        if #report.candidates >= 60 then break end
        table.insert(report.candidates, {name = item.obj.Name, class = item.obj.ClassName,
            path = item.obj:GetFullName(), rarity = item.rarity, distance = math.floor(item.distance)})
    end
    local encoded = HttpService:JSONEncode(report)
    reportBox.Text = encoded
    local copied = type(setclipboard) == "function" and pcall(setclipboard, encoded)
    notify(copied and "Relatório copiado." or "Relatório gerado. Selecione o texto para copiar.")
end)
local cleanup
local systemSection = section(settingsPage, "Interface", "RightShift: abrir/esconder. Descarregar remove marcações e restaura as propriedades alteradas por este script.")
action(systemSection, "Centralizar menu", function() main.Position = UDim2.fromScale(0.5, 0.5) end)
action(systemSection, "Descarregar e restaurar", function() cleanup() end)

local function destroyMarker(marker)
    if marker.highlight then marker.highlight:Destroy() end
    marker.billboard:Destroy()
end
local function makeMarker(obj, part, isPlayer)
    local billboard = new("BillboardGui", {Adornee = part, AlwaysOnTop = true,
        Size = UDim2.fromOffset(190, 44), StudsOffsetWorldSpace = Vector3.new(0, 3, 0),
        MaxDistance = state.range}, worldUI)
    local label = text(billboard, "", 12, isPlayer and C.text or C.accent,
        {Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
            TextStrokeTransparency = 0.35, TextWrapped = true, Font = Enum.Font.GothamBold})
    local highlight = nil
    if not isPlayer then
        highlight = new("Highlight", {Adornee = obj, FillColor = C.accent, OutlineColor = C.accent,
            FillTransparency = 0.8, OutlineTransparency = 0.1, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop}, worldUI)
    end
    return {billboard = billboard, label = label, highlight = highlight}
end
local function updateMarkers()
    local wanted, list = {}, sortedCandidates()
    if state.eggs then
        for _, item in ipairs(list) do
            if item.distance <= state.range and #wanted < CONFIG.MaxMarkers then table.insert(wanted, item) end
        end
    end
    local keep = {}
    for _, item in ipairs(wanted) do
        local obj = item.obj
        keep[obj] = true
        local marker = markers[obj]
        if not marker then marker = makeMarker(obj, item.part, false); markers[obj] = marker end
        marker.billboard.Adornee = item.part; marker.billboard.MaxDistance = state.range
        marker.billboard.Enabled = state.labels
        marker.label.Text = string.format("%s\n%.0f studs  ·  %s", obj.Name, item.distance, item.rarity)
        local color = obj == state.selected and C.gold or C.accent
        marker.highlight.FillColor = color; marker.highlight.OutlineColor = color; marker.label.TextColor3 = color
    end
    for obj, marker in pairs(markers) do if not keep[obj] then destroyMarker(marker); markers[obj] = nil end end
    local playerKeep = {}
    if state.players then
        local _, _, root = character()
        local nearby = {}
        for _, other in ipairs(Players:GetPlayers()) do
            local model = other.Character
            local p = model and (model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart"))
            if other ~= player and p and root then
                local distance = (p.Position - root.Position).Magnitude
                if distance <= state.range then table.insert(nearby, {player = other, part = p, distance = distance}) end
            end
        end
        table.sort(nearby, function(a, b) return a.distance < b.distance end)
        for i = 1, math.min(12, #nearby) do
            local item = nearby[i]; local other = item.player
            playerKeep[other] = true
            local marker = playerMarkers[other]
            if not marker then marker = makeMarker(other.Character, item.part, true); playerMarkers[other] = marker end
            marker.billboard.Adornee = item.part; marker.billboard.MaxDistance = state.range
            marker.label.Text = string.format("%s\n%.0f studs", other.DisplayName, item.distance)
        end
    end
    for obj, marker in pairs(playerMarkers) do if not playerKeep[obj] then destroyMarker(marker); playerMarkers[obj] = nil end end
    local _, h, root = character()
    overview.Text = string.format("%d candidatos  ·  %d jogadores  ·  %.0f FPS\nVida: %s  ·  Buscas: %d", #list, #Players:GetPlayers(), state.fps or 0,
        h and tostring(math.floor(h.Health)) or "—", scanCount)
    local p = partOf(state.selected)
    if p then
        local label = rarity(state.selected)
        targetInfo.Text = string.format("%s  ·  %s\nDistância: %s studs", state.selected.Name, label, root and tostring(math.floor((p.Position - root.Position).Magnitude)) or "?")
    else
        state.selected = nil; targetInfo.Text = "Nenhum alvo selecionado."
        if state.spectating then stopSpectate() end
    end
end
local frameCount, frameTime, tickTime, walkTime, listTime = 0, 0, 0, 0, 0
connect(RunService.RenderStepped, function(dt)
    frameCount, frameTime = frameCount + 1, frameTime + dt
    if frameTime >= 1 then state.fps = frameCount / frameTime; frameCount, frameTime = 0, 0 end
end)
connect(RunService.Stepped, function()
    if not state.noclip then return end
    local model = player.Character
    if model then
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                if collisionSaved[part] == nil then collisionSaved[part] = part.CanCollide end
                part.CanCollide = false
            end
        end
    end
end)
connect(RunService.Heartbeat, guarded(function(dt)
    local _, h, root = character()
    if h and h.Health > 0 then
        if state.speed or state.jump or state.fly then rememberHumanoid(h) end
        if state.speed then h.WalkSpeed = state.speedValue end
        if state.jump then
            if h.UseJumpPower then h.JumpPower = state.jumpValue
            else h.JumpHeight = state.jumpValue * state.jumpValue / (2 * math.max(workspace.Gravity, 1)) end
        end
        if state.fly and root and workspace.CurrentCamera then
            h.PlatformStand = true; h.AutoRotate = false
            local direction = Vector3.zero
            if not UIS:GetFocusedTextBox() then
                local cf = workspace.CurrentCamera.CFrame
                if UIS:IsKeyDown(Enum.KeyCode.W) then direction = direction + cf.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.S) then direction = direction - cf.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.D) then direction = direction + cf.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.A) then direction = direction - cf.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.Space) then direction = direction + Vector3.yAxis end
                if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then direction = direction - Vector3.yAxis end
                if UIS.TouchEnabled and direction.Magnitude == 0 then direction = h.MoveDirection end
            end
            if direction.Magnitude > 1 then direction = direction.Unit end
            root.AssemblyLinearVelocity = direction * state.flySpeed
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end
    local camera = workspace.CurrentCamera
    if state.fov and camera then
        if cameraSaved[camera] == nil then cameraSaved[camera] = camera.FieldOfView end
        camera.FieldOfView = state.fovValue
    end
    tickTime, walkTime, listTime = tickTime + dt, walkTime + dt, listTime + dt
    if state.walking and walkTime >= 0.4 then
        walkTime = 0
        local p = partOf(state.selected)
        if not p or not h or not root or h.Health <= 0 then stopWalk()
        elseif (p.Position - root.Position).Magnitude < 6 then stopWalk(); notify("Você chegou perto do alvo. Interaja normalmente no jogo.")
        else h:MoveTo(p.Position) end
    end
    if tickTime >= 0.35 then tickTime = 0; updateMarkers() end
    if listTime >= 4 then listTime = 0; if eggsPage.Visible then refreshList() end end
    if state.autoScan and not scanBusy and os.clock() - lastScan >= CONFIG.ScanSeconds then scan() end
end))
connect(UIS.JumpRequest, function()
    if state.extraJump and not state.fly and not UIS:GetFocusedTextBox() then
        local _, h = character()
        if h and h.Health > 0 then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)
connect(workspace.DescendantAdded, function(obj) if state.lowFX then pcall(applyEffect, obj) end end)
connect(Lighting.DescendantAdded, function(obj)
    if state.lowFX then pcall(applyEffect, obj) end
    if state.noFog and obj:IsA("Atmosphere") then
        atmosphereSaved[obj] = {Density = obj.Density, Haze = obj.Haze}; obj.Density, obj.Haze = 0, 0
    end
end)
connect(player.CharacterAdded, function()
    stopWalk(); stopSpectate(); restoreCollisions()
    notify("Personagem recarregado; opções ativas serão reaplicadas.")
end)
local dragging, dragInput, dragStart, dragPosition
connect(header.InputBegan, function(inputObject)
    if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, dragPosition = true, inputObject.Position, main.Position
        if inputObject.UserInputType == Enum.UserInputType.Touch then dragInput = inputObject end
    end
end)
connect(header.InputChanged, function(inputObject)
    if inputObject.UserInputType == Enum.UserInputType.MouseMovement then dragInput = inputObject end
end)
connect(UIS.InputChanged, function(inputObject)
    if dragging and inputObject == dragInput then
        local delta = inputObject.Position - dragStart
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
        if viewport then
            local x = dragPosition.X.Scale * viewport.X + dragPosition.X.Offset + delta.X
            local y = dragPosition.Y.Scale * viewport.Y + dragPosition.Y.Offset + delta.Y
            local halfWidth, halfHeight = 390 * uiScale.Scale, 265 * uiScale.Scale
            main.Position = UDim2.fromOffset(math.clamp(x, halfWidth, math.max(halfWidth, viewport.X - halfWidth)),
                math.clamp(y, halfHeight, math.max(halfHeight, viewport.Y - halfHeight)))
        end
    end
end)
connect(UIS.InputEnded, function(inputObject)
    if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject == dragInput then dragging = false end
end)
local function showHide() main.Visible = not main.Visible end
connect(launcher.Activated, showHide); connect(minimize.Activated, showHide)
connect(UIS.InputBegan, function(inputObject, processed)
    if not processed and not UIS:GetFocusedTextBox() and inputObject.KeyCode == Enum.KeyCode.RightShift then showHide() end
end)
local resizeClock = 0
connect(RunService.RenderStepped, function(dt)
    resizeClock = resizeClock + dt
    if resizeClock < 0.5 then return end
    resizeClock = 0
    local camera = workspace.CurrentCamera
    if camera then
        local size = camera.ViewportSize
        uiScale.Scale = math.clamp(math.min((size.X - 24) / 780, (size.Y - 24) / 530), 0.3, 1)
    end
end)
cleanup = function()
    if not state.alive then return end
    state.alive = false; scansGeneration = scansGeneration + 1
    for _, conn in ipairs(connections) do conn:Disconnect() end
    stopWalk(); stopSpectate(); stopFly(); restoreCollisions(); restoreEffects()
    for h, saved in pairs(humanoidSaved) do for prop, value in pairs(saved) do pcall(function() h[prop] = value end) end end
    for camera, value in pairs(cameraSaved) do pcall(function() camera.FieldOfView = value end) end
    if state.bright or state.noFog then
        state.bright, state.noFog = false, false; pcall(applyLighting)
    end
    worldUI:Destroy()
    gui:Destroy()
end
connect(shutdown.Event, cleanup)
connect(close.Activated, cleanup)
connect(gui.Destroying, cleanup)
notify("Egg Atlas carregado. Abra Ovos → Buscar. RightShift alterna o menu.")
print("[Egg Atlas] Interface pronta. PlaceId:", game.PlaceId, "| Nenhum offset ou código remoto utilizado.")
