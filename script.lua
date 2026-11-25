--========================================================
-- BUBBA SCRIPTS | BUBBA UI
-- CINEMATIC LOADING SCREEN + 24 THEMES
-- CRYSTAL PURPLE LIGHT-LINE LOADING LOOK
-- SWEEPING LIGHT STREAKS + ROTATING RAYS + PARTICLES
-- FIXED 100% COMPLETION + CLEAN FADE TRANSITION
-- THEME-SYNCED UNLOAD + RESIZE BUTTONS
-- SCROLLABLE THEME SELECTOR
-- INFO TAB + LIVE FPS + PLAYER INFORMATION
-- CONFIGS TAB + CHARACTER MODIFIERS
-- MOBILE B / MINUS CONTROLS + PC RIGHT SHIFT CONTROL
-- PC DEVICE-DETECTION NOTIFICATION (bottom corner)
-- TELEPORT TAB + VIEW PLAYER SYSTEM + CLICK TELEPORT + LIVE PLAYER LIST
-- OWNER IDENTITY: OWNER TAG + RAINBOW OWNER TAB (adenrobers only)
-- THE BUBBA CURTAIN CALL: cinematic unload sequence
-- AUTO-BOOT ON JOIN + GAME AUTO-DETECTION (drop into auto-execute)
-- LocalScript | StarterPlayerScripts
--========================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

--[[ ================================================================
    AUTO-BOOT ENGINE
    Put this file in your executor's AUTO-EXECUTE folder and forget
    about it. It now survives being fired at ANY point of the join
    process on ANY game:

      1. If the script runs while Roblox is still on its loading
         screen, it parks here until the DataModel finishes loading
         (event path + poll path, double redundant).
      2. LocalPlayer is polled briefly in case auto-exec beat the
         Player object into existence.
      3. PlayerGui is awaited the same way before a single UI
         element is built.
      4. A BOOT SUPERVISOR timer is armed before construction even
         starts: if any build step throws on a live executor and
         the intro never runs, the supervisor force-reveals the
         hub window anyway, so the UI can never silently fail.
    After the gate the cinematic boot and the hub window run
    themselves. Nothing to press, on any game, on any server,
    including after teleports (auto-exec re-fires on arrival).
================================================================ ]]
local BOOT_GATE_TIMEOUT=45

local function GameFullyLoaded()
    local loaded=true
    pcall(function() loaded=game:IsLoaded() end)
    return loaded==true
end

if not GameFullyLoaded() then
    print("[BUBBA AUTO-BOOT]: game still loading, holding the boot until you are in...")

    local signalled=false
    local loadedConnection=nil
    pcall(function()
        loadedConnection=game.Loaded:Connect(function()
            signalled=true
        end)
    end)

    local gateStart=os.clock()
    while not signalled and not GameFullyLoaded() do
        if os.clock()-gateStart>BOOT_GATE_TIMEOUT then
            warn("[BUBBA AUTO-BOOT]: game load wait timed out, booting anyway")
            break
        end
        task.wait(0.25)
    end

    if loadedConnection then
        pcall(function() loadedConnection:Disconnect() end)
    end

    print("[BUBBA AUTO-BOOT]: join complete, booting the hub")
end

local Player=Players.LocalPlayer
if not Player then
    -- extremely early auto-exec can land here for a frame or two
    local playerStart=os.clock()
    while not Player and os.clock()-playerStart<45 do
        task.wait(0.1)
        Player=Players.LocalPlayer
    end
end

if not Player then
    warn("[BUBBA AUTO-BOOT]: LocalPlayer never appeared on this client; cannot build the hub UI")
    return
end

local PlayerGui=Player:FindFirstChild("PlayerGui") or Player:FindFirstChildOfClass("PlayerGui")
if not PlayerGui then
    local guiStart=os.clock()
    while not PlayerGui and os.clock()-guiStart<45 do
        task.wait(0.2)
        PlayerGui=Player:FindFirstChild("PlayerGui") or Player:FindFirstChildOfClass("PlayerGui")
    end
end
if not PlayerGui then
    -- bounded final wait: a bare WaitForChild could hang the boot forever
    PlayerGui=Player:WaitForChild("PlayerGui",30)
end

if not PlayerGui then
    warn("[BUBBA AUTO-BOOT]: PlayerGui was never created for this session; cannot build the hub UI")
    return
end

--[[ ================================================================
    GAME AUTO-DETECTION
    Resolves exactly which experience you are playing, with three
    layers so every game on the platform is covered:
      layer 1: offline database of verified popular games (instant)
      layer 2: MarketplaceService product lookup (any public game)
      layer 3: DataModel name (studio / private fallback)
    The resolved name is pushed to every surface that registers an
    updater: the boot terminal line, the loading status, the Home
    hero game chip and the Info tab game card. This is detection,
    not a notification — the hub just knows where it is.
================================================================ ]]
local MarketplaceService=nil
pcall(function()
    MarketplaceService=game:GetService("MarketplaceService")
end)

local KnownGames={
    [2788229376]="Da Hood",
    [2753915549]="Blox Fruits",
    [4924922222]="Brookhaven RP",
    [920587237]="Adopt Me!",
    [142823291]="Murder Mystery 2",
    [6516141723]="DOORS",
    [8737899170]="Pet Simulator 99",
    [286090429]="Arsenal",
    [606849621]="Jailbreak",
    [1962086868]="Tower of Hell",
    [13772394625]="Blade Ball",
    [126884695634066]="Grow a Garden",
    [116495829188952]="Dead Rails",
    [185655149]="Welcome to Bloxburg",
    [189707]="Natural Disaster Survival"
}

local DetectedGame={
    PlaceId=game.PlaceId,
    JobId=game.JobId,
    Name=KnownGames[game.PlaceId],
    Source=KnownGames[game.PlaceId] and "database" or nil
}

local GameUpdaters={}
local gameResolved=DetectedGame.Name~=nil

local function PushGameName(name,source)
    if not name or name=="" then return end

    local improved=false
    if not DetectedGame.Name then
        improved=true
    elseif source=="marketplace" and DetectedGame.Source~="marketplace" and DetectedGame.Source~="database" then
        improved=true
    end
    if not improved then return end

    DetectedGame.Name=name
    DetectedGame.Source=source
    gameResolved=true

    for _,update in ipairs(GameUpdaters) do
        pcall(update,name,source)
    end
end

local function OnGameResolved(update)
    table.insert(GameUpdaters,update)
    if gameResolved then
        pcall(update,DetectedGame.Name,DetectedGame.Source)
    end
end

-- async marketplace resolution: never blocks the UI boot for a second.
-- the lookup is attempted twice (executors frequently rate-limit the
-- first request while the join is still settling), then falls back.
if not gameResolved then
    task.spawn(function()
        if MarketplaceService then
            for attempt=1,2 do
                local ok,info=pcall(function()
                    return MarketplaceService:GetProductInfo(game.PlaceId)
                end)
                if ok and type(info)=="table" then
                    local name=tostring(info.Name or "")
                    if name~="" then
                        PushGameName(name,"marketplace")
                        return
                    end
                end
                if attempt==1 then task.wait(2) end
            end
        end

        -- last resort: the DataModel name
        local dataModelName=""
        pcall(function() dataModelName=tostring(game.Name or "") end)
        if dataModelName~="" and dataModelName~="Workspace" then
            PushGameName(dataModelName,"datamodel")
        else
            PushGameName("Unknown Game","unresolved")
        end
    end)
end

local MIN_WIDTH, MIN_HEIGHT = 520, 350
local MAX_WIDTH, MAX_HEIGHT = 900, 600

local unloading = false
local dragging = false
local resizing = false

local Themes = {
    {Name="Midnight",Description="Classic purple",Accent=Color3.fromRGB(155,115,255),Background=Color3.fromRGB(12,12,15),Panel=Color3.fromRGB(17,17,21),PanelLight=Color3.fromRGB(25,24,31),Text=Color3.fromRGB(240,240,245),Muted=Color3.fromRGB(130,130,140)},
    {Name="Ocean",Description="Cool blue",Accent=Color3.fromRGB(75,165,255),Background=Color3.fromRGB(10,14,20),Panel=Color3.fromRGB(15,22,31),PanelLight=Color3.fromRGB(23,33,45),Text=Color3.fromRGB(235,243,250),Muted=Color3.fromRGB(130,150,170)},
    {Name="Emerald",Description="Clean green",Accent=Color3.fromRGB(75,205,145),Background=Color3.fromRGB(10,16,14),Panel=Color3.fromRGB(15,23,20),PanelLight=Color3.fromRGB(23,34,29),Text=Color3.fromRGB(235,245,239),Muted=Color3.fromRGB(130,155,140)},
    {Name="Crimson",Description="Deep red",Accent=Color3.fromRGB(235,95,115),Background=Color3.fromRGB(17,11,14),Panel=Color3.fromRGB(25,15,19),PanelLight=Color3.fromRGB(36,22,28),Text=Color3.fromRGB(248,238,241),Muted=Color3.fromRGB(165,130,140)},
    {Name="Rose",Description="Soft pink",Accent=Color3.fromRGB(255,105,170),Background=Color3.fromRGB(20,11,17),Panel=Color3.fromRGB(30,16,25),PanelLight=Color3.fromRGB(43,22,35),Text=Color3.fromRGB(255,238,247),Muted=Color3.fromRGB(170,130,153)},
    {Name="Gold",Description="Luxury gold",Accent=Color3.fromRGB(245,190,75),Background=Color3.fromRGB(18,16,10),Panel=Color3.fromRGB(27,23,14),PanelLight=Color3.fromRGB(40,34,20),Text=Color3.fromRGB(250,245,230),Muted=Color3.fromRGB(165,150,115)},
    {Name="Arctic",Description="Ice white",Accent=Color3.fromRGB(105,225,255),Background=Color3.fromRGB(10,17,22),Panel=Color3.fromRGB(16,27,34),PanelLight=Color3.fromRGB(24,40,49),Text=Color3.fromRGB(235,250,255),Muted=Color3.fromRGB(135,165,180)},
    {Name="Neon",Description="Electric cyan",Accent=Color3.fromRGB(0,255,210),Background=Color3.fromRGB(7,14,15),Panel=Color3.fromRGB(11,22,23),PanelLight=Color3.fromRGB(17,34,35),Text=Color3.fromRGB(225,255,250),Muted=Color3.fromRGB(110,165,155)},
    {Name="Sunset",Description="Orange glow",Accent=Color3.fromRGB(255,135,65),Background=Color3.fromRGB(20,12,10),Panel=Color3.fromRGB(31,18,14),PanelLight=Color3.fromRGB(45,26,19),Text=Color3.fromRGB(255,240,230),Muted=Color3.fromRGB(175,135,115)},
    {Name="Lavender",Description="Soft violet",Accent=Color3.fromRGB(190,155,255),Background=Color3.fromRGB(16,13,23),Panel=Color3.fromRGB(24,19,34),PanelLight=Color3.fromRGB(35,28,48),Text=Color3.fromRGB(245,239,255),Muted=Color3.fromRGB(155,140,180)},
    {Name="Ruby",Description="Bright ruby",Accent=Color3.fromRGB(255,45,75),Background=Color3.fromRGB(18,9,12),Panel=Color3.fromRGB(29,13,18),PanelLight=Color3.fromRGB(43,18,26),Text=Color3.fromRGB(255,235,239),Muted=Color3.fromRGB(175,120,135)},
    {Name="Monochrome",Description="Black and white",Accent=Color3.fromRGB(220,220,230),Background=Color3.fromRGB(10,10,12),Panel=Color3.fromRGB(19,19,22),PanelLight=Color3.fromRGB(31,31,35),Text=Color3.fromRGB(250,250,250),Muted=Color3.fromRGB(145,145,155)},
    {Name="Slate",Description="Steel gray",Accent=Color3.fromRGB(135,155,180),Background=Color3.fromRGB(12,15,20),Panel=Color3.fromRGB(20,25,32),PanelLight=Color3.fromRGB(30,37,47),Text=Color3.fromRGB(235,240,248),Muted=Color3.fromRGB(135,150,170)},
    {Name="Teal",Description="Deep teal",Accent=Color3.fromRGB(35,210,190),Background=Color3.fromRGB(8,17,18),Panel=Color3.fromRGB(13,27,28),PanelLight=Color3.fromRGB(20,39,40),Text=Color3.fromRGB(230,250,247),Muted=Color3.fromRGB(120,165,160)},
    {Name="Lime",Description="Bright lime",Accent=Color3.fromRGB(170,235,65),Background=Color3.fromRGB(14,18,9),Panel=Color3.fromRGB(23,29,14),PanelLight=Color3.fromRGB(34,43,20),Text=Color3.fromRGB(245,250,230),Muted=Color3.fromRGB(155,170,120)},
    {Name="Coral",Description="Warm coral",Accent=Color3.fromRGB(255,125,110),Background=Color3.fromRGB(20,12,13),Panel=Color3.fromRGB(31,19,20),PanelLight=Color3.fromRGB(45,27,28),Text=Color3.fromRGB(255,240,238),Muted=Color3.fromRGB(180,135,130)},
    {Name="Indigo",Description="Royal indigo",Accent=Color3.fromRGB(105,110,255),Background=Color3.fromRGB(11,11,22),Panel=Color3.fromRGB(19,19,36),PanelLight=Color3.fromRGB(29,29,52),Text=Color3.fromRGB(239,239,255),Muted=Color3.fromRGB(140,140,185)},
    {Name="Ice",Description="Frozen blue",Accent=Color3.fromRGB(160,220,255),Background=Color3.fromRGB(11,17,24),Panel=Color3.fromRGB(18,29,40),PanelLight=Color3.fromRGB(28,43,57),Text=Color3.fromRGB(240,250,255),Muted=Color3.fromRGB(145,175,195)},
    {Name="Forest",Description="Dark forest",Accent=Color3.fromRGB(90,175,105),Background=Color3.fromRGB(9,16,11),Panel=Color3.fromRGB(15,25,17),PanelLight=Color3.fromRGB(23,37,25),Text=Color3.fromRGB(235,247,237),Muted=Color3.fromRGB(125,155,130)},
    {Name="Cherry",Description="Cherry red",Accent=Color3.fromRGB(220,55,95),Background=Color3.fromRGB(18,8,13),Panel=Color3.fromRGB(29,13,20),PanelLight=Color3.fromRGB(43,19,29),Text=Color3.fromRGB(255,235,242),Muted=Color3.fromRGB(170,120,140)},
    {Name="Copper",Description="Burnished copper",Accent=Color3.fromRGB(205,125,75),Background=Color3.fromRGB(19,13,10),Panel=Color3.fromRGB(30,21,16),PanelLight=Color3.fromRGB(44,30,22),Text=Color3.fromRGB(250,239,230),Muted=Color3.fromRGB(170,140,120)},
    {Name="Sky",Description="Bright sky blue",Accent=Color3.fromRGB(80,180,255),Background=Color3.fromRGB(9,15,23),Panel=Color3.fromRGB(15,25,37),PanelLight=Color3.fromRGB(23,37,53),Text=Color3.fromRGB(235,247,255),Muted=Color3.fromRGB(130,165,195)},
    {Name="Plum",Description="Rich plum",Accent=Color3.fromRGB(190,100,210),Background=Color3.fromRGB(17,10,20),Panel=Color3.fromRGB(27,16,32),PanelLight=Color3.fromRGB(40,24,47),Text=Color3.fromRGB(248,235,252),Muted=Color3.fromRGB(165,130,180)},
    {Name="Graphite",Description="Dark graphite",Accent=Color3.fromRGB(175,185,200),Background=Color3.fromRGB(9,10,12),Panel=Color3.fromRGB(17,19,22),PanelLight=Color3.fromRGB(27,30,35),Text=Color3.fromRGB(245,246,250),Muted=Color3.fromRGB(135,140,150)}
}

local CurrentTheme = Themes[1]
local UIAccent = CurrentTheme.Accent

--[[ ================================================================
    OWNER IDENTITY | adenrobers
    The script owner is detected by username OR display name
    (case-insensitive). Only the owner ever sees: the OWNER tag
    beside the Home welcome line, the OWNER CONTROLS toggle in
    Home, and the rainbow OWNER tab. Everyone else gets the
    exact same hub with zero owner footprint.
================================================================ ]]
local OwnerKeys={["adenrobers"]=true}
local IsOwner=false
do
    local ownerName=string.lower(tostring(Player.Name or ""))
    local ownerDisplay=string.lower(tostring(Player.DisplayName or ""))
    IsOwner=OwnerKeys[ownerName]==true or OwnerKeys[ownerDisplay]==true
end

-- one shared clock drives every owner rainbow gradient in the hub
local OwnerRainbowGradients={}
local OwnerGold=Color3.fromRGB(255,200,80)
local function OwnerRainbow()
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0.00,Color3.fromRGB(255,90,90)),
        ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255,165,70)),
        ColorSequenceKeypoint.new(0.33,Color3.fromRGB(255,235,90)),
        ColorSequenceKeypoint.new(0.50,Color3.fromRGB(90,255,130)),
        ColorSequenceKeypoint.new(0.67,Color3.fromRGB(90,170,255)),
        ColorSequenceKeypoint.new(0.83,Color3.fromRGB(175,110,255)),
        ColorSequenceKeypoint.new(1.00,Color3.fromRGB(255,90,180))
    })
end

local function ButtonColor()
    return UIAccent:Lerp(Color3.new(0,0,0),0.42)
end

local function ButtonHoverColor()
    return UIAccent:Lerp(Color3.new(1,1,1),0.12)
end

local OldGui = PlayerGui:FindFirstChild("BubbaScripts")
if OldGui then
    OldGui:Destroy()
end

local function Create(className,properties,parent)
    local object = Instance.new(className)
    for property,value in pairs(properties) do
        object[property] = value
    end
    object.Parent = parent
    return object
end

local function Round(parent,radius)
    Create("UICorner",{CornerRadius=UDim.new(0,radius)},parent)
end

local function Stroke(parent,color,transparency,thickness)
    return Create("UIStroke",{
        Color=color,
        Transparency=transparency or 0,
        Thickness=thickness or 1
    },parent)
end

local function Tween(object,properties,duration,style,direction)
    if not object or not object.Parent then
        return nil
    end
    local tween = TweenService:Create(
        object,
        TweenInfo.new(
            duration or 0.2,
            style or Enum.EasingStyle.Quart,
            direction or Enum.EasingDirection.Out
        ),
        properties
    )
    tween:Play()
    return tween
end

local function PlayTween(object,properties,duration,style,direction)
    local tween = Tween(object,properties,duration,style,direction)
    if tween then
        tween.Completed:Wait()
    end
end

local ScreenGui = Create("ScreenGui",{
    Name="BubbaScripts",
    ResetOnSpawn=false,
    IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling
},PlayerGui)

LoadingScreen = Create("Frame",{
    Name="CinematicLoadingScreen",
    Size=UDim2.fromScale(1,1),
    Position=UDim2.fromScale(0,0),
    BackgroundColor3=CurrentTheme.Background,
    BorderSizePixel=0,
    ZIndex=200,
    ClipsDescendants=true
},ScreenGui)

--[[ ================================================================
    BOOT SUPERVISOR -- construction crash insurance
    The cinematic intro normally starts itself at the bottom of this
    file. But if any single line of UI construction below throws a
    runtime error in a live executor, execution dies before that
    auto-boot spawn is ever reached and the hub would stay invisible
    forever. This timer is scheduled BEFORE any of that can happen,
    so it survives every crash after this line: if the intro has not
    started 20 seconds in, it takes over, force-reveals the hub
    window and clears the stale loading screen. Boot is guaranteed
    on every game, every executor, with nothing to press.
================================================================ ]]
task.delay(20,function()
    if LoadingStarted then return end               -- normal intro owns the boot
    if unloading or not ScreenGui.Parent then return end -- re-executed or unloaded

    warn("[BUBBA BOOT SUPERVISOR]: the intro never started (a build step errored on this executor) -- force-booting the hub window")

    LoadingCancelled=true
    LoadingFinished=true

    pcall(function()
        if LoadingScreen and LoadingScreen.Parent then LoadingScreen:Destroy() end
    end)

    pcall(function()
        local supervisorMain=ScreenGui:FindFirstChild("Main")
        if supervisorMain then
            supervisorMain.Visible=true
            supervisorMain.BackgroundTransparency=0
            supervisorMain.Position=UDim2.new(0.5,-380,0.5,-230)
            supervisorMain.Rotation=0
        else
            warn("[BUBBA BOOT SUPERVISOR]: hub window was never built -- UI construction died before the window existed, re-execute the script")
        end
    end)
end)

LoadingGradient = Create("UIGradient",{
    Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(5,5,9)),
        ColorSequenceKeypoint.new(0.5,CurrentTheme.Background),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(15,12,24))
    }),
    Rotation=35
},LoadingScreen)

BackgroundGlow1 = Create("Frame",{
    AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.fromScale(0.25,0.45),
    Size=UDim2.fromScale(0.55,0.7),
    BackgroundColor3=CurrentTheme.Accent,
    BackgroundTransparency=0.91,
    BorderSizePixel=0,
    ZIndex=201
},LoadingScreen)
Round(BackgroundGlow1,500)

Create("UIGradient",{
    Transparency=NumberSequence.new({
        NumberSequenceKeypoint.new(0,1),
        NumberSequenceKeypoint.new(0.5,0.2),
        NumberSequenceKeypoint.new(1,1)
    }),
    Rotation=45
},BackgroundGlow1)

BackgroundGlow2 = Create("Frame",{
    AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.fromScale(0.8,0.65),
    Size=UDim2.fromScale(0.5,0.6),
    BackgroundColor3=CurrentTheme.Accent,
    BackgroundTransparency=0.94,
    BorderSizePixel=0,
    ZIndex=201
},LoadingScreen)
Round(BackgroundGlow2,500)

Create("UIGradient",{
    Transparency=NumberSequence.new({
        NumberSequenceKeypoint.new(0,1),
        NumberSequenceKeypoint.new(0.5,0.15),
        NumberSequenceKeypoint.new(1,1)
    }),
    Rotation=130
},BackgroundGlow2)

LightStreaks = {}

for i=1,5 do
    local streak = Create("Frame",{
        AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.new(-0.3,0,0.15+(i*0.16),0),
        Size=UDim2.new(0.35,0,0,1),
        BackgroundColor3=CurrentTheme.Accent,
        BackgroundTransparency=0.72,
        BorderSizePixel=0,
        Rotation=-18,
        ZIndex=202
    },LoadingScreen)

    Create("UIGradient",{
        Transparency=NumberSequence.new({
            NumberSequenceKeypoint.new(0,1),
            NumberSequenceKeypoint.new(0.5,0),
            NumberSequenceKeypoint.new(1,1)
        })
    },streak)

    table.insert(LightStreaks,streak)
end

ParticleHolder = Create("Frame",{
    Name="Particles",
    Size=UDim2.fromScale(1,1),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ZIndex=203
},LoadingScreen)

ParticleObjects = {}

for i=1,42 do
    local size=math.random(2,5)
    local particle=Create("Frame",{
        AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.fromScale(math.random(),math.random()),
        Size=UDim2.fromOffset(size,size),
        BackgroundColor3=CurrentTheme.Accent,
        BackgroundTransparency=math.random(25,65)/100,
        BorderSizePixel=0,
        ZIndex=203
    },ParticleHolder)
    Round(particle,20)
    table.insert(ParticleObjects,{
        Object=particle,
        Duration=math.random(35,75)/10
    })
end

-- rotating crystal light rays above the title
GodRays=Create("Frame",{
    Name="GodRays",
    AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.new(0.5,0,0.34,0),
    Size=UDim2.fromOffset(0,0),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ZIndex=203
},LoadingScreen)

for i=1,6 do
    local ray=Create("Frame",{
        AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.fromOffset(0,0),
        Size=UDim2.fromOffset(math.random(240,380),2),
        BackgroundColor3=CurrentTheme.Accent,
        BackgroundTransparency=0.6,
        BorderSizePixel=0,
        Rotation=(i*60)+math.random(-10,10),
        ZIndex=203
    },GodRays)
    Create("UIGradient",{
        Transparency=NumberSequence.new({
            NumberSequenceKeypoint.new(0,1),
            NumberSequenceKeypoint.new(0.5,0.3),
            NumberSequenceKeypoint.new(1,1)
        })
    },ray)
end

-- the title slams in one letter at a time
BubbaTitleLetters={}

local TitleWord="BUBBA"

for i=1,#TitleWord do
    local letter=Create("TextLabel",{
        Name="TitleLetter"..i,
        AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.new(0.5,(i-3)*27,0.52,0),
        Size=UDim2.fromOffset(26,40),
        BackgroundTransparency=1,
        Text=TitleWord:sub(i,i),
        TextColor3=CurrentTheme.Text,
        TextSize=44,
        Font=Enum.Font.GothamBlack,
        TextTransparency=1,
        ZIndex=207
    },LoadingScreen)
    table.insert(BubbaTitleLetters,letter)
end

TitleUnderline=Create("Frame",{
    Name="TitleUnderline",
    AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.new(0.5,0,0.52,26),
    Size=UDim2.new(0,0,0,2),
    BackgroundColor3=CurrentTheme.Accent,
    BackgroundTransparency=0.25,
    BorderSizePixel=0,
    ZIndex=207
},LoadingScreen)
Round(TitleUnderline,100)

BubbaSubtitle=Create("TextLabel",{
    AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.fromScale(0.5,0.585),
    Size=UDim2.new(0.8,0,0,22),
    BackgroundTransparency=1,
    Text="B U B B A   S C R I P T S",
    TextColor3=CurrentTheme.Muted,
    TextSize=9,
    Font=Enum.Font.GothamMedium,
    TextTransparency=1,
    ZIndex=207
},LoadingScreen)

-- boot terminal that decrypts the startup log in the corner
BootTerminal=Create("Frame",{
    Name="BootTerminal",
    Position=UDim2.new(0.025,0,0.05,0),
    Size=UDim2.new(0.42,0,0,116),
    BackgroundColor3=Color3.fromRGB(6,6,12),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ZIndex=210
},LoadingScreen)
Round(BootTerminal,8)
BootTerminalStroke=Stroke(BootTerminal,CurrentTheme.Accent,1,1)

Create("UIPadding",{
    PaddingLeft=UDim.new(0,10),
    PaddingRight=UDim.new(0,10),
    PaddingTop=UDim.new(0,8)
},BootTerminal)

Create("UIListLayout",{
    Padding=UDim.new(0,3),
    SortOrder=Enum.SortOrder.LayoutOrder
},BootTerminal)

BootLines={}

function LoadingAccentHex(theme)
    return string.format("#%02X%02X%02X",
        math.floor(theme.Accent.R*255+0.5),
        math.floor(theme.Accent.G*255+0.5),
        math.floor(theme.Accent.B*255+0.5)
    )
end

-- decrypt effect: garbage characters cycle then settle on the real text
function LoadingScramble(label,finalText,richSuffix)
    task.spawn(function()
        if not label or not label.Parent then return end
        local garbage="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#%*+-="
        local length=#finalText
        for step=1,4 do
            if not label.Parent or LoadingCancelled then return end
            local scrambled=""
            for i=1,length do
                local character=finalText:sub(i,i)
                if character==" " then
                    scrambled=scrambled.." "
                else
                    local index=math.random(1,#garbage)
                    scrambled=scrambled..garbage:sub(index,index)
                end
            end
            label.Text=scrambled
            label.TextTransparency=0.35
            task.wait(0.035)
        end
        if not label.Parent or LoadingCancelled then return end
        label.Text=finalText..(richSuffix or "")
        label.TextTransparency=0
    end)
end

function AddBootLine(plainText,okSuffix)
    if not BootTerminal or not BootTerminal.Parent then return end
    local label=Create("TextLabel",{
        Size=UDim2.new(1,-20,0,13),
        BackgroundTransparency=1,
        Text="",
        TextColor3=CurrentTheme.Muted,
        TextSize=10,
        Font=Enum.Font.Code,
        TextXAlignment=Enum.TextXAlignment.Left,
        RichText=true,
        TextTransparency=1,
        ZIndex=211,
        LayoutOrder=#BootLines+1
    },BootTerminal)
    local entry={Label=label,Plain=plainText,Ok=okSuffix}
    table.insert(BootLines,entry)
    local richSuffix=nil
    if okSuffix then
        richSuffix=" <font color=\""..LoadingAccentHex(CurrentTheme).."\">"..okSuffix.."</font>"
    end
    LoadingScramble(label,plainText,richSuffix)
    return label
end

LoadingStatus=Create("TextLabel",{
    AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.fromScale(0.5,0.72),
    Size=UDim2.new(0.8,0,0,20),
    BackgroundTransparency=1,
    Text="INITIALIZING BUBBA",
    TextColor3=CurrentTheme.Muted,
    TextSize=9,
    Font=Enum.Font.GothamSemibold,
    TextTransparency=1,
    ZIndex=207
},LoadingScreen)

LoadingPercent=Create("TextLabel",{
    AnchorPoint=Vector2.new(1,0.5),
    Position=UDim2.new(0.78,0,0.77,0),
    Size=UDim2.fromOffset(55,18),
    BackgroundTransparency=1,
    Text="0%",
    TextColor3=CurrentTheme.Text,
    TextSize=10,
    Font=Enum.Font.GothamBold,
    TextTransparency=1,
    TextXAlignment=Enum.TextXAlignment.Right,
    ZIndex=207
},LoadingScreen)

ProgressBackground=Create("Frame",{
    AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.fromScale(0.5,0.81),
    Size=UDim2.new(0.34,0,0,4),
    BackgroundColor3=CurrentTheme.PanelLight,
    BackgroundTransparency=0.15,
    BorderSizePixel=0,
    ZIndex=207
},LoadingScreen)
Round(ProgressBackground,10)

ProgressFill=Create("Frame",{
    Size=UDim2.new(0,0,1,0),
    BackgroundColor3=CurrentTheme.Accent,
    BorderSizePixel=0,
    ClipsDescendants=true,
    ZIndex=208
},ProgressBackground)
Round(ProgressFill,10)

ProgressShimmer=Create("Frame",{
    Name="Shimmer",
    Size=UDim2.new(0.32,0,1,0),
    Position=UDim2.new(-0.32,0,0,0),
    BackgroundColor3=Color3.fromRGB(255,255,255),
    BackgroundTransparency=0.55,
    BorderSizePixel=0,
    ZIndex=209
},ProgressFill)

Create("UIGradient",{
    Transparency=NumberSequence.new({
        NumberSequenceKeypoint.new(0,1),
        NumberSequenceKeypoint.new(0.5,0.3),
        NumberSequenceKeypoint.new(1,1)
    })
},ProgressShimmer)

ProgressGradient=Create("UIGradient",{
    Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,CurrentTheme.Accent:Lerp(Color3.new(1,1,1),0.35)),
        ColorSequenceKeypoint.new(1,CurrentTheme.Accent)
    })
},ProgressFill)

LoadingFooter=Create("TextLabel",{
    AnchorPoint=Vector2.new(0.5,1),
    Position=UDim2.new(0.5,0,1,-22),
    Size=UDim2.new(0.8,0,0,18),
    BackgroundTransparency=1,
    Text="B U B B A   S C R I P T S",
    TextColor3=CurrentTheme.Muted,
    TextSize=8,
    Font=Enum.Font.GothamMedium,
    TextTransparency=1,
    ZIndex=207
},LoadingScreen)

LoadingFinished=false
LoadingCancelled=false
LoadingStarted=false

function UpdateLoadingTheme(theme)
    if not LoadingScreen or not LoadingScreen.Parent then return end

    LoadingScreen.BackgroundColor3=theme.Background
    LoadingGradient.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(5,5,9)),
        ColorSequenceKeypoint.new(0.5,theme.Background),
        ColorSequenceKeypoint.new(1,theme.Panel)
    })

    BackgroundGlow1.BackgroundColor3=theme.Accent
    BackgroundGlow2.BackgroundColor3=theme.Accent

    for _,streak in ipairs(LightStreaks) do
        streak.BackgroundColor3=theme.Accent
    end
    for _,particleData in ipairs(ParticleObjects) do
        particleData.Object.BackgroundColor3=theme.Accent
    end

    for _,ray in ipairs(GodRays:GetDescendants()) do
        if ray:IsA("Frame") then
            ray.BackgroundColor3=theme.Accent
        end
    end

    for _,letter in ipairs(BubbaTitleLetters) do
        letter.TextColor3=theme.Text
    end
    TitleUnderline.BackgroundColor3=theme.Accent
    BubbaSubtitle.TextColor3=theme.Muted

    BootTerminalStroke.Color=theme.Accent
    local accentHex=LoadingAccentHex(theme)
    for _,entry in ipairs(BootLines) do
        entry.Label.TextColor3=theme.Muted
        if entry.Ok then
            entry.Label.Text=entry.Plain.." <font color=\""..accentHex.."\">"..entry.Ok.."</font>"
        end
    end

    LoadingStatus.TextColor3=theme.Muted
    LoadingPercent.TextColor3=theme.Text
    LoadingFooter.TextColor3=theme.Muted
    ProgressBackground.BackgroundColor3=theme.PanelLight
    ProgressFill.BackgroundColor3=theme.Accent

    ProgressGradient.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,theme.Accent:Lerp(Color3.new(1,1,1),0.35)),
        ColorSequenceKeypoint.new(1,theme.Accent)
    })
end

function StartLoadingAnimations()
    task.spawn(function()
        while LoadingScreen.Parent and not LoadingCancelled do
            Tween(BackgroundGlow1,{
                Position=UDim2.fromScale(0.72,0.32),
                Size=UDim2.fromScale(0.7,0.85)
            },5,Enum.EasingStyle.Sine)
            Tween(BackgroundGlow2,{
                Position=UDim2.fromScale(0.22,0.72),
                Size=UDim2.fromScale(0.65,0.7)
            },5,Enum.EasingStyle.Sine)
            task.wait(5)
            if not LoadingScreen.Parent or LoadingCancelled then break end
            Tween(BackgroundGlow1,{
                Position=UDim2.fromScale(0.25,0.45),
                Size=UDim2.fromScale(0.55,0.7)
            },5,Enum.EasingStyle.Sine)
            Tween(BackgroundGlow2,{
                Position=UDim2.fromScale(0.8,0.65),
                Size=UDim2.fromScale(0.5,0.6)
            },5,Enum.EasingStyle.Sine)
            task.wait(5)
        end
    end)

    task.spawn(function()
        while LoadingScreen.Parent and not LoadingCancelled do
            Tween(LoadingGradient,{Rotation=LoadingGradient.Rotation+90},8,Enum.EasingStyle.Linear)
            task.wait(8)
        end
    end)

    for index,streak in ipairs(LightStreaks) do
        task.spawn(function()
            while LoadingScreen.Parent and not LoadingCancelled do
                streak.Position=UDim2.new(-0.35,0,0.15+(index*0.16),0)
                local tween=Tween(streak,{
                    Position=UDim2.new(1.35,0,0.15+(index*0.16),0)
                },math.random(45,70)/10,Enum.EasingStyle.Linear)
                if tween then tween.Completed:Wait() end
                if LoadingCancelled or not LoadingScreen.Parent then break end
                task.wait(math.random(1,3))
            end
        end)
    end

    for _,particleData in ipairs(ParticleObjects) do
        task.spawn(function()
            local particle=particleData.Object
            while LoadingScreen.Parent and not LoadingCancelled do
                Tween(particle,{
                    Position=UDim2.fromScale(math.random(5,95)/100,math.random(5,95)/100),
                    BackgroundTransparency=math.random(25,75)/100
                },particleData.Duration,Enum.EasingStyle.Sine)
                task.wait(particleData.Duration)
            end
        end)
    end

    -- god rays slowly rotate above the title
    task.spawn(function()
        while LoadingScreen.Parent and not LoadingCancelled do
            local tween=Tween(GodRays,{Rotation=GodRays.Rotation+360},7,Enum.EasingStyle.Linear)
            if tween then tween.Completed:Wait() end
        end
    end)

    -- shimmer light sweeps across the progress bar
    task.spawn(function()
        while LoadingScreen.Parent and not LoadingCancelled do
            ProgressShimmer.Position=UDim2.new(-0.32,0,0,0)
            local sweep=Tween(ProgressShimmer,{Position=UDim2.new(1,0,0,0)},0.85,Enum.EasingStyle.Linear)
            if sweep then sweep.Completed:Wait() end
            task.wait(0.35)
        end
    end)
end

function FadeLoadingScreen()
    if not LoadingScreen or not LoadingScreen.Parent then return end
    LoadingCancelled=true
    local fadeTweens={}

    -- the interface gathers back into the core one last time
    local ExitRing=Create("Frame",{
        AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.new(0.5,0,0.34,0),
        Size=UDim2.fromOffset(90,90),
        BackgroundTransparency=1,
        BorderSizePixel=0,
        ZIndex=250
    },LoadingScreen)
    Round(ExitRing,100)
    local ExitRingStroke=Stroke(ExitRing,CurrentTheme.Accent,0.1,3)
    Tween(ExitRing,{Size=UDim2.fromOffset(430,430)},0.5,Enum.EasingStyle.Quart)
    Tween(ExitRingStroke,{Transparency=1},0.5)

    local function AddFade(object,properties,duration)
        if object and object.Parent then
            local tween=Tween(object,properties,duration)
            if tween then table.insert(fadeTweens,tween) end
        end
    end

    AddFade(LoadingScreen,{BackgroundTransparency=1},0.55)

    for _,object in ipairs(LoadingScreen:GetDescendants()) do
        if object:IsA("Frame") then
            AddFade(object,{BackgroundTransparency=1},0.45)
        elseif object:IsA("TextLabel") or object:IsA("TextButton") then
            AddFade(object,{TextTransparency=1,BackgroundTransparency=1},0.45)
        elseif object:IsA("UIStroke") then
            AddFade(object,{Transparency=1},0.45)
        elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
            AddFade(object,{ImageTransparency=1,BackgroundTransparency=1},0.45)
        end
    end

    if #fadeTweens>0 then
        local remaining=#fadeTweens
        local finishedEvent=Instance.new("BindableEvent")
        local released=false
        local function ReleaseFade()
            if released then return end
            released=true
            pcall(function()
                finishedEvent:Fire()
            end)
        end
        for _,tween in ipairs(fadeTweens) do
            local counted=false
            tween.Completed:Connect(function()
                if counted then return end
                counted=true
                remaining-=1
                if remaining<=0 then ReleaseFade() end
            end)
        end
        -- hard release: even if an executor never delivers a Completed event,
        -- the fade still ends and the boot sequence continues
        task.delay(0.9,ReleaseFade)
        if remaining>0 then finishedEvent.Event:Wait() end
        pcall(function()
            finishedEvent:Destroy()
        end)
    end

    task.wait(0.08)
    if LoadingScreen and LoadingScreen.Parent then
        LoadingScreen:Destroy()
    end
end

local Main=Create("Frame",{
    Name="Main",
    Size=UDim2.fromOffset(760,460),
    Position=UDim2.new(0.5,-380,0.5,-230),
    BackgroundColor3=CurrentTheme.Background,
    BackgroundTransparency=0,
    BorderSizePixel=0,
    ClipsDescendants=true,
    Visible=false
},ScreenGui)
Round(Main,12)

local IsMobile = UIS.TouchEnabled

MobileToggle=nil
MobileMinus=nil
MobileNotification=nil
MobileNotificationStroke=nil
MobileNotificationAccent=nil
MobileNotificationTitle=nil
MobileNotificationDescription=nil
MobileToggleDragging = false
MobileToggleDragStart=nil
MobileToggleStartPosition=nil
MobileToggleMoved = false
MobileUIHidden = false
MobileFadeTweens = {}
MobileOriginalTransparency = {}

local function CacheMobileTransparency()
    MobileOriginalTransparency={}

    local function CacheObject(object)
        local values={}

        if object:IsA("GuiObject") then
            values.BackgroundTransparency=object.BackgroundTransparency
        end

        if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
            values.TextTransparency=object.TextTransparency
            values.TextStrokeTransparency=object.TextStrokeTransparency
        end

        if object:IsA("ImageLabel") or object:IsA("ImageButton") then
            values.ImageTransparency=object.ImageTransparency
        end

        if object:IsA("UIStroke") then
            values.Transparency=object.Transparency
        end

        if next(values) then
            MobileOriginalTransparency[object]=values
        end
    end

    CacheObject(Main)

    for _,object in ipairs(Main:GetDescendants()) do
        CacheObject(object)
    end
end

local function CancelMobileFadeTweens()
    for _,tween in ipairs(MobileFadeTweens) do
        pcall(function()
            tween:Cancel()
        end)
    end
    table.clear(MobileFadeTweens)
end

local function FadeMobileObject(object,properties,duration)
    if not object or not object.Parent then return end

    local tween=Tween(object,properties,duration,Enum.EasingStyle.Quart)
    if tween then
        table.insert(MobileFadeTweens,tween)
    end
end

local function HideMobileMain()
    if unloading or MobileUIHidden then return end

    -- if a boot fallback path never cached transparencies (e.g. the
    -- supervisor force-revealed the window), cache them now so the
    -- Right Shift / B fade still works on every platform
    if not next(MobileOriginalTransparency) then
        CacheMobileTransparency()
    end

    MobileUIHidden=true
    CancelMobileFadeTweens()

    for object,values in pairs(MobileOriginalTransparency) do
        if object and object.Parent then
            local properties={}

            for property in pairs(values) do
                properties[property]=1
            end

            FadeMobileObject(object,properties,0.22)
        end
    end

    task.delay(0.24,function()
        if unloading or not ScreenGui.Parent or not MobileUIHidden then return end

        Main.Visible=false

        if MobileToggle and MobileToggle.Parent then
            MobileToggle.Visible=true
            MobileToggle.Size=UDim2.fromOffset(0,0)
            MobileToggle.BackgroundTransparency=1
            MobileToggle.TextTransparency=1
            Tween(MobileToggle,{
                Size=UDim2.fromOffset(48,48),
                BackgroundTransparency=0.15,
                TextTransparency=0
            },0.45,Enum.EasingStyle.Back)
        end
    end)
end

local function ShowMobileMain()
    if unloading or not MobileUIHidden then return end

    MobileUIHidden=false
    CancelMobileFadeTweens()

    if MobileToggle and MobileToggle.Parent then
        Tween(MobileToggle,{
            BackgroundTransparency=1,
            TextTransparency=1
        },0.12)
    end

    Main.Visible=true

    for object,values in pairs(MobileOriginalTransparency) do
        if object and object.Parent then
            FadeMobileObject(object,values,0.25)
        end
    end

    task.delay(0.27,function()
        if unloading or not ScreenGui.Parent or MobileUIHidden then return end

        for object,values in pairs(MobileOriginalTransparency) do
            if object and object.Parent then
                for property,value in pairs(values) do
                    pcall(function()
                        object[property]=value
                    end)
                end
            end
        end

        if MobileToggle and MobileToggle.Parent then
            MobileToggle.Visible=false
            MobileToggle.BackgroundTransparency=0.15
            MobileToggle.TextTransparency=0
            MobileToggle.Size=UDim2.fromOffset(48,48)
        end
    end)
end

-- the reopen bubble is built on every device now: Right Shift hides the
-- hub on PC, the minus button hides it on mobile, and B reopens it anywhere
do
    MobileToggle = Create("TextButton",{
        Name="MobileBButton",
        AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.new(1,-28,0.5,0),
        Size=UDim2.fromOffset(48,48),
        BackgroundColor3=Color3.fromRGB(0,0,0),
        BackgroundTransparency=0.15,
        BorderSizePixel=0,
        Text="B",
        TextColor3=Color3.new(1,1,1),
        TextSize=21,
        Font=Enum.Font.GothamBlack,
        AutoButtonColor=false,
        Visible=false,
        Active=true,
        ZIndex=310
    },ScreenGui)

    Round(MobileToggle,24)
    local MobileToggleStroke=Stroke(MobileToggle,UIAccent,0.2,1.5)

    -- gentle glow pulse while the bubble is visible
    task.spawn(function()
        while ScreenGui.Parent do
            if MobileToggle.Visible and MobileToggle.BackgroundTransparency<0.9 then
                if MobileToggleStroke and MobileToggleStroke.Parent then
                    MobileToggleStroke.Transparency=0.1
                    Tween(MobileToggleStroke,{Transparency=0.75},1.1)
                end
                task.wait(1.1)
                if MobileToggle.Visible and MobileToggleStroke and MobileToggleStroke.Parent then
                    MobileToggleStroke.Transparency=0.75
                    Tween(MobileToggleStroke,{Transparency=0.1},1.1)
                end
                task.wait(1.1)
            else
                task.wait(0.3)
            end
        end
    end)

    MobileToggle.InputBegan:Connect(function(input)
        if unloading then return end

        if input.UserInputType==Enum.UserInputType.Touch
            or input.UserInputType==Enum.UserInputType.MouseButton1 then

            MobileToggleDragging=true
            MobileToggleMoved=false
            MobileToggleDragStart=input.Position
            MobileToggleStartPosition=MobileToggle.Position
            Tween(MobileToggle,{Size=UDim2.fromOffset(42,42)},0.1)

            input.Changed:Connect(function()
                if input.UserInputState==Enum.UserInputState.End then
                    MobileToggleDragging=false
                    Tween(MobileToggle,{Size=UDim2.fromOffset(48,48)},0.15,Enum.EasingStyle.Back)

                    -- keep the bubble fully on screen after dragging
                    if MobileToggleMoved then
                        local camera=workspace.CurrentCamera

                        if camera then
                            local viewport=camera.ViewportSize
                            local half=24
                            local cx=MobileToggle.AbsolutePosition.X+MobileToggle.AbsoluteSize.X/2
                            local cy=MobileToggle.AbsolutePosition.Y+MobileToggle.AbsoluteSize.Y/2

                            cx=math.clamp(cx,half+2,viewport.X-half-2)
                            cy=math.clamp(cy,half+2,viewport.Y-half-2)

                            Tween(MobileToggle,{Position=UDim2.new(0,cx,0,cy)},0.2)
                        end
                    end
                end
            end)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if MobileToggleDragging and not unloading then
            if input.UserInputType==Enum.UserInputType.Touch
                or input.UserInputType==Enum.UserInputType.MouseMovement then

                local delta=input.Position-MobileToggleDragStart

                if delta.Magnitude>12 then
                    MobileToggleMoved=true
                end

                MobileToggle.Position=UDim2.new(
                    MobileToggleStartPosition.X.Scale,
                    MobileToggleStartPosition.X.Offset+delta.X,
                    MobileToggleStartPosition.Y.Scale,
                    MobileToggleStartPosition.Y.Offset+delta.Y
                )
            end
        end
    end)

    MobileToggle.Activated:Connect(function()
        if unloading or MobileToggleMoved then return end
        ShowMobileMain()
    end)

    -- the device-detection corner toast is PC ONLY: on mobile the B/minus
    -- flow is already self-explanatory, so no popup
    if not IsMobile then
        MobileNotification = Create("Frame",{
            Name="DeviceDetectionNotification",
            AnchorPoint=Vector2.new(1,1),
            Position=UDim2.new(1,340,1,-76),
            Size=UDim2.fromOffset(310,105),
            BackgroundColor3=CurrentTheme.PanelLight,
            BorderSizePixel=0,
            Visible=false,
            ZIndex=320
        },ScreenGui)

    Round(MobileNotification,10)
    MobileNotificationStroke = Stroke(MobileNotification,UIAccent,0.35,1.2)

    MobileNotificationAccent = Create("Frame",{
        Name="AccentLine",
        Position=UDim2.fromOffset(0,12),
        Size=UDim2.new(0,3,1,-24),
        BackgroundColor3=UIAccent,
        BorderSizePixel=0,
        ZIndex=321
    },MobileNotification)

    Round(MobileNotificationAccent,5)

    Create("TextLabel",{
        Position=UDim2.fromOffset(17,13),
        Size=UDim2.new(1,-32,0,22),
        BackgroundTransparency=1,
        Text="●  DEVICE DETECTION",
        TextColor3=UIAccent,
        TextSize=9,
        Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left,
        ZIndex=322
    },MobileNotification)

    MobileNotificationTitle = Create("TextLabel",{
        Position=UDim2.fromOffset(17,35),
        Size=UDim2.new(1,-32,0,23),
        BackgroundTransparency=1,
        Text="PC DETECTED",
        TextColor3=CurrentTheme.Text,
        TextSize=14,
        Font=Enum.Font.GothamBlack,
        TextXAlignment=Enum.TextXAlignment.Left,
        ZIndex=322
    },MobileNotification)

    MobileNotificationDescription = Create("TextLabel",{
        Position=UDim2.fromOffset(17,62),
        Size=UDim2.new(1,-32,0,34),
        BackgroundTransparency=1,
        Text="Right Shift closes and reopens the menu.\nDrag the B bubble anywhere on your screen.",
        TextColor3=CurrentTheme.Muted,
        TextSize=8,
        Font=Enum.Font.Gotham,
        TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center,
        ZIndex=322
    },MobileNotification)
    end -- PC-only notification gate
end -- reopen bubble / device chrome block

local function ShowMobileNotification()
    -- the device-detection corner toast is PC only; mobile keeps its clean
    -- B/minus flow without the popup
    if IsMobile or unloading then return end
    if not MobileNotification or not MobileNotification.Parent then return end

    MobileNotification.Visible=true
    MobileNotification.Position=UDim2.new(1,340,1,-76)

    Tween(MobileNotification,{
        Position=UDim2.new(1,-22,1,-76)
    },0.45,Enum.EasingStyle.Back)

    task.delay(5.5,function()
        if unloading or not MobileNotification or not MobileNotification.Parent then return end

        local tween=Tween(MobileNotification,{
            Position=UDim2.new(1,340,1,-76)
        },0.35,Enum.EasingStyle.Quart)

        if tween then
            tween.Completed:Wait()
        end

        if MobileNotification and MobileNotification.Parent then
            MobileNotification.Visible=false
        end
    end)
end

local MainStroke=Stroke(Main,Color3.fromRGB(43,42,50),0.15)

-- PC keybind: Right Shift closes and reopens the hub, mirroring the mobile
-- B bubble (gameProcessed keeps it inert while typing in settings boxes)
UIS.InputBegan:Connect(function(input,gameProcessed)
    if IsMobile or unloading or not ScreenGui.Parent then return end
    if gameProcessed then return end
    if input.KeyCode~=Enum.KeyCode.RightShift then return end

    if MobileUIHidden then
        ShowMobileMain()
    else
        HideMobileMain()
    end
end)

Create("UISizeConstraint",{
    MinSize=Vector2.new(MIN_WIDTH,MIN_HEIGHT),
    MaxSize=Vector2.new(MAX_WIDTH,MAX_HEIGHT)
},Main)

local Header=Create("Frame",{
    Name="Header",
    Size=UDim2.new(1,0,0,88),
    BackgroundColor3=CurrentTheme.Panel,
    BorderSizePixel=0
},Main)

if IsMobile then
    MobileMinus = Create("TextButton",{
        Name="MobileMinusButton",
        AnchorPoint=Vector2.new(1,0),
        Position=UDim2.new(1,-12,0,16),
        Size=UDim2.fromOffset(32,32),
        BackgroundColor3=ButtonColor(),
        BorderSizePixel=0,
        Text="−",
        TextColor3=CurrentTheme.Text,
        TextSize=23,
        Font=Enum.Font.GothamBold,
        AutoButtonColor=false,
        Visible=true,
        ZIndex=15
    },Header)

    Round(MobileMinus,8)
    Stroke(MobileMinus,UIAccent,0.25,1.2)

    MobileMinus.Activated:Connect(HideMobileMain)
end

Create("TextLabel",{
    Size=UDim2.fromOffset(35,35),
    Position=UDim2.fromOffset(20,15),
    BackgroundTransparency=1,
    Text="💫",
    TextSize=25,
    Font=Enum.Font.Gotham,
    TextColor3=CurrentTheme.Text
},Header)

Create("TextLabel",{
    Position=UDim2.fromOffset(65,15),
    Size=UDim2.new(0,300,0,24),
    BackgroundTransparency=1,
    Text="Good morning, "..Player.DisplayName,
    TextColor3=CurrentTheme.Text,
    TextSize=15,
    Font=Enum.Font.GothamSemibold,
    TextXAlignment=Enum.TextXAlignment.Left
},Header)

Create("TextLabel",{
    Position=UDim2.fromOffset(66,41),
    Size=UDim2.new(0,260,0,18),
    BackgroundTransparency=1,
    Text="B U B B A   S C R I P T S",
    TextColor3=CurrentTheme.Muted,
    TextSize=9,
    Font=Enum.Font.GothamMedium,
    TextXAlignment=Enum.TextXAlignment.Left
},Header)

local Clock=Create("TextLabel",{
    AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-64,0,18),
    Size=UDim2.fromOffset(150,22),
    BackgroundTransparency=1,
    Text="--:--",
    TextColor3=CurrentTheme.Text,
    TextSize=14,
    Font=Enum.Font.GothamSemibold,
    TextXAlignment=Enum.TextXAlignment.Right
},Header)

local DateLabel=Create("TextLabel",{
    AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-64,0,42),
    Size=UDim2.fromOffset(150,18),
    BackgroundTransparency=1,
    Text="---",
    TextColor3=CurrentTheme.Muted,
    TextSize=10,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Right
},Header)

task.spawn(function()
    while ScreenGui.Parent do
        local now=DateTime.now()
        local success,timeText,dateText=pcall(function()
            return now:FormatLocalTime("h:mm a","en-us"),
                now:FormatLocalTime("ddd, MMM D","en-us")
        end)
        if success then
            Clock.Text=timeText
            DateLabel.Text=dateText
        end
        task.wait(1)
    end
end)

local TabBar=Create("Frame",{
    Name="TabBar",
    Position=UDim2.fromOffset(0,88),
    Size=UDim2.new(1,0,0,48),
    BackgroundColor3=CurrentTheme.Background,
    BorderSizePixel=0
},Main)

Create("UIListLayout",{
    FillDirection=Enum.FillDirection.Horizontal,
    HorizontalAlignment=Enum.HorizontalAlignment.Left,
    VerticalAlignment=Enum.VerticalAlignment.Center,
    SortOrder=Enum.SortOrder.LayoutOrder,
    Padding=UDim.new(0,7)
},TabBar)

Create("UIPadding",{
    PaddingLeft=UDim.new(0,18),
    PaddingRight=UDim.new(0,18)
},TabBar)

local Content=Create("Frame",{
    Name="Content",
    Position=UDim2.fromOffset(14,148),
    Size=UDim2.new(1,-28,1,-162),
    BackgroundColor3=CurrentTheme.Panel,
    BorderSizePixel=0
},Main)
Round(Content,9)

local ContentStroke=Stroke(Content,Color3.fromRGB(38,37,45),0.35)

local Pages={}
local Tabs={}
local Indicators={}

local TabNames={"HOME","VISUALS","TELEPORT","SETTINGS","CONFIGS","INFO"}
-- the owner tab rides at the end of the bar; the toggle in Home
-- decides whether the button is visible this session
if IsOwner then
    table.insert(TabNames,"OWNER")
end
local SelectedTab
local IndicatorTween

local function SelectTab(tabName)
    if SelectedTab==tabName or unloading then return end
    SelectedTab=tabName

    for name,button in pairs(Tabs) do
        local selected=name==tabName
        Tween(button,{
            BackgroundColor3=selected and CurrentTheme.PanelLight or CurrentTheme.Background,
            TextColor3=selected and CurrentTheme.Text or CurrentTheme.Muted
        },0.16)

        local indicator=Indicators[name]
        if selected then
            indicator.Visible=true
            indicator.BackgroundColor3=UIAccent
            indicator.Size=UDim2.new(0,0,0,2)
            if IndicatorTween then IndicatorTween:Cancel() end
            IndicatorTween=Tween(indicator,{Size=UDim2.new(0.45,0,0,2)},0.22)
        else
            Tween(indicator,{Size=UDim2.new(0,0,0,2)},0.12)
            task.delay(0.13,function()
                if SelectedTab~=name and indicator.Parent then
                    indicator.Visible=false
                end
            end)
        end
        Pages[name].Visible=selected
    end
end

for index,tabName in ipairs(TabNames) do
    local Page=Create("Frame",{
        Name=tabName.."Page",
        Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,
        Visible=false
    },Content)
    Pages[tabName]=Page

    local Button=Create("TextButton",{
        Name=tabName.."Tab",
        Size=UDim2.fromOffset(105,34),
        BackgroundColor3=CurrentTheme.Background,
        BorderSizePixel=0,
        Text=tabName,
        TextColor3=CurrentTheme.Muted,
        TextSize=10,
        Font=Enum.Font.GothamSemibold,
        AutoButtonColor=false,
        LayoutOrder=index
    },TabBar)
    Round(Button,6)

    local Indicator=Create("Frame",{
        Name="ThemeIndicator",
        AnchorPoint=Vector2.new(0.5,1),
        Position=UDim2.new(0.5,0,1,-1),
        Size=UDim2.new(0,0,0,2),
        BackgroundColor3=UIAccent,
        BorderSizePixel=0,
        Visible=false
    },Button)
    Round(Indicator,5)

    Tabs[tabName]=Button
    Indicators[tabName]=Indicator

    Button.MouseButton1Click:Connect(function()
        SelectTab(tabName)
    end)
end

------------------------------------------------------------
-- OWNER TAB BUTTON | compact rainbow pill for adenrobers
-- deliberately narrower than the other tabs so the bar still
-- fits the 760px window: a small crown chip that stands apart
------------------------------------------------------------
if IsOwner then
    local OwnerTabButton=Tabs.OWNER
    OwnerTabButton.Size=UDim2.fromOffset(52,34)
    OwnerTabButton.Text=""

    Stroke(OwnerTabButton,OwnerGold,0.25,1)

    local OwnerTabWash=Create("UIGradient",{
        Color=OwnerRainbow(),
        Rotation=25,
        Transparency=NumberSequence.new(0.55)
    },OwnerTabButton)

    local OwnerTabLabel=Create("TextLabel",{
        Name="OwnerTabLabel",
        Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,
        Text="OWNER",
        TextColor3=Color3.fromRGB(255,255,255),
        TextSize=9,
        Font=Enum.Font.GothamBold
    },OwnerTabButton)

    local OwnerTabTextWash=Create("UIGradient",{
        Color=OwnerRainbow(),
        Rotation=20
    },OwnerTabLabel)

    table.insert(OwnerRainbowGradients,OwnerTabWash)
    table.insert(OwnerRainbowGradients,OwnerTabTextWash)

    -- one shared clock: every owner gradient in the hub slides
    -- along the same seamless rainbow cycle
    task.spawn(function()
        local ownerClock=0
        while ScreenGui.Parent do
            if not unloading then
                ownerClock=(ownerClock+0.005)%1
                local ownerOffset=Vector2.new(ownerClock,0)
                for _,gradient in ipairs(OwnerRainbowGradients) do
                    if gradient and gradient.Parent then
                        gradient.Offset=ownerOffset
                    end
                end
            end
            task.wait(1/30)
        end
    end)
end

Create("TextLabel",{
    Position=UDim2.fromOffset(20,12),
    Size=UDim2.new(1,-40,0,25),
    BackgroundTransparency=1,
    Text="System Information",
    TextColor3=CurrentTheme.Text,
    TextSize=18,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},Pages.INFO)

Create("TextLabel",{
    Position=UDim2.fromOffset(21,37),
    Size=UDim2.new(1,-42,0,18),
    BackgroundTransparency=1,
    Text="Live details about your player, device, and session.",
    TextColor3=CurrentTheme.Muted,
    TextSize=10,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left
},Pages.INFO)

local InfoScroll=Create("ScrollingFrame",{
    Name="InformationScroll",
    Position=UDim2.fromOffset(20,65),
    Size=UDim2.new(1,-40,1,-78),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ScrollBarThickness=3,
    ScrollBarImageColor3=UIAccent,
    ScrollingDirection=Enum.ScrollingDirection.Y,
    CanvasSize=UDim2.new(0,0,0,0),
    AutomaticCanvasSize=Enum.AutomaticSize.Y
},Pages.INFO)
InfoScroll.ScrollBarImageTransparency=0.15

Create("UIGridLayout",{
    CellSize=UDim2.new(0.5,-7,0,62),
    CellPadding=UDim2.fromOffset(10,9),
    SortOrder=Enum.SortOrder.LayoutOrder
},InfoScroll)

local InfoValues={}

local function CreateInfoCard(key,title,initialValue,order)
    local Card=Create("Frame",{
        Name=key.."InfoCard",
        BackgroundColor3=CurrentTheme.PanelLight,
        BorderSizePixel=0,
        LayoutOrder=order
    },InfoScroll)
    Round(Card,7)
    local CardStroke=Stroke(Card,CurrentTheme.Accent,0.78,1)

    Create("Frame",{
        Name="AccentBar",
        Position=UDim2.fromOffset(0,10),
        Size=UDim2.new(0,3,1,-20),
        BackgroundColor3=CurrentTheme.Accent,
        BorderSizePixel=0
    },Card)

    Create("TextLabel",{
        Position=UDim2.fromOffset(12,8),
        Size=UDim2.new(1,-22,0,15),
        BackgroundTransparency=1,
        Text=title,
        TextColor3=CurrentTheme.Muted,
        TextSize=9,
        Font=Enum.Font.GothamSemibold,
        TextXAlignment=Enum.TextXAlignment.Left
    },Card)

    local ValueLabel=Create("TextLabel",{
        Name="Value",
        Position=UDim2.fromOffset(12,27),
        Size=UDim2.new(1,-22,0,23),
        BackgroundTransparency=1,
        Text=tostring(initialValue),
        TextColor3=CurrentTheme.Text,
        TextSize=12,
        Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd
    },Card)

    InfoValues[key]={Value=ValueLabel,Card=Card,Stroke=CardStroke}
    return ValueLabel
end

CreateInfoCard("DisplayName","DISPLAY NAME",Player.DisplayName,1)
CreateInfoCard("Username","USERNAME","@"..Player.Name,2)
CreateInfoCard("UserId","USER ID",Player.UserId,3)
CreateInfoCard("AccountAge","ACCOUNT AGE",tostring(Player.AccountAge).." days",4)
CreateInfoCard("FPS","CURRENT FPS","Calculating...",5)

local function DetectExecutor()
    local executorName="Not detected"
    local success,result=pcall(function()
        local identifyFunction=identifyexecutor or getexecutorname
        if type(identifyFunction)=="function" then
            local detectedName=identifyFunction()
            if detectedName and tostring(detectedName)~="" then
                return tostring(detectedName)
            end
        end
        if type(syn)=="table" then return "Synapse X" end
        if type(getgenv)=="function" then return "Executor environment" end
        if KRNL_LOADED then return "KRNL" end
        if fluxus then return "Fluxus" end
        return "Not detected"
    end)
    if success and result then executorName=tostring(result) end
    return executorName
end

CreateInfoCard("Executor","EXECUTOR",DetectExecutor(),6)

local function GetDeviceType()
    if UIS.GamepadEnabled and not UIS.KeyboardEnabled and not UIS.TouchEnabled then
        return "Console"
    elseif UIS.TouchEnabled and not UIS.KeyboardEnabled then
        return "Mobile"
    elseif UIS.KeyboardEnabled then
        return "PC / Desktop"
    elseif UIS.TouchEnabled then
        return "Touch Device"
    end
    return "Unknown"
end

CreateInfoCard("Device","DEVICE TYPE",GetDeviceType(),7)
CreateInfoCard("GameName","GAME NAME",DetectedGame.Name or "Detecting...",8)
CreateInfoCard("PlaceId","PLACE ID",game.PlaceId,9)
CreateInfoCard("Players","PLAYERS IN SERVER",#Players:GetPlayers(),10)
CreateInfoCard("ServerId","SERVER JOB ID",game.JobId~="" and game.JobId or "Not available",11)
CreateInfoCard("Membership","ACCOUNT MEMBERSHIP",tostring(Player.MembershipType):gsub("Enum.MembershipType.",""),12)

local function UpdateInfoValue(key,value)
    local info=InfoValues[key]
    if info and info.Value and info.Value.Parent then
        info.Value.Text=tostring(value)
    end
end

-- game auto-detection: this card fills in the moment the marketplace
-- lookup lands, or instantly for games in the offline database
OnGameResolved(function(name)
    UpdateInfoValue("GameName",name)
end)

local fpsFrames=0
local fpsElapsed=0

RunService.RenderStepped:Connect(function(deltaTime)
    fpsFrames+=1
    fpsElapsed+=deltaTime
    if fpsElapsed>=1 then
        local currentFPS=math.floor(fpsFrames/fpsElapsed+0.5)
        UpdateInfoValue("FPS",tostring(currentFPS).." FPS")
        fpsFrames=0
        fpsElapsed=0
    end
end)

Players.PlayerAdded:Connect(function()
    UpdateInfoValue("Players",#Players:GetPlayers())
end)

Players.PlayerRemoving:Connect(function()
    task.defer(function()
        UpdateInfoValue("Players",#Players:GetPlayers())
    end)
end)

Player:GetPropertyChangedSignal("DisplayName"):Connect(function()
    UpdateInfoValue("DisplayName",Player.DisplayName)
end)

UIS.LastInputTypeChanged:Connect(function()
    UpdateInfoValue("Device",GetDeviceType())
end)

task.spawn(function()
    while ScreenGui.Parent do
        UpdateInfoValue("Executor",DetectExecutor())
        UpdateInfoValue("Players",#Players:GetPlayers())
        UpdateInfoValue("Device",GetDeviceType())
        task.wait(5)
    end
end)

Create("TextLabel",{
    Position=UDim2.fromOffset(20,12),
    Size=UDim2.new(1,-40,0,25),
    BackgroundTransparency=1,
    Text="Appearance",
    TextColor3=CurrentTheme.Text,
    TextSize=18,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},Pages.SETTINGS)

Create("TextLabel",{
    Position=UDim2.fromOffset(21,37),
    Size=UDim2.new(1,-42,0,18),
    BackgroundTransparency=1,
    Text="Choose a look for your interface.",
    TextColor3=CurrentTheme.Muted,
    TextSize=10,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left
},Pages.SETTINGS)

local SettingsScroll=Create("ScrollingFrame",{
    Name="SettingsScroll",
    Position=UDim2.fromOffset(20,65),
    Size=UDim2.new(1,-40,1,-153),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ScrollBarThickness=3,
    ScrollBarImageColor3=UIAccent,
    ScrollingDirection=Enum.ScrollingDirection.Y,
    CanvasSize=UDim2.new(0,0,0,345),
    AutomaticCanvasSize=Enum.AutomaticSize.None
},Pages.SETTINGS)
SettingsScroll.ScrollBarImageTransparency=0.15

local ThemePanel=Create("Frame",{
    Name="ThemeSelector",
    Size=UDim2.new(1,0,0,345),
    BackgroundColor3=CurrentTheme.PanelLight,
    BorderSizePixel=0
},SettingsScroll)
Round(ThemePanel,9)

local ThemePanelStroke=Stroke(ThemePanel,Color3.fromRGB(55,55,65),0.45)

Create("TextLabel",{
    Position=UDim2.fromOffset(13,10),
    Size=UDim2.new(1,-26,0,18),
    BackgroundTransparency=1,
    Text="INTERFACE THEMES  •  24 AVAILABLE",
    TextColor3=CurrentTheme.Muted,
    TextSize=9,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},ThemePanel)

local ThemeChoices=Create("ScrollingFrame",{
    Name="ThemeChoices",
    Position=UDim2.fromOffset(12,35),
    Size=UDim2.new(0.46,-12,1,-45),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ScrollBarThickness=3,
    ScrollBarImageColor3=UIAccent,
    ScrollingDirection=Enum.ScrollingDirection.Y,
    CanvasSize=UDim2.new(0,0,0,0),
    AutomaticCanvasSize=Enum.AutomaticSize.Y,
    ClipsDescendants=true
},ThemePanel)
ThemeChoices.ScrollBarImageTransparency=0.15

Create("UIGridLayout",{
    CellSize=UDim2.new(0.5,-5,0,43),
    CellPadding=UDim2.fromOffset(7,7),
    SortOrder=Enum.SortOrder.LayoutOrder
},ThemeChoices)

local ThemeButtons={}

local PreviewPanel=Create("Frame",{
    AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-12,0,35),
    Size=UDim2.new(0.49,0,0,125),
    BackgroundColor3=CurrentTheme.Background,
    BorderSizePixel=0
},ThemePanel)
Round(PreviewPanel,7)

local PreviewStroke=Stroke(PreviewPanel,UIAccent,0.35)

Create("TextLabel",{
    Position=UDim2.fromOffset(10,7),
    Size=UDim2.new(1,-20,0,14),
    BackgroundTransparency=1,
    Text="LIVE PREVIEW",
    TextColor3=CurrentTheme.Muted,
    TextSize=8,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},PreviewPanel)

local PreviewHeader=Create("Frame",{
    Position=UDim2.fromOffset(9,27),
    Size=UDim2.new(1,-18,0,25),
    BackgroundColor3=CurrentTheme.Panel,
    BorderSizePixel=0
},PreviewPanel)
Round(PreviewHeader,5)

local PreviewDot=Create("Frame",{
    Position=UDim2.fromOffset(7,8),
    Size=UDim2.fromOffset(8,8),
    BackgroundColor3=UIAccent,
    BorderSizePixel=0
},PreviewHeader)
Round(PreviewDot,10)

Create("TextLabel",{
    Position=UDim2.fromOffset(21,0),
    Size=UDim2.new(1,-27,1,0),
    BackgroundTransparency=1,
    Text="BUBBA SCRIPTS",
    TextColor3=CurrentTheme.Text,
    TextSize=8,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},PreviewHeader)

local PreviewCard=Create("Frame",{
    Position=UDim2.fromOffset(9,59),
    Size=UDim2.new(1,-18,0,35),
    BackgroundColor3=CurrentTheme.PanelLight,
    BorderSizePixel=0
},PreviewPanel)
Round(PreviewCard,5)

Create("TextLabel",{
    Position=UDim2.fromOffset(8,3),
    Size=UDim2.new(1,-16,0,13),
    BackgroundTransparency=1,
    Text="Welcome back",
    TextColor3=CurrentTheme.Text,
    TextSize=8,
    Font=Enum.Font.GothamSemibold,
    TextXAlignment=Enum.TextXAlignment.Left
},PreviewCard)

Create("TextLabel",{
    Position=UDim2.fromOffset(8,17),
    Size=UDim2.new(1,-16,0,12),
    BackgroundTransparency=1,
    Text="Your interface preview",
    TextColor3=CurrentTheme.Muted,
    TextSize=7,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left
},PreviewCard)

local PreviewAccent=Create("Frame",{
    Position=UDim2.fromOffset(9,101),
    Size=UDim2.new(0.48,0,0,4),
    BackgroundColor3=UIAccent,
    BorderSizePixel=0
},PreviewPanel)
Round(PreviewAccent,5)

local PreviewAccent2=Create("Frame",{
    Position=UDim2.new(0.53,0,0,101),
    Size=UDim2.new(0.39,0,0,4),
    BackgroundColor3=UIAccent,
    BackgroundTransparency=0.65,
    BorderSizePixel=0
},PreviewPanel)
Round(PreviewAccent2,5)

local PreviewThemeName=Create("TextLabel",{
    Position=UDim2.fromOffset(9,110),
    Size=UDim2.new(1,-18,0,13),
    BackgroundTransparency=1,
    Text=CurrentTheme.Name,
    TextColor3=CurrentTheme.Text,
    TextSize=8,
    Font=Enum.Font.GothamSemibold,
    TextXAlignment=Enum.TextXAlignment.Left
},PreviewPanel)

--[[ ANTI-AFK layered protection (blocks the 20 minute idle kick):
        1. The instant you toggle it ON the idle timer is reset immediately
        2. The moment Roblox marks you idle (Player.Idled) the timer resets again
        3. A heartbeat pings fake input every 60 seconds, so the idle timer never
           gets anywhere near the 20 minute kick even if the Idled event is missed
        4. Each reset double-taps (2 seconds apart) to fully reset the timer
        5. Toggling OFF or unloading stops everything cleanly
        6. A bottom right corner notification reports "Anti AFK On" / "Anti AFK Off"
]]
local AntiAfkEnabled=false
local AntiAfkConnection=nil
local AntiAfkLoopId=0
local AntiAfkToastGeneration=0

-- boot guard: some executors restrict the VirtualUser service. Fetching it
-- must never kill the hub, so wrap the lookup and fall back to nil.
local VirtualUserService=nil
do
    local serviceOk,service=pcall(function()
        return game:GetService("VirtualUser")
    end)
    if serviceOk and service then
        VirtualUserService=service
    else
        warn("[BUBBA ANTI-AFK]: VirtualUser unavailable on this executor, idle protection is limited")
    end
end

local function ResetIdleTimer()
    if not VirtualUserService then return end
    pcall(function()
        VirtualUserService:CaptureController()
        VirtualUserService:ClickButton2(Vector2.new())
    end)
    -- double tap a couple seconds later so the idle timer fully resets
    task.delay(2,function()
        if AntiAfkEnabled and not unloading and VirtualUserService then
            pcall(function()
                VirtualUserService:CaptureController()
                VirtualUserService:ClickButton2(Vector2.new())
            end)
        end
    end)
end

-- NOTE: the anti-afk toggle lives in the HOME tab quick actions grid.
-- The old settings-menu switch was removed to avoid a duplicate control.

-- ANTI-AFK bottom right corner notification (standalone system, fully
-- separate from every other notification in this script)
local AntiAfkToast=Create("Frame",{
    Name="AntiAfkToast",
    AnchorPoint=Vector2.new(1,1),
    Position=UDim2.new(1,230,1,-16),
    Size=UDim2.fromOffset(196,44),
    BackgroundColor3=CurrentTheme.PanelLight,
    BorderSizePixel=0,
    Visible=false,
    ZIndex=320
},ScreenGui)
Round(AntiAfkToast,9)
local AntiAfkToastStroke=Stroke(AntiAfkToast,UIAccent,0.3,1.2)

local AntiAfkToastBar=Create("Frame",{
    Name="AccentLine",
    Position=UDim2.fromOffset(0,10),
    Size=UDim2.new(0,3,1,-20),
    BackgroundColor3=UIAccent,
    BorderSizePixel=0,
    ZIndex=321
},AntiAfkToast)
Round(AntiAfkToastBar,5)

local AntiAfkToastDot=Create("Frame",{
    Name="StatusDot",
    Position=UDim2.fromOffset(16,18),
    Size=UDim2.fromOffset(8,8),
    BackgroundColor3=CurrentTheme.Muted,
    BorderSizePixel=0,
    ZIndex=321
},AntiAfkToast)
Round(AntiAfkToastDot,8)

local AntiAfkToastLabel=Create("TextLabel",{
    Position=UDim2.fromOffset(32,0),
    Size=UDim2.new(1,-44,1,0),
    BackgroundTransparency=1,
    Text="Anti AFK Off",
    TextColor3=CurrentTheme.Text,
    TextSize=12,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left,
    ZIndex=321
},AntiAfkToast)

local function ShowAntiAfkToast(enabled)
    if unloading or not ScreenGui.Parent then return end
    if not AntiAfkToast or not AntiAfkToast.Parent then return end

    AntiAfkToastGeneration+=1
    local generation=AntiAfkToastGeneration

    AntiAfkToastDot.BackgroundColor3=enabled and UIAccent or CurrentTheme.Muted
    AntiAfkToastLabel.Text=enabled and "Anti AFK On" or "Anti AFK Off"
    AntiAfkToastLabel.TextColor3=CurrentTheme.Text
    AntiAfkToast.BackgroundColor3=CurrentTheme.PanelLight
    AntiAfkToastStroke.Color=UIAccent
    AntiAfkToastBar.BackgroundColor3=UIAccent

    AntiAfkToast.Visible=true
    AntiAfkToast.Position=UDim2.new(1,230,1,-16)
    Tween(AntiAfkToast,{
        Position=UDim2.new(1,-22,1,-16)
    },0.45,Enum.EasingStyle.Back)

    task.delay(3,function()
        if unloading then return end
        if AntiAfkToastGeneration~=generation then return end
        if not AntiAfkToast or not AntiAfkToast.Parent then return end

        local tween=Tween(AntiAfkToast,{
            Position=UDim2.new(1,230,1,-16)
        },0.35,Enum.EasingStyle.Quart)

        if tween then
            tween.Completed:Wait()
        end

        if AntiAfkToastGeneration==generation and AntiAfkToast and AntiAfkToast.Parent then
            AntiAfkToast.Visible=false
        end
    end)
end

local function SetAntiAfk(enabled)
    AntiAfkEnabled=enabled

    -- reroute: always tear down the previous protection layers first so
    -- nothing double-fires when the toggle is flipped rapidly
    if AntiAfkConnection then
        AntiAfkConnection:Disconnect()
        AntiAfkConnection=nil
    end
    AntiAfkLoopId+=1

    if enabled then
        -- instant reset: if you were already sitting idle before flipping the
        -- switch on, the 20 minute kick timer is cleared the moment it turns on
        ResetIdleTimer()

        -- layer 1: the exact moment Roblox marks you idle, reset the timer
        -- (Roblox kicks idle players after 20 minutes; faking controller input resets that idle timer)
        AntiAfkConnection=Player.Idled:Connect(function()
            if not AntiAfkEnabled or unloading then return end
            ResetIdleTimer()
        end)

        -- layer 2: heartbeat every 60 seconds so the idle timer never builds
        -- up to the 20 minute kick, even if the Idled event is missed
        AntiAfkLoopId+=1
        local loopId=AntiAfkLoopId
        task.spawn(function()
            while AntiAfkEnabled and loopId==AntiAfkLoopId and ScreenGui.Parent and not unloading do
                task.wait(60)
                if AntiAfkEnabled and loopId==AntiAfkLoopId and ScreenGui.Parent and not unloading then
                    ResetIdleTimer()
                end
            end
        end)

        ShowAntiAfkToast(true)
    else
        ShowAntiAfkToast(false)
    end
end

-- full cleanup when the UI is unloaded or destroyed: kill the idle heartbeat
-- and disconnect the Idled watcher so anti-afk never leaks after unloading
ScreenGui.Destroying:Connect(function()
    AntiAfkEnabled=false
    AntiAfkLoopId+=1
    if AntiAfkConnection then
        AntiAfkConnection:Disconnect()
        AntiAfkConnection=nil
    end
end)

local UnloadPanel
local UnloadPanelStroke
local UnloadTitle
local UnloadDescription
local UnloadButton
local UnloadButtonStroke
local ResizeHandle
local ResizeHandleStroke
local ConfigThemeObjects={}

local function ApplyTheme(theme)
    CurrentTheme=theme
    UIAccent=theme.Accent

    Tween(Main,{BackgroundColor3=theme.Background},0.2)
    Tween(Header,{BackgroundColor3=theme.Panel},0.2)
    Tween(TabBar,{BackgroundColor3=theme.Background},0.2)
    Tween(Content,{BackgroundColor3=theme.Panel},0.2)

    MainStroke.Color=theme.Accent
    ContentStroke.Color=theme.Accent

    for _,object in ipairs(Header:GetChildren()) do
        if object:IsA("TextLabel") then
            if object==Clock then
                object.TextColor3=theme.Text
            elseif object==DateLabel then
                object.TextColor3=theme.Muted
            elseif object.Text=="💫" then
                object.TextColor3=theme.Text
            elseif object.Text:find("Good morning") then
                object.TextColor3=theme.Text
            else
                object.TextColor3=theme.Muted
            end
        end
    end

    for name,button in pairs(Tabs) do
        local selected=name==SelectedTab
        Tween(button,{
            BackgroundColor3=selected and theme.PanelLight or theme.Background,
            TextColor3=selected and theme.Text or theme.Muted
        },0.2)
        Indicators[name].BackgroundColor3=theme.Accent
    end

    SettingsScroll.ScrollBarImageColor3=theme.Accent
    ThemeChoices.ScrollBarImageColor3=theme.Accent
    InfoScroll.ScrollBarImageColor3=theme.Accent

    for _,info in pairs(InfoValues) do
        info.Card.BackgroundColor3=theme.PanelLight
        info.Stroke.Color=theme.Accent
        local accentBar=info.Card:FindFirstChild("AccentBar")
        if accentBar then accentBar.BackgroundColor3=theme.Accent end
        for _,child in ipairs(info.Card:GetChildren()) do
            if child:IsA("TextLabel") then
                child.TextColor3=child.Name=="Value" and theme.Text or theme.Muted
            end
        end
    end

    ThemePanel.BackgroundColor3=theme.PanelLight
    ThemePanelStroke.Color=theme.Accent
    ThemePanelStroke.Transparency=0.65

    if AntiAfkToast and AntiAfkToast.Parent then
        Tween(AntiAfkToast,{BackgroundColor3=theme.PanelLight},0.2)
        AntiAfkToastStroke.Color=theme.Accent
        AntiAfkToastStroke.Transparency=0.3
        AntiAfkToastBar.BackgroundColor3=theme.Accent
        AntiAfkToastDot.BackgroundColor3=AntiAfkEnabled and theme.Accent or theme.Muted
        AntiAfkToastLabel.TextColor3=theme.Text
    end
    PreviewPanel.BackgroundColor3=theme.Background
    PreviewStroke.Color=theme.Accent
    PreviewHeader.BackgroundColor3=theme.Panel
    PreviewDot.BackgroundColor3=theme.Accent
    PreviewCard.BackgroundColor3=theme.PanelLight
    PreviewAccent.BackgroundColor3=theme.Accent
    PreviewAccent2.BackgroundColor3=theme.Accent
    PreviewThemeName.Text=theme.Name

    for _,object in ipairs(PreviewPanel:GetDescendants()) do
        if object:IsA("TextLabel") then
            if object.Text=="LIVE PREVIEW" or object.Text=="Your interface preview" then
                object.TextColor3=theme.Muted
            else
                object.TextColor3=theme.Text
            end
        end
    end

    for themeName,button in pairs(ThemeButtons) do
        local selected=themeName==theme.Name
        local outline=button:FindFirstChild("SelectionStroke")
        button.BackgroundColor3=selected and theme.Panel or theme.Background
        if outline then
            outline.Color=selected and theme.Accent or Color3.fromRGB(65,65,75)
            outline.Transparency=selected and 0 or 0.65
        end
        local title=button:FindFirstChild("ThemeName")
        local description=button:FindFirstChild("ThemeDescription")
        if title then title.TextColor3=theme.Text end
        if description then description.TextColor3=theme.Muted end
    end

    for _,object in ipairs(ConfigThemeObjects) do
        if object and object.Parent then
            if object:IsA("Frame") then
                if object.Name=="ConfigCard" or object.Name=="ConfigSection" then
                    object.BackgroundColor3=theme.PanelLight
                elseif object.Name=="ConfigInput" then
                    object.BackgroundColor3=theme.Background
                elseif object.Name=="ConfigAccent" then
                    object.BackgroundColor3=theme.Accent
                end
            elseif object:IsA("TextLabel") then
                object.TextColor3=object:GetAttribute("MutedText") and theme.Muted or theme.Text
            elseif object:IsA("TextButton") then
                if object:GetAttribute("ConfigToggle") then
                    object.BackgroundColor3=object:GetAttribute("ToggleOn") and theme.Accent or theme.Background
                    object.TextColor3=theme.Text
                else
                    object.BackgroundColor3=theme.Background
                    object.TextColor3=theme.Text
                end
            elseif object:IsA("TextBox") then
                object.BackgroundColor3=theme.Background
                object.TextColor3=theme.Text
                object.PlaceholderColor3=theme.Muted
            elseif object:IsA("UIStroke") then
                object.Color=theme.Accent
            end
        end
    end

    if UnloadPanel then Tween(UnloadPanel,{BackgroundColor3=theme.PanelLight},0.2) end
    if UnloadPanelStroke then Tween(UnloadPanelStroke,{Color=theme.Accent,Transparency=0.55},0.2) end
    if UnloadTitle then UnloadTitle.TextColor3=theme.Text end
    if UnloadDescription then UnloadDescription.TextColor3=theme.Muted end
    if UnloadButton then
        Tween(UnloadButton,{BackgroundColor3=ButtonColor(),TextColor3=theme.Text},0.2)
    end
    if UnloadButtonStroke then Tween(UnloadButtonStroke,{Color=theme.Accent},0.2) end
    if ResizeHandle then
        Tween(ResizeHandle,{BackgroundColor3=theme.PanelLight,TextColor3=theme.Accent},0.2)
    end
    if ResizeHandleStroke then
        Tween(ResizeHandleStroke,{Color=theme.Accent,Transparency=0.35},0.2)
    end

    -- device chrome restyles on every platform now (MobileMinus is nil on
    -- PC and self-guards below)
    do
        if MobileToggle then
            Tween(MobileToggle,{
                BackgroundColor3=Color3.fromRGB(0,0,0),
                TextColor3=Color3.new(1,1,1)
            },0.2)

            local toggleStroke=MobileToggle:FindFirstChildOfClass("UIStroke")
            if toggleStroke then
                Tween(toggleStroke,{Color=theme.Accent},0.2)
            end
        end

        if MobileMinus then
            Tween(MobileMinus,{
                BackgroundColor3=ButtonColor(),
                TextColor3=theme.Text
            },0.2)

            local minusStroke=MobileMinus:FindFirstChildOfClass("UIStroke")
            if minusStroke then
                Tween(minusStroke,{Color=theme.Accent},0.2)
            end
        end

        if MobileNotification then
            Tween(MobileNotification,{
                BackgroundColor3=theme.PanelLight
            },0.2)

            if MobileNotificationStroke then
                Tween(MobileNotificationStroke,{
                    Color=theme.Accent
                },0.2)
            end

            if MobileNotificationAccent then
                Tween(MobileNotificationAccent,{
                    BackgroundColor3=theme.Accent
                },0.2)
            end

            if MobileNotificationTitle then
                MobileNotificationTitle.TextColor3=theme.Text
            end

            if MobileNotificationDescription then
                MobileNotificationDescription.TextColor3=theme.Muted
            end
        end
    end

    if LoadingScreen and LoadingScreen.Parent then
        UpdateLoadingTheme(theme)
    end
end

for index,theme in ipairs(Themes) do
    local ThemeButton=Create("TextButton",{
        Name=theme.Name.."Theme",
        BackgroundColor3=CurrentTheme.Background,
        BorderSizePixel=0,
        Text="",
        AutoButtonColor=false,
        LayoutOrder=index
    },ThemeChoices)
    Round(ThemeButton,6)

    local outline=Stroke(
        ThemeButton,
        theme==CurrentTheme and UIAccent or Color3.fromRGB(65,65,75),
        theme==CurrentTheme and 0 or 0.65,
        1
    )
    outline.Name="SelectionStroke"

    local dot=Create("Frame",{
        Name="ThemeDot",
        Position=UDim2.fromOffset(8,9),
        Size=UDim2.fromOffset(8,8),
        BackgroundColor3=theme.Accent,
        BorderSizePixel=0
    },ThemeButton)
    Round(dot,10)

    Create("TextLabel",{
        Name="ThemeName",
        Position=UDim2.fromOffset(22,5),
        Size=UDim2.new(1,-27,0,16),
        BackgroundTransparency=1,
        Text=theme.Name,
        TextColor3=CurrentTheme.Text,
        TextSize=8,
        Font=Enum.Font.GothamSemibold,
        TextXAlignment=Enum.TextXAlignment.Left
    },ThemeButton)

    Create("TextLabel",{
        Name="ThemeDescription",
        Position=UDim2.fromOffset(22,20),
        Size=UDim2.new(1,-27,0,13),
        BackgroundTransparency=1,
        Text=theme.Description,
        TextColor3=CurrentTheme.Muted,
        TextSize=7,
        Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left
    },ThemeButton)

    ThemeButtons[theme.Name]=ThemeButton

    ThemeButton.MouseEnter:Connect(function()
        if CurrentTheme.Name~=theme.Name then
            Tween(ThemeButton,{BackgroundColor3=CurrentTheme.Panel},0.12)
        end
    end)

    ThemeButton.MouseLeave:Connect(function()
        if CurrentTheme.Name~=theme.Name then
            Tween(ThemeButton,{BackgroundColor3=CurrentTheme.Background},0.12)
        end
    end)

    ThemeButton.MouseButton1Click:Connect(function()
        if not unloading then ApplyTheme(theme) end
    end)
end

local CharacterSettings={
    WalkSpeed=16,
    JumpPower=50,
    HipHeight=2,
    MaxHealth=100,
    FieldOfView=70,
    Gravity=196.2,
    Noclip=false,
    InfiniteJump=false,
    AutoRotate=true
}

local SavedConfigs={}
local ConfigRows={}
local SettingInputs={}
local SettingToggleButtons={}
local OriginalCollisions=setmetatable({},{__mode="k"})
local NoclipConnection
local InfiniteJumpConnection

local function GetCharacter()
    return Player.Character
end

local function GetHumanoid()
    local character=GetCharacter()
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function SafeSet(object,property,value)
    if not object then return false end

    local success=pcall(function()
        object[property]=value
    end)

    return success
end

local function FormatSettingValue(value)
    if value==math.huge then
        return "Inf"
    elseif value==-math.huge then
        return "-Inf"
    end

    return tostring(value)
end

local function ParseSettingValue(value)
    local text=tostring(value):gsub("^%s+",""):gsub("%s+$","")
    local lowered=string.lower(text)

    if lowered=="inf" or lowered=="+inf" or lowered=="infinity" or lowered=="+infinity" then
        return math.huge
    end

    if lowered=="-inf" or lowered=="-infinity" then
        return -math.huge
    end

    local numberValue=tonumber(text)

    if numberValue==nil or numberValue~=numberValue then
        return nil
    end

    return numberValue
end

local function ApplyCharacterSettings()
    local humanoid=GetHumanoid()

    if humanoid then
        SafeSet(humanoid,"UseJumpPower",true)
        SafeSet(humanoid,"WalkSpeed",CharacterSettings.WalkSpeed)
        SafeSet(humanoid,"JumpPower",CharacterSettings.JumpPower)
        SafeSet(humanoid,"HipHeight",CharacterSettings.HipHeight)
        SafeSet(humanoid,"MaxHealth",CharacterSettings.MaxHealth)
        SafeSet(humanoid,"AutoRotate",CharacterSettings.AutoRotate)

        pcall(function()
            humanoid.Health=math.min(humanoid.Health,humanoid.MaxHealth)
        end)
    end

    local camera=workspace.CurrentCamera

    if camera then
        SafeSet(camera,"FieldOfView",CharacterSettings.FieldOfView)
    end

    SafeSet(workspace,"Gravity",CharacterSettings.Gravity)
end

local function SetNoclip(enabled)
    CharacterSettings.Noclip=enabled

    if NoclipConnection then
        NoclipConnection:Disconnect()
        NoclipConnection=nil
    end

    if enabled then
        NoclipConnection=RunService.Stepped:Connect(function()
            if not ScreenGui.Parent or not CharacterSettings.Noclip then return end
            local character=GetCharacter()
            if not character then return end

            for _,part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    if OriginalCollisions[part]==nil then
                        OriginalCollisions[part]=part.CanCollide
                    end
                    part.CanCollide=false
                end
            end
        end)
    else
        for part,wasCollidable in pairs(OriginalCollisions) do
            if part and part.Parent then
                part.CanCollide=wasCollidable
            end
            OriginalCollisions[part]=nil
        end
    end
end

local function SetInfiniteJump(enabled)
    CharacterSettings.InfiniteJump=enabled

    if InfiniteJumpConnection then
        InfiniteJumpConnection:Disconnect()
        InfiniteJumpConnection=nil
    end

    if enabled then
        InfiniteJumpConnection=UIS.JumpRequest:Connect(function()
            if not CharacterSettings.InfiniteJump or unloading then return end
            local humanoid=GetHumanoid()
            if humanoid and humanoid.Health>0 then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end

local function ApplySetting(key,value)
    local allowedSettings={
        WalkSpeed=true,
        JumpPower=true,
        HipHeight=true,
        MaxHealth=true,
        FieldOfView=true,
        Gravity=true
    }

    if not allowedSettings[key] then
        return false
    end

    local numberValue=ParseSettingValue(value)

    if numberValue==nil then
        return false
    end

    CharacterSettings[key]=numberValue
    ApplyCharacterSettings()

    local input=SettingInputs[key]

    if input then
        input.Text=FormatSettingValue(numberValue)
    end

    return true
end

local ConfigPage=Pages.CONFIGS

Create("TextLabel",{
    Name="ConfigsTitle",
    Position=UDim2.fromOffset(20,10),
    Size=UDim2.new(1,-40,0,25),
    BackgroundTransparency=1,
    Text="Player Configuration",
    TextColor3=CurrentTheme.Text,
    TextSize=18,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},ConfigPage)

local ConfigSubtitle=Create("TextLabel",{
    Name="ConfigsSubtitle",
    Position=UDim2.fromOffset(21,35),
    Size=UDim2.new(1,-42,0,18),
    BackgroundTransparency=1,
    Text="Customize your character and manage your saved setups.",
    TextColor3=CurrentTheme.Muted,
    TextSize=10,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left
},ConfigPage)
ConfigSubtitle:SetAttribute("MutedText",true)

local ConfigScroll=Create("ScrollingFrame",{
    Name="ConfigScroll",
    Position=UDim2.fromOffset(18,62),
    Size=UDim2.new(1,-36,1,-74),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ScrollBarThickness=3,
    ScrollBarImageColor3=UIAccent,
    ScrollingDirection=Enum.ScrollingDirection.Y,
    CanvasSize=UDim2.new(0,0,0,0),
    AutomaticCanvasSize=Enum.AutomaticSize.Y
},ConfigPage)

Create("UIListLayout",{
    SortOrder=Enum.SortOrder.LayoutOrder,
    Padding=UDim.new(0,10)
},ConfigScroll)

local function RegisterConfigObject(object)
    table.insert(ConfigThemeObjects,object)
    return object
end

local function CreateConfigSection(title,description,height,order)
    local section=RegisterConfigObject(Create("Frame",{
        Name="ConfigSection",
        Size=UDim2.new(1,0,0,height),
        BackgroundColor3=CurrentTheme.PanelLight,
        BorderSizePixel=0,
        LayoutOrder=order
    },ConfigScroll))
    Round(section,8)
    RegisterConfigObject(Stroke(section,CurrentTheme.Accent,0.72,1))

    RegisterConfigObject(Create("TextLabel",{
        Position=UDim2.fromOffset(13,9),
        Size=UDim2.new(1,-26,0,19),
        BackgroundTransparency=1,
        Text=title,
        TextColor3=CurrentTheme.Text,
        TextSize=11,
        Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left
    },section))

    local sub=RegisterConfigObject(Create("TextLabel",{
        Position=UDim2.fromOffset(13,28),
        Size=UDim2.new(1,-26,0,16),
        BackgroundTransparency=1,
        Text=description,
        TextColor3=CurrentTheme.Muted,
        TextSize=8,
        Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left
    },section))
    sub:SetAttribute("MutedText",true)
    return section
end

local function CreateSettingControl(parent,key,label,defaultValue,positionY)
    local row=Create("Frame",{
        Name=key.."Setting",
        Position=UDim2.fromOffset(12,positionY),
        Size=UDim2.new(1,-24,0,39),
        BackgroundColor3=CurrentTheme.Background,
        BorderSizePixel=0
    },parent)
    Round(row,6)
    RegisterConfigObject(row)

    RegisterConfigObject(Create("TextLabel",{
        Position=UDim2.fromOffset(10,0),
        Size=UDim2.new(0.48,-10,1,0),
        BackgroundTransparency=1,
        Text=label,
        TextColor3=CurrentTheme.Text,
        TextSize=9,
        Font=Enum.Font.GothamSemibold,
        TextXAlignment=Enum.TextXAlignment.Left
    },row))

    local input=RegisterConfigObject(Create("TextBox",{
        Name="ConfigInput",
        AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-57,0.5,0),
        Size=UDim2.fromOffset(72,27),
        BackgroundColor3=CurrentTheme.Panel,
        BorderSizePixel=0,
        Text=FormatSettingValue(defaultValue),
        PlaceholderText="Value / Inf",
        PlaceholderColor3=CurrentTheme.Muted,
        TextColor3=CurrentTheme.Text,
        TextSize=9,
        Font=Enum.Font.GothamSemibold,
        ClearTextOnFocus=false
    },row))
    Round(input,5)
    SettingInputs[key]=input

    local apply=RegisterConfigObject(Create("TextButton",{
        Name="ApplyValue",
        AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-5,0.5,0),
        Size=UDim2.fromOffset(43,27),
        BackgroundColor3=ButtonColor(),
        BorderSizePixel=0,
        Text="SET",
        TextColor3=CurrentTheme.Text,
        TextSize=8,
        Font=Enum.Font.GothamBold,
        AutoButtonColor=false
    },row))
    Round(apply,5)

    apply.MouseButton1Click:Connect(function()
        if ApplySetting(key,input.Text) then
            Tween(apply,{BackgroundColor3=CurrentTheme.Accent},0.12)
            task.delay(0.35,function()
                if apply.Parent then
                    Tween(apply,{BackgroundColor3=ButtonColor()},0.15)
                end
            end)
        else
            input.Text=FormatSettingValue(CharacterSettings[key])
            Tween(input,{BackgroundColor3=Color3.fromRGB(95,35,45)},0.12)
            task.delay(0.4,function()
                if input.Parent then
                    Tween(input,{BackgroundColor3=CurrentTheme.Background},0.15)
                end
            end)
        end
    end)

    input.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            if not ApplySetting(key,input.Text) then
                input.Text=FormatSettingValue(CharacterSettings[key])
            end
        end
    end)

    return row
end

local function CreateConfigToggle(parent,key,label,initialValue,positionY,callback)
    local row=Create("Frame",{
        Name=key.."ToggleRow",
        Position=UDim2.fromOffset(12,positionY),
        Size=UDim2.new(1,-24,0,39),
        BackgroundColor3=CurrentTheme.Background,
        BorderSizePixel=0
    },parent)
    Round(row,6)
    RegisterConfigObject(row)

    RegisterConfigObject(Create("TextLabel",{
        Position=UDim2.fromOffset(10,0),
        Size=UDim2.new(1,-100,1,0),
        BackgroundTransparency=1,
        Text=label,
        TextColor3=CurrentTheme.Text,
        TextSize=9,
        Font=Enum.Font.GothamSemibold,
        TextXAlignment=Enum.TextXAlignment.Left
    },row))

    local toggle=RegisterConfigObject(Create("TextButton",{
        Name="Toggle",
        AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-7,0.5,0),
        Size=UDim2.fromOffset(75,27),
        BackgroundColor3=initialValue and UIAccent or CurrentTheme.Panel,
        BorderSizePixel=0,
        Text=initialValue and "ENABLED" or "DISABLED",
        TextColor3=CurrentTheme.Text,
        TextSize=8,
        Font=Enum.Font.GothamBold,
        AutoButtonColor=false
    },row))
    Round(toggle,5)
    toggle:SetAttribute("ConfigToggle",true)
    toggle:SetAttribute("ToggleOn",initialValue)

    SettingToggleButtons[key]=toggle

    local currentValue=initialValue
    local function updateVisual()
        toggle:SetAttribute("ToggleOn",currentValue)
        toggle.Text=currentValue and "ENABLED" or "DISABLED"
        Tween(toggle,{
            BackgroundColor3=currentValue and CurrentTheme.Accent or CurrentTheme.Background
        },0.15)
    end

    toggle.MouseButton1Click:Connect(function()
        if unloading then return end
        currentValue=not currentValue
        callback(currentValue)
        CharacterSettings[key]=currentValue
        updateVisual()
    end)

    return {
        Set=function(value)
            currentValue=value
            callback(value)
            CharacterSettings[key]=value
            updateVisual()
        end,
        Get=function()
            return currentValue
        end
    }
end

local CharacterSection=CreateConfigSection(
    "CHARACTER MODIFIERS",
    "Adjust movement, jumping, health, and camera settings.",
    300,
    1
)

CreateSettingControl(CharacterSection,"WalkSpeed","PLAYER SPEED",16,52)
CreateSettingControl(CharacterSection,"JumpPower","JUMP POWER",50,96)
CreateSettingControl(CharacterSection,"HipHeight","HIP HEIGHT",2,140)
CreateSettingControl(CharacterSection,"MaxHealth","MAX HEALTH",100,184)
CreateSettingControl(CharacterSection,"FieldOfView","FIELD OF VIEW",70,228)
CreateSettingControl(CharacterSection,"Gravity","WORLD GRAVITY",196.2,272)

local MovementSection=CreateConfigSection(
    "MOVEMENT OPTIONS",
    "Toggle extra movement and character behavior features.",
    166,
    2
)

local NoclipToggle=CreateConfigToggle(
    MovementSection,
    "Noclip",
    "Noclip — walk through parts",
    false,
    52,
    SetNoclip
)

local InfiniteJumpToggle=CreateConfigToggle(
    MovementSection,
    "InfiniteJump",
    "Infinite jump — jump repeatedly",
    false,
    96,
    SetInfiniteJump
)

local AutoRotateToggle=CreateConfigToggle(
    MovementSection,
    "AutoRotate",
    "Auto rotate — face movement direction",
    true,
    140,
    function(value)
        CharacterSettings.AutoRotate=value
        local humanoid=GetHumanoid()
        if humanoid then
            SafeSet(humanoid,"AutoRotate",value)
        end
    end
)

local SaveSection=CreateConfigSection(
    "CONFIGURATION MANAGER",
    "Save your current character settings and selected theme.",
    245,
    3
)

local ConfigNameBox=RegisterConfigObject(Create("TextBox",{
    Name="ConfigInput",
    Position=UDim2.fromOffset(13,52),
    Size=UDim2.new(1,-26,0,34),
    BackgroundColor3=CurrentTheme.Background,
    BorderSizePixel=0,
    Text="",
    PlaceholderText="Enter a configuration name...",
    PlaceholderColor3=CurrentTheme.Muted,
    TextColor3=CurrentTheme.Text,
    TextSize=10,
    Font=Enum.Font.Gotham,
    ClearTextOnFocus=false
},SaveSection))
Round(ConfigNameBox,6)

local SaveConfigButton=RegisterConfigObject(Create("TextButton",{
    Position=UDim2.fromOffset(13,95),
    Size=UDim2.new(0.5,-18,0,34),
    BackgroundColor3=ButtonColor(),
    BorderSizePixel=0,
    Text="SAVE CONFIG",
    TextColor3=CurrentTheme.Text,
    TextSize=9,
    Font=Enum.Font.GothamBold,
    AutoButtonColor=false
},SaveSection))
Round(SaveConfigButton,6)

local ConfigStatus=RegisterConfigObject(Create("TextLabel",{
    Position=UDim2.fromOffset(13,134),
    Size=UDim2.new(1,-26,0,20),
    BackgroundTransparency=1,
    Text="Configurations are stored for this session.",
    TextColor3=CurrentTheme.Muted,
    TextSize=8,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left
},SaveSection))
ConfigStatus:SetAttribute("MutedText",true)

local ConfigListTitle=RegisterConfigObject(Create("TextLabel",{
    Position=UDim2.fromOffset(13,160),
    Size=UDim2.new(1,-26,0,17),
    BackgroundTransparency=1,
    Text="SAVED CONFIGURATIONS",
    TextColor3=CurrentTheme.Text,
    TextSize=8,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},SaveSection))

local ConfigList=Create("Frame",{
    Name="SavedConfigList",
    Position=UDim2.fromOffset(13,181),
    Size=UDim2.new(1,-26,0,54),
    BackgroundTransparency=1
},SaveSection)

local ConfigListLayout=Create("UIListLayout",{
    SortOrder=Enum.SortOrder.LayoutOrder,
    Padding=UDim.new(0,5)
},ConfigList)

local function SetConfigStatus(message,isError)
    ConfigStatus.Text=message
    ConfigStatus.TextColor3=isError and Color3.fromRGB(255,115,125) or CurrentTheme.Muted
end

local function RefreshConfigList()
    for _,child in ipairs(ConfigList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    ConfigRows={}

    local count=0
    for configName in pairs(SavedConfigs) do
        count+=1
        local row=Create("Frame",{
            Name="Saved_"..configName,
            Size=UDim2.new(1,0,0,34),
            BackgroundColor3=CurrentTheme.Background,
            BorderSizePixel=0,
            LayoutOrder=count
        },ConfigList)
        Round(row,5)
        RegisterConfigObject(row)

        RegisterConfigObject(Create("TextLabel",{
            Position=UDim2.fromOffset(9,0),
            Size=UDim2.new(1,-150,1,0),
            BackgroundTransparency=1,
            Text=configName,
            TextColor3=CurrentTheme.Text,
            TextSize=9,
            Font=Enum.Font.GothamSemibold,
            TextXAlignment=Enum.TextXAlignment.Left,
            TextTruncate=Enum.TextTruncate.AtEnd
        },row))

        local load=RegisterConfigObject(Create("TextButton",{
            AnchorPoint=Vector2.new(1,0.5),
            Position=UDim2.new(1,-72,0.5,0),
            Size=UDim2.fromOffset(58,24),
            BackgroundColor3=ButtonColor(),
            BorderSizePixel=0,
            Text="LOAD",
            TextColor3=CurrentTheme.Text,
            TextSize=8,
            Font=Enum.Font.GothamBold,
            AutoButtonColor=false
        },row))
        Round(load,4)

        local delete=RegisterConfigObject(Create("TextButton",{
            AnchorPoint=Vector2.new(1,0.5),
            Position=UDim2.new(1,-5,0.5,0),
            Size=UDim2.fromOffset(58,24),
            BackgroundColor3=Color3.fromRGB(105,42,52),
            BorderSizePixel=0,
            Text="DELETE",
            TextColor3=Color3.fromRGB(255,240,240),
            TextSize=7,
            Font=Enum.Font.GothamBold,
            AutoButtonColor=false
        },row))
        Round(delete,4)

        ConfigRows[configName]=row

        load.MouseButton1Click:Connect(function()
            local data=SavedConfigs[configName]
            if not data then return end

            for key,value in pairs(data.Settings) do
                if key=="Noclip" then
                    NoclipToggle.Set(value)
                elseif key=="InfiniteJump" then
                    InfiniteJumpToggle.Set(value)
                elseif key=="AutoRotate" then
                    AutoRotateToggle.Set(value)
                else
                    ApplySetting(key,value)
                end
            end

            local savedTheme
            for _,theme in ipairs(Themes) do
                if theme.Name==data.Theme then
                    savedTheme=theme
                    break
                end
            end

            if savedTheme then
                ApplyTheme(savedTheme)
            end

            ApplyCharacterSettings()
            SetConfigStatus("Loaded: "..configName,false)
        end)

        delete.MouseButton1Click:Connect(function()
            SavedConfigs[configName]=nil
            RefreshConfigList()
            SetConfigStatus("Deleted: "..configName,false)
        end)
    end

    if count==0 then
        local empty=RegisterConfigObject(Create("TextLabel",{
            Name="EmptyConfigList",
            Size=UDim2.new(1,0,0,30),
            BackgroundTransparency=1,
            Text="No saved configurations yet.",
            TextColor3=CurrentTheme.Muted,
            TextSize=8,
            Font=Enum.Font.Gotham,
            TextXAlignment=Enum.TextXAlignment.Left
        },ConfigList))
        empty:SetAttribute("MutedText",true)
    end

    ConfigList.Size=UDim2.new(1,0,0,math.max(30,count*39))
    SaveSection.Size=UDim2.new(1,0,0,math.max(245,181+ConfigList.Size.Y.Offset+10))
end

SaveConfigButton.MouseButton1Click:Connect(function()
    if unloading then return end

    local configName=ConfigNameBox.Text:gsub("^%s+",""):gsub("%s+$","")
    if configName=="" then
        SetConfigStatus("Enter a name before saving.",true)
        return
    end

    if #configName>24 then
        SetConfigStatus("Configuration names must be 24 characters or less.",true)
        return
    end

    local settingsCopy={}
    for key,value in pairs(CharacterSettings) do
        settingsCopy[key]=value
    end

    SavedConfigs[configName]={
        Settings=settingsCopy,
        Theme=CurrentTheme.Name
    }

    RefreshConfigList()
    ConfigNameBox.Text=""
    SetConfigStatus("Saved configuration: "..configName,false)
end)

RefreshConfigList()

--========================================================
-- VISUALS TAB | ESP + HIGHLIGHTS + WORLD VISUALS
-- chams, box esp, nametags, health bars, distance,
-- tracers, team check, team colors, accent sync,
-- rainbow mode, max distance, fullbright, crosshair
--========================================================

local Lighting=game:GetService("Lighting")

local ESPSettings={
    Master=false,
    Chams=true,
    Boxes=true,
    Names=true,
    Health=true,
    Distance=true,
    Tracers=false,
    TeamCheck=false,
    TeamColors=true,
    AccentSync=true,
    Rainbow=false,
    ThroughWalls=true,
    MaxDistance=2000,
    Fullbright=false,
    Crosshair=false
}

local OldESPGui=PlayerGui:FindFirstChild("BubbaESP")
if OldESPGui then
    OldESPGui:Destroy()
end

for _,plr in ipairs(Players:GetPlayers()) do
    local character=plr.Character
    if character then
        for _,child in ipairs(character:GetChildren()) do
            if child.Name=="BubbaESP_Highlight" then
                child:Destroy()
            end
        end
        local hrp=character:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _,child in ipairs(hrp:GetChildren()) do
                if child.Name=="BubbaESP_Tag" then
                    child:Destroy()
                end
            end
        end
    end
end

local ESPGui=Create("ScreenGui",{
    Name="BubbaESP",
    ResetOnSpawn=false,
    IgnoreGuiInset=true,
    DisplayOrder=1,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling
},PlayerGui)

-- Crosshair overlay
local CrosshairParts={}
local CrosshairHolder=Create("Frame",{
    Name="BubbaCrosshair",
    AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.fromScale(0.5,0.5),
    Size=UDim2.fromOffset(0,0),
    BackgroundTransparency=1,
    Visible=false,
    ZIndex=1
},ESPGui)

local armDefinitions={
    {AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,0.5,-5),Size=UDim2.fromOffset(2,7)},
    {AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0.5,5),Size=UDim2.fromOffset(2,7)},
    {AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(0.5,-5,0.5,0),Size=UDim2.fromOffset(7,2)},
    {AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0.5,5,0.5,0),Size=UDim2.fromOffset(7,2)}
}

for _,definition in ipairs(armDefinitions) do
    local arm=Create("Frame",{
        BackgroundColor3=UIAccent,
        BackgroundTransparency=0.15,
        BorderSizePixel=0,
        ZIndex=1
    },CrosshairHolder)
    arm.AnchorPoint=definition.AnchorPoint
    arm.Position=definition.Position
    arm.Size=definition.Size
    table.insert(CrosshairParts,arm)
end

local crosshairDot=Create("Frame",{
    AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.fromScale(0.5,0.5),
    Size=UDim2.fromOffset(2,2),
    BackgroundColor3=UIAccent,
    BackgroundTransparency=0.15,
    BorderSizePixel=0,
    ZIndex=1
},CrosshairHolder)
table.insert(CrosshairParts,crosshairDot)

-- Fullbright
local FullbrightSaved=nil

local function SetFullbright(enabled)
    ESPSettings.Fullbright=enabled

    if enabled then
        if not FullbrightSaved then
            FullbrightSaved={
                Ambient=Lighting.Ambient,
                OutdoorAmbient=Lighting.OutdoorAmbient,
                Brightness=Lighting.Brightness,
                ClockTime=Lighting.ClockTime,
                FogEnd=Lighting.FogEnd,
                GlobalShadows=Lighting.GlobalShadows
            }
        end
        SafeSet(Lighting,"Ambient",Color3.fromRGB(255,255,255))
        SafeSet(Lighting,"OutdoorAmbient",Color3.fromRGB(255,255,255))
        SafeSet(Lighting,"Brightness",3)
        SafeSet(Lighting,"ClockTime",14)
        SafeSet(Lighting,"FogEnd",100000)
        SafeSet(Lighting,"GlobalShadows",false)
    else
        if FullbrightSaved then
            for property,value in pairs(FullbrightSaved) do
                SafeSet(Lighting,property,value)
            end
        end
    end
end

--========================================================
-- VISUALS PAGE UI
--========================================================

local VisualPage=Pages.VISUALS

local VisualTitle=Create("TextLabel",{
    Name="VisualsTitle",
    Position=UDim2.fromOffset(20,12),
    Size=UDim2.new(1,-40,0,25),
    BackgroundTransparency=1,
    Text="Visual Enhancements",
    TextColor3=CurrentTheme.Text,
    TextSize=18,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},VisualPage)

local VisualSubtitle=Create("TextLabel",{
    Name="VisualsSubtitle",
    Position=UDim2.fromOffset(21,37),
    Size=UDim2.new(1,-42,0,18),
    BackgroundTransparency=1,
    Text="ESP, highlights, tracers, and world visuals.",
    TextColor3=CurrentTheme.Muted,
    TextSize=10,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left
},VisualPage)
VisualSubtitle:SetAttribute("MutedText",true)

local ESPStatusLabel=Create("TextLabel",{
    Name="ESPStatus",
    AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-20,0,16),
    Size=UDim2.fromOffset(240,16),
    BackgroundTransparency=1,
    Text="●  ESP OFFLINE",
    TextColor3=CurrentTheme.Muted,
    TextSize=9,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Right
},VisualPage)

local VisualScroll=Create("ScrollingFrame",{
    Name="VisualsScroll",
    Position=UDim2.fromOffset(20,65),
    Size=UDim2.new(1,-40,1,-78),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ScrollBarThickness=3,
    ScrollBarImageColor3=UIAccent,
    ScrollingDirection=Enum.ScrollingDirection.Y,
    CanvasSize=UDim2.new(0,0,0,0),
    AutomaticCanvasSize=Enum.AutomaticSize.Y
},VisualPage)
VisualScroll.ScrollBarImageTransparency=0.15

Create("UIListLayout",{
    SortOrder=Enum.SortOrder.LayoutOrder,
    Padding=UDim.new(0,10)
},VisualScroll)

local VisualThemeObjects={}

local function RegisterVisualObject(object)
    table.insert(VisualThemeObjects,object)
    return object
end

local function UpdateESPStatus(tracked)
    if not ESPStatusLabel or not ESPStatusLabel.Parent then return end
    if ESPSettings.Master then
        ESPStatusLabel.Text="●  ESP ACTIVE  •  "..tostring(tracked or 0).." TRACKED"
        ESPStatusLabel.TextColor3=UIAccent
    else
        ESPStatusLabel.Text="●  ESP OFFLINE"
        ESPStatusLabel.TextColor3=CurrentTheme.Muted
    end
end

local function CreateVisualSection(title,description,height,order)
    local section=RegisterVisualObject(Create("Frame",{
        Name="VisualSection",
        Size=UDim2.new(1,0,0,height),
        BackgroundColor3=CurrentTheme.PanelLight,
        BorderSizePixel=0,
        LayoutOrder=order
    },VisualScroll))
    Round(section,8)
    RegisterVisualObject(Stroke(section,CurrentTheme.Accent,0.72,1))

    RegisterVisualObject(Create("TextLabel",{
        Position=UDim2.fromOffset(13,9),
        Size=UDim2.new(1,-26,0,19),
        BackgroundTransparency=1,
        Text=title,
        TextColor3=CurrentTheme.Text,
        TextSize=11,
        Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left
    },section))

    local sub=RegisterVisualObject(Create("TextLabel",{
        Position=UDim2.fromOffset(13,28),
        Size=UDim2.new(1,-26,0,16),
        BackgroundTransparency=1,
        Text=description,
        TextColor3=CurrentTheme.Muted,
        TextSize=8,
        Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left
    },section))
    sub:SetAttribute("MutedText",true)

    return section
end

local function CreateVisualToggle(parent,label,initialValue,keyName,positionY,callback)
    local row=RegisterVisualObject(Create("Frame",{
        Name="VisualRow",
        Position=UDim2.fromOffset(12,positionY),
        Size=UDim2.new(1,-24,0,39),
        BackgroundColor3=CurrentTheme.Background,
        BorderSizePixel=0
    },parent))
    Round(row,6)

    RegisterVisualObject(Create("TextLabel",{
        Position=UDim2.fromOffset(10,0),
        Size=UDim2.new(1,-100,1,0),
        BackgroundTransparency=1,
        Text=label,
        TextColor3=CurrentTheme.Text,
        TextSize=9,
        Font=Enum.Font.GothamSemibold,
        TextXAlignment=Enum.TextXAlignment.Left
    },row))

    local toggle=RegisterVisualObject(Create("TextButton",{
        Name="Toggle",
        AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-7,0.5,0),
        Size=UDim2.fromOffset(75,27),
        BackgroundColor3=initialValue and UIAccent or CurrentTheme.Panel,
        BorderSizePixel=0,
        Text=initialValue and "ENABLED" or "DISABLED",
        TextColor3=CurrentTheme.Text,
        TextSize=8,
        Font=Enum.Font.GothamBold,
        AutoButtonColor=false
    },row))
    Round(toggle,5)
    toggle:SetAttribute("VisualToggle",true)
    toggle:SetAttribute("ToggleOn",initialValue)

    local currentValue=initialValue

    local function refresh()
        toggle:SetAttribute("ToggleOn",currentValue)
        toggle.Text=currentValue and "ENABLED" or "DISABLED"
        Tween(toggle,{
            BackgroundColor3=currentValue and CurrentTheme.Accent or CurrentTheme.Background
        },0.15)
    end

    toggle.MouseButton1Click:Connect(function()
        if unloading then return end
        currentValue=not currentValue
        ESPSettings[keyName]=currentValue
        if callback then callback(currentValue) end
        refresh()
    end)

    return {
        Button=toggle,
        Set=function(value)
            currentValue=value
            ESPSettings[keyName]=value
            if callback then callback(value) end
            refresh()
        end,
        Get=function()
            return currentValue
        end
    }
end

local function CreateVisualInput(parent,label,keyName,positionY,onApply)
    local row=RegisterVisualObject(Create("Frame",{
        Name="VisualRow",
        Position=UDim2.fromOffset(12,positionY),
        Size=UDim2.new(1,-24,0,39),
        BackgroundColor3=CurrentTheme.Background,
        BorderSizePixel=0
    },parent))
    Round(row,6)

    RegisterVisualObject(Create("TextLabel",{
        Position=UDim2.fromOffset(10,0),
        Size=UDim2.new(1,-140,1,0),
        BackgroundTransparency=1,
        Text=label,
        TextColor3=CurrentTheme.Text,
        TextSize=9,
        Font=Enum.Font.GothamSemibold,
        TextXAlignment=Enum.TextXAlignment.Left
    },row))

    local input=RegisterVisualObject(Create("TextBox",{
        Name="VisualInput",
        AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-57,0.5,0),
        Size=UDim2.fromOffset(72,27),
        BackgroundColor3=CurrentTheme.Panel,
        BorderSizePixel=0,
        Text=FormatSettingValue(ESPSettings[keyName]),
        PlaceholderText="Value / Inf",
        PlaceholderColor3=CurrentTheme.Muted,
        TextColor3=CurrentTheme.Text,
        TextSize=9,
        Font=Enum.Font.GothamSemibold,
        ClearTextOnFocus=false
    },row))
    Round(input,5)

    local apply=RegisterVisualObject(Create("TextButton",{
        Name="ApplyValue",
        AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-5,0.5,0),
        Size=UDim2.fromOffset(43,27),
        BackgroundColor3=ButtonColor(),
        BorderSizePixel=0,
        Text="SET",
        TextColor3=CurrentTheme.Text,
        TextSize=8,
        Font=Enum.Font.GothamBold,
        AutoButtonColor=false
    },row))
    Round(apply,5)

    local function tryApply()
        local parsed=ParseSettingValue(input.Text)

        if parsed==nil then
            input.Text=FormatSettingValue(ESPSettings[keyName])
            Tween(input,{BackgroundColor3=Color3.fromRGB(95,35,45)},0.12)
            task.delay(0.4,function()
                if input.Parent then
                    Tween(input,{BackgroundColor3=CurrentTheme.Background},0.15)
                end
            end)
            return
        end

        local value=parsed
        if value~=math.huge and value~=-math.huge then
            value=math.clamp(value,50,100000)
        end

        ESPSettings[keyName]=value
        input.Text=FormatSettingValue(value)
        if onApply then onApply(value) end

        Tween(apply,{BackgroundColor3=CurrentTheme.Accent},0.12)
        task.delay(0.35,function()
            if apply.Parent then
                Tween(apply,{BackgroundColor3=ButtonColor()},0.15)
            end
        end)
    end

    apply.MouseButton1Click:Connect(tryApply)
    input.FocusLost:Connect(function(enterPressed)
        if enterPressed then tryApply() end
    end)

    return row
end

local ESPSection=CreateVisualSection(
    "PLAYER ESP",
    "See every player with chams, boxes, names, health, and tracers.",
    412,
    1
)

local ESPMasterToggle=CreateVisualToggle(ESPSection,"Master switch — enable all ESP",ESPSettings.Master,"Master",52,function(value)
    UpdateESPStatus(0)
end)
CreateVisualToggle(ESPSection,"Chams — highlight player bodies",ESPSettings.Chams,"Chams",96)
CreateVisualToggle(ESPSection,"Box ESP — corner brackets",ESPSettings.Boxes,"Boxes",140)
CreateVisualToggle(ESPSection,"Nametags — names above heads",ESPSettings.Names,"Names",184)
CreateVisualToggle(ESPSection,"Health bars — live health status",ESPSettings.Health,"Health",228)
CreateVisualToggle(ESPSection,"Distance — meters below names",ESPSettings.Distance,"Distance",272)
CreateVisualToggle(ESPSection,"Tracers — screen lines to players",ESPSettings.Tracers,"Tracers",316)
CreateVisualToggle(ESPSection,"Team check — hide teammates",ESPSettings.TeamCheck,"TeamCheck",360)

local StyleSection=CreateVisualSection(
    "ESP STYLE",
    "Fine-tune how your visuals look and render.",
    280,
    2
)

CreateVisualToggle(StyleSection,"Accent sync — match UI theme color",ESPSettings.AccentSync,"AccentSync",52)
CreateVisualToggle(StyleSection,"Rainbow mode — animated colors",ESPSettings.Rainbow,"Rainbow",96)
CreateVisualToggle(StyleSection,"Team colors — use player team colors",ESPSettings.TeamColors,"TeamColors",140)
CreateVisualToggle(StyleSection,"Through walls — always visible on top",ESPSettings.ThroughWalls,"ThroughWalls",184)
CreateVisualInput(StyleSection,"Max distance — studs, Inf allowed","MaxDistance",228)

local WorldSection=CreateVisualSection(
    "WORLD VISUALS",
    "Change lighting and add screen overlays.",
    148,
    3
)

local ESPFullbrightToggle=CreateVisualToggle(WorldSection,"Fullbright — brighten the world",ESPSettings.Fullbright,"Fullbright",52,SetFullbright)
local ESPCrosshairToggle=CreateVisualToggle(WorldSection,"Crosshair — center screen overlay",ESPSettings.Crosshair,"Crosshair",96,function(value)
    CrosshairHolder.Visible=value
end)

--========================================================
-- VISUALS THEME SYNC
--========================================================

local function UpdateVisualsTheme(theme)
    if VisualScroll and VisualScroll.Parent then
        VisualScroll.ScrollBarImageColor3=theme.Accent
    end

    for _,object in ipairs(VisualThemeObjects) do
        if object and object.Parent then
            if object:IsA("Frame") then
                if object.Name=="VisualSection" then
                    object.BackgroundColor3=theme.PanelLight
                elseif object.Name=="VisualRow" then
                    object.BackgroundColor3=theme.Background
                end
            elseif object:IsA("TextLabel") then
                object.TextColor3=object:GetAttribute("MutedText") and theme.Muted or theme.Text
            elseif object:IsA("TextButton") then
                if object:GetAttribute("VisualToggle") then
                    object.BackgroundColor3=object:GetAttribute("ToggleOn") and theme.Accent or theme.Background
                    object.TextColor3=theme.Text
                else
                    object.BackgroundColor3=ButtonColor()
                    object.TextColor3=theme.Text
                end
            elseif object:IsA("TextBox") then
                object.BackgroundColor3=theme.Background
                object.TextColor3=theme.Text
                object.PlaceholderColor3=theme.Muted
            elseif object:IsA("UIStroke") then
                object.Color=theme.Accent
            end
        end
    end

    if VisualTitle and VisualTitle.Parent then
        VisualTitle.TextColor3=theme.Text
    end
    if VisualSubtitle and VisualSubtitle.Parent then
        VisualSubtitle.TextColor3=theme.Muted
    end
    if ESPStatusLabel and ESPStatusLabel.Parent then
        ESPStatusLabel.TextColor3=ESPSettings.Master and theme.Accent or theme.Muted
    end
    for _,part in ipairs(CrosshairParts) do
        part.BackgroundColor3=theme.Accent
    end
end

local BaseApplyTheme=ApplyTheme
ApplyTheme=function(theme)
    BaseApplyTheme(theme)
    UpdateVisualsTheme(theme)
end

--========================================================
-- ESP RUNTIME
--========================================================

local ESPEntries={}

local function RemoveESPVisuals(entry)
    if entry.Billboard and entry.Billboard.Parent then
        entry.Billboard:Destroy()
    end
    if entry.Highlight and entry.Highlight.Parent then
        entry.Highlight:Destroy()
    end
    entry.Billboard=nil
    entry.BoxFrame=nil
    entry.BoxStroke=nil
    entry.Brackets=nil
    entry.NameLabel=nil
    entry.InfoLabel=nil
    entry.HealthBack=nil
    entry.HealthFill=nil
    entry.Highlight=nil
end

local function RemoveESPEntry(plr)
    local entry=ESPEntries[plr]
    if not entry then return end
    RemoveESPVisuals(entry)
    if entry.Tracer and entry.Tracer.Parent then
        entry.Tracer:Destroy()
    end
    ESPEntries[plr]=nil
end

local function CreateTracer()
    return Create("Frame",{
        Name="BubbaESP_Tracer",
        BackgroundColor3=UIAccent,
        BackgroundTransparency=0.2,
        BorderSizePixel=0,
        Size=UDim2.fromOffset(0,1),
        Visible=false,
        ZIndex=1
    },ESPGui)
end

local function BuildESPVisuals(entry)
    local character=entry.Character
    if not character then return end

    local hrp=character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    RemoveESPVisuals(entry)

    local highlight=Create("Highlight",{
        Name="BubbaESP_Highlight",
        Adornee=character,
        FillColor=UIAccent,
        FillTransparency=0.55,
        OutlineColor=Color3.fromRGB(255,255,255),
        OutlineTransparency=0,
        DepthMode=ESPSettings.ThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded,
        Enabled=false
    },character)
    entry.Highlight=highlight

    local billboard=Create("BillboardGui",{
        Name="BubbaESP_Tag",
        Adornee=hrp,
        Size=UDim2.new(4.4,0,7.6,0),
        AlwaysOnTop=ESPSettings.ThroughWalls,
        MaxDistance=ESPSettings.MaxDistance,
        Enabled=false
    },hrp)
    entry.Billboard=billboard

    local boxFrame=Create("Frame",{
        Name="Box",
        AnchorPoint=Vector2.new(0.5,0),
        Position=UDim2.new(0.5,0,0.263,0),
        Size=UDim2.new(0.42,0,0.618,0),
        BackgroundTransparency=1,
        BorderSizePixel=0
    },billboard)
    entry.BoxFrame=boxFrame
    entry.BoxStroke=Stroke(boxFrame,UIAccent,0.25,1.4)

    entry.Brackets={}
    for _,corner in ipairs({{1,1},{1,-1},{-1,1},{-1,-1}}) do
        local sx,sy=corner[1],corner[2]
        local anchor=Vector2.new(sx==-1 and 0 or 1, sy==-1 and 0 or 1)
        local position=UDim2.new(sx==-1 and 0 or 1, 0, sy==-1 and 0 or 1, 0)

        local horizontal=Create("Frame",{
            AnchorPoint=anchor,
            Position=position,
            Size=UDim2.new(0.32,0,0,2),
            BackgroundColor3=UIAccent,
            BackgroundTransparency=0.1,
            BorderSizePixel=0
        },boxFrame)

        local vertical=Create("Frame",{
            AnchorPoint=anchor,
            Position=position,
            Size=UDim2.new(0,2,0.24,0),
            BackgroundColor3=UIAccent,
            BackgroundTransparency=0.1,
            BorderSizePixel=0
        },boxFrame)

        table.insert(entry.Brackets,horizontal)
        table.insert(entry.Brackets,vertical)
    end

    local healthBack=Create("Frame",{
        Name="HealthBack",
        AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(0.29,-7,0.5,0),
        Size=UDim2.new(0,4,0.5,0),
        BackgroundColor3=Color3.fromRGB(12,12,16),
        BackgroundTransparency=0.25,
        BorderSizePixel=0
    },billboard)

    local healthFill=Create("Frame",{
        Name="HealthFill",
        AnchorPoint=Vector2.new(1,1),
        Position=UDim2.new(1,0,1,0),
        Size=UDim2.new(1,0,1,0),
        BackgroundColor3=Color3.fromRGB(75,215,130),
        BorderSizePixel=0
    },healthBack)

    entry.HealthBack=healthBack
    entry.HealthFill=healthFill

    local nameLabel=Create("TextLabel",{
        Name="NameLabel",
        AnchorPoint=Vector2.new(0.5,1),
        Position=UDim2.new(0.5,0,0.263,-18),
        Size=UDim2.fromOffset(260,15),
        BackgroundTransparency=1,
        Text=entry.Player.DisplayName,
        TextColor3=Color3.fromRGB(255,255,255),
        TextStrokeColor3=Color3.new(0,0,0),
        TextStrokeTransparency=0.4,
        TextSize=12,
        Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Center
    },billboard)

    local infoLabel=Create("TextLabel",{
        Name="InfoLabel",
        AnchorPoint=Vector2.new(0.5,1),
        Position=UDim2.new(0.5,0,0.263,-2),
        Size=UDim2.fromOffset(260,14),
        BackgroundTransparency=1,
        Text="",
        TextColor3=Color3.fromRGB(235,235,245),
        TextStrokeColor3=Color3.new(0,0,0),
        TextStrokeTransparency=0.5,
        TextSize=10,
        Font=Enum.Font.GothamSemibold,
        TextXAlignment=Enum.TextXAlignment.Center
    },billboard)

    entry.NameLabel=nameLabel
    entry.InfoLabel=infoLabel
end

local ESPStatusClock=0

RunService.RenderStepped:Connect(function(deltaTime)
    if unloading then return end

    local camera=workspace.CurrentCamera
    if not camera then return end

    local active=ESPSettings.Master
    local rainbowColor=ESPSettings.Rainbow and Color3.fromHSV((tick()*0.35)%1,0.7,1) or nil

    if ESPSettings.Crosshair then
        local crosshairColor=rainbowColor or UIAccent
        for _,part in ipairs(CrosshairParts) do
            part.BackgroundColor3=crosshairColor
        end
    end

    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=Player then
            local entry=ESPEntries[plr]
            if not entry then
                entry={Player=plr,Tracer=CreateTracer()}
                ESPEntries[plr]=entry
            end
            if plr.Character~=entry.Character then
                RemoveESPVisuals(entry)
                entry.Character=plr.Character
            end
            if entry.Character and not entry.Billboard then
                BuildESPVisuals(entry)
            end
        end
    end

    for plr,entry in pairs(ESPEntries) do
        if not plr.Parent then
            RemoveESPEntry(plr)
        end
    end

    local viewport=camera.ViewportSize
    local cameraPosition=camera.CFrame.Position
    local tracked=0

    for plr,entry in pairs(ESPEntries) do
        local character=entry.Character
        local billboard=entry.Billboard

        if character and billboard and billboard.Parent then
            local humanoid=character:FindFirstChildOfClass("Humanoid")
            local hrp=character:FindFirstChild("HumanoidRootPart")
            local alive=humanoid~=nil and humanoid.Health>0

            local sameTeam=ESPSettings.TeamCheck and plr.Team~=nil and plr.Team==Player.Team
            local rootPos=hrp and hrp.Position
            local inRange=true
            if rootPos then
                inRange=(cameraPosition-rootPos).Magnitude<=ESPSettings.MaxDistance
            end

            local visible=active and alive and not sameTeam and rootPos~=nil and inRange
            if visible then
                tracked+=1
            end

            local color
            if ESPSettings.TeamColors and not plr.Neutral and plr.Team and plr.Team.TeamColor then
                color=plr.Team.TeamColor.Color
            elseif rainbowColor then
                color=rainbowColor
            elseif ESPSettings.AccentSync then
                color=UIAccent
            else
                color=Color3.fromRGB(255,255,255)
            end

            if entry.Highlight and entry.Highlight.Parent then
                entry.Highlight.Enabled=visible and ESPSettings.Chams
                entry.Highlight.FillColor=color
                entry.Highlight.OutlineColor=Color3.fromRGB(255,255,255)
                entry.Highlight.DepthMode=ESPSettings.ThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
            end

            billboard.Enabled=visible and (ESPSettings.Boxes or ESPSettings.Names or ESPSettings.Distance or ESPSettings.Health)
            billboard.AlwaysOnTop=ESPSettings.ThroughWalls
            billboard.MaxDistance=ESPSettings.MaxDistance

            if entry.BoxFrame then
                entry.BoxFrame.Visible=ESPSettings.Boxes
            end
            if entry.BoxStroke then
                entry.BoxStroke.Color=color
            end
            if entry.Brackets then
                for _,bracket in ipairs(entry.Brackets) do
                    bracket.BackgroundColor3=color
                end
            end
            if entry.NameLabel then
                entry.NameLabel.Visible=ESPSettings.Names
                if ESPSettings.Names and entry.NameLabel.Text~=plr.DisplayName then
                    entry.NameLabel.Text=plr.DisplayName
                end
            end
            if entry.InfoLabel then
                entry.InfoLabel.Visible=ESPSettings.Distance
                if ESPSettings.Distance and rootPos then
                    entry.InfoLabel.Text="@"..plr.Name.."  •  "..math.floor((cameraPosition-rootPos).Magnitude).."m"
                end
            end
            if entry.HealthBack then
                entry.HealthBack.Visible=ESPSettings.Health
                if ESPSettings.Health and humanoid then
                    local fraction=math.clamp(humanoid.Health/math.max(humanoid.MaxHealth,1),0,1)
                    entry.HealthFill.Size=UDim2.new(1,0,fraction,0)
                    entry.HealthFill.BackgroundColor3=Color3.fromRGB(235,60,70):Lerp(Color3.fromRGB(75,215,130),fraction)
                end
            end

            local tracer=entry.Tracer
            if tracer then
                local show=visible and ESPSettings.Tracers
                if show then
                    local head=character:FindFirstChild("Head")
                    local targetPosition=head and head.Position or (rootPos and rootPos+Vector3.new(0,1.5,0))
                    if targetPosition then
                        local screenPosition,onScreen=camera:WorldToViewportPoint(targetPosition)
                        if onScreen then
                            local origin=Vector2.new(viewport.X/2,viewport.Y)
                            local target=Vector2.new(screenPosition.X,screenPosition.Y)
                            local delta=target-origin
                            tracer.Visible=true
                            tracer.BackgroundColor3=color
                            tracer.Size=UDim2.fromOffset(delta.Magnitude,1)
                            tracer.Position=UDim2.fromOffset((origin.X+target.X)/2,(origin.Y+target.Y)/2)
                            tracer.Rotation=math.deg(math.atan2(delta.Y,delta.X))
                        else
                            tracer.Visible=false
                        end
                    else
                        tracer.Visible=false
                    end
                else
                    tracer.Visible=false
                end
            end
        else
            if entry.Tracer then
                entry.Tracer.Visible=false
            end
        end
    end

    ESPStatusClock+=deltaTime or 0
    if ESPStatusClock>=0.25 then
        ESPStatusClock=0
        UpdateESPStatus(tracked)
    end
end)

UpdateESPStatus(0)

--========================================================
-- VISUALS CLEANUP (runs when Bubba unloads)
--========================================================

local function CleanupVisuals()
    for plr,entry in pairs(ESPEntries) do
        RemoveESPVisuals(entry)
        if entry.Tracer and entry.Tracer.Parent then
            entry.Tracer:Destroy()
        end
        ESPEntries[plr]=nil
    end

    if FullbrightSaved then
        for property,value in pairs(FullbrightSaved) do
            SafeSet(Lighting,property,value)
        end
        FullbrightSaved=nil
    end

    if ESPGui and ESPGui.Parent then
        ESPGui:Destroy()
    end
end

ScreenGui.Destroying:Connect(function()
    CleanupVisuals()
end)

Player.CharacterAdded:Connect(function(character)
    task.wait(0.35)
    if unloading or not ScreenGui.Parent then return end
    ApplyCharacterSettings()
    if CharacterSettings.Noclip then
        SetNoclip(true)
    end
end)

------------------------------------------------------------
-- CHAOS ENGINE HANDLE (filled in by the owner FUN deck)
-- Declared before UnloadBubba so the outro can shut every
-- fling / troll loop down before the curtain call begins.
------------------------------------------------------------
local ChaosEngine=nil

local function UnloadBubba()
    if unloading then return end
    unloading=true
    -- stop every chaos loop before the curtain call begins
    if ChaosEngine then
        pcall(function()
            ChaosEngine.StopAll()
        end)
    end

    if NoclipConnection then
        NoclipConnection:Disconnect()
        NoclipConnection=nil
    end

    if InfiniteJumpConnection then
        InfiniteJumpConnection:Disconnect()
        InfiniteJumpConnection=nil
    end

    for part,wasCollidable in pairs(OriginalCollisions) do
        if part and part.Parent then
            part.CanCollide=wasCollidable
        end
        OriginalCollisions[part]=nil
    end

    local theme=CurrentTheme

    -- hide every floating layer so the outro owns the whole screen
    if MobileToggle and MobileToggle.Parent then MobileToggle.Visible=false end
    if MobileNotification and MobileNotification.Parent then MobileNotification.Visible=false end
    if AntiAfkToast and AntiAfkToast.Parent then AntiAfkToast.Visible=false end

    ------------------------------------------------------------
    -- THE BUBBA CURTAIN CALL | cinematic outro v6
    -- THE LAST RIDE: the hub does not just close — it takes one
    -- last drive down a golden hour corniche somewhere between
    -- Nice and Portofino, then lifts off into the dusk.
    -- 1. the drive: a pseudo-3D coastal road unfolds — perspective
    --    asphalt with flowing dashes, a slanted shoreline with a
    --    glittering sea, cypresses and umbrella pines rushing past,
    --    a hilltop village with a church tower on the cape
    -- 2. the rise: the camera lifts off the road — the whole
    --    coastline sinks away below and the evening sky opens up
    -- 3. the farewell: THANK YOU FOR USING BUBBA hangs in the
    --    dusk in gold Bodoni with a shimmering sweep, holds its
    --    bow, then the entire memory fades back to the game
    ------------------------------------------------------------

    local Ok,Err=pcall(function()
        -- oversized so the rise and drift never expose screen edges
        local Veil=Create("Frame",{
            Name="FinaleVeil",
            Size=UDim2.fromScale(1.12,1.12),
            Position=UDim2.fromScale(-0.06,-0.06),
            BackgroundColor3=Color3.fromRGB(5,7,12),
            BackgroundTransparency=1,
            BorderSizePixel=0,
            ZIndex=400
        },ScreenGui)

        ------------------------------------------------------------
        -- palette: riviera golden hour
        ------------------------------------------------------------
        local SkyTop=Color3.fromRGB(61,78,134)
        local SkyRose=Color3.fromRGB(176,106,110)
        local SkyAmber=Color3.fromRGB(232,154,110)
        local SkyGold=Color3.fromRGB(246,198,138)
        local SkyCream=Color3.fromRGB(251,224,172)
        local HazeGold=Color3.fromRGB(255,227,176)
        local SeaDeep=Color3.fromRGB(39,80,126)
        local SeaMid=Color3.fromRGB(122,158,184)
        local SeaGlow=Color3.fromRGB(239,201,143)
        local AsphaltA=Color3.fromRGB(88,90,94)
        local AsphaltB=Color3.fromRGB(80,82,86)
        local AsphaltHaze=Color3.fromRGB(147,134,122)
        local DashIvory=Color3.fromRGB(245,235,216)
        local EdgeIvory=Color3.fromRGB(238,228,206)
        local GrassLight=Color3.fromRGB(119,128,78)
        local GrassDark=Color3.fromRGB(110,119,72)
        local GrassWarm=Color3.fromRGB(168,154,94)
        local Sand=Color3.fromRGB(226,211,160)
        local MountainFar=Color3.fromRGB(139,128,166)
        local MountainNear=Color3.fromRGB(108,98,136)
        local WoodBrown=Color3.fromRGB(107,74,50)
        local CypressGreen=Color3.fromRGB(44,66,48)
        local PineGreen=Color3.fromRGB(59,92,58)
        local PineLight=Color3.fromRGB(78,115,72)
        local BushGreen=Color3.fromRGB(70,99,60)
        local BushLight=Color3.fromRGB(85,116,71)
        local TerraRoof=Color3.fromRGB(180,85,47)
        local WallCream=Color3.fromRGB(230,217,190)
        local WallSand=Color3.fromRGB(220,201,164)

        local HorizonY=0.40

        local function YAt(t)
            return HorizonY+0.63*t^2.15
        end
        local function RoadCenterX(t)
            return 0.5+0.13*(1-t)^1.8
        end
        local function RoadHalfW(t)
            return (0.024+1.02*t^1.9)/2
        end
        local function ShoreX(t)
            return 0.56-0.84*t^1.1
        end

        ------------------------------------------------------------
        -- the whole drive lives inside one canvas so it can fade
        -- in and dissolve as a single memory
        ------------------------------------------------------------
        local Canvas=Create("CanvasGroup",{
            Name="RideCanvas",
            AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.new(0.5,0,0.5,0),
            Size=UDim2.fromScale(1,1),
            BackgroundTransparency=1,
            GroupTransparency=1,
            BorderSizePixel=0,
            ZIndex=401
        },Veil)
        local CanvasScale=Create("UIScale",{Scale=1},Canvas)

        ------------------------------------------------------------
        -- SKY: dusk blue melting into a riviera golden hour
        ------------------------------------------------------------
        local Sky=Create("Frame",{
            Name="Sky",
            Size=UDim2.fromScale(1,1),
            BackgroundColor3=Color3.fromRGB(255,255,255),
            BorderSizePixel=0,
            ZIndex=1
        },Canvas)
        Create("UIGradient",{
            Rotation=90,
            Color=ColorSequence.new({
                ColorSequenceKeypoint.new(0,SkyTop),
                ColorSequenceKeypoint.new(0.42,SkyRose),
                ColorSequenceKeypoint.new(0.68,SkyAmber),
                ColorSequenceKeypoint.new(0.85,SkyGold),
                ColorSequenceKeypoint.new(1,SkyCream)
            })
        },Sky)

        -- the sun hanging over the sea, gently breathing
        local SunGlow2=Create("Frame",{
            Name="SunGlow2",
            AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.new(0.18,0,0.155,0),
            Size=UDim2.new(0.17,0,0.17,0),
            BackgroundColor3=Color3.fromRGB(255,206,120),
            BackgroundTransparency=0.78,
            BorderSizePixel=0,
            ZIndex=2
        },Canvas)
        Round(SunGlow2,200)
        local SunGlow=Create("Frame",{
            Name="SunGlow",
            AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.new(0.18,0,0.155,0),
            Size=UDim2.new(0.10,0,0.10,0),
            BackgroundColor3=Color3.fromRGB(255,217,143),
            BackgroundTransparency=0.55,
            BorderSizePixel=0,
            ZIndex=2
        },Canvas)
        Round(SunGlow,200)
        local SunCore=Create("Frame",{
            Name="SunCore",
            AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.new(0.18,0,0.155,0),
            Size=UDim2.new(0.05,0,0.05,0),
            BackgroundColor3=Color3.fromRGB(255,243,206),
            BorderSizePixel=0,
            ZIndex=3
        },Canvas)
        Round(SunCore,200)

        ------------------------------------------------------------
        -- CLOUDS: slow warm drifters
        ------------------------------------------------------------
        local Clouds={}
        local CloudDefs={
            {X=0.30,Y=0.075,Speed=0.010,Scale=1.0},
            {X=0.72,Y=0.05,Speed=0.006,Scale=0.8},
            {X=0.55,Y=0.17,Speed=0.008,Scale=1.15},
            {X=0.92,Y=0.115,Speed=0.007,Scale=0.65}
        }
        for _,def in ipairs(CloudDefs) do
            local cloud=Create("Frame",{
                Name="Cloud",
                AnchorPoint=Vector2.new(0.5,0.5),
                Position=UDim2.new(def.X,0,def.Y,0),
                Size=UDim2.new(0.16*def.Scale,0,0.028*def.Scale,0),
                BackgroundTransparency=1,
                ZIndex=4
            },Canvas)
            local main=Create("Frame",{
                Position=UDim2.new(0.03,0,0.38,0),
                Size=UDim2.new(0.58,0,0.55,0),
                BackgroundColor3=Color3.fromRGB(255,244,228),
                BackgroundTransparency=0.20,
                BorderSizePixel=0
            },cloud)
            Round(main,40)
            local puffL=Create("Frame",{
                Position=UDim2.new(0,0,0.22,0),
                Size=UDim2.new(0.38,0,0.48,0),
                BackgroundColor3=Color3.fromRGB(255,244,228),
                BackgroundTransparency=0.26,
                BorderSizePixel=0
            },cloud)
            Round(puffL,40)
            local puffR=Create("Frame",{
                Position=UDim2.new(0.46,0,0.5,0),
                Size=UDim2.new(0.52,0,0.42,0),
                BackgroundColor3=Color3.fromRGB(255,240,220),
                BackgroundTransparency=0.30,
                BorderSizePixel=0
            },cloud)
            Round(puffR,40)
            table.insert(Clouds,{Root=cloud,X=def.X,Y=def.Y,Speed=def.Speed})
        end

        ------------------------------------------------------------
        -- MOUNTAINS: diamond peaks on the cape, haze behind
        ------------------------------------------------------------
        local function Peak(x,size,color,z)
            local peak=Create("Frame",{
                AnchorPoint=Vector2.new(0.5,0.5),
                Position=UDim2.new(x,0,HorizonY+size*0.10,0),
                Size=UDim2.new(size,0,size,0),
                Rotation=45,
                BackgroundColor3=color,
                BorderSizePixel=0,
                ZIndex=z
            },Canvas)
            return peak
        end
        Peak(0.68,0.30,MountainFar,5)
        Peak(0.87,0.20,MountainFar,5)
        Peak(1.03,0.24,MountainFar,5)
        Peak(0.78,0.22,MountainNear,6)
        Peak(0.97,0.30,MountainNear,6)
        -- tiny islands on the far sea
        Peak(0.07,0.030,Color3.fromRGB(126,147,168),5)
        Peak(0.13,0.020,Color3.fromRGB(118,140,164),5)

        ------------------------------------------------------------
        -- BIRDS: three lazy gliders over the water
        ------------------------------------------------------------
        local Birds={}
        local BirdDefs={
            {X=0.30,Y=0.20,Ph=0},
            {X=0.34,Y=0.185,Ph=1.9},
            {X=0.27,Y=0.165,Ph=3.7}
        }
        local BirdBaseScale=math.clamp(Veil.AbsoluteSize.X/1400,0.8,2.0)
        for _,def in ipairs(BirdDefs) do
            local bird=Create("Frame",{
                Name="Bird",
                AnchorPoint=Vector2.new(0.5,0.5),
                Position=UDim2.new(def.X,0,def.Y,0),
                Size=UDim2.fromOffset(18,10),
                BackgroundTransparency=1,
                ZIndex=8
            },Canvas)
            Create("UIScale",{Scale=BirdBaseScale},bird)
            local w1=Create("Frame",{
                AnchorPoint=Vector2.new(1,0.5),
                Position=UDim2.new(0.5,0,0.5,0),
                Size=UDim2.fromOffset(9,2),
                Rotation=-18,
                BackgroundColor3=Color3.fromRGB(59,58,74),
                BackgroundTransparency=0.1,
                BorderSizePixel=0
            },bird)
            local w2=Create("Frame",{
                AnchorPoint=Vector2.new(0,0.5),
                Position=UDim2.new(0.5,0,0.5,0),
                Size=UDim2.fromOffset(9,2),
                Rotation=18,
                BackgroundColor3=Color3.fromRGB(59,58,74),
                BackgroundTransparency=0.1,
                BorderSizePixel=0
            },bird)
            table.insert(Birds,{Root=bird,W1=w1,W2=w2,X=def.X,Y=def.Y,Ph=def.Ph})
        end

        ------------------------------------------------------------
        -- SEA + shore + glitter path under the sun
        ------------------------------------------------------------
        local Sea=Create("Frame",{
            Name="Sea",
            Position=UDim2.new(0,0,HorizonY-0.002,0),
            Size=UDim2.new(0.60,0,0.34,0),
            BackgroundColor3=Color3.fromRGB(255,255,255),
            BorderSizePixel=0,
            ZIndex=7
        },Canvas)
        Create("UIGradient",{
            Rotation=90,
            Color=ColorSequence.new({
                ColorSequenceKeypoint.new(0,SeaGlow),
                ColorSequenceKeypoint.new(0.25,SeaMid),
                ColorSequenceKeypoint.new(1,SeaDeep)
            })
        },Sea)
        -- a luminous horizon line
        local HazeLine=Create("Frame",{
            Position=UDim2.new(0,0,HorizonY-0.004,0),
            Size=UDim2.new(1,0,0.008,0),
            BackgroundColor3=HazeGold,
            BackgroundTransparency=0.35,
            BorderSizePixel=0,
            ZIndex=8
        },Canvas)
        local Glitter={}
        local GlitterDefs={
            {X=0.168,Y=0.016,W=0.020,Ph=0},
            {X=0.185,Y=0.030,W=0.028,Ph=1.3},
            {X=0.160,Y=0.046,W=0.016,Ph=2.6},
            {X=0.192,Y=0.060,W=0.024,Ph=0.7},
            {X=0.176,Y=0.078,W=0.012,Ph=3.4},
            {X=0.196,Y=0.092,W=0.018,Ph=2.1}
        }
        for _,def in ipairs(GlitterDefs) do
            local spark=Create("Frame",{
                Position=UDim2.new(def.X,0,HorizonY+def.Y,0),
                Size=UDim2.new(def.W,0,0.0035,0),
                BackgroundColor3=Color3.fromRGB(255,233,184),
                BackgroundTransparency=0.4,
                BorderSizePixel=0,
                ZIndex=8
            },Canvas)
            Round(spark,4)
            table.insert(Glitter,{Frame=spark,Ph=def.Ph})
        end

        ------------------------------------------------------------
        -- GROUND: slanted coastline bands, sea to the left
        ------------------------------------------------------------
        local GroundBands={}
        local GroundM=30
        for j=0,GroundM-1 do
            local t0=j/GroundM
            local t1=(j+1)/GroundM
            local y0=YAt(t0)
            local y1=YAt(t1)+0.0015
            local lx=ShoreX(t0)
            local band=Create("Frame",{
                Position=UDim2.new(lx,0,y0,0),
                Size=UDim2.new(1.08-lx,0,y1-y0,0),
                BackgroundColor3=GrassLight,
                BorderSizePixel=0,
                ZIndex=10
            },Canvas)
            -- sand strip along the shore edge
            local stripW=(0.012+0.10*t0*t0)/(1.08-lx)
            Create("Frame",{
                Size=UDim2.new(stripW,0,1,0),
                BackgroundColor3=Sand,
                BackgroundTransparency=0.1,
                BorderSizePixel=0
            },band)
            table.insert(GroundBands,{Frame=band,T=t0})
        end
        -- tint the far ground warm before painting it over
        for _,g in ipairs(GroundBands) do
            g.Frame.BackgroundColor3=GrassLight:Lerp(GrassWarm,(1-g.T)^1.6*0.55)
        end

        ------------------------------------------------------------
        -- VILLAGE: a hilltop hamlet with a campanile on the cape
        ------------------------------------------------------------
        local BaseY=HorizonY+0.014
        -- soft hill mound behind the hamlet
        local Hill=Create("Frame",{
            Position=UDim2.new(0.62,0,HorizonY-0.045,0),
            Size=UDim2.new(0.52,0,0.075,0),
            BackgroundColor3=Color3.fromRGB(122,131,85),
            BorderSizePixel=0,
            ZIndex=9
        },Canvas)
        Round(Hill,60)
        local HouseDefs={
            {X=0.700,W=0.030,H=0.024,C=WallCream},
            {X=0.742,W=0.024,H=0.018,C=WallSand},
            {X=0.772,W=0.034,H=0.028,C=WallCream},
            {X=0.880,W=0.026,H=0.020,C=WallSand},
            {X=0.916,W=0.030,H=0.024,C=WallCream}
        }
        for _,h in ipairs(HouseDefs) do
            local wall=Create("Frame",{
                Position=UDim2.new(h.X,0,BaseY-h.H,0),
                Size=UDim2.new(h.W,0,h.H,0),
                BackgroundColor3=h.C,
                BorderSizePixel=0,
                ZIndex=15
            },Canvas)
            Round(wall,2)
            local roof=Create("Frame",{
                Position=UDim2.new(h.X-0.002,0,BaseY-h.H-0.008,0),
                Size=UDim2.new(h.W+0.004,0,0.009,0),
                BackgroundColor3=TerraRoof,
                BorderSizePixel=0,
                ZIndex=16
            },Canvas)
            Round(roof,2)
        end
        -- village cypresses
        for _,c in ipairs({{0.716,0.050},{0.806,0.058},{0.958,0.044}}) do
            local cy=Create("Frame",{
                Position=UDim2.new(c[1],0,BaseY-c[2],0),
                Size=UDim2.new(0.006,0,c[2],0),
                BackgroundColor3=CypressGreen,
                BorderSizePixel=0,
                ZIndex=15
            },Canvas)
            Round(cy,4)
        end
        -- the church tower with dome and cross
        local Tower=Create("Frame",{
            Position=UDim2.new(0.845,0,HorizonY-0.052,0),
            Size=UDim2.new(0.017,0,0.062,0),
            BackgroundColor3=Color3.fromRGB(234,224,206),
            BorderSizePixel=0,
            ZIndex=16
        },Canvas)
        Round(Tower,2)
        local Belfry=Create("Frame",{
            Position=UDim2.new(0.8485,0,HorizonY-0.044,0),
            Size=UDim2.new(0.010,0,0.013,0),
            BackgroundColor3=Color3.fromRGB(74,58,48),
            BorderSizePixel=0,
            ZIndex=17
        },Canvas)
        Round(Belfry,6)
        local Dome=Create("Frame",{
            Position=UDim2.new(0.8435,0,HorizonY-0.062,0),
            Size=UDim2.new(0.020,0,0.013,0),
            BackgroundColor3=TerraRoof,
            BorderSizePixel=0,
            ZIndex=17
        },Canvas)
        Round(Dome,8)
        local CrossV=Create("Frame",{
            Position=UDim2.new(0.8527,0,HorizonY-0.070,0),
            Size=UDim2.new(0.0016,0,0.008,0),
            BackgroundColor3=Color3.fromRGB(233,185,78),
            BorderSizePixel=0,
            ZIndex=17
        },Canvas)
        local CrossH=Create("Frame",{
            Position=UDim2.new(0.8505,0,HorizonY-0.0675,0),
            Size=UDim2.new(0.006,0,0.0016,0),
            BackgroundColor3=Color3.fromRGB(233,185,78),
            BorderSizePixel=0,
            ZIndex=17
        },Canvas)

        ------------------------------------------------------------
        -- ROAD: perspective bands with flowing dashes and edges
        ------------------------------------------------------------
        local RoadBands={}
        local RoadN=46
        for i=0,RoadN-1 do
            local t0=i/RoadN
            local t1=(i+1)/RoadN
            local y0=YAt(t0)
            local y1=YAt(t1)+0.0018
            local tm=(t0+t1)/2
            local band=Create("Frame",{
                AnchorPoint=Vector2.new(0.5,0),
                Position=UDim2.new(RoadCenterX(tm),0,y0,0),
                Size=UDim2.new(0.024+1.02*tm^1.9,0,y1-y0,0),
                BackgroundColor3=AsphaltA,
                BorderSizePixel=0,
                ZIndex=12
            },Canvas)
            local edgeW=0.022+0.012*tm
            Create("Frame",{
                Size=UDim2.new(edgeW,0,1,0),
                BackgroundColor3=EdgeIvory,
                BackgroundTransparency=0.15+0.35*(1-tm),
                BorderSizePixel=0
            },band)
            Create("Frame",{
                AnchorPoint=Vector2.new(1,0),
                Position=UDim2.new(1,0,0,0),
                Size=UDim2.new(edgeW,0,1,0),
                BackgroundColor3=EdgeIvory,
                BackgroundTransparency=0.15+0.35*(1-tm),
                BorderSizePixel=0
            },band)
            local dash=Create("Frame",{
                AnchorPoint=Vector2.new(0.5,0),
                Position=UDim2.new(0.5,0,0,0),
                Size=UDim2.new(0.05,0,1,0),
                BackgroundColor3=DashIvory,
                BackgroundTransparency=0.06+0.30*(1-tm),
                BorderSizePixel=0
            },band)
            table.insert(RoadBands,{Frame=band,Dash=dash,T=tm,Index=i+1})
        end

        ------------------------------------------------------------
        -- ROADSIDE: cypresses, umbrella pines, bollards, bushes
        -- rushing past with true perspective
        ------------------------------------------------------------
        local function BuildCypress()
            local root=Create("Frame",{
                Size=UDim2.fromOffset(44,84),
                BackgroundTransparency=1
            })
            Create("Frame",{
                Position=UDim2.fromOffset(20,78),
                Size=UDim2.fromOffset(4,6),
                BackgroundColor3=WoodBrown,
                BorderSizePixel=0
            },root)
            local body=Create("Frame",{
                Position=UDim2.fromOffset(15,26),
                Size=UDim2.fromOffset(14,52),
                BackgroundColor3=CypressGreen,
                BorderSizePixel=0
            },root)
            Round(body,7)
            local tip=Create("Frame",{
                Position=UDim2.fromOffset(18,8),
                Size=UDim2.fromOffset(8,24),
                BackgroundColor3=Color3.fromRGB(51,80,58),
                BorderSizePixel=0
            },root)
            Round(tip,4)
            return root
        end
        local function BuildPine()
            local root=Create("Frame",{
                Size=UDim2.fromOffset(44,84),
                BackgroundTransparency=1
            })
            Create("Frame",{
                Position=UDim2.fromOffset(20,54),
                Size=UDim2.fromOffset(5,30),
                BackgroundColor3=WoodBrown,
                BorderSizePixel=0
            },root)
            local crown=Create("Frame",{
                Position=UDim2.fromOffset(5,40),
                Size=UDim2.fromOffset(34,14),
                BackgroundColor3=PineGreen,
                BorderSizePixel=0
            },root)
            Round(crown,7)
            local inner=Create("Frame",{
                Position=UDim2.fromOffset(10,42),
                Size=UDim2.fromOffset(24,9),
                BackgroundColor3=PineLight,
                BorderSizePixel=0
            },root)
            Round(inner,5)
            return root
        end
        local function BuildBollard()
            local root=Create("Frame",{
                Size=UDim2.fromOffset(44,84),
                BackgroundTransparency=1
            })
            local post=Create("Frame",{
                Position=UDim2.fromOffset(18,58),
                Size=UDim2.fromOffset(8,24),
                BackgroundColor3=Color3.fromRGB(242,237,226),
                BorderSizePixel=0
            },root)
            Round(post,2)
            local cap=Create("Frame",{
                Position=UDim2.fromOffset(18,52),
                Size=UDim2.fromOffset(8,8),
                BackgroundColor3=Color3.fromRGB(196,59,46),
                BorderSizePixel=0
            },root)
            Round(cap,2)
            return root
        end
        local function BuildBush()
            local root=Create("Frame",{
                Size=UDim2.fromOffset(44,84),
                BackgroundTransparency=1
            })
            local blob=Create("Frame",{
                Position=UDim2.fromOffset(10,72),
                Size=UDim2.fromOffset(26,12),
                BackgroundColor3=BushGreen,
                BorderSizePixel=0
            },root)
            Round(blob,6)
            local blob2=Create("Frame",{
                Position=UDim2.fromOffset(16,68),
                Size=UDim2.fromOffset(14,9),
                BackgroundColor3=BushLight,
                BorderSizePixel=0
            },root)
            Round(blob2,5)
            return root
        end
        local TreePool={}
        local TreeDefs={
            {Side=1,P=0.00,Build=BuildCypress},
            {Side=1,P=0.18,Build=BuildPine},
            {Side=1,P=0.36,Build=BuildBush},
            {Side=1,P=0.54,Build=BuildCypress},
            {Side=1,P=0.72,Build=BuildPine},
            {Side=1,P=0.90,Build=BuildBollard},
            {Side=-1,P=0.09,Build=BuildBollard},
            {Side=-1,P=0.31,Build=BuildBush},
            {Side=-1,P=0.53,Build=BuildBollard},
            {Side=-1,P=0.75,Build=BuildPine}
        }
        for _,def in ipairs(TreeDefs) do
            local root=def.Build()
            root.AnchorPoint=Vector2.new(0.5,1)
            root.ZIndex=20
            root.Parent=Canvas
            local scale=Create("UIScale",{Scale=0.1},root)
            table.insert(TreePool,{Root=root,Scale=scale,Side=def.Side,P=def.P})
        end

        ------------------------------------------------------------
        -- THE CAR: a scarlet gran turismo, rear three-quarter
        -- hero shot — wide haunches, full-width light bar,
        -- big diffuser, GT wing, and a BUBBA plate
        ------------------------------------------------------------
        local CarRoot=Create("Frame",{
            Name="TheCar",
            AnchorPoint=Vector2.new(0.5,1),
            Position=UDim2.new(0.5,0,0.972,0),
            Size=UDim2.fromOffset(260,120),
            BackgroundTransparency=1,
            ZIndex=30
        },Canvas)
        local CarScale=Create("UIScale",{Scale=1},CarRoot)
        local BodyRed=Color3.fromRGB(200,30,48)
        local BodyDark=Color3.fromRGB(126,15,29)
        local BodyLight=Color3.fromRGB(230,59,76)
        local function RedPanel(x,y,w,h,radius,z)
            local panel=Create("Frame",{
                Position=UDim2.fromOffset(x,y),
                Size=UDim2.fromOffset(w,h),
                BackgroundColor3=BodyRed,
                BorderSizePixel=0,
                ZIndex=z
            },CarRoot)
            Round(panel,radius)
            Create("UIGradient",{
                Rotation=90,
                Color=ColorSequence.new({
                    ColorSequenceKeypoint.new(0,BodyLight),
                    ColorSequenceKeypoint.new(1,BodyDark)
                })
            },panel)
            return panel
        end
        -- ground shadow
        local Shadow=Create("Frame",{
            Position=UDim2.fromOffset(10,104),
            Size=UDim2.fromOffset(240,12),
            BackgroundColor3=Color3.fromRGB(0,0,0),
            BackgroundTransparency=0.45,
            BorderSizePixel=0,
            ZIndex=29
        },CarRoot)
        Round(Shadow,6)
        -- rear tires
        for _,tx in ipairs({14,210}) do
            local tire=Create("Frame",{
                Position=UDim2.fromOffset(tx,88),
                Size=UDim2.fromOffset(36,32),
                BackgroundColor3=Color3.fromRGB(23,24,28),
                BorderSizePixel=0,
                ZIndex=30
            },CarRoot)
            Round(tire,16)
            local hub=Create("Frame",{
                Position=UDim2.fromOffset(tx+10,97),
                Size=UDim2.fromOffset(16,14),
                BackgroundColor3=Color3.fromRGB(46,49,56),
                BorderSizePixel=0,
                ZIndex=31
            },CarRoot)
            Round(hub,7)
        end
        -- wide rear haunches (the 3D fender curve)
        RedPanel(20,64,54,40,18,32)
        RedPanel(186,64,54,40,18,32)
        -- main body
        RedPanel(20,52,220,56,26,33)
        -- cabin
        RedPanel(55,28,150,36,18,34)
        -- rear window
        local Glass=Create("Frame",{
            Position=UDim2.fromOffset(72,36),
            Size=UDim2.fromOffset(116,20),
            BackgroundColor3=Color3.fromRGB(35,46,60),
            BackgroundTransparency=0.05,
            BorderSizePixel=0,
            ZIndex=35
        },CarRoot)
        Round(Glass,10)
        Create("UIGradient",{
            Rotation=90,
            Color=ColorSequence.new({
                ColorSequenceKeypoint.new(0,Color3.fromRGB(58,76,94)),
                ColorSequenceKeypoint.new(1,Color3.fromRGB(20,27,36))
            })
        },Glass)
        -- side mirrors
        for _,mx in ipairs({44,206}) do
            local mirror=Create("Frame",{
                Position=UDim2.fromOffset(mx,36),
                Size=UDim2.fromOffset(10,7),
                BackgroundColor3=Color3.fromRGB(176,24,40),
                BorderSizePixel=0,
                ZIndex=35
            },CarRoot)
            Round(mirror,3)
        end
        -- GT wing above the roofline
        for _,px in ipairs({70,184}) do
            Create("Frame",{
                Position=UDim2.fromOffset(px,22),
                Size=UDim2.fromOffset(6,9),
                BackgroundColor3=Color3.fromRGB(20,22,26),
                BorderSizePixel=0,
                ZIndex=36
            },CarRoot)
        end
        local Wing=Create("Frame",{
            Position=UDim2.fromOffset(48,16),
            Size=UDim2.fromOffset(164,7),
            BackgroundColor3=Color3.fromRGB(20,22,26),
            BorderSizePixel=0,
            ZIndex=37
        },CarRoot)
        Round(Wing,3)
        Create("UIGradient",{
            Rotation=90,
            Color=ColorSequence.new({
                ColorSequenceKeypoint.new(0,Color3.fromRGB(58,62,70)),
                ColorSequenceKeypoint.new(1,Color3.fromRGB(12,14,16))
            })
        },Wing)
        -- full-width taillight bar
        local TailHousing=Create("Frame",{
            Position=UDim2.fromOffset(40,74),
            Size=UDim2.fromOffset(180,12),
            BackgroundColor3=Color3.fromRGB(16,18,22),
            BorderSizePixel=0,
            ZIndex=38
        },CarRoot)
        Round(TailHousing,6)
        local TailGlow=Create("Frame",{
            Position=UDim2.fromOffset(42,75),
            Size=UDim2.fromOffset(176,10),
            BackgroundColor3=Color3.fromRGB(255,70,84),
            BackgroundTransparency=0.55,
            BorderSizePixel=0,
            ZIndex=39
        },CarRoot)
        Round(TailGlow,5)
        local TailDim=Color3.fromRGB(232,40,56)
        local TailBright=Color3.fromRGB(255,68,80)
        local TailL=Create("Frame",{
            Position=UDim2.fromOffset(46,77),
            Size=UDim2.fromOffset(74,6),
            BackgroundColor3=TailDim,
            BorderSizePixel=0,
            ZIndex=40
        },CarRoot)
        Round(TailL,3)
        local TailR=Create("Frame",{
            Position=UDim2.fromOffset(140,77),
            Size=UDim2.fromOffset(74,6),
            BackgroundColor3=TailDim,
            BorderSizePixel=0,
            ZIndex=40
        },CarRoot)
        Round(TailR,3)
        -- diffuser with fins
        local Diffuser=Create("Frame",{
            Position=UDim2.fromOffset(70,96),
            Size=UDim2.fromOffset(120,12),
            BackgroundColor3=Color3.fromRGB(19,20,23),
            BorderSizePixel=0,
            ZIndex=38
        },CarRoot)
        Round(Diffuser,4)
        for k=0,3 do
            Create("Frame",{
                Position=UDim2.fromOffset(86+k*26,98),
                Size=UDim2.fromOffset(3,9),
                BackgroundColor3=Color3.fromRGB(12,13,16),
                BorderSizePixel=0,
                ZIndex=39
            },CarRoot)
        end
        -- twin exhausts
        for _,ex in ipairs({92,152}) do
            local pipe=Create("Frame",{
                Position=UDim2.fromOffset(ex,100),
                Size=UDim2.fromOffset(16,8),
                BackgroundColor3=Color3.fromRGB(62,67,75),
                BorderSizePixel=0,
                ZIndex=39
            },CarRoot)
            Round(pipe,4)
            local inner=Create("Frame",{
                Position=UDim2.fromOffset(ex+3,102),
                Size=UDim2.fromOffset(10,4),
                BackgroundColor3=Color3.fromRGB(16,17,20),
                BorderSizePixel=0,
                ZIndex=40
            },CarRoot)
            Round(inner,2)
        end
        -- license plate
        local Plate=Create("Frame",{
            Position=UDim2.fromOffset(102,84),
            Size=UDim2.fromOffset(56,15),
            BackgroundColor3=Color3.fromRGB(242,237,221),
            BorderSizePixel=0,
            ZIndex=41
        },CarRoot)
        Round(Plate,3)
        local PlateBand=Create("Frame",{
            Position=UDim2.fromOffset(102,84),
            Size=UDim2.fromOffset(56,4),
            BackgroundColor3=Color3.fromRGB(36,64,143),
            BorderSizePixel=0,
            ZIndex=42
        },CarRoot)
        Round(PlateBand,2)
        Create("TextLabel",{
            Position=UDim2.fromOffset(102,88),
            Size=UDim2.fromOffset(56,10),
            BackgroundTransparency=1,
            Text="BUBBA",
            TextColor3=Color3.fromRGB(35,38,45),
            TextSize=8,
            Font=Enum.Font.GothamBold,
            ZIndex=43
        },CarRoot)
        -- gold prancing badge
        local Badge=Create("Frame",{
            Position=UDim2.fromOffset(126,69),
            Size=UDim2.fromOffset(9,9),
            Rotation=45,
            BackgroundColor3=Color3.fromRGB(233,185,78),
            BorderSizePixel=0,
            ZIndex=41
        },CarRoot)
        Round(Badge,2)
        -- the moving roof glint
        local Glint=Create("Frame",{
            Position=UDim2.fromOffset(60,30),
            Size=UDim2.fromOffset(36,4),
            BackgroundColor3=Color3.fromRGB(255,255,255),
            BackgroundTransparency=1,
            BorderSizePixel=0,
            ZIndex=44
        },CarRoot)
        Round(Glint,2)

        ------------------------------------------------------------
        -- cinematic vignette
        ------------------------------------------------------------
        local VignetteTop=Create("Frame",{
            Position=UDim2.new(0,0,0,0),
            Size=UDim2.new(1,0,0.12,0),
            BackgroundColor3=Color3.fromRGB(0,0,0),
            BackgroundTransparency=0.35,
            BorderSizePixel=0,
            ZIndex=40
        },Canvas)
        Create("UIGradient",{
            Rotation=90,
            Transparency=NumberSequence.new({
                NumberSequenceKeypoint.new(0,0.55),
                NumberSequenceKeypoint.new(1,1)
            })
        },VignetteTop)
        local VignetteBottom=Create("Frame",{
            AnchorPoint=Vector2.new(0,1),
            Position=UDim2.new(0,0,1,0),
            Size=UDim2.new(1,0,0.14,0),
            BackgroundColor3=Color3.fromRGB(0,0,0),
            BackgroundTransparency=0.35,
            BorderSizePixel=0,
            ZIndex=40
        },Canvas)
        Create("UIGradient",{
            Rotation=90,
            Transparency=NumberSequence.new({
                NumberSequenceKeypoint.new(0,1),
                NumberSequenceKeypoint.new(1,0.5)
            })
        },VignetteBottom)

        ------------------------------------------------------------
        -- caption
        ------------------------------------------------------------
        local Caption=Create("TextLabel",{
            Name="FinaleCaption",
            AnchorPoint=Vector2.new(0.5,1),
            Position=UDim2.new(0.5,0,1,-42),
            Size=UDim2.new(0.8,0,0,16),
            BackgroundTransparency=1,
            Text="",
            TextColor3=Color3.fromRGB(232,201,143),
            TextSize=10,
            Font=Enum.Font.Gotham,
            TextXAlignment=Enum.TextXAlignment.Center,
            TextTransparency=1,
            ZIndex=425
        },Veil)
        local function SayCaption(text)
            if Caption and Caption.Parent then
                Caption.Text=text
                Tween(Caption,{TextTransparency=0.15},0.3)
            end
        end
        local function ClearCaption()
            if Caption and Caption.Parent then
                Tween(Caption,{TextTransparency=1},0.35)
            end
        end

        ------------------------------------------------------------
        -- THE FAREWELL BLOCK: hangs in the dusk above the sunk
        -- coastline while the last light dies
        ------------------------------------------------------------
        local FarewellWash=Create("Frame",{
            Position=UDim2.new(0,0,0.015,0),
            Size=UDim2.new(1,0,0.26,0),
            BackgroundColor3=Color3.fromRGB(4,6,11),
            BackgroundTransparency=1,
            BorderSizePixel=0,
            ZIndex=428
        },Veil)
        Create("UIGradient",{
            Rotation=90,
            Transparency=NumberSequence.new({
                NumberSequenceKeypoint.new(0,0.3),
                NumberSequenceKeypoint.new(1,1)
            })
        },FarewellWash)
        local Stars={}
        local StarDefs={
            {0.07,0.030},{0.16,0.072},{0.25,0.045},{0.38,0.025},{0.47,0.080},
            {0.58,0.055},{0.67,0.030},{0.78,0.070},{0.90,0.050}
        }
        for k,def in ipairs(StarDefs) do
            local star=Create("Frame",{
                Position=UDim2.new(def[1],0,def[2],0),
                Size=UDim2.fromOffset(2,2),
                BackgroundColor3=Color3.fromRGB(255,246,224),
                BackgroundTransparency=1,
                BorderSizePixel=0,
                ZIndex=429
            },Veil)
            Round(star,2)
            table.insert(Stars,{Frame=star,Ph=k*1.7})
        end
        local MerciLine=Create("TextLabel",{
            Name="MerciLine",
            AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.new(0.5,0,0.088,0),
            Size=UDim2.new(0.9,0,0,14),
            BackgroundTransparency=1,
            Text="M E R C I   ·   G R A Z I E",
            TextColor3=Color3.fromRGB(232,201,143),
            TextSize=11,
            Font=Enum.Font.Gotham,
            TextTransparency=1,
            ZIndex=431
        },Veil)
        local DiamondL=Create("Frame",{
            Position=UDim2.new(0.5,-168,0.088,0),
            AnchorPoint=Vector2.new(0.5,0.5),
            Size=UDim2.fromOffset(7,7),
            Rotation=45,
            BackgroundColor3=Color3.fromRGB(233,190,99),
            BackgroundTransparency=1,
            BorderSizePixel=0,
            ZIndex=431
        },Veil)
        local DiamondR=Create("Frame",{
            Position=UDim2.new(0.5,168,0.088,0),
            AnchorPoint=Vector2.new(0.5,0.5),
            Size=UDim2.fromOffset(7,7),
            Rotation=45,
            BackgroundColor3=Color3.fromRGB(233,190,99),
            BackgroundTransparency=1,
            BorderSizePixel=0,
            ZIndex=431
        },Veil)
        local ThanksLine=Create("TextLabel",{
            Name="ThanksLine",
            AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.new(0.5,0,0.138,0),
            Size=UDim2.new(0.9,0,0,30),
            BackgroundTransparency=1,
            Text="Thank You for Using",
            TextColor3=Color3.fromRGB(244,233,214),
            TextSize=26,
            Font=Enum.Font.Bodoni,
            TextTransparency=1,
            ZIndex=431
        },Veil)
        local BubbaLine=Create("TextLabel",{
            Name="BubbaLine",
            AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.new(0.5,0,0.203,0),
            Size=UDim2.new(0.9,0,0,64),
            BackgroundTransparency=1,
            Text="BUBBA",
            TextColor3=Color3.fromRGB(255,255,255),
            TextSize=62,
            Font=Enum.Font.Bodoni,
            TextTransparency=1,
            ZIndex=432
        },Veil)
        local BubbaGrad=Create("UIGradient",{
            Rotation=90,
            Color=ColorSequence.new({
                ColorSequenceKeypoint.new(0,Color3.fromRGB(255,233,174)),
                ColorSequenceKeypoint.new(1,Color3.fromRGB(217,164,55))
            })
        },BubbaLine)
        local Underline=Create("Frame",{
            Name="FarewellUnderline",
            AnchorPoint=Vector2.new(0.5,0.5),
            Position=UDim2.new(0.5,0,0.249,0),
            Size=UDim2.fromOffset(0,3),
            BackgroundColor3=Color3.fromRGB(233,190,99),
            BorderSizePixel=0,
            ZIndex=432
        },Veil)
        Round(Underline,3)

        ------------------------------------------------------------
        -- RENDER ENGINE: one heartbeat drives the whole coast
        ------------------------------------------------------------
        local Phase=1 -- 1 drive | 2 rise | 3 farewell
        local Clock=0
        local Last=os.clock()
        local RoadScroll=0
        local RisingT=0
        local StarsOn=false
        local StarsClock=0
        local function QuintInOut(x)
            if x<0.5 then
                return 16*x^5
            end
            return 1-((-2*x+2)^5)/2
        end
        task.spawn(function()
            while Canvas.Parent do
                local now=os.clock()
                local dt=now-Last
                Last=now
                Clock=Clock+dt
                -- the rise: scene sinks and swells, motion calms
                local speedMul=1
                if Phase>=2 then
                    if RisingT<1 then
                        RisingT=math.min(1,RisingT+dt/2.4)
                        local e=QuintInOut(RisingT)
                        Canvas.Position=UDim2.new(0.5,0,0.5+0.34*e,0)
                        CanvasScale.Scale=1+0.18*e
                        Canvas.GroupTransparency=0.12*e
                        speedMul=1-0.88*e
                    else
                        speedMul=0.12
                    end
                end
                RoadScroll=RoadScroll+dt*4.0*speedMul
                local dashPhase=math.floor(RoadScroll)
                local patchPhase=math.floor(RoadScroll*0.5)
                -- road bands: haze near the horizon, patches drift
                for _,b in ipairs(RoadBands) do
                    local base=AsphaltA
                    if (b.Index+patchPhase)%11<4 then
                        base=AsphaltB
                    end
                    b.Frame.BackgroundColor3=base:Lerp(AsphaltHaze,(1-b.T)^2*0.5)
                    b.Dash.Visible=((b.Index+dashPhase)%8)<3
                end
                -- trees flow down the perspective curve
                for _,tr in ipairs(TreePool) do
                    tr.P=tr.P+dt*0.34*speedMul
                    if tr.P>=1 then
                        tr.P=tr.P-1
                    end
                    local t=tr.P
                    if t<0.02 then t=0.02 end
                    local half=RoadHalfW(t)
                    local cx=RoadCenterX(t)
                    tr.Root.Position=UDim2.new(cx+tr.Side*(half+0.028+0.10*t*t),0,YAt(t)+0.004,0)
                    tr.Scale.Scale=0.10+1.25*t^1.95
                    tr.Root.Visible=t>0.04
                end
                -- car suspension: bob, sway, lean into the curve
                local bob=math.sin(Clock*6.5)*1.5*(0.4+0.6*speedMul)
                local sway=math.sin(Clock*3.1)*1.0
                CarRoot.Position=UDim2.new(0.5,sway,0.972,-bob)
                CarRoot.Rotation=-2.2+math.sin(Clock*2.2)*0.7
                CarScale.Scale=math.clamp(Veil.AbsoluteSize.X/1500*1.75,0.85,2.3)
                -- taillight breathing
                local pulse=0.5+0.5*math.sin(Clock*2.4)
                local tailCol=TailDim:Lerp(TailBright,pulse)
                TailL.BackgroundColor3=tailCol
                TailR.BackgroundColor3=tailCol
                TailGlow.BackgroundTransparency=0.35+0.4*pulse
                -- roof glint sweeping every few seconds
                local gph=(Clock%2.8)/2.8
                if gph<0.5 then
                    local gp=gph/0.5
                    Glint.Position=UDim2.fromOffset(60+170*gp,30)
                    Glint.BackgroundTransparency=0.65-0.5*math.sin(gp*math.pi)
                else
                    Glint.BackgroundTransparency=1
                end
                -- clouds drift, wrap around
                for _,c in ipairs(Clouds) do
                    c.X=c.X-dt*c.Speed
                    if c.X<-0.25 then
                        c.X=c.X+1.5
                    end
                    c.Root.Position=UDim2.new(c.X,0,c.Y,0)
                end
                -- birds flap and glide
                for _,b in ipairs(Birds) do
                    local flap=math.sin(Clock*7+b.Ph)*14
                    b.W1.Rotation=-18+flap
                    b.W2.Rotation=18-flap
                    b.X=b.X+dt*0.004
                    b.Root.Position=UDim2.new(b.X,0,b.Y+math.sin(Clock*0.7+b.Ph)*0.004,0)
                end
                -- sea glitter shimmer
                for _,g in ipairs(Glitter) do
                    g.Frame.BackgroundTransparency=0.35+0.45*math.abs(math.sin(Clock*1.6+g.Ph))
                end
                SunGlow.BackgroundTransparency=0.55+0.06*math.sin(Clock*1.3)
                -- stars wake with the rise, twinkle, then the
                -- farewell tweens take over for the fade
                if StarsOn and Phase<3 then
                    StarsClock=StarsClock+dt
                    local reveal=math.min(StarsClock/0.6,1)
                    for _,s in ipairs(Stars) do
                        local tw=0.25+0.45*math.abs(math.sin(Clock*1.1+s.Ph))
                        s.Frame.BackgroundTransparency=1-reveal*(1-tw)
                    end
                end
                -- gold shimmer sweeping through BUBBA
                BubbaGrad.Rotation=(Clock*35+90)%360
                task.wait(1/30)
            end
        end)

        ------------------------------------------------------------
        -- SHOWTIME
        ------------------------------------------------------------
        -- the game fades to night, the coast fades in
        Tween(Veil,{BackgroundTransparency=0},0.35)
        Tween(Canvas,{GroupTransparency=0},0.8)
        task.delay(1.2,function()
            SayCaption("one last ride along the coast.")
        end)

        -- PHASE 1: THE DRIVE
        task.wait(5.6)
        ClearCaption()
        task.wait(0.3)

        -- PHASE 2: THE RISE — the camera lifts off the road and
        -- the whole coastline sinks away into the evening
        Phase=2
        task.delay(0.9,function()
            Tween(FarewellWash,{BackgroundTransparency=0},0.8)
            Tween(MerciLine,{TextTransparency=0.15},0.5)
        end)
        task.delay(1.15,function()
            Tween(ThanksLine,{TextTransparency=0.05},0.6)
        end)
        task.delay(1.35,function()
            Tween(BubbaLine,{TextTransparency=0},0.6)
            Tween(Underline,{Size=UDim2.fromOffset(230,3)},0.5,Enum.EasingStyle.Quint)
            Tween(DiamondL,{BackgroundTransparency=0.2},0.4)
            Tween(DiamondR,{BackgroundTransparency=0.2},0.4)
        end)
        task.delay(1.5,function()
            StarsOn=true
        end)
        task.wait(2.4)

        -- PHASE 3: THE FAREWELL — hold the bow, then let go
        Phase=3
        task.wait(1.7)
        Tween(Canvas,{GroupTransparency=1},0.9)
        Tween(FarewellWash,{BackgroundTransparency=1},0.7)
        Tween(MerciLine,{TextTransparency=1},0.7)
        Tween(ThanksLine,{TextTransparency=1},0.7)
        Tween(BubbaLine,{TextTransparency=1},0.7)
        Tween(Underline,{BackgroundTransparency=1},0.7)
        Tween(DiamondL,{BackgroundTransparency=1},0.7)
        Tween(DiamondR,{BackgroundTransparency=1},0.7)
        for _,s in ipairs(Stars) do
            Tween(s.Frame,{BackgroundTransparency=1},0.7)
        end
        Tween(Veil,{BackgroundTransparency=1},0.9)
        task.wait(1.05)
    end)
    if not Ok then
        warn("[BUBBA OUTRO ERROR]:",Err)
        if Main and Main.Parent then Main.Visible=false end
    end

    ScreenGui:Destroy()
end

UnloadPanel=Create("Frame",{
    Name="UnloadPanel",
    AnchorPoint=Vector2.new(0,1),
    Position=UDim2.new(0,20,1,-8),
    Size=UDim2.new(1,-40,0,70),
    BackgroundColor3=CurrentTheme.PanelLight,
    BorderSizePixel=0,
    ZIndex=3
},Pages.SETTINGS)
Round(UnloadPanel,8)

UnloadPanelStroke=Stroke(UnloadPanel,CurrentTheme.Accent,0.55)

UnloadTitle=Create("TextLabel",{
    Position=UDim2.fromOffset(14,10),
    Size=UDim2.new(1,-170,0,20),
    BackgroundTransparency=1,
    Text="Unload Bubba",
    TextColor3=CurrentTheme.Text,
    TextSize=12,
    Font=Enum.Font.GothamSemibold,
    TextXAlignment=Enum.TextXAlignment.Left,
    ZIndex=4
},UnloadPanel)

UnloadDescription=Create("TextLabel",{
    Position=UDim2.fromOffset(14,32),
    Size=UDim2.new(1,-170,0,20),
    BackgroundTransparency=1,
    Text="Close the ui",
    TextColor3=CurrentTheme.Muted,
    TextSize=9,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left,
    ZIndex=4
},UnloadPanel)

UnloadButton=Create("TextButton",{
    AnchorPoint=Vector2.new(1,0.5),
    Position=UDim2.new(1,-12,0.5,0),
    Size=UDim2.fromOffset(125,36),
    BackgroundColor3=ButtonColor(),
    BorderSizePixel=0,
    Text="UNLOAD",
    TextColor3=CurrentTheme.Text,
    TextSize=10,
    Font=Enum.Font.GothamBold,
    AutoButtonColor=false,
    ZIndex=4
},UnloadPanel)
Round(UnloadButton,6)

UnloadButtonStroke=Stroke(UnloadButton,CurrentTheme.Accent,0.65)

UnloadButton.MouseEnter:Connect(function()
    if not unloading then
        Tween(UnloadButton,{BackgroundColor3=ButtonHoverColor()},0.15)
    end
end)

UnloadButton.MouseLeave:Connect(function()
    if not unloading then
        Tween(UnloadButton,{BackgroundColor3=ButtonColor()},0.15)
    end
end)

UnloadButton.MouseButton1Click:Connect(UnloadBubba)

-- BOOT GUARD: the home tab is the newest system in the hub. If anything
-- inside it fails on an exotic executor, the rest of the UI still boots.
local HomeBuildOk,HomeBuildError=pcall(function()

--========================================================
-- HOME TAB | THE COMMAND CENTER
-- welcome hero with live avatar + session identity
-- quick actions pulled from every tab (real sync both ways)
-- live session intel + news feed + quick navigation
--========================================================

local HomePage=Pages.HOME

local HomeThemeObjects={}
local HomeSwitches={}

local HomeSessionSeconds=0
local HomeFpsFrames=0
local HomeFpsElapsed=0
local HomeFpsCurrent=0

local function RegisterHomeObject(object)
    table.insert(HomeThemeObjects,object)
    return object
end

------------------------------------------------------------
-- PAGE HEADER
------------------------------------------------------------

local HomeTitle=RegisterHomeObject(Create("TextLabel",{
    Name="HomeTitle",
    Position=UDim2.fromOffset(20,12),
    Size=UDim2.new(1,-40,0,25),
    BackgroundTransparency=1,
    Text="Dashboard",
    TextColor3=CurrentTheme.Text,
    TextSize=18,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},HomePage))

local HomeSubtitle=RegisterHomeObject(Create("TextLabel",{
    Name="HomeSubtitle",
    Position=UDim2.fromOffset(21,37),
    Size=UDim2.new(1,-42,0,18),
    BackgroundTransparency=1,
    Text="Your command center — live status, quick actions, and the latest from Bubba Scripts.",
    TextColor3=CurrentTheme.Muted,
    TextSize=10,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left
},HomePage))
HomeSubtitle:SetAttribute("MutedText",true)

local HomeStatusPill=Create("TextLabel",{
    Name="HomeStatusPill",
    AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-20,0,16),
    Size=UDim2.fromOffset(160,16),
    BackgroundTransparency=1,
    Text="●  SYSTEMS ONLINE",
    TextColor3=UIAccent,
    TextSize=9,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Right
},HomePage)

local HomeScroll=Create("ScrollingFrame",{
    Name="HomeScroll",
    Position=UDim2.fromOffset(20,65),
    Size=UDim2.new(1,-40,1,-78),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ScrollBarThickness=3,
    ScrollBarImageColor3=UIAccent,
    ScrollingDirection=Enum.ScrollingDirection.Y,
    CanvasSize=UDim2.new(0,0,0,0),
    AutomaticCanvasSize=Enum.AutomaticSize.Y
},HomePage)
HomeScroll.ScrollBarImageTransparency=0.15

Create("UIListLayout",{
    SortOrder=Enum.SortOrder.LayoutOrder,
    Padding=UDim.new(0,10)
},HomeScroll)

local function CreateHomeSection(height,order)
    local section=RegisterHomeObject(Create("Frame",{
        Name="HomeSection",
        Size=UDim2.new(1,0,0,height),
        BackgroundColor3=CurrentTheme.PanelLight,
        BorderSizePixel=0,
        LayoutOrder=order
    },HomeScroll))
    Round(section,8)
    RegisterHomeObject(Stroke(section,CurrentTheme.Accent,0.72,1))
    return section
end

------------------------------------------------------------
-- SECTION 1 | WELCOME HERO
------------------------------------------------------------

local HeroSection=CreateHomeSection(128,1)

local HomeAvatar=RegisterHomeObject(Create("ImageLabel",{
    Name="HomeAvatar",
    Position=UDim2.fromOffset(14,15),
    Size=UDim2.fromOffset(68,68),
    BackgroundColor3=CurrentTheme.Panel,
    BorderSizePixel=0,
    Image="",
    ScaleType=Enum.ScaleType.Crop
},HeroSection))
Round(HomeAvatar,100)
local HomeAvatarRing=Stroke(HomeAvatar,UIAccent,0.35,2)

local HomeMonogram=RegisterHomeObject(Create("TextLabel",{
    Name="HomeMonogram",
    Size=UDim2.fromScale(1,1),
    BackgroundTransparency=1,
    Text=string.upper(string.sub(Player.DisplayName,1,1)),
    TextColor3=CurrentTheme.Accent,
    TextSize=26,
    Font=Enum.Font.GothamBold
},HomeAvatar))

local HomeWelcome=RegisterHomeObject(Create("TextLabel",{
    Name="HomeWelcome",
    Position=UDim2.fromOffset(96,16),
    Size=UDim2.new(1,-320,0,22),
    BackgroundTransparency=1,
    Text="Welcome back, "..Player.DisplayName,
    TextColor3=CurrentTheme.Text,
    TextSize=15,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd
},HeroSection))

------------------------------------------------------------
-- OWNER TAG | rainbow badge riding beside the welcome line
-- (owner-only; positioned after the measured name width so it
-- sits tight against the text on every display name)
------------------------------------------------------------
if IsOwner then
    local ownerWelcomeWidth=#HomeWelcome.Text*7.6
    if ownerWelcomeWidth>264 then ownerWelcomeWidth=264 end

    local OwnerTag=Create("Frame",{
        Name="OwnerTag",
        Position=UDim2.fromOffset(96+math.floor(ownerWelcomeWidth)+12,15),
        Size=UDim2.fromOffset(68,22),
        BackgroundColor3=Color3.fromRGB(24,22,30),
        BorderSizePixel=0,
        ZIndex=3
    },HeroSection)
    Round(OwnerTag,11)
    Stroke(OwnerTag,OwnerGold,0.18,1)

    local OwnerTagWash=Create("UIGradient",{
        Color=OwnerRainbow(),
        Rotation=20,
        Transparency=NumberSequence.new(0.38)
    },OwnerTag)

    Create("TextLabel",{
        Name="OwnerTagText",
        Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,
        Text="OWNER",
        TextColor3=Color3.fromRGB(255,255,255),
        TextSize=9,
        Font=Enum.Font.GothamBold,
        ZIndex=4
    },OwnerTag)

    table.insert(OwnerRainbowGradients,OwnerTagWash)
end

local HomeGreeting=RegisterHomeObject(Create("TextLabel",{
    Name="HomeGreeting",
    Position=UDim2.fromOffset(96,38),
    Size=UDim2.new(1,-320,0,16),
    BackgroundTransparency=1,
    Text="Warming up the session...",
    TextColor3=CurrentTheme.Muted,
    TextSize=9,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left
},HeroSection))
HomeGreeting:SetAttribute("MutedText",true)

local function CreateHomeChip(text,width,x,y)
    local chip=RegisterHomeObject(Create("TextLabel",{
        Name="HomeChip",
        Position=UDim2.fromOffset(x,y or 60),
        Size=UDim2.fromOffset(width,18),
        BackgroundColor3=CurrentTheme.Panel,
        BorderSizePixel=0,
        Text=text,
        TextColor3=CurrentTheme.Muted,
        TextSize=8,
        Font=Enum.Font.GothamSemibold
    },HeroSection))
    Round(chip,9)
    RegisterHomeObject(Stroke(chip,CurrentTheme.Accent,0.75,1))
    chip:SetAttribute("MutedText",true)
    return chip
end

CreateHomeChip("ACCOUNT "..tostring(Player.AccountAge).." DAYS",118,96)
CreateHomeChip("@"..Player.Name,132,222)

local membershipName="FREE ACCOUNT"
pcall(function()
    if Player.MembershipType~=Enum.MembershipType.None then
        membershipName=tostring(Player.MembershipType):gsub("Enum.MembershipType.","")
    end
end)
CreateHomeChip(membershipName,104,362)

-- game auto-detection chip: shows which experience was detected under
-- your avatar. Known games fill instantly; everything else fills the
-- moment the marketplace lookup lands
local HomeGameChip=CreateHomeChip("GAME: "..string.upper(DetectedGame.Name or "DETECTING..."),190,96,84)
HomeGameChip.TextXAlignment=Enum.TextXAlignment.Left
HomeGameChip.TextTruncate=Enum.TextTruncate.AtEnd
OnGameResolved(function(name)
    if HomeGameChip and HomeGameChip.Parent then
        HomeGameChip.Text="GAME: "..string.upper(name)
    end
end)

local HomeEngineTag=RegisterHomeObject(Create("TextLabel",{
    Name="HomeEngineTag",
    AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-16,0,12),
    Size=UDim2.fromOffset(120,14),
    BackgroundTransparency=1,
    Text="BUBBA ENGINE",
    TextColor3=CurrentTheme.Muted,
    TextSize=8,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Right
},HeroSection))
HomeEngineTag:SetAttribute("MutedText",true)

local HomeEngineVersion=RegisterHomeObject(Create("TextLabel",{
    Name="HomeEngineVersion",
    AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-16,0,26),
    Size=UDim2.fromOffset(120,24),
    BackgroundTransparency=1,
    Text="v2.4",
    TextColor3=CurrentTheme.Accent,
    TextSize=20,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Right
},HeroSection))

local HomeStatusGroup=RegisterHomeObject(Create("Frame",{
    Name="HomeStatusGroup",
    AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-16,0,62),
    Size=UDim2.fromOffset(160,16),
    BackgroundTransparency=1
},HeroSection))

local HomePulseDot=Create("Frame",{
    Name="HomePulseDot",
    Position=UDim2.fromOffset(0,5),
    Size=UDim2.fromOffset(6,6),
    BackgroundColor3=UIAccent,
    BorderSizePixel=0
},HomeStatusGroup)
Round(HomePulseDot,100)

local HomeSystemsLabel=RegisterHomeObject(Create("TextLabel",{
    Name="HomeSystemsLabel",
    Position=UDim2.fromOffset(14,0),
    Size=UDim2.new(1,-14,1,0),
    BackgroundTransparency=1,
    Text="SYSTEMS OPERATIONAL",
    TextColor3=CurrentTheme.Accent,
    TextSize=8,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},HomeStatusGroup))

local HomeSessionLabel=RegisterHomeObject(Create("TextLabel",{
    Name="HomeSessionLabel",
    AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-16,0,84),
    Size=UDim2.fromOffset(160,14),
    BackgroundTransparency=1,
    Text="SESSION 00:00",
    TextColor3=CurrentTheme.Muted,
    TextSize=9,
    Font=Enum.Font.GothamSemibold,
    TextXAlignment=Enum.TextXAlignment.Right
},HeroSection))
HomeSessionLabel:SetAttribute("MutedText",true)

------------------------------------------------------------
-- SECTION 2 | QUICK ACTIONS (pulled from the other tabs)
------------------------------------------------------------

local QuickSection=CreateHomeSection(150,2)

RegisterHomeObject(Create("TextLabel",{
    Name="QuickTitle",
    Position=UDim2.fromOffset(13,9),
    Size=UDim2.new(1,-26,0,19),
    BackgroundTransparency=1,
    Text="QUICK ACTIONS",
    TextColor3=CurrentTheme.Text,
    TextSize=11,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},QuickSection))

local QuickSub=RegisterHomeObject(Create("TextLabel",{
    Name="QuickSub",
    Position=UDim2.fromOffset(13,28),
    Size=UDim2.new(1,-26,0,16),
    BackgroundTransparency=1,
    Text="Flip your favorite modules without leaving home.",
    TextColor3=CurrentTheme.Muted,
    TextSize=8,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left
},QuickSection))
QuickSub:SetAttribute("MutedText",true)

local QuickGrid=RegisterHomeObject(Create("Frame",{
    Name="QuickGrid",
    Position=UDim2.fromOffset(12,50),
    Size=UDim2.new(1,-24,0,92),
    BackgroundTransparency=1
},QuickSection))

Create("UIGridLayout",{
    CellSize=UDim2.new(1/3,-8,0,42),
    CellPadding=UDim2.fromOffset(8,8),
    SortOrder=Enum.SortOrder.LayoutOrder
},QuickGrid)

local QuickActions={
    {
        Icon="🛡️",Name="ANTI-AFK",Desc="Beats the 20 min idle kick",
        Get=function() return AntiAfkEnabled end,
        Set=function(v) SetAntiAfk(v) end
    },
    {
        Icon="👁️",Name="PLAYER ESP",Desc="Chams, boxes, names, tracers",
        Get=function() return ESPSettings.Master end,
        Set=function(v) ESPMasterToggle.Set(v) end
    },
    {
        Icon="🚪",Name="NOCLIP",Desc="Walk straight through walls",
        Get=function() return CharacterSettings.Noclip end,
        Set=function(v) NoclipToggle.Set(v) end
    },
    {
        Icon="⬆️",Name="INFINITE JUMP",Desc="Jump as many times as you want",
        Get=function() return CharacterSettings.InfiniteJump end,
        Set=function(v) InfiniteJumpToggle.Set(v) end
    },
    {
        Icon="☀️",Name="FULLBRIGHT",Desc="Light up the entire map",
        Get=function() return ESPSettings.Fullbright end,
        Set=function(v) ESPFullbrightToggle.Set(v) end
    },
    {
        Icon="🎯",Name="CROSSHAIR",Desc="Precision center screen overlay",
        Get=function() return ESPSettings.Crosshair end,
        Set=function(v) ESPCrosshairToggle.Set(v) end
    }
}

for index,action in ipairs(QuickActions) do
    local card=RegisterHomeObject(Create("Frame",{
        Name="HomeQuickCard",
        BackgroundColor3=CurrentTheme.Background,
        BorderSizePixel=0,
        LayoutOrder=index
    },QuickGrid))
    Round(card,7)
    RegisterHomeObject(Stroke(card,CurrentTheme.Accent,0.78,1))

    RegisterHomeObject(Create("TextLabel",{
        Name="QuickIcon",
        Position=UDim2.fromOffset(8,0),
        Size=UDim2.fromOffset(22,42),
        BackgroundTransparency=1,
        Text=action.Icon,
        TextColor3=CurrentTheme.Text,
        TextSize=14,
        Font=Enum.Font.Gotham
    },card))

    RegisterHomeObject(Create("TextLabel",{
        Name="QuickName",
        Position=UDim2.fromOffset(34,7),
        Size=UDim2.new(1,-80,0,13),
        BackgroundTransparency=1,
        Text=action.Name,
        TextColor3=CurrentTheme.Text,
        TextSize=9,
        Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd
    },card))

    local quickDesc=RegisterHomeObject(Create("TextLabel",{
        Name="QuickDesc",
        Position=UDim2.fromOffset(34,23),
        Size=UDim2.new(1,-80,0,12),
        BackgroundTransparency=1,
        Text=action.Desc,
        TextColor3=CurrentTheme.Muted,
        TextSize=8,
        Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd
    },card))
    quickDesc:SetAttribute("MutedText",true)

    local pill=RegisterHomeObject(Create("TextButton",{
        Name="HomeSwitch",
        AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-7,0.5,0),
        Size=UDim2.fromOffset(36,18),
        BackgroundColor3=CurrentTheme.Panel,
        BorderSizePixel=0,
        Text="",
        AutoButtonColor=false,
        ZIndex=6
    },card))
    Round(pill,9)
    pill:SetAttribute("HomeToggle",true)
    pill:SetAttribute("HomeToggleOn",false)

    local knob=RegisterHomeObject(Create("Frame",{
        Name="HomeKnob",
        Position=UDim2.fromOffset(3,3),
        Size=UDim2.fromOffset(12,12),
        BackgroundColor3=CurrentTheme.Muted,
        BorderSizePixel=0,
        ZIndex=7
    },pill))
    Round(knob,6)

    local function SetSwitchVisual(state)
        pill:SetAttribute("HomeToggleOn",state)
        Tween(pill,{
            BackgroundColor3=state and UIAccent:Lerp(Color3.new(0,0,0),0.45) or CurrentTheme.Panel
        },0.15)
        Tween(knob,{
            Position=state and UDim2.fromOffset(21,3) or UDim2.fromOffset(3,3),
            BackgroundColor3=state and UIAccent or CurrentTheme.Muted
        },0.18,Enum.EasingStyle.Back)
    end

    local function Flip()
        if unloading then return end
        local newState=not action.Get()
        action.Set(newState)
        SetSwitchVisual(newState)
    end

    pill.MouseButton1Click:Connect(Flip)

    local hit=Create("TextButton",{
        Name="CardHit",
        Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,
        Text="",
        AutoButtonColor=false,
        ZIndex=5
    },card)

    hit.MouseButton1Click:Connect(Flip)

    hit.MouseEnter:Connect(function()
        if not unloading then
            Tween(card,{BackgroundColor3=CurrentTheme.PanelLight},0.12)
        end
    end)

    hit.MouseLeave:Connect(function()
        if not unloading then
            Tween(card,{BackgroundColor3=CurrentTheme.Background},0.16)
        end
    end)

    table.insert(HomeSwitches,{
        Pill=pill,
        SetVisual=SetSwitchVisual,
        Get=action.Get
    })
end

local function RefreshHomeSwitches()
    for _,switch in ipairs(HomeSwitches) do
        if switch.Pill and switch.Pill.Parent then
            switch.SetVisual(switch.Get())
        end
    end
end

------------------------------------------------------------
-- SECTION 3 | SESSION INTEL + WHAT'S NEW
------------------------------------------------------------

local SplitSection=CreateHomeSection(210,3)

local IntelPanel=RegisterHomeObject(Create("Frame",{
    Name="HomeSubPanel",
    Position=UDim2.fromOffset(12,10),
    Size=UDim2.new(0.56,-18,1,-20),
    BackgroundColor3=CurrentTheme.Background,
    BorderSizePixel=0
},SplitSection))
Round(IntelPanel,7)
RegisterHomeObject(Stroke(IntelPanel,CurrentTheme.Accent,0.8,1))

RegisterHomeObject(Create("TextLabel",{
    Name="IntelTitle",
    Position=UDim2.fromOffset(12,8),
    Size=UDim2.new(1,-24,0,13),
    BackgroundTransparency=1,
    Text="SESSION INTEL",
    TextColor3=CurrentTheme.Text,
    TextSize=9,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},IntelPanel))

local IntelGrid=Create("Frame",{
    Name="IntelGrid",
    Position=UDim2.fromOffset(9,26),
    Size=UDim2.new(1,-18,0,164),
    BackgroundTransparency=1
},IntelPanel)

Create("UIGridLayout",{
    CellSize=UDim2.new(0.5,-5,0,48),
    CellPadding=UDim2.fromOffset(10,10),
    SortOrder=Enum.SortOrder.LayoutOrder
},IntelGrid)

local HomeStatValues={}

local function CreateHomeStat(key,labelText,order)
    local cell=RegisterHomeObject(Create("Frame",{
        Name="HomeStatCell",
        BackgroundColor3=CurrentTheme.Panel,
        BorderSizePixel=0,
        LayoutOrder=order
    },IntelGrid))
    Round(cell,6)
    RegisterHomeObject(Stroke(cell,CurrentTheme.Accent,0.82,1))

    local statLabel=RegisterHomeObject(Create("TextLabel",{
        Name="HomeStatLabel",
        Position=UDim2.fromOffset(9,8),
        Size=UDim2.new(1,-18,0,11),
        BackgroundTransparency=1,
        Text=labelText,
        TextColor3=CurrentTheme.Muted,
        TextSize=8,
        Font=Enum.Font.GothamSemibold,
        TextXAlignment=Enum.TextXAlignment.Left
    },cell))
    statLabel:SetAttribute("MutedText",true)

    local value=Create("TextLabel",{
        Name="HomeStatValue",
        Position=UDim2.fromOffset(9,24),
        Size=UDim2.new(1,-18,0,17),
        BackgroundTransparency=1,
        Text="--",
        TextColor3=CurrentTheme.Text,
        TextSize=12,
        Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd
    },cell)

    HomeStatValues[key]=value
    return value
end

CreateHomeStat("FPS","FPS",1)
CreateHomeStat("Ping","PING",2)
CreateHomeStat("Players","PLAYERS",3)
CreateHomeStat("Uptime","UPTIME",4)
CreateHomeStat("Executor","EXECUTOR",5)
CreateHomeStat("Device","DEVICE",6)

local NewsPanel=RegisterHomeObject(Create("Frame",{
    Name="HomeSubPanel",
    AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-12,0,10),
    Size=UDim2.new(0.44,-24,1,-20),
    BackgroundColor3=CurrentTheme.Background,
    BorderSizePixel=0
},SplitSection))
Round(NewsPanel,7)
RegisterHomeObject(Stroke(NewsPanel,CurrentTheme.Accent,0.8,1))

RegisterHomeObject(Create("TextLabel",{
    Name="NewsTitle",
    Position=UDim2.fromOffset(12,8),
    Size=UDim2.new(1,-24,0,13),
    BackgroundTransparency=1,
    Text="WHAT'S NEW",
    TextColor3=CurrentTheme.Text,
    TextSize=9,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},NewsPanel))

local HomeNewsEntries={
    {Tag="NEW",AccentTag=true,Text="Cinematic boot intro with CRT power-on"},
    {Tag="UI",AccentTag=false,Text="The Bubba Curtain Call unload sequence"},
    {Tag="CORE",AccentTag=false,Text="Bubba Engine v2.4 session handshake"},
    {Tag="VISUAL",AccentTag=false,Text="24 interface themes with live preview"},
    {Tag="UTILITY",AccentTag=false,Text="Anti-AFK guard for idle kick protection"}
}

for index,entry in ipairs(HomeNewsEntries) do
    local row=RegisterHomeObject(Create("Frame",{
        Name="HomeNewsRow",
        Position=UDim2.fromOffset(10,28+(index-1)*29),
        Size=UDim2.new(1,-20,0,25),
        BackgroundColor3=CurrentTheme.Panel,
        BorderSizePixel=0
    },NewsPanel))
    Round(row,5)

    local tag=RegisterHomeObject(Create("TextLabel",{
        Name="HomeNewsTag",
        Position=UDim2.fromOffset(5,5),
        Size=UDim2.fromOffset(46,15),
        BackgroundColor3=entry.AccentTag and UIAccent:Lerp(Color3.new(0,0,0),0.55) or CurrentTheme.Background,
        BorderSizePixel=0,
        Text=entry.Tag,
        TextColor3=entry.AccentTag and CurrentTheme.Text or CurrentTheme.Muted,
        TextSize=7,
        Font=Enum.Font.GothamBold
    },row))
    Round(tag,7)
    tag:SetAttribute("TagAccent",entry.AccentTag)

    local newsLabel=RegisterHomeObject(Create("TextLabel",{
        Name="HomeNewsText",
        Position=UDim2.fromOffset(58,0),
        Size=UDim2.new(1,-64,1,0),
        BackgroundTransparency=1,
        Text=entry.Text,
        TextColor3=CurrentTheme.Text,
        TextSize=8,
        Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd
    },row))
end

local HomeNewsFooter=RegisterHomeObject(Create("TextLabel",{
    Name="HomeNewsFooter",
    Position=UDim2.fromOffset(12,176),
    Size=UDim2.new(1,-24,0,12),
    BackgroundTransparency=1,
    Text="BUBBA SCRIPTS  •  MORE DROPPING SOON",
    TextColor3=CurrentTheme.Muted,
    TextSize=7,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},NewsPanel))
HomeNewsFooter:SetAttribute("MutedText",true)

------------------------------------------------------------
-- SECTION 4 | THEME STRIP + QUICK NAVIGATION
------------------------------------------------------------

local NavSection=CreateHomeSection(56,4)

local HomeThemeTag=RegisterHomeObject(Create("TextLabel",{
    Name="HomeThemeTag",
    Position=UDim2.fromOffset(13,9),
    Size=UDim2.fromOffset(120,12),
    BackgroundTransparency=1,
    Text="ACTIVE THEME",
    TextColor3=CurrentTheme.Muted,
    TextSize=8,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},NavSection))
HomeThemeTag:SetAttribute("MutedText",true)

local HomeThemeName=RegisterHomeObject(Create("TextLabel",{
    Name="HomeThemeName",
    Position=UDim2.fromOffset(13,22),
    Size=UDim2.fromOffset(150,20),
    BackgroundTransparency=1,
    Text=CurrentTheme.Name,
    TextColor3=CurrentTheme.Text,
    TextSize=12,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},NavSection))

local HomeSwatchBackground=RegisterHomeObject(Create("Frame",{
    Name="HomeSwatchBackground",
    Position=UDim2.fromOffset(172,24),
    Size=UDim2.fromOffset(14,14),
    BackgroundColor3=CurrentTheme.Background,
    BorderSizePixel=0
},NavSection))
Round(HomeSwatchBackground,4)
RegisterHomeObject(Stroke(HomeSwatchBackground,CurrentTheme.Muted,0.6,1))

local HomeSwatchPanel=RegisterHomeObject(Create("Frame",{
    Name="HomeSwatchPanel",
    Position=UDim2.fromOffset(191,24),
    Size=UDim2.fromOffset(14,14),
    BackgroundColor3=CurrentTheme.PanelLight,
    BorderSizePixel=0
},NavSection))
Round(HomeSwatchPanel,4)
RegisterHomeObject(Stroke(HomeSwatchPanel,CurrentTheme.Muted,0.6,1))

local HomeSwatchAccent=RegisterHomeObject(Create("Frame",{
    Name="HomeSwatchAccent",
    Position=UDim2.fromOffset(210,24),
    Size=UDim2.fromOffset(14,14),
    BackgroundColor3=CurrentTheme.Accent,
    BorderSizePixel=0
},NavSection))
Round(HomeSwatchAccent,4)
RegisterHomeObject(Stroke(HomeSwatchAccent,CurrentTheme.Muted,0.6,1))

local HomeSwatchText=RegisterHomeObject(Create("Frame",{
    Name="HomeSwatchText",
    Position=UDim2.fromOffset(229,24),
    Size=UDim2.fromOffset(14,14),
    BackgroundColor3=CurrentTheme.Text,
    BorderSizePixel=0
},NavSection))
Round(HomeSwatchText,4)
RegisterHomeObject(Stroke(HomeSwatchText,CurrentTheme.Muted,0.6,1))

local HomeNavTargets={"VISUALS","CONFIGS","SETTINGS","INFO"}

for index,label in ipairs(HomeNavTargets) do
    local button=RegisterHomeObject(Create("TextButton",{
        Name="HomeNavButton",
        AnchorPoint=Vector2.new(1,0),
        Position=UDim2.new(1,-12-(#HomeNavTargets-index)*84,0,12),
        Size=UDim2.fromOffset(78,32),
        BackgroundColor3=ButtonColor(),
        BorderSizePixel=0,
        Text=label,
        TextColor3=CurrentTheme.Text,
        TextSize=9,
        Font=Enum.Font.GothamBold,
        AutoButtonColor=false
    },NavSection))
    Round(button,6)
    RegisterHomeObject(Stroke(button,CurrentTheme.Accent,0.7,1))

    button.MouseEnter:Connect(function()
        if not unloading then
            Tween(button,{BackgroundColor3=ButtonHoverColor()},0.12)
        end
    end)

    button.MouseLeave:Connect(function()
        if not unloading then
            Tween(button,{BackgroundColor3=ButtonColor()},0.16)
        end
    end)

    button.MouseButton1Click:Connect(function()
        if not unloading then
            SelectTab(label)
        end
    end)
end

------------------------------------------------------------
-- SECTION 5 | OWNER CONTROLS (adenrobers only)
-- ON  = the rainbow OWNER tab sits in the tab bar
-- OFF = the tab vanishes; this switch stays right here so it
--       can always be flipped back on
------------------------------------------------------------
local OwnerTabEnabled=true
local OwnerSwitchPill,OwnerSwitchKnob

local function SetOwnerSwitchVisual(state)
    if OwnerSwitchPill and OwnerSwitchPill.Parent then
        OwnerSwitchPill:SetAttribute("HomeToggleOn",state)
        Tween(OwnerSwitchPill,{
            BackgroundColor3=state and UIAccent:Lerp(Color3.new(0,0,0),0.45) or CurrentTheme.Panel
        },0.15)
    end
    if OwnerSwitchKnob and OwnerSwitchKnob.Parent then
        Tween(OwnerSwitchKnob,{
            Position=state and UDim2.fromOffset(21,3) or UDim2.fromOffset(3,3),
            BackgroundColor3=state and Color3.fromRGB(255,255,255) or Color3.fromRGB(120,120,130)
        },0.18,Enum.EasingStyle.Back)
    end
end

if IsOwner then
    local OwnerSection=CreateHomeSection(88,5)

    RegisterHomeObject(Create("TextLabel",{
        Name="OwnerSectionTitle",
        Position=UDim2.fromOffset(13,9),
        Size=UDim2.new(1,-26,0,19),
        BackgroundTransparency=1,
        Text="OWNER CONTROLS",
        TextColor3=CurrentTheme.Text,
        TextSize=11,
        Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left
    },OwnerSection))

    local ownerSectionSub=RegisterHomeObject(Create("TextLabel",{
        Name="OwnerSectionSub",
        Position=UDim2.fromOffset(13,28),
        Size=UDim2.new(1,-26,0,16),
        BackgroundTransparency=1,
        Text="Your tab, your rules — flip it whenever you want.",
        TextColor3=CurrentTheme.Muted,
        TextSize=8,
        Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left
    },OwnerSection))
    ownerSectionSub:SetAttribute("MutedText",true)

    local OwnerTabRow=RegisterHomeObject(Create("Frame",{
        Name="HomeQuickCard",
        Position=UDim2.fromOffset(12,50),
        Size=UDim2.new(1,-24,0,30),
        BackgroundColor3=CurrentTheme.Background,
        BorderSizePixel=0
    },OwnerSection))
    Round(OwnerTabRow,7)
    RegisterHomeObject(Stroke(OwnerTabRow,CurrentTheme.Accent,0.78,1))

    RegisterHomeObject(Create("TextLabel",{
        Name="OwnerTabRowCrown",
        Position=UDim2.fromOffset(8,0),
        Size=UDim2.fromOffset(18,30),
        BackgroundTransparency=1,
        Text="👑",
        TextColor3=CurrentTheme.Text,
        TextSize=11,
        Font=Enum.Font.Gotham
    },OwnerTabRow))

    RegisterHomeObject(Create("TextLabel",{
        Name="OwnerTabRowName",
        Position=UDim2.fromOffset(30,5),
        Size=UDim2.new(1,-110,0,12),
        BackgroundTransparency=1,
        Text="OWNER TAB",
        TextColor3=CurrentTheme.Text,
        TextSize=9,
        Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left
    },OwnerTabRow))

    local ownerTabRowDesc=RegisterHomeObject(Create("TextLabel",{
        Name="OwnerTabRowDesc",
        Position=UDim2.fromOffset(30,18),
        Size=UDim2.new(1,-110,0,10),
        BackgroundTransparency=1,
        Text="Show the rainbow OWNER tab in the tab bar.",
        TextColor3=CurrentTheme.Muted,
        TextSize=8,
        Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd
    },OwnerTabRow))
    ownerTabRowDesc:SetAttribute("MutedText",true)

    OwnerSwitchPill=RegisterHomeObject(Create("TextButton",{
        Name="OwnerTabSwitch",
        AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-7,0.5,0),
        Size=UDim2.fromOffset(36,18),
        BackgroundColor3=UIAccent:Lerp(Color3.new(0,0,0),0.45),
        BorderSizePixel=0,
        Text="",
        AutoButtonColor=false,
        ZIndex=6
    },OwnerTabRow))
    Round(OwnerSwitchPill,9)
    OwnerSwitchPill:SetAttribute("HomeToggle",true)
    OwnerSwitchPill:SetAttribute("HomeToggleOn",true)

    OwnerSwitchKnob=Create("Frame",{
        Name="OwnerKnob",
        Position=UDim2.fromOffset(21,3),
        Size=UDim2.fromOffset(12,12),
        BackgroundColor3=Color3.fromRGB(255,255,255),
        BorderSizePixel=0,
        ZIndex=7
    },OwnerSwitchPill)
    Round(OwnerSwitchKnob,6)

    Create("UIGradient",{
        Color=OwnerRainbow(),
        Rotation=45
    },OwnerSwitchKnob)

    OwnerSwitchPill.MouseButton1Click:Connect(function()
        if unloading then return end
        OwnerTabEnabled=not OwnerTabEnabled
        SetOwnerSwitchVisual(OwnerTabEnabled)

        local ownerButton=Tabs.OWNER
        if ownerButton then
            ownerButton.Visible=OwnerTabEnabled
            if not OwnerTabEnabled and SelectedTab=="OWNER" then
                SelectTab("HOME")
            end
        end
    end)
end

------------------------------------------------------------
-- LIVE DATA
------------------------------------------------------------

local function GetHomeGreeting()
    local hour
    local success,result=pcall(function()
        return tonumber(DateTime.now():FormatLocalTime("H","en-us"))
    end)
    if success and result then hour=result else hour=12 end

    if hour>=5 and hour<12 then
        return "Good morning"
    elseif hour>=12 and hour<17 then
        return "Good afternoon"
    elseif hour>=17 and hour<22 then
        return "Good evening"
    end
    return "Late night session"
end

local function GetHomePing()
    local success,value=pcall(function()
        local stats=game:GetService("Stats")
        local pingValue=stats.Network.ServerStatsItem["Ping Data"]:GetValue()
        return math.floor(pingValue+0.5)
    end)
    if success and value and value>0 then
        return value
    end
    return nil
end

local function FpsColor(fps)
    if fps>=50 then
        return Color3.fromRGB(95,205,125)
    elseif fps>=30 then
        return Color3.fromRGB(235,190,75)
    end
    return Color3.fromRGB(235,95,115)
end

local function PingColor(ping)
    if ping<=60 then
        return Color3.fromRGB(95,205,125)
    elseif ping<=120 then
        return Color3.fromRGB(235,190,75)
    end
    return Color3.fromRGB(235,95,115)
end

local function FormatHomeUptime(seconds)
    local hours=math.floor(seconds/3600)
    local minutes=math.floor((seconds%3600)/60)
    local remaining=seconds%60
    if hours>0 then
        return string.format("%d:%02d:%02d",hours,minutes,remaining)
    end
    return string.format("%02d:%02d",minutes,remaining)
end

local HomeFpsConnection
HomeFpsConnection=RunService.RenderStepped:Connect(function(deltaTime)
    if not ScreenGui.Parent then
        HomeFpsConnection:Disconnect()
        return
    end
    HomeFpsFrames+=1
    HomeFpsElapsed+=deltaTime
    if HomeFpsElapsed>=1 then
        HomeFpsCurrent=math.floor(HomeFpsFrames/HomeFpsElapsed+0.5)
        HomeFpsFrames=0
        HomeFpsElapsed=0
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        if not unloading and HomePage.Parent then
            HomeSessionSeconds+=1

            HomeGreeting.Text=GetHomeGreeting().." — all modules armed and standing by."

            local fpsValue=HomeStatValues.FPS
            if fpsValue and fpsValue.Parent then
                if HomeFpsCurrent>0 then
                    fpsValue.Text=tostring(HomeFpsCurrent).." FPS"
                    fpsValue.TextColor3=FpsColor(HomeFpsCurrent)
                else
                    fpsValue.Text="..."
                    fpsValue.TextColor3=CurrentTheme.Text
                end
            end

            local pingValue=HomeStatValues.Ping
            if pingValue and pingValue.Parent then
                local ping=GetHomePing()
                if ping then
                    pingValue.Text=tostring(ping).." ms"
                    pingValue.TextColor3=PingColor(ping)
                else
                    pingValue.Text="—"
                    pingValue.TextColor3=CurrentTheme.Muted
                end
            end

            local playersValue=HomeStatValues.Players
            if playersValue and playersValue.Parent then
                playersValue.Text=tostring(#Players:GetPlayers()).." IN GAME"
                playersValue.TextColor3=CurrentTheme.Text
            end

            local uptimeValue=HomeStatValues.Uptime
            if uptimeValue and uptimeValue.Parent then
                uptimeValue.Text=FormatHomeUptime(HomeSessionSeconds)
                uptimeValue.TextColor3=CurrentTheme.Text
            end

            local executorValue=HomeStatValues.Executor
            if executorValue and executorValue.Parent then
                executorValue.Text=DetectExecutor()
                executorValue.TextColor3=CurrentTheme.Text
            end

            local deviceValue=HomeStatValues.Device
            if deviceValue and deviceValue.Parent then
                deviceValue.Text=GetDeviceType()
                deviceValue.TextColor3=CurrentTheme.Text
            end

            HomeSessionLabel.Text="SESSION "..FormatHomeUptime(HomeSessionSeconds)
            HomeStatusPill.TextColor3=UIAccent
        end
        task.wait(1)
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        if not unloading then
            if HomePulseDot and HomePulseDot.Parent then
                HomePulseDot.BackgroundColor3=UIAccent
                Tween(HomePulseDot,{BackgroundTransparency=0.55},0.8)
                Tween(HomeAvatarRing,{Transparency=0.15},0.8)
                task.wait(0.8)
                if not ScreenGui.Parent then break end
                Tween(HomePulseDot,{BackgroundTransparency=0},0.8)
                Tween(HomeAvatarRing,{Transparency=0.35},0.8)
            end
        end
        task.wait(0.8)
    end
end)

task.spawn(function()
    local success,content=pcall(function()
        return Players:GetUserThumbnailAsync(Player.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size48x48)
    end)
    if success and content and content~="" and HomeAvatar and HomeAvatar.Parent then
        HomeAvatar.Image=content
        if HomeMonogram and HomeMonogram.Parent then
            HomeMonogram.Visible=false
        end
    end
end)

HomePage:GetPropertyChangedSignal("Visible"):Connect(function()
    if HomePage.Visible and not unloading then
        RefreshHomeSwitches()
    end
end)

------------------------------------------------------------
-- HOME THEME SYNC (chained onto the master theme pipeline)
------------------------------------------------------------

local function UpdateHomeTheme(theme)
    if HomeScroll and HomeScroll.Parent then
        HomeScroll.ScrollBarImageColor3=theme.Accent
    end

    if HomeTitle then HomeTitle.TextColor3=theme.Text end
    if HomeSubtitle then HomeSubtitle.TextColor3=theme.Muted end
    if HomeGreeting then HomeGreeting.TextColor3=theme.Muted end
    if HomeStatusPill then HomeStatusPill.TextColor3=theme.Accent end

    if HomeAvatar then HomeAvatar.BackgroundColor3=theme.Panel end
    if HomeAvatarRing then HomeAvatarRing.Color=theme.Accent end
    if HomeMonogram then HomeMonogram.TextColor3=theme.Accent end

    if HomeEngineVersion then HomeEngineVersion.TextColor3=theme.Accent end
    if HomeSystemsLabel then HomeSystemsLabel.TextColor3=theme.Accent end
    if HomePulseDot then HomePulseDot.BackgroundColor3=theme.Accent end
    if HomeSessionLabel then HomeSessionLabel.TextColor3=theme.Muted end

    if HomeThemeName then
        HomeThemeName.Text=theme.Name
        HomeThemeName.TextColor3=theme.Text
    end

    if HomeSwatchBackground then HomeSwatchBackground.BackgroundColor3=theme.Background end
    if HomeSwatchPanel then HomeSwatchPanel.BackgroundColor3=theme.PanelLight end
    if HomeSwatchAccent then HomeSwatchAccent.BackgroundColor3=theme.Accent end
    if HomeSwatchText then HomeSwatchText.BackgroundColor3=theme.Text end

    for _,object in ipairs(HomeThemeObjects) do
        if object and object.Parent then
            if object:IsA("Frame") then
                if object.Name=="HomeSection" then
                    object.BackgroundColor3=theme.PanelLight
                elseif object.Name=="HomeSubPanel" then
                    object.BackgroundColor3=theme.Background
                elseif object.Name=="HomeQuickCard" then
                    object.BackgroundColor3=theme.Background
                elseif object.Name=="HomeStatCell" or object.Name=="HomeNewsRow" then
                    object.BackgroundColor3=theme.Panel
                elseif object.Name=="HomeChip" then
                    object.BackgroundColor3=theme.Panel
                elseif object.Name=="HomeKnob" then
                    local on=object.Parent and object.Parent:GetAttribute("HomeToggleOn")
                    object.BackgroundColor3=on and theme.Accent or theme.Muted
                end
            elseif object:IsA("ImageLabel") then
                if object.Name=="HomeAvatar" then
                    object.BackgroundColor3=theme.Panel
                end
            elseif object:IsA("TextLabel") then
                if object.Name=="HomeNewsTag" then
                    object.BackgroundColor3=object:GetAttribute("TagAccent") and theme.Accent:Lerp(Color3.new(0,0,0),0.55) or theme.Background
                    object.TextColor3=object:GetAttribute("TagAccent") and theme.Text or theme.Muted
                else
                    object.TextColor3=object:GetAttribute("MutedText") and theme.Muted or theme.Text
                end
            elseif object:IsA("TextButton") then
                if object:GetAttribute("HomeToggle") then
                    local on=object:GetAttribute("HomeToggleOn")
                    object.BackgroundColor3=on and theme.Accent:Lerp(Color3.new(0,0,0),0.45) or theme.Panel
                elseif object.Name=="HomeNavButton" then
                    object.BackgroundColor3=ButtonColor()
                    object.TextColor3=theme.Text
                end
            elseif object:IsA("UIStroke") then
                object.Color=theme.Accent
            end
        end
    end
end

local BaseApplyThemeHome=ApplyTheme
ApplyTheme=function(theme)
    BaseApplyThemeHome(theme)
    UpdateHomeTheme(theme)
end

-- paint the quick switches with their real starting states
RefreshHomeSwitches()

SelectTab("HOME")

end)

if not HomeBuildOk then
    warn("[BUBBA HOME TAB ERROR]:",HomeBuildError)
end

--========================================================
-- OWNER TAB | THE OWNER CONSOLE (adenrobers only)
-- A rainbow command deck reserved for the script owner:
-- identity banner, live server roster, session intel and
-- power actions. Nothing here is built for anyone else.
--========================================================
local OwnerPageBuildOk,OwnerPageBuildError=pcall(function()
if not IsOwner then return end

local OwnerPage=Pages.OWNER

local OwnerThemeObjects={}
local function RegisterOwnerObject(object)
    table.insert(OwnerThemeObjects,object)
    return object
end

local OwnerIdentity=tostring(Player.DisplayName or Player.Name or "adenrobers")

------------------------------------------------------------
-- PAGE HEADER
------------------------------------------------------------

local OwnerTitle=RegisterOwnerObject(Create("TextLabel",{
    Name="OwnerTitle",
    Position=UDim2.fromOffset(20,12),
    Size=UDim2.new(1,-220,0,25),
    BackgroundTransparency=1,
    Text="Owner Console",
    TextColor3=CurrentTheme.Text,
    TextSize=18,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},OwnerPage))

local OwnerSubtitle=RegisterOwnerObject(Create("TextLabel",{
    Name="OwnerSubtitle",
    Position=UDim2.fromOffset(21,37),
    Size=UDim2.new(1,-230,0,18),
    BackgroundTransparency=1,
    Text="Command deck reserved for adenrobers — script owner.",
    TextColor3=CurrentTheme.Muted,
    TextSize=10,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left
},OwnerPage))
OwnerSubtitle:SetAttribute("MutedText",true)

local OwnerStatusPill=RegisterOwnerObject(Create("TextLabel",{
    Name="OwnerStatusPill",
    AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-20,0,16),
    Size=UDim2.fromOffset(180,16),
    BackgroundTransparency=1,
    Text="●  OWNER VERIFIED",
    TextColor3=OwnerGold,
    TextSize=9,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Right
},OwnerPage))

local OwnerScroll=Create("ScrollingFrame",{
    Name="OwnerScroll",
    Position=UDim2.fromOffset(20,65),
    Size=UDim2.new(1,-40,1,-78),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ScrollBarThickness=3,
    ScrollBarImageColor3=UIAccent,
    ScrollingDirection=Enum.ScrollingDirection.Y,
    CanvasSize=UDim2.new(0,0,0,0),
    AutomaticCanvasSize=Enum.AutomaticSize.Y
},OwnerPage)
OwnerScroll.ScrollBarImageTransparency=0.15

Create("UIListLayout",{
    SortOrder=Enum.SortOrder.LayoutOrder,
    Padding=UDim.new(0,10)
},OwnerScroll)

local function CreateOwnerSection(height,order)
    local section=RegisterOwnerObject(Create("Frame",{
        Name="OwnerCard",
        Size=UDim2.new(1,0,0,height),
        BackgroundColor3=CurrentTheme.PanelLight,
        BorderSizePixel=0,
        LayoutOrder=order
    },OwnerScroll))
    Round(section,8)
    RegisterOwnerObject(Stroke(section,CurrentTheme.Accent,0.72,1))
    return section
end

------------------------------------------------------------
-- SECTION 1 | IDENTITY BANNER (rainbow)
------------------------------------------------------------

local OwnerBanner=CreateOwnerSection(96,1)
Stroke(OwnerBanner,OwnerGold,0.35,1)

local OwnerBannerWash=Create("UIGradient",{
    Color=OwnerRainbow(),
    Rotation=15,
    Transparency=NumberSequence.new(0.62)
},OwnerBanner)
table.insert(OwnerRainbowGradients,OwnerBannerWash)

local OwnerMonogram=Create("Frame",{
    Name="OwnerMonogram",
    Position=UDim2.fromOffset(18,18),
    Size=UDim2.fromOffset(60,60),
    BackgroundColor3=Color3.fromRGB(24,22,30),
    BorderSizePixel=0
},OwnerBanner)
Round(OwnerMonogram,100)
Stroke(OwnerMonogram,OwnerGold,0.2,1)

Create("UIGradient",{
    Color=OwnerRainbow(),
    Rotation=45,
    Transparency=NumberSequence.new(0.35)
},OwnerMonogram)

Create("TextLabel",{
    Name="OwnerMonogramLetter",
    Size=UDim2.fromScale(1,1),
    BackgroundTransparency=1,
    Text=string.upper(string.sub(OwnerIdentity,1,1)),
    TextColor3=Color3.fromRGB(255,255,255),
    TextSize=26,
    Font=Enum.Font.GothamBold
},OwnerMonogram)

RegisterOwnerObject(Create("TextLabel",{
    Name="OwnerBannerName",
    Position=UDim2.fromOffset(94,16),
    Size=UDim2.new(1,-130,0,24),
    BackgroundTransparency=1,
    Text=string.upper(OwnerIdentity),
    TextColor3=CurrentTheme.Text,
    TextSize=16,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd
},OwnerBanner))

local OwnerBannerRole=RegisterOwnerObject(Create("TextLabel",{
    Name="OwnerBannerRole",
    Position=UDim2.fromOffset(94,44),
    Size=UDim2.new(1,-130,0,14),
    BackgroundTransparency=1,
    Text="SCRIPT OWNER  ·  FULL COMMAND AUTHORITY",
    TextColor3=CurrentTheme.Muted,
    TextSize=9,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},OwnerBanner))
OwnerBannerRole:SetAttribute("MutedText",true)

local OwnerBannerChip=RegisterOwnerObject(Create("TextLabel",{
    Name="OwnerBannerChip",
    AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-14,0,62),
    Size=UDim2.fromOffset(96,18),
    BackgroundColor3=CurrentTheme.Background,
    BorderSizePixel=0,
    Text="VERIFIED OWNER",
    TextColor3=OwnerGold,
    TextSize=8,
    Font=Enum.Font.GothamBold
},OwnerBanner))
Round(OwnerBannerChip,9)
RegisterOwnerObject(Stroke(OwnerBannerChip,OwnerGold,0.45,1))

------------------------------------------------------------
-- SECTION 2 | LIVE SERVER ROSTER
------------------------------------------------------------

local OwnerServerSection=CreateOwnerSection(206,2)

RegisterOwnerObject(Create("TextLabel",{
    Name="OwnerServerTitle",
    Position=UDim2.fromOffset(13,9),
    Size=UDim2.new(1,-160,0,19),
    BackgroundTransparency=1,
    Text="LIVE SERVER",
    TextColor3=CurrentTheme.Text,
    TextSize=11,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},OwnerServerSection))

local OwnerCountLabel=RegisterOwnerObject(Create("TextLabel",{
    Name="OwnerCountLabel",
    AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-13,0,9),
    Size=UDim2.fromOffset(140,19),
    BackgroundTransparency=1,
    Text="... ONLINE",
    TextColor3=CurrentTheme.Text,
    TextSize=11,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Right
},OwnerServerSection))

local ownerServerSub=RegisterOwnerObject(Create("TextLabel",{
    Name="OwnerServerSub",
    Position=UDim2.fromOffset(13,28),
    Size=UDim2.new(1,-26,0,16),
    BackgroundTransparency=1,
    Text="Everyone sharing this server with you right now.",
    TextColor3=CurrentTheme.Muted,
    TextSize=8,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left
},OwnerServerSection))
ownerServerSub:SetAttribute("MutedText",true)

local OwnerRosterList=RegisterOwnerObject(Create("Frame",{
    Name="OwnerRosterList",
    Position=UDim2.fromOffset(12,48),
    Size=UDim2.new(1,-24,0,124),
    BackgroundTransparency=1
},OwnerServerSection))

local OwnerSessionStrip=RegisterOwnerObject(Create("TextLabel",{
    Name="OwnerSessionStrip",
    Position=UDim2.fromOffset(13,182),
    Size=UDim2.new(1,-26,0,14),
    BackgroundTransparency=1,
    Text="SESSION 00:00   ·   JOINS 0   ·   LEAVES 0",
    TextColor3=CurrentTheme.Muted,
    TextSize=8,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},OwnerServerSection))
OwnerSessionStrip:SetAttribute("MutedText",true)

local OwnerRosterRows={}
local OwnerJoins=0
local OwnerLeaves=0

local function RebuildOwnerRoster()
    if not OwnerRosterList or not OwnerRosterList.Parent then return end

    for _,row in ipairs(OwnerRosterRows) do
        if row and row.Parent then row:Destroy() end
    end
    OwnerRosterRows={}

    local players=Players:GetPlayers()
    local maxRows=6

    for index,p in ipairs(players) do
        if index>maxRows then break end
        local isLocal=(p==Player)

        local row=RegisterOwnerObject(Create("Frame",{
            Name="OwnerRosterRow",
            Position=UDim2.fromOffset(0,(index-1)*20),
            Size=UDim2.new(1,0,0,18),
            BackgroundColor3=isLocal and CurrentTheme.Background or CurrentTheme.Panel,
            BackgroundTransparency=isLocal and 0 or 0.35,
            BorderSizePixel=0
        },OwnerRosterList))
        Round(row,5)
        table.insert(OwnerRosterRows,row)

        local dot=Create("Frame",{
            Name="OwnerRosterDot",
            Position=UDim2.fromOffset(6,6),
            Size=UDim2.fromOffset(6,6),
            BackgroundColor3=isLocal and OwnerGold or UIAccent,
            BorderSizePixel=0
        },row)
        Round(dot,100)

        RegisterOwnerObject(Create("TextLabel",{
            Name="OwnerRosterName",
            Position=UDim2.fromOffset(20,0),
            Size=UDim2.new(0.55,-20,1,0),
            BackgroundTransparency=1,
            Text="@"..tostring(p.Name or "?"),
            TextColor3=isLocal and CurrentTheme.Text or CurrentTheme.Text,
            TextSize=9,
            Font=Enum.Font.GothamBold,
            TextXAlignment=Enum.TextXAlignment.Left,
            TextTruncate=Enum.TextTruncate.AtEnd
        },row))

        RegisterOwnerObject(Create("TextLabel",{
            Name="OwnerRosterDisplay",
            AnchorPoint=Vector2.new(1,0),
            Position=UDim2.new(1,-8,0,0),
            Size=UDim2.new(0.42,-12,1,0),
            BackgroundTransparency=1,
            Text=tostring(p.DisplayName or p.Name or "?"),
            TextColor3=CurrentTheme.Muted,
            TextSize=8,
            Font=Enum.Font.Gotham,
            TextXAlignment=Enum.TextXAlignment.Right,
            TextTruncate=Enum.TextTruncate.AtEnd
        },row))
    end

    local overflow=#players-maxRows
    if overflow>0 then
        local more=RegisterOwnerObject(Create("TextLabel",{
            Name="OwnerRosterMore",
            Position=UDim2.fromOffset(0,maxRows*20),
            Size=UDim2.new(1,0,0,14),
            BackgroundTransparency=1,
            Text="…and "..overflow.." more in this server",
            TextColor3=CurrentTheme.Muted,
            TextSize=8,
            Font=Enum.Font.Gotham,
            TextXAlignment=Enum.TextXAlignment.Left
        },OwnerRosterList))
        more:SetAttribute("MutedText",true)
        table.insert(OwnerRosterRows,more)
    end

    if OwnerCountLabel and OwnerCountLabel.Parent then
        OwnerCountLabel.Text=tostring(#players).." ONLINE"
    end
end

RebuildOwnerRoster()

Players.PlayerAdded:Connect(function()
    if unloading or not ScreenGui.Parent then return end
    OwnerJoins+=1
    RebuildOwnerRoster()
end)

Players.PlayerRemoving:Connect(function()
    if unloading or not ScreenGui.Parent then return end
    OwnerLeaves+=1
    RebuildOwnerRoster()
    -- fire a second pass for executors that drop the player object
    -- a beat after the event, so the roster never shows a ghost
    task.delay(0.25,function()
        if not unloading and ScreenGui.Parent then
            RebuildOwnerRoster()
        end
    end)
end)

------------------------------------------------------------
-- SECTION 3 | FUN DECK — FLING SYSTEM + TROLL ZONE
-- (adenrobers only)
-- Owner-only chaos console. Every effect runs through real
-- physics and real movement on your OWN character, so all of
-- it replicates: the entire server sees the flings, the
-- tornado spin, the orbit, the head-sit, the follow and the
-- chat spam. Nothing here is a local-only illusion.
------------------------------------------------------------

local FunOk,FunErr=pcall(function()

-- chaos state ------------------------------------------------
local ChaosTarget=nil
local ChaosPower=2
local ChaosPowerValues={9000,32000,75000,150000}
local ChaosYeetValues={120,200,300,460}
local ChaosAuraRadius=22
local FlingBusy=false
local FlingAuraOn=false
local TornadoOn=false
local ChatSpamOn=false
local TornadoSpin=nil
local ChaosMotionConnected=false
local ChaosOrbitAngle=0
local WreckSpin=nil
local MeteorOn=false
local MeteorBusy=false
local GlitchOn=false
local ZoomiesOn=false
local MoonOn=false
local RaveOn=false
local SavedWalkSpeed=nil
local SavedJump=nil
local SavedGravity=nil

local FunSwitches={}
local FunToggleRows={}
local FunButtons={}
local FunPickerPills={}
local FunPowerButtons={}
local FunStatusLabels={}
local FunStatusText="pick a target and cause some chaos."
local FunStatusKind="muted"

local OrbitToggle,SitToggle,FollowToggle,WreckToggle,MeteorToggle,GlitchToggle,ZoomiesToggle,MoonToggle,RaveToggle,SpamToggle
local FunChatBox
local FunTargetCard
local FunTargetKicker
local FunTargetClear
local FunPicker

-- chaos helpers ----------------------------------------------
local function GetChaosRoot(plr)
    if not plr then return nil end
    local character=plr.Character
    if not character then return nil end
    local root=character:FindFirstChild("HumanoidRootPart")
    if root then return root end
    return character.PrimaryPart
end

local function ApplyFunStatus()
    for _,label in ipairs(FunStatusLabels) do
        if label and label.Parent then
            label.Text=FunStatusText
            if FunStatusKind=="good" then
                label.TextColor3=Color3.fromRGB(95,205,125)
            elseif FunStatusKind=="bad" then
                label.TextColor3=Color3.fromRGB(235,95,115)
            elseif FunStatusKind=="hot" then
                label.TextColor3=OwnerGold
            else
                label.TextColor3=CurrentTheme.Muted
            end
        end
    end
end

local function SetFunStatus(text,kind)
    FunStatusText=tostring(text or "")
    FunStatusKind=kind or "muted"
    ApplyFunStatus()
end

------------------------------------------------------------
-- THE FLING ENGINE (v2 — rerouted)
-- The battle-tested route: your character becomes a client-
-- owned spinning top pinned INSIDE the target for a LONG
-- sustained window. Three fixes over the old broken engine:
-- 1. the humanoid is dropped into the Physics state +
--    PlatformStand first, so it stops fighting the spin
--    (the old engine's humanoid dampened the whole fling)
-- 2. the pin holds ~1.5s instead of 0.3s — every physics
--    step resolves the overlap and shoves them skyward
-- 3. the pin sits right inside their root (0.3 studs up)
--    instead of hovering above their head
-- Your client owns your assembly, so the contact impulse
-- replicates and they launch on every screen in the server.
-- Then you snap back home and stand up instantly.
------------------------------------------------------------
local function FlingPlayer(target)
    if FlingBusy or unloading or not ScreenGui.Parent then return false end
    if not target or target==Player or not target.Parent then return false end

    local myCharacter=Player.Character
    local myRoot=GetChaosRoot(Player)
    local myHumanoid=myCharacter and myCharacter:FindFirstChildOfClass("Humanoid")
    if not myRoot or not myHumanoid or myHumanoid.Health<=0 then return false end

    local theirCharacter=target.Character
    local theirRoot=GetChaosRoot(target)
    if not theirRoot or theirRoot.Anchored then return false end
    local theirHumanoid=theirCharacter and theirCharacter:FindFirstChildOfClass("Humanoid")
    if theirHumanoid and theirHumanoid.Health<=0 then return false end

    FlingBusy=true
    task.spawn(function()
        local ok=pcall(function()
            local homeCFrame=myRoot.CFrame

            -- let go of your body so nothing resists the spin
            myHumanoid.PlatformStand=true
            myHumanoid:ChangeState(Enum.HumanoidStateType.Physics)
            myRoot.AssemblyLinearVelocity=Vector3.new(0,0,0)
            myRoot.AssemblyAngularVelocity=Vector3.new(0,0,0)

            local spin=Instance.new("BodyAngularVelocity")
            spin.AngularVelocity=Vector3.new(0,ChaosPowerValues[ChaosPower] or 32000,0)
            spin.MaxTorque=Vector3.new(9e9,9e9,9e9)
            spin.Parent=myRoot

            -- LONG sustained pin: stay inside the target so every
            -- physics frame resolves the collision and launches them
            local holdUntil=os.clock()+1.5
            while os.clock()<holdUntil do
                if unloading or not ScreenGui.Parent or not myRoot.Parent then break end
                local liveRoot=GetChaosRoot(target)
                if not liveRoot then break end
                local liveHum=target.Character and target.Character:FindFirstChildOfClass("Humanoid")
                if liveHum and liveHum.Health<=0 then break end
                myRoot.CFrame=liveRoot.CFrame*CFrame.new(0,0.3,0)
                task.wait()
            end

            if spin and spin.Parent then spin:Destroy() end
            if myRoot and myRoot.Parent then
                myRoot.AssemblyLinearVelocity=Vector3.new(0,0,0)
                myRoot.AssemblyAngularVelocity=Vector3.new(0,0,0)
                myRoot.CFrame=homeCFrame
            end
            if myHumanoid and myHumanoid.Parent then
                myHumanoid.PlatformStand=false
                myHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end)
        if not ok then
            warn("[BUBBA FLING]: fling hiccup — recovered safely")
        end
        FlingBusy=false
    end)
    return true
end

local function YeetSelf()
    if unloading or not ScreenGui.Parent then return end
    local myRoot=GetChaosRoot(Player)
    if not myRoot then return end
    pcall(function()
        local spin=Instance.new("BodyAngularVelocity")
        spin.AngularVelocity=Vector3.new(0,ChaosPowerValues[ChaosPower] or 32000,0)
        spin.MaxTorque=Vector3.new(9e9,9e9,9e9)
        spin.Parent=myRoot

        local boost=Instance.new("BodyVelocity")
        boost.Velocity=Vector3.new(0,ChaosYeetValues[ChaosPower] or 200,0)
        boost.MaxForce=Vector3.new(0,9e9,0)
        boost.P=1250
        boost.Parent=myRoot

        task.delay(0.55,function()
            if spin and spin.Parent then spin:Destroy() end
            if boost and boost.Parent then boost:Destroy() end
        end)
    end)
end

local function FlingEveryone()
    task.spawn(function()
        local count=0
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=Player and p.Parent then
                count=count+1
            end
        end
        if count==0 then
            SetFunStatus("nobody else is in this server.","bad")
            return
        end
        for _,p in ipairs(Players:GetPlayers()) do
            if unloading or not ScreenGui.Parent then break end
            if p~=Player and p.Parent then
                FlingPlayer(p)
                local waitStart=os.clock()
                while FlingBusy and os.clock()-waitStart<3 do
                    task.wait()
                end
                task.wait(0.15)
            end
        end
    end)
end

------------------------------------------------------------
-- TORNADO MODE
-- A persistent mega-spin on your own character. Anyone who
-- touches you eats the angular velocity and gets flung.
------------------------------------------------------------
local function ApplyTornadoSpin()
    if TornadoSpin and TornadoSpin.Parent then
        TornadoSpin:Destroy()
    end
    TornadoSpin=nil
    if not TornadoOn then return end
    local myRoot=GetChaosRoot(Player)
    if not myRoot then return end
    local spin=Instance.new("BodyAngularVelocity")
    spin.AngularVelocity=Vector3.new(0,(ChaosPowerValues[ChaosPower] or 32000)*0.35,0)
    spin.MaxTorque=Vector3.new(9e9,9e9,9e9)
    spin.Parent=myRoot
    TornadoSpin=spin
end

------------------------------------------------------------
-- MOTION PRANKS (orbit / sit on head / follow)
-- One shared Heartbeat loop drives all three modes. Your own
-- character is CFramed every frame, which replicates, so the
-- victim and the whole server see you doing it.
------------------------------------------------------------
local function EnsureChaosMotion()
    if ChaosMotionConnected then return end
    ChaosMotionConnected=true
    local connection
    connection=RunService.Heartbeat:Connect(function(deltaTime)
        if unloading or not ScreenGui.Parent then
            connection:Disconnect()
            ChaosMotionConnected=false
            return
        end
        if FlingBusy then return end

        if GlitchOn or MeteorBusy then return end

        local orbitOn=OrbitToggle and OrbitToggle.Get()
        local sitOn=SitToggle and SitToggle.Get()
        local followOn=FollowToggle and FollowToggle.Get()
        local wreckOn=WreckToggle and WreckToggle.Get()
        if not (orbitOn or sitOn or followOn or wreckOn) then
            connection:Disconnect()
            ChaosMotionConnected=false
            return
        end

        local target=ChaosTarget
        if not target or not target.Parent then return end
        local theirCharacter=target.Character
        local theirRoot=GetChaosRoot(target)
        if not theirRoot then return end

        local myCharacter=Player.Character
        local myRoot=GetChaosRoot(Player)
        if not myRoot then return end
        local myHumanoid=myCharacter and myCharacter:FindFirstChildOfClass("Humanoid")

        if orbitOn then
            ChaosOrbitAngle=(ChaosOrbitAngle+deltaTime*4.5)%(math.pi*2)
            myRoot.CFrame=CFrame.new(theirRoot.Position+Vector3.new(math.cos(ChaosOrbitAngle)*5.5,1.6,math.sin(ChaosOrbitAngle)*5.5))
        elseif wreckOn then
            -- wrecking ball: tight + fast orbit while mega-spinning
            ChaosOrbitAngle=(ChaosOrbitAngle+deltaTime*22)%(math.pi*2)
            myRoot.CFrame=CFrame.new(theirRoot.Position+Vector3.new(math.cos(ChaosOrbitAngle)*2.4,1.2,math.sin(ChaosOrbitAngle)*2.4))
        elseif sitOn then
            local head=theirCharacter and theirCharacter:FindFirstChild("Head")
            local base=head and head.Position or (theirRoot.Position+Vector3.new(0,2.6,0))
            myRoot.CFrame=CFrame.new(base+Vector3.new(0,2.35,0))
            if myHumanoid then
                myHumanoid.Sit=true
            end
        else
            myRoot.CFrame=theirRoot.CFrame+Vector3.new(0,0.6,3)
        end

        myRoot.AssemblyLinearVelocity=Vector3.new(0,0,0)
    end)
end

------------------------------------------------------------
-- CHAT TROLLING
-- Real chat messages as YOU — new TextChatService pipeline
-- first, legacy chat remote as fallback. Everyone reads along.
------------------------------------------------------------
local ChaosChatLines={
    "the tornado has entered the chat",
    "free flights today, courtesy of bubba airlines",
    "warning: gravity is now optional",
    "you cant catch me, im the gingerbread man",
    "this is your captain speaking: we are going UP",
    "certified fling zone. proceed with caution",
    "get flung, stay humble",
    "bubba was here. check the sky.",
    "physics called. it quit.",
    "if you can read this, you havent been flung yet"
}

local function SendChaosChat(message)
    if not message or message=="" then return false end
    message=string.sub(message,1,180)

    local sent=false
    pcall(function()
        local chatService=game:GetService("TextChatService")
        if chatService.ChatVersion==Enum.ChatVersion.TextChatService then
            local channels=chatService:FindFirstChild("TextChannels")
            local general=channels and channels:FindFirstChild("RBXGeneral")
            if general then
                general:SendAsync(message)
                sent=true
            end
        end
    end)

    if not sent then
        pcall(function()
            local legacyEvents=game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
            if legacyEvents and legacyEvents:FindFirstChild("SayMessageRequest") then
                legacyEvents.SayMessageRequest:FireServer(message,"All")
                sent=true
            end
        end)
    end

    return sent==true
end

local function StartFlingAuraLoop()
    task.spawn(function()
        while FlingAuraOn and ScreenGui.Parent and not unloading do
            local myRoot=GetChaosRoot(Player)
            if myRoot then
                local nearestTarget=nil
                local nearestDistance=math.huge
                for _,p in ipairs(Players:GetPlayers()) do
                    if p~=Player and p.Parent then
                        local theirRoot=GetChaosRoot(p)
                        if theirRoot then
                            local distance=(theirRoot.Position-myRoot.Position).Magnitude
                            if distance<=ChaosAuraRadius and distance<nearestDistance then
                                nearestTarget=p
                                nearestDistance=distance
                            end
                        end
                    end
                end
                if nearestTarget then
                    FlingPlayer(nearestTarget)
                end
            end
            task.wait(0.3)
        end
    end)
end

local function StartChatSpamLoop()
    task.spawn(function()
        local lineIndex=1
        while ChatSpamOn and ScreenGui.Parent and not unloading do
            local message=""
            if FunChatBox and FunChatBox.Parent then
                message=tostring(FunChatBox.Text or "")
            end
            if message=="" then
                message=ChaosChatLines[lineIndex]
                lineIndex=lineIndex+1
                if lineIndex>#ChaosChatLines then
                    lineIndex=1
                end
            end

            local sent=SendChaosChat(message)
            if not sent then
                ChatSpamOn=false
                if SpamToggle then SpamToggle.Set(false) end
                SetFunStatus("chat is locked down in this game.","bad")
                return
            end

            local waited=0
            while ChatSpamOn and waited<3.5 and ScreenGui.Parent and not unloading do
                task.wait(0.25)
                waited=waited+0.25
            end
        end
    end)
end

------------------------------------------------------------
-- ZOOMIES: super speed + super jump on your own humanoid.
-- Movement is simulated on your client, so the whole server
-- watches you sprint and bounce like a rocket.
------------------------------------------------------------
local function ApplyZoomies()
    local myCharacter=Player.Character
    local myHumanoid=myCharacter and myCharacter:FindFirstChildOfClass("Humanoid")
    if not myHumanoid then return end
    if ZoomiesOn then
        if not SavedWalkSpeed then
            SavedWalkSpeed=myHumanoid.WalkSpeed
            if myHumanoid.UseJumpPower then
                SavedJump=myHumanoid.JumpPower
            else
                SavedJump=myHumanoid.JumpHeight
            end
        end
        myHumanoid.WalkSpeed=120
        if myHumanoid.UseJumpPower then
            myHumanoid.JumpPower=180
        else
            myHumanoid.JumpHeight=40
        end
    else
        if SavedWalkSpeed then
            myHumanoid.WalkSpeed=SavedWalkSpeed
        end
        if SavedJump then
            if myHumanoid.UseJumpPower then
                myHumanoid.JumpPower=SavedJump
            else
                myHumanoid.JumpHeight=SavedJump
            end
        end
        SavedWalkSpeed=nil
        SavedJump=nil
    end
end

------------------------------------------------------------
-- MOON GRAVITY: floaty falls for your own character. Your
-- client owns your assembly, so everyone sees you drift.
------------------------------------------------------------
local function ApplyMoonGravity()
    if MoonOn then
        if not SavedGravity then
            SavedGravity=workspace.Gravity
        end
        workspace.Gravity=42
    else
        if SavedGravity then
            workspace.Gravity=SavedGravity
        end
        SavedGravity=nil
    end
end

------------------------------------------------------------
-- GLITCH OUT: your character violently teleports in place
-- like a corrupted asset. Pure CFrame, fully replicated.
------------------------------------------------------------
local function StartGlitchLoop()
    task.spawn(function()
        while GlitchOn and ScreenGui.Parent and not unloading do
            local myRoot=GetChaosRoot(Player)
            if myRoot then
                local jx=math.random(-150,150)/100
                local jy=math.random(-60,120)/100
                local jz=math.random(-150,150)/100
                myRoot.CFrame=myRoot.CFrame+Vector3.new(jx,jy,jz)
                if math.random(1,4)==1 then
                    myRoot.CFrame=myRoot.CFrame*CFrame.Angles(0,math.rad(math.random(-160,160)),0)
                end
            end
            task.wait(0.07)
        end
    end)
end

------------------------------------------------------------
-- METEOR MODE: leap above your target and body-slam into
-- them over and over. Every impact is a real contact fling.
------------------------------------------------------------
local function StartMeteorLoop()
    task.spawn(function()
        while MeteorOn and ScreenGui.Parent and not unloading do
            local myRoot=GetChaosRoot(Player)
            local theirRoot=ChaosTarget and GetChaosRoot(ChaosTarget)
            if myRoot and theirRoot and not FlingBusy then
                MeteorBusy=true
                pcall(function()
                    -- climb above them, then slam down
                    myRoot.AssemblyLinearVelocity=Vector3.new(0,0,0)
                    myRoot.CFrame=theirRoot.CFrame+Vector3.new(0,28,0)
                    local slam=Instance.new("BodyVelocity")
                    slam.MaxForce=Vector3.new(9e9,9e9,9e9)
                    slam.P=1250
                    slam.Parent=myRoot
                    local diveStart=os.clock()
                    while os.clock()-diveStart<0.7 do
                        if unloading or not ScreenGui.Parent or not myRoot.Parent then break end
                        local liveRoot=ChaosTarget and GetChaosRoot(ChaosTarget)
                        if not liveRoot then break end
                        local direction=(liveRoot.Position-myRoot.Position)
                        if direction.Magnitude>0.5 then
                            slam.Velocity=direction.Unit*170
                        else
                            break
                        end
                        task.wait()
                    end
                    if slam and slam.Parent then slam:Destroy() end
                    if myRoot and myRoot.Parent then
                        myRoot.AssemblyLinearVelocity=Vector3.new(0,0,0)
                    end
                end)
                MeteorBusy=false
            end
            local pause=0
            while MeteorOn and pause<0.45 and ScreenGui.Parent and not unloading do
                task.wait(0.15)
                pause=pause+0.15
            end
        end
        MeteorBusy=false
    end)
end

------------------------------------------------------------
-- EMOTE RAVE: spam real /e emote commands through chat so
-- your character dances non-stop for the whole server.
------------------------------------------------------------
local ChaosEmoteCommands={"/e dance","/e dance2","/e dance3","/e breakdance"}
local function StartRaveLoop()
    task.spawn(function()
        local cmdIndex=1
        while RaveOn and ScreenGui.Parent and not unloading do
            local sent=SendChaosChat(ChaosEmoteCommands[cmdIndex])
            if not sent then
                RaveOn=false
                if RaveToggle then RaveToggle.Set(false) end
                SetFunStatus("chat is locked down — emote rave cancelled.","bad")
                return
            end
            cmdIndex=cmdIndex+1
            if cmdIndex>#ChaosEmoteCommands then
                cmdIndex=1
            end
            local waited=0
            while RaveOn and waited<2.4 and ScreenGui.Parent and not unloading do
                task.wait(0.2)
                waited=waited+0.2
            end
        end
    end)
end

------------------------------------------------------------
-- MASTER STOP
------------------------------------------------------------
local function StopAllChaos()
    FlingAuraOn=false
    TornadoOn=false
    ChatSpamOn=false
    MeteorOn=false
    GlitchOn=false
    RaveOn=false
    if OrbitToggle then OrbitToggle.Set(false) end
    if SitToggle then SitToggle.Set(false) end
    if FollowToggle then FollowToggle.Set(false) end
    if WreckToggle then WreckToggle.Set(false) end
    if MeteorToggle then MeteorToggle.Set(false) end
    if GlitchToggle then GlitchToggle.Set(false) end
    if ZoomiesToggle then ZoomiesToggle.Set(false) end
    if MoonToggle then MoonToggle.Set(false) end
    if RaveToggle then RaveToggle.Set(false) end
    if SpamToggle then SpamToggle.Set(false) end
    if WreckSpin and WreckSpin.Parent then
        WreckSpin:Destroy()
    end
    WreckSpin=nil
    ZoomiesOn=false
    MoonOn=false
    pcall(ApplyZoomies)
    pcall(ApplyMoonGravity)
    ApplyTornadoSpin()
end

------------------------------------------------------------
-- SECTION 3 CARD | FLING SYSTEM
------------------------------------------------------------
local FlingSection=CreateOwnerSection(378,3)

RegisterOwnerObject(Create("TextLabel",{
    Name="FunFlingTitle",
    Position=UDim2.fromOffset(13,9),
    Size=UDim2.new(1,-26,0,19),
    BackgroundTransparency=1,
    Text="FLING SYSTEM",
    TextColor3=CurrentTheme.Text,
    TextSize=11,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},FlingSection))

local funFlingSub=RegisterOwnerObject(Create("TextLabel",{
    Name="FunFlingSub",
    Position=UDim2.fromOffset(13,28),
    Size=UDim2.new(1,-26,0,16),
    BackgroundTransparency=1,
    Text="pick a target, choose a power, send them to the sky — the whole server sees it.",
    TextColor3=CurrentTheme.Muted,
    TextSize=8,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd
},FlingSection))
funFlingSub:SetAttribute("MutedText",true)

-- live target card
FunTargetCard=Create("Frame",{
    Name="FunTargetCard",
    Position=UDim2.fromOffset(12,50),
    Size=UDim2.new(1,-24,0,26),
    BackgroundColor3=CurrentTheme.Background,
    BorderSizePixel=0
},FlingSection)
Round(FunTargetCard,7)
RegisterOwnerObject(Stroke(FunTargetCard,CurrentTheme.Accent,0.78,1))

FunTargetKicker=Create("TextLabel",{
    Name="FunTargetKicker",
    Position=UDim2.fromOffset(8,0),
    Size=UDim2.fromOffset(46,26),
    BackgroundTransparency=1,
    Text="TARGET",
    TextColor3=OwnerGold,
    TextSize=8,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},FunTargetCard)

local FunTargetLabel=RegisterOwnerObject(Create("TextLabel",{
    Name="FunTargetLabel",
    Position=UDim2.fromOffset(56,0),
    Size=UDim2.new(1,-160,0,26),
    BackgroundTransparency=1,
    Text="none — pick someone below",
    TextColor3=CurrentTheme.Text,
    TextSize=9,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd
},FunTargetCard))

FunTargetClear=Create("TextButton",{
    Name="FunTargetClear",
    AnchorPoint=Vector2.new(1,0.5),
    Position=UDim2.new(1,-7,0.5,0),
    Size=UDim2.fromOffset(52,18),
    BackgroundColor3=ButtonColor(),
    BorderSizePixel=0,
    Text="CLEAR",
    TextColor3=CurrentTheme.Text,
    TextSize=8,
    Font=Enum.Font.GothamBold,
    AutoButtonColor=false
},FunTargetCard)
Round(FunTargetClear,6)
RegisterOwnerObject(Stroke(FunTargetClear,CurrentTheme.Accent,0.65,1))

-- forward declaration: the picker visuals refresher is built
-- further down, but the clear button needs it right now
local RefreshFunPickerVisuals

FunTargetClear.MouseButton1Click:Connect(function()
    if unloading then return end
    ChaosTarget=nil
    if FunTargetLabel and FunTargetLabel.Parent then
        FunTargetLabel.Text="none — pick someone below"
    end
    RefreshFunPickerVisuals()
    SetFunStatus("target cleared.","muted")
end)

-- live target readout (name + distance)
local function UpdateFunTargetLabel()
    if not FunTargetLabel or not FunTargetLabel.Parent then return end
    if ChaosTarget and ChaosTarget.Parent then
        local targetRoot=GetChaosRoot(ChaosTarget)
        local myRoot=GetChaosRoot(Player)
        if targetRoot and myRoot then
            local distance=math.floor((targetRoot.Position-myRoot.Position).Magnitude+0.5)
            FunTargetLabel.Text="@"..tostring(ChaosTarget.Name).."  ·  "..tostring(distance).."m away"
        else
            FunTargetLabel.Text="@"..tostring(ChaosTarget.Name)
        end
    else
        FunTargetLabel.Text="none — pick someone below"
    end
end

-- scrolling target picker (4 per row, live)
FunPicker=Create("ScrollingFrame",{
    Name="FunPicker",
    Position=UDim2.fromOffset(12,82),
    Size=UDim2.new(1,-24,0,92),
    BackgroundColor3=CurrentTheme.Background,
    BackgroundTransparency=0.35,
    BorderSizePixel=0,
    ScrollBarThickness=3,
    ScrollBarImageColor3=UIAccent,
    ScrollBarImageTransparency=0.15,
    ScrollingDirection=Enum.ScrollingDirection.Y,
    CanvasSize=UDim2.new(0,0,0,0),
    AutomaticCanvasSize=Enum.AutomaticSize.Y
},FlingSection)

Create("UIGridLayout",{
    CellSize=UDim2.new(0.25,-8,0,24),
    CellPadding=UDim2.new(0,4,0,4),
    SortOrder=Enum.SortOrder.LayoutOrder
},FunPicker)

Create("UIPadding",{
    PaddingLeft=UDim.new(0,5),
    PaddingRight=UDim.new(0,5),
    PaddingTop=UDim.new(0,5),
    PaddingBottom=UDim.new(0,5)
},FunPicker)

RefreshFunPickerVisuals=function()
    for _,entry in ipairs(FunPickerPills) do
        if entry.Button and entry.Button.Parent then
            local selected=ChaosTarget~=nil and entry.Player==ChaosTarget
            if selected then
                entry.Button.BackgroundColor3=OwnerGold
                entry.Button.TextColor3=Color3.fromRGB(32,22,6)
            else
                entry.Button.BackgroundColor3=CurrentTheme.Panel
                entry.Button.TextColor3=CurrentTheme.Text
            end
        end
    end
end

local function RebuildFunPicker()
    if not FunPicker or not FunPicker.Parent then return end

    for _,entry in ipairs(FunPickerPills) do
        if entry.Button and entry.Button.Parent then
            entry.Button:Destroy()
        end
    end
    FunPickerPills={}

    if ChaosTarget and (not ChaosTarget.Parent or ChaosTarget==Player) then
        ChaosTarget=nil
    end

    local order=0
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=Player and p.Parent then
            order=order+1
            local pill=Create("TextButton",{
                Name="FunPickerPill",
                LayoutOrder=order,
                Size=UDim2.fromOffset(80,24),
                BackgroundColor3=CurrentTheme.Panel,
                BorderSizePixel=0,
                Text=tostring(p.DisplayName or p.Name),
                TextColor3=CurrentTheme.Text,
                TextSize=8,
                Font=Enum.Font.GothamBold,
                TextTruncate=Enum.TextTruncate.AtEnd,
                AutoButtonColor=false
            },FunPicker)
            Round(pill,6)
            RegisterOwnerObject(Stroke(pill,CurrentTheme.Accent,0.78,1))

            pill.MouseButton1Click:Connect(function()
                if unloading then return end
                if not p.Parent then return end
                ChaosTarget=p
                RefreshFunPickerVisuals()
                UpdateFunTargetLabel()
                SetFunStatus("target locked: @"..tostring(p.Name),"hot")
            end)

            table.insert(FunPickerPills,{Button=pill,Player=p})
        end
    end

    RefreshFunPickerVisuals()
end

RebuildFunPicker()

Players.PlayerAdded:Connect(function()
    if unloading or not ScreenGui.Parent then return end
    RebuildFunPicker()
end)

Players.PlayerRemoving:Connect(function(leaving)
    if unloading or not ScreenGui.Parent then return end
    if ChaosTarget==leaving then
        ChaosTarget=nil
        SetFunStatus("target left the server.","muted")
    end
    task.delay(0.25,function()
        if not unloading and ScreenGui.Parent then
            RebuildFunPicker()
        end
    end)
end)

task.spawn(function()
    while ScreenGui.Parent do
        if not unloading then
            UpdateFunTargetLabel()
        end
        task.wait(0.3)
    end
end)

-- fling power segmented control
RegisterOwnerObject(Create("TextLabel",{
    Name="FunPowerLabel",
    Position=UDim2.fromOffset(13,180),
    Size=UDim2.new(1,-26,0,12),
    BackgroundTransparency=1,
    Text="FLING POWER",
    TextColor3=CurrentTheme.Text,
    TextSize=9,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},FlingSection))

local function RefreshPowerVisuals()
    for _,entry in ipairs(FunPowerButtons) do
        if entry.Button and entry.Button.Parent then
            local selected=entry.Index==ChaosPower
            if selected then
                entry.Button.BackgroundColor3=UIAccent:Lerp(Color3.new(0,0,0),0.45)
                entry.Button.TextColor3=Color3.fromRGB(255,255,255)
            else
                entry.Button.BackgroundColor3=CurrentTheme.Panel
                entry.Button.TextColor3=CurrentTheme.Muted
            end
        end
    end
end

local PowerNames={"LOW","MED","HIGH","MAX"}
for index=1,4 do
    local powerButton=Create("TextButton",{
        Name="FunPowerButton",
        Position=UDim2.fromOffset(12+(index-1)*50,196),
        Size=UDim2.fromOffset(46,24),
        BackgroundColor3=CurrentTheme.Panel,
        BorderSizePixel=0,
        Text=PowerNames[index],
        TextColor3=CurrentTheme.Muted,
        TextSize=8,
        Font=Enum.Font.GothamBold,
        AutoButtonColor=false
    },FlingSection)
    Round(powerButton,6)
    RegisterOwnerObject(Stroke(powerButton,CurrentTheme.Accent,0.7,1))

    powerButton.MouseButton1Click:Connect(function()
        if unloading then return end
        ChaosPower=index
        RefreshPowerVisuals()
        SetFunStatus("fling power: "..PowerNames[index],"muted")
    end)

    table.insert(FunPowerButtons,{Button=powerButton,Index=index})
end

RefreshPowerVisuals()

-- fun button factory
local function CreateFunButton(parent,name,text,x,y,width,height,onClick,style,anchorRight)
    local isDanger=style=="danger"
    local isGold=style=="gold"
    local button=RegisterOwnerObject(Create("TextButton",{
        Name=name,
        AnchorPoint=anchorRight and Vector2.new(1,0) or Vector2.new(0,0),
        Position=anchorRight and UDim2.new(1,-x,0,y) or UDim2.fromOffset(x,y),
        Size=UDim2.new(0,width,0,height),
        BackgroundColor3=isDanger and Color3.fromRGB(96,26,38) or ButtonColor(),
        BorderSizePixel=0,
        Text=text,
        TextColor3=isDanger and Color3.fromRGB(255,120,140) or CurrentTheme.Text,
        TextSize=9,
        Font=Enum.Font.GothamBold,
        AutoButtonColor=false
    },parent))
    Round(button,7)

    if isDanger then
        Stroke(button,Color3.fromRGB(235,95,115),0.45,1)
    elseif isGold then
        Stroke(button,OwnerGold,0.45,1)
    else
        RegisterOwnerObject(Stroke(button,CurrentTheme.Accent,0.45,1))
    end

    button.MouseEnter:Connect(function()
        if not unloading then
            Tween(button,{BackgroundColor3=isDanger and Color3.fromRGB(128,36,52) or ButtonHoverColor()},0.12)
        end
    end)
    button.MouseLeave:Connect(function()
        if not unloading then
            Tween(button,{BackgroundColor3=isDanger and Color3.fromRGB(96,26,38) or ButtonColor()},0.16)
        end
    end)
    button.MouseButton1Click:Connect(function()
        if unloading then return end
        onClick()
    end)

    table.insert(FunButtons,{Button=button,Danger=isDanger})
    return button
end

-- fling action buttons
CreateFunButton(FlingSection,"FunFlingButton","FLING TARGET",12,228,170,30,function()
    if not ChaosTarget or not ChaosTarget.Parent then
        SetFunStatus("no target — pick someone below first.","bad")
        return
    end
    local launched=FlingPlayer(ChaosTarget)
    if launched then
        SetFunStatus("LAUNCHED @"..tostring(ChaosTarget.Name).." — check the sky.","good")
    else
        SetFunStatus("could not fling right now (busy, dead or protected).","bad")
    end
end,"gold")

CreateFunButton(FlingSection,"FunFlingAllButton","FLING ALL",190,228,170,30,function()
    SetFunStatus("flinging the whole server — hold tight...","hot")
    FlingEveryone()
end)

CreateFunButton(FlingSection,"FunYeetButton","YEET SELF",12,264,170,30,function()
    local myRoot=GetChaosRoot(Player)
    if not myRoot then
        SetFunStatus("no character to yeet right now.","bad")
        return
    end
    YeetSelf()
    SetFunStatus("you have been yeeted. godspeed.","hot")
end)

CreateFunButton(FlingSection,"FunPanicButton","STOP ALL CHAOS",190,264,170,30,function()
    StopAllChaos()
    SetFunStatus("all chaos stopped. behave yourself.","muted")
end,"danger")

-- fun toggle factory (pill + knob, same feel as the home switches)
local function CreateFunToggle(parent,y,label,description,onFlip)
    local row=Create("Frame",{
        Name="FunToggleRow",
        Position=UDim2.fromOffset(12,y),
        Size=UDim2.new(1,-24,0,26),
        BackgroundColor3=CurrentTheme.Background,
        BorderSizePixel=0
    },parent)
    Round(row,7)
    RegisterOwnerObject(Stroke(row,CurrentTheme.Accent,0.78,1))

    RegisterOwnerObject(Create("TextLabel",{
        Name="FunToggleName",
        Position=UDim2.fromOffset(10,3),
        Size=UDim2.new(1,-64,0,11),
        BackgroundTransparency=1,
        Text=label,
        TextColor3=CurrentTheme.Text,
        TextSize=9,
        Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left
    },row))

    local toggleDesc=RegisterOwnerObject(Create("TextLabel",{
        Name="FunToggleDesc",
        Position=UDim2.fromOffset(10,16),
        Size=UDim2.new(1,-64,0,9),
        BackgroundTransparency=1,
        Text=description,
        TextColor3=CurrentTheme.Muted,
        TextSize=8,
        Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd
    },row))
    toggleDesc:SetAttribute("MutedText",true)

    local pill=Create("TextButton",{
        Name="FunSwitchPill",
        AnchorPoint=Vector2.new(1,0.5),
        Position=UDim2.new(1,-7,0.5,0),
        Size=UDim2.fromOffset(36,18),
        BackgroundColor3=CurrentTheme.Panel,
        BorderSizePixel=0,
        Text="",
        AutoButtonColor=false,
        ZIndex=6
    },row)
    Round(pill,9)

    local knob=Create("Frame",{
        Name="FunSwitchKnob",
        Position=UDim2.fromOffset(3,3),
        Size=UDim2.fromOffset(12,12),
        BackgroundColor3=CurrentTheme.Muted,
        BorderSizePixel=0,
        ZIndex=7
    },pill)
    Round(knob,6)

    local state=false

    local entry={
        Pill=pill,
        Knob=knob,
        Get=function()
            return state
        end
    }

    function entry.Set(on)
        state=on and true or false
        Tween(pill,{
            BackgroundColor3=state and UIAccent:Lerp(Color3.new(0,0,0),0.45) or CurrentTheme.Panel
        },0.15)
        Tween(knob,{
            Position=state and UDim2.fromOffset(21,3) or UDim2.fromOffset(3,3),
            BackgroundColor3=state and UIAccent or CurrentTheme.Muted
        },0.18,Enum.EasingStyle.Back)
        onFlip(state)
    end

    pill.MouseButton1Click:Connect(function()
        if unloading then return end
        entry.Set(not state)
    end)

    table.insert(FunSwitches,entry)
    table.insert(FunToggleRows,row)
    return entry
end

-- fling toggles
CreateFunToggle(FlingSection,298,"FLING AURA","auto-fling anyone within 22 studs",function(on)
    FlingAuraOn=on
    if on then
        StartFlingAuraLoop()
        SetFunStatus("fling aura live — anyone within 22 studs gets launched.","hot")
    else
        SetFunStatus("fling aura off.","muted")
    end
end)

CreateFunToggle(FlingSection,330,"TORNADO MODE","spin forever — walk into people to fling them",function(on)
    TornadoOn=on
    ApplyTornadoSpin()
    if on then
        SetFunStatus("tornado mode — walk into people to fling them.","hot")
    else
        SetFunStatus("tornado off.","muted")
    end
end)

local FunStatusLabel=Create("TextLabel",{
    Name="FunStatusLabel",
    Position=UDim2.fromOffset(13,364),
    Size=UDim2.new(1,-26,0,12),
    BackgroundTransparency=1,
    Text=FunStatusText,
    TextColor3=CurrentTheme.Muted,
    TextSize=8,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd
},FlingSection)
table.insert(FunStatusLabels,FunStatusLabel)

------------------------------------------------------------
-- SECTION 4 CARD | TROLL ZONE
------------------------------------------------------------
local TrollSection=CreateOwnerSection(424,4)

RegisterOwnerObject(Create("TextLabel",{
    Name="FunTrollTitle",
    Position=UDim2.fromOffset(13,9),
    Size=UDim2.new(1,-26,0,19),
    BackgroundTransparency=1,
    Text="TROLL ZONE",
    TextColor3=CurrentTheme.Text,
    TextSize=11,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},TrollSection))

local funTrollSub=RegisterOwnerObject(Create("TextLabel",{
    Name="FunTrollSub",
    Position=UDim2.fromOffset(13,28),
    Size=UDim2.new(1,-26,0,16),
    BackgroundTransparency=1,
    Text="pranks the whole server can see — pick your poison.",
    TextColor3=CurrentTheme.Muted,
    TextSize=8,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd
},TrollSection))
funTrollSub:SetAttribute("MutedText",true)

OrbitToggle=CreateFunToggle(TrollSection,50,"ORBIT TARGET","circle your target like a shark",function(on)
    if not on then return end
    if not ChaosTarget or not ChaosTarget.Parent then
        SetFunStatus("pick a target in the fling deck first.","bad")
        if OrbitToggle then OrbitToggle.Set(false) end
        return
    end
    if SitToggle then SitToggle.Set(false) end
    if FollowToggle then FollowToggle.Set(false) end
    if WreckToggle then WreckToggle.Set(false) end
    if MeteorToggle then MeteorToggle.Set(false) end
    if GlitchToggle then GlitchToggle.Set(false) end
    EnsureChaosMotion()
    SetFunStatus("orbiting @"..tostring(ChaosTarget.Name).." — dizzy yet?","hot")
end)

SitToggle=CreateFunToggle(TrollSection,82,"SIT ON HEAD","permanently sit on their head",function(on)
    if not on then return end
    if not ChaosTarget or not ChaosTarget.Parent then
        SetFunStatus("pick a target in the fling deck first.","bad")
        if SitToggle then SitToggle.Set(false) end
        return
    end
    if OrbitToggle then OrbitToggle.Set(false) end
    if FollowToggle then FollowToggle.Set(false) end
    if WreckToggle then WreckToggle.Set(false) end
    if MeteorToggle then MeteorToggle.Set(false) end
    if GlitchToggle then GlitchToggle.Set(false) end
    EnsureChaosMotion()
    SetFunStatus("sitting on @"..tostring(ChaosTarget.Name).."'s head. cozy.","hot")
end)

FollowToggle=CreateFunToggle(TrollSection,114,"FOLLOW TARGET","stay glued behind them, no escape",function(on)
    if not on then return end
    if not ChaosTarget or not ChaosTarget.Parent then
        SetFunStatus("pick a target in the fling deck first.","bad")
        if FollowToggle then FollowToggle.Set(false) end
        return
    end
    if OrbitToggle then OrbitToggle.Set(false) end
    if SitToggle then SitToggle.Set(false) end
    if WreckToggle then WreckToggle.Set(false) end
    if MeteorToggle then MeteorToggle.Set(false) end
    if GlitchToggle then GlitchToggle.Set(false) end
    EnsureChaosMotion()
    SetFunStatus("hunting @"..tostring(ChaosTarget.Name).." — they cant escape.","hot")
end)

WreckToggle=CreateFunToggle(TrollSection,146,"WRECKING BALL","tight fast orbit + mega spin around them",function(on)
    if WreckSpin and WreckSpin.Parent then
        WreckSpin:Destroy()
    end
    WreckSpin=nil
    if not on then return end
    if not ChaosTarget or not ChaosTarget.Parent then
        SetFunStatus("pick a target in the fling deck first.","bad")
        if WreckToggle then WreckToggle.Set(false) end
        return
    end
    if OrbitToggle then OrbitToggle.Set(false) end
    if SitToggle then SitToggle.Set(false) end
    if FollowToggle then FollowToggle.Set(false) end
    if MeteorToggle then MeteorToggle.Set(false) end
    if GlitchToggle then GlitchToggle.Set(false) end
    local myRoot=GetChaosRoot(Player)
    if myRoot then
        local spin=Instance.new("BodyAngularVelocity")
        spin.AngularVelocity=Vector3.new(0,(ChaosPowerValues[ChaosPower] or 32000)*0.45,0)
        spin.MaxTorque=Vector3.new(9e9,9e9,9e9)
        spin.Parent=myRoot
        WreckSpin=spin
    end
    EnsureChaosMotion()
    SetFunStatus("wrecking ball armed around @"..tostring(ChaosTarget.Name)..".","hot")
end)

MeteorToggle=CreateFunToggle(TrollSection,178,"METEOR MODE","body-slam your target from the sky on repeat",function(on)
    MeteorOn=on
    if not on then return end
    if not ChaosTarget or not ChaosTarget.Parent then
        SetFunStatus("pick a target in the fling deck first.","bad")
        if MeteorToggle then MeteorToggle.Set(false) end
        return
    end
    if OrbitToggle then OrbitToggle.Set(false) end
    if SitToggle then SitToggle.Set(false) end
    if FollowToggle then FollowToggle.Set(false) end
    if WreckToggle then WreckToggle.Set(false) end
    if GlitchToggle then GlitchToggle.Set(false) end
    StartMeteorLoop()
    SetFunStatus("meteor mode — the sky is falling on @"..tostring(ChaosTarget.Name)..".","hot")
end)

GlitchToggle=CreateFunToggle(TrollSection,210,"GLITCH OUT","vibrate and teleport like a corrupted file",function(on)
    GlitchOn=on
    if not on then return end
    if OrbitToggle then OrbitToggle.Set(false) end
    if SitToggle then SitToggle.Set(false) end
    if FollowToggle then FollowToggle.Set(false) end
    if WreckToggle then WreckToggle.Set(false) end
    if MeteorToggle then MeteorToggle.Set(false) end
    StartGlitchLoop()
    SetFunStatus("glitching out — you look corrupted to everyone.","hot")
end)

ZoomiesToggle=CreateFunToggle(TrollSection,242,"ZOOMIES","sprint at 120 speed and bounce like a rocket",function(on)
    ZoomiesOn=on
    ApplyZoomies()
    if on then
        SetFunStatus("zoomies on — try not to hit a wall.","hot")
    else
        SetFunStatus("zoomies off.","muted")
    end
end)

MoonToggle=CreateFunToggle(TrollSection,274,"MOON GRAVITY","floaty moon falls for your character",function(on)
    MoonOn=on
    ApplyMoonGravity()
    if on then
        SetFunStatus("moon gravity on — one small step for bubba.","hot")
    else
        SetFunStatus("moon gravity off.","muted")
    end
end)

RaveToggle=CreateFunToggle(TrollSection,306,"EMOTE RAVE","non-stop /e dances everyone can see",function(on)
    RaveOn=on
    if on then
        StartRaveLoop()
        SetFunStatus("emote rave — dance like everyone is watching.","hot")
    else
        SetFunStatus("emote rave off.","muted")
    end
end)

SpamToggle=CreateFunToggle(TrollSection,338,"CHAT SPAM","funny lines in chat until you stop it",function(on)
    ChatSpamOn=on
    if on then
        StartChatSpamLoop()
        SetFunStatus("chat spam live — the whole server reads along.","hot")
    else
        SetFunStatus("chat spam off.","muted")
    end
end)

FunChatBox=Create("TextBox",{
    Name="FunChatBox",
    Position=UDim2.fromOffset(12,370),
    Size=UDim2.new(1,-112,0,26),
    BackgroundColor3=CurrentTheme.Background,
    BorderSizePixel=0,
    Text="",
    PlaceholderText="custom spam message (optional)",
    PlaceholderColor3=CurrentTheme.Muted,
    TextColor3=CurrentTheme.Text,
    TextSize=9,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left,
    ClearTextOnFocus=false,
    TextTruncate=Enum.TextTruncate.AtEnd
},TrollSection)
Round(FunChatBox,7)
RegisterOwnerObject(Stroke(FunChatBox,CurrentTheme.Accent,0.6,1))

CreateFunButton(TrollSection,"FunChatTestButton","TEST CHAT",12,370,88,26,function()
    local message=""
    if FunChatBox and FunChatBox.Parent then
        message=tostring(FunChatBox.Text or "")
    end
    if message=="" then
        message=ChaosChatLines[math.random(1,#ChaosChatLines)]
    end
    local sent=SendChaosChat(message)
    if sent then
        SetFunStatus("sent: \""..message.."\"","good")
    else
        SetFunStatus("chat is locked down in this game.","bad")
    end
end,"gold",true)

local TrollStatusLabel=Create("TextLabel",{
    Name="TrollStatusLabel",
    Position=UDim2.fromOffset(13,402),
    Size=UDim2.new(1,-26,0,12),
    BackgroundTransparency=1,
    Text=FunStatusText,
    TextColor3=CurrentTheme.Muted,
    TextSize=8,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd
},TrollSection)
table.insert(FunStatusLabels,TrollStatusLabel)

ApplyFunStatus()

------------------------------------------------------------
-- FUN DECK THEME SYNC
------------------------------------------------------------
local function UpdateFunTheme(theme)
    if FunTargetCard and FunTargetCard.Parent then
        FunTargetCard.BackgroundColor3=theme.Background
    end
    if FunTargetKicker and FunTargetKicker.Parent then
        FunTargetKicker.TextColor3=OwnerGold
    end
    if FunTargetClear and FunTargetClear.Parent then
        FunTargetClear.BackgroundColor3=ButtonColor()
        FunTargetClear.TextColor3=theme.Text
    end
    if FunPicker and FunPicker.Parent then
        FunPicker.BackgroundColor3=theme.Background
        FunPicker.ScrollBarImageColor3=theme.Accent
    end
    if FunChatBox and FunChatBox.Parent then
        FunChatBox.BackgroundColor3=theme.Background
        FunChatBox.TextColor3=theme.Text
        FunChatBox.PlaceholderColor3=theme.Muted
    end

    for _,row in ipairs(FunToggleRows) do
        if row and row.Parent then
            row.BackgroundColor3=theme.Background
        end
    end

    RefreshFunPickerVisuals()
    RefreshPowerVisuals()

    for _,entry in ipairs(FunButtons) do
        if entry.Button and entry.Button.Parent then
            if entry.Danger then
                entry.Button.BackgroundColor3=Color3.fromRGB(96,26,38)
                entry.Button.TextColor3=Color3.fromRGB(255,120,140)
            else
                entry.Button.BackgroundColor3=ButtonColor()
                entry.Button.TextColor3=theme.Text
            end
        end
    end

    for _,switch in ipairs(FunSwitches) do
        if switch and switch.Pill and switch.Pill.Parent then
            switch.Pill.BackgroundColor3=switch.Get() and UIAccent:Lerp(Color3.new(0,0,0),0.45) or theme.Panel
            switch.Knob.BackgroundColor3=switch.Get() and UIAccent or theme.Muted
        end
    end

    ApplyFunStatus()
end

local BaseApplyThemeFun=ApplyTheme
ApplyTheme=function(theme)
    BaseApplyThemeFun(theme)
    UpdateFunTheme(theme)
end

------------------------------------------------------------
-- CHAOS ENGINE WIRING + CLEANUP GUARDS
------------------------------------------------------------
-- keep tornado spinning after respawns
Player.CharacterAdded:Connect(function(character)
    task.wait(0.4)
    if unloading or not ScreenGui.Parent then return end
    if TornadoOn then
        ApplyTornadoSpin()
    end
    if WreckToggle and WreckToggle.Get() then
        local myRoot=GetChaosRoot(Player)
        if myRoot then
            if WreckSpin and WreckSpin.Parent then
                WreckSpin:Destroy()
            end
            local spin=Instance.new("BodyAngularVelocity")
            spin.AngularVelocity=Vector3.new(0,(ChaosPowerValues[ChaosPower] or 32000)*0.45,0)
            spin.MaxTorque=Vector3.new(9e9,9e9,9e9)
            spin.Parent=myRoot
            WreckSpin=spin
        end
    end
    if ZoomiesOn then
        SavedWalkSpeed=nil
        SavedJump=nil
        ApplyZoomies()
    end
end)

-- hand the master stop to UnloadBubba so every chaos loop dies
-- the moment the curtain call begins
ChaosEngine={
    StopAll=StopAllChaos
}

-- backup: if the gui is destroyed by any other path, chaos dies with it
ScreenGui.Destroying:Connect(function()
    pcall(function()
        StopAllChaos()
    end)
end)

-- watchdog: even if an executor never fires Destroying, the
-- unloading flag alone ends every loop
task.spawn(function()
    while ScreenGui.Parent and not unloading do
        task.wait(0.5)
    end
    pcall(function()
        StopAllChaos()
    end)
end)

end)

if not FunOk then
    warn("[BUBBA FUN DECK ERROR]:",FunErr)
end

------------------------------------------------------------
-- SECTION 5 | POWER ACTIONS
------------------------------------------------------------

local OwnerPowerSection=CreateOwnerSection(118,5)

RegisterOwnerObject(Create("TextLabel",{
    Name="OwnerPowerTitle",
    Position=UDim2.fromOffset(13,9),
    Size=UDim2.new(1,-26,0,19),
    BackgroundTransparency=1,
    Text="POWER ACTIONS",
    TextColor3=CurrentTheme.Text,
    TextSize=11,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},OwnerPowerSection))

local ownerPowerSub=RegisterOwnerObject(Create("TextLabel",{
    Name="OwnerPowerSub",
    Position=UDim2.fromOffset(13,28),
    Size=UDim2.new(1,-26,0,16),
    BackgroundTransparency=1,
    Text="Owner-only moves. Handle with pride.",
    TextColor3=CurrentTheme.Muted,
    TextSize=8,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left
},OwnerPowerSection))
ownerPowerSub:SetAttribute("MutedText",true)

local function CreateOwnerPowerButton(name,text,x,width)
    local button=RegisterOwnerObject(Create("TextButton",{
        Name=name,
        Position=UDim2.fromOffset(x,50),
        Size=UDim2.new(0,width,0,30),
        BackgroundColor3=ButtonColor(),
        BorderSizePixel=0,
        Text=text,
        TextColor3=CurrentTheme.Text,
        TextSize=10,
        Font=Enum.Font.GothamBold,
        AutoButtonColor=false
    },OwnerPowerSection))
    Round(button,7)
    RegisterOwnerObject(Stroke(button,OwnerGold,0.45,1))

    button.MouseEnter:Connect(function()
        if not unloading then
            Tween(button,{BackgroundColor3=ButtonHoverColor()},0.12)
        end
    end)
    button.MouseLeave:Connect(function()
        if not unloading then
            Tween(button,{BackgroundColor3=ButtonColor()},0.16)
        end
    end)
    return button
end

local OwnerRejoinButton=CreateOwnerPowerButton("OwnerRejoinButton","REJOIN SERVER",12,348)

local OwnerPowerStatus=RegisterOwnerObject(Create("TextLabel",{
    Name="OwnerPowerStatus",
    Position=UDim2.fromOffset(13,88),
    Size=UDim2.new(1,-26,0,14),
    BackgroundTransparency=1,
    Text="Standing by.",
    TextColor3=CurrentTheme.Muted,
    TextSize=8,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd
},OwnerPowerSection))
OwnerPowerStatus:SetAttribute("MutedText",true)

OwnerRejoinButton.MouseButton1Click:Connect(function()
    if unloading then return end
    local ok=pcall(function()
        local teleportService=game:GetService("TeleportService")
        teleportService:Teleport(game.PlaceId,Player)
    end)
    if ok then
        OwnerPowerStatus.Text="Rejoin armed — warping back in..."
        OwnerPowerStatus.TextColor3=Color3.fromRGB(95,205,125)
        OwnerPowerStatus:SetAttribute("MutedText",false)
    else
        OwnerPowerStatus.Text="Rejoin is not available in this environment."
        OwnerPowerStatus.TextColor3=CurrentTheme.Muted
    end
end)

------------------------------------------------------------
-- OWNER THEME SYNC + LIVE STRIP
------------------------------------------------------------

local function FormatOwnerUptime(seconds)
    local hours=math.floor(seconds/3600)
    local minutes=math.floor((seconds%3600)/60)
    local remaining=seconds%60
    if hours>0 then
        return string.format("%d:%02d:%02d",hours,minutes,remaining)
    end
    return string.format("%02d:%02d",minutes,remaining)
end

local OwnerUptimeSeconds=0
task.spawn(function()
    while ScreenGui.Parent do
        if not unloading and OwnerSessionStrip and OwnerSessionStrip.Parent then
            OwnerSessionStrip.Text="SESSION "..FormatOwnerUptime(OwnerUptimeSeconds)
                .."   ·   JOINS "..tostring(OwnerJoins)
                .."   ·   LEAVES "..tostring(OwnerLeaves)
        end
        OwnerUptimeSeconds+=1
        task.wait(1)
    end
end)

local function UpdateOwnerTheme(theme)
    if OwnerScroll and OwnerScroll.Parent then
        OwnerScroll.ScrollBarImageColor3=theme.Accent
    end
    if OwnerTitle then OwnerTitle.TextColor3=theme.Text end
    if OwnerSubtitle then OwnerSubtitle.TextColor3=theme.Muted end

    for _,object in ipairs(OwnerThemeObjects) do
        if object and object.Parent then
            if object:IsA("Frame") then
                if object.Name=="OwnerCard" then
                    object.BackgroundColor3=theme.PanelLight
                elseif object.Name=="OwnerBannerChip" then
                    object.BackgroundColor3=theme.Background
                elseif object.Name=="OwnerRosterRow" then
                    -- local player row keeps its highlight, guests go panel
                    object.BackgroundColor3=theme.Panel
                end
            elseif object:IsA("TextLabel") then
                if object.Name=="OwnerCountLabel" or object.Name=="OwnerBannerName"
                    or object.Name=="OwnerRosterName" or object.Name=="OwnerServerTitle"
                    or object.Name=="OwnerPowerTitle" then
                    object.TextColor3=theme.Text
                elseif object.Name=="OwnerStatusPill" then
                    object.TextColor3=OwnerGold
                else
                    object.TextColor3=object:GetAttribute("MutedText") and theme.Muted or theme.Text
                end
            elseif object:IsA("TextButton") then
                if object.Name=="OwnerRejoinButton" then
                    object.BackgroundColor3=ButtonColor()
                    object.TextColor3=theme.Text
                end
            elseif object:IsA("UIStroke") then
                object.Color=theme.Accent
            end
        end
    end
end

local BaseApplyThemeOwner=ApplyTheme
ApplyTheme=function(theme)
    BaseApplyThemeOwner(theme)
    UpdateOwnerTheme(theme)
end

end)

if not OwnerPageBuildOk then
    warn("[BUBBA OWNER TAB ERROR]:",OwnerPageBuildError)
end

-- BOOT GUARD: the teleport tab is a self-contained system. If anything
-- inside it fails on an exotic executor, the rest of the hub still boots.
local TeleportBuildOk,TeleportBuildError=pcall(function()

--========================================================
-- TELEPORT TAB | MOVEMENT + PLAYER INSPECTION + CLICK TELEPORT
-- live player list: rebuilt the moment anyone joins or leaves (no typing)
-- per player: TP, WALK, VIEW + full inspection panel
-- click teleport: toggle on, click anywhere in the world to warp there
-- quick jumps: spawn, saved spot, random player
--========================================================

local TeleportPage=Pages.TELEPORT

local TeleportThemeObjects={}
local function RegisterTeleportObject(object)
    table.insert(TeleportThemeObjects,object)
    return object
end

local TELEPORT_ARRIVE_DISTANCE=5

local TeleportRows={}
local TeleportSelected=nil
local TeleportSavedWaypoint=nil
local TeleportWalking=false
local TeleportWalkTarget=nil
local TeleportViewing=nil
local TeleportOriginalCameraType=nil
local ClickTeleportOn=false
local TeleportPendingLeaves={}

------------------------------------------------------------
-- ENGINE HELPERS (nil-safe on every executor / game state)
------------------------------------------------------------

local function GetTeleportRoot(plr)
    if not plr then return nil end
    local character=plr.Character
    if not character then return nil end
    local hrp=character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    return hrp
end

local function GetTeleportTargetHumanoid(plr)
    if not plr then return nil end
    local character=plr.Character
    if not character then return nil end
    return character:FindFirstChildOfClass("Humanoid")
end

local function GetTeleportDistance(plr)
    local myRoot=GetTeleportRoot(Player)
    local targetRoot=GetTeleportRoot(plr)
    if not myRoot or not targetRoot then return nil end
    local myPosition=myRoot.Position
    local targetPosition=targetRoot.Position
    if not myPosition or not targetPosition then return nil end
    local delta=myPosition-targetPosition
    if not delta then return nil end
    return math.floor(delta.Magnitude+0.5)
end

local function IsTeleportTargetValid(plr)
    return plr~=nil and plr.Parent~=nil and plr~=Player
end

local function FormatTeleportPosition(cf)
    if not cf then return "unknown" end
    return "("..math.floor((cf.X or 0)+0.5)..", "..math.floor((cf.Y or 0)+0.5)..", "..math.floor((cf.Z or 0)+0.5)..")"
end

------------------------------------------------------------
-- TELEPORT TOAST (bottom-right corner feedback)
------------------------------------------------------------
local TeleportToast=Create("Frame",{
    Name="TeleportToast",
    AnchorPoint=Vector2.new(1,1),
    Position=UDim2.new(1,300,1,-16),
    Size=UDim2.fromOffset(252,44),
    BackgroundColor3=CurrentTheme.PanelLight,
    BorderSizePixel=0,
    Visible=false,
    ZIndex=320
},ScreenGui)
Round(TeleportToast,9)
local TeleportToastStroke=Stroke(TeleportToast,UIAccent,0.3,1.2)

local TeleportToastBar=Create("Frame",{
    Name="AccentLine",
    Position=UDim2.fromOffset(0,10),
    Size=UDim2.new(0,3,1,-20),
    BackgroundColor3=UIAccent,
    BorderSizePixel=0,
    ZIndex=321
},TeleportToast)
Round(TeleportToastBar,5)

local TeleportToastLabel=Create("TextLabel",{
    Name="TeleportToastLabel",
    Position=UDim2.fromOffset(14,0),
    Size=UDim2.new(1,-26,1,0),
    BackgroundTransparency=1,
    Text="",
    TextColor3=CurrentTheme.Text,
    TextSize=10,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd,
    ZIndex=321
},TeleportToast)

local TeleportToastGeneration=0

local function ShowTeleportToast(message)
    if unloading or not ScreenGui.Parent then return end
    if not TeleportToast or not TeleportToast.Parent then return end

    TeleportToastGeneration+=1
    local generation=TeleportToastGeneration

    TeleportToastLabel.Text=tostring(message)
    TeleportToastLabel.TextColor3=CurrentTheme.Text
    TeleportToast.BackgroundColor3=CurrentTheme.PanelLight
    TeleportToastStroke.Color=UIAccent
    TeleportToastBar.BackgroundColor3=UIAccent

    TeleportToast.Visible=true
    TeleportToast.Position=UDim2.new(1,300,1,-16)
    Tween(TeleportToast,{Position=UDim2.new(1,-22,1,-16)},0.4,Enum.EasingStyle.Back)

    task.delay(2.6,function()
        if unloading then return end
        if TeleportToastGeneration~=generation then return end
        if not TeleportToast or not TeleportToast.Parent then return end

        local tween=Tween(TeleportToast,{Position=UDim2.new(1,300,1,-16)},0.3,Enum.EasingStyle.Quart)
        if tween then
            tween.Completed:Wait()
        end

        if TeleportToastGeneration==generation and TeleportToast and TeleportToast.Parent then
            TeleportToast.Visible=false
        end
    end)
end

------------------------------------------------------------
-- PAGE CHROME
------------------------------------------------------------
local TeleportTitle=RegisterTeleportObject(Create("TextLabel",{
    Name="TeleportTitle",
    Position=UDim2.fromOffset(20,12),
    Size=UDim2.new(1,-40,0,25),
    BackgroundTransparency=1,
    Text="Teleport",
    TextColor3=CurrentTheme.Text,
    TextSize=18,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left
},TeleportPage))

local TeleportSubtitle=RegisterTeleportObject(Create("TextLabel",{
    Name="TeleportSubtitle",
    Position=UDim2.fromOffset(21,37),
    Size=UDim2.new(1,-280,0,18),
    BackgroundTransparency=1,
    Text="Teleport to players, view anyone, walk the map, or click-warp anywhere.",
    TextColor3=CurrentTheme.Muted,
    TextSize=10,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left
},TeleportPage))
TeleportSubtitle:SetAttribute("MutedText",true)

local TeleportPlayerPill=RegisterTeleportObject(Create("TextLabel",{
    Name="TeleportPlayerPill",
    AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-20,0,16),
    Size=UDim2.fromOffset(160,16),
    BackgroundTransparency=1,
    Text="●  0 PLAYERS",
    TextColor3=UIAccent,
    TextSize=9,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Right
},TeleportPage))

local TeleportScroll=Create("ScrollingFrame",{
    Name="TeleportScroll",
    Position=UDim2.fromOffset(20,65),
    Size=UDim2.new(1,-40,1,-78),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ScrollBarThickness=3,
    ScrollBarImageColor3=UIAccent,
    ScrollingDirection=Enum.ScrollingDirection.Y,
    CanvasSize=UDim2.new(0,0,0,0),
    AutomaticCanvasSize=Enum.AutomaticSize.Y
},TeleportPage)
TeleportScroll.ScrollBarImageTransparency=0.15

Create("UIListLayout",{
    SortOrder=Enum.SortOrder.LayoutOrder,
    Padding=UDim.new(0,10)
},TeleportScroll)

local function CreateTeleportSection(height,order,sectionName)
    local section=RegisterTeleportObject(Create("Frame",{
        Name=sectionName,
        Size=UDim2.new(1,0,0,height),
        BackgroundColor3=CurrentTheme.PanelLight,
        BorderSizePixel=0,
        LayoutOrder=order
    },TeleportScroll))
    Round(section,8)
    RegisterTeleportObject(Stroke(section,CurrentTheme.Accent,0.72,1))
    return section
end

local function CreateTeleportSectionTitle(section,text,description)
    RegisterTeleportObject(Create("TextLabel",{
        Name="TeleportSectionTitle",
        Position=UDim2.fromOffset(13,9),
        Size=UDim2.new(1,-26,0,19),
        BackgroundTransparency=1,
        Text=text,
        TextColor3=CurrentTheme.Text,
        TextSize=11,
        Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left
    },section))

    local sub=RegisterTeleportObject(Create("TextLabel",{
        Name="TeleportSectionSub",
        Position=UDim2.fromOffset(13,28),
        Size=UDim2.new(1,-26,0,16),
        BackgroundTransparency=1,
        Text=description,
        TextColor3=CurrentTheme.Muted,
        TextSize=8,
        Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left
    },section))
    sub:SetAttribute("MutedText",true)
end

local function CreateTeleportButton(parent,position,width,height,label,isAccent,buttonName)
    -- width may be a pixel number or a full UDim2 (responsive scale size)
    -- so panels can stretch on small and large windows alike
    local size
    if typeof(width)=="UDim2" then
        size=width
    else
        size=UDim2.fromOffset(width,height)
    end
    local button=RegisterTeleportObject(Create("TextButton",{
        Name=buttonName or "TeleportActionButton",
        Position=position,
        Size=size,
        BackgroundColor3=isAccent and UIAccent:Lerp(Color3.new(0,0,0),0.45) or ButtonColor(),
        BorderSizePixel=0,
        Text=label,
        TextColor3=CurrentTheme.Text,
        TextSize=9,
        Font=Enum.Font.GothamBold,
        AutoButtonColor=false
    },parent))
    Round(button,6)
    RegisterTeleportObject(Stroke(button,CurrentTheme.Accent,0.7,1))
    if isAccent then
        button:SetAttribute("TeleportAccentButton",true)
    end
    button.MouseEnter:Connect(function()
        if not unloading then
            Tween(button,{BackgroundColor3=ButtonHoverColor()},0.15)
        end
    end)
    button.MouseLeave:Connect(function()
        if not unloading then
            Tween(button,{BackgroundColor3=button:GetAttribute("TeleportAccentButton") and UIAccent:Lerp(Color3.new(0,0,0),0.45) or ButtonColor()},0.15)
        end
    end)
    return button
end

local function SetTeleportButtonAccent(button,on)
    if not button then return end
    if on then
        button:SetAttribute("TeleportAccentButton",true)
        button.BackgroundColor3=UIAccent:Lerp(Color3.new(0,0,0),0.45)
    else
        button:SetAttribute("TeleportAccentButton",false)
        button.BackgroundColor3=ButtonColor()
    end
end

------------------------------------------------------------
-- SECTION 1 | PLAYER TELEPORT (live list — no typing, ever)
------------------------------------------------------------
local TeleportPlayersSection=CreateTeleportSection(252,1,"TeleportPlayersSection")
CreateTeleportSectionTitle(TeleportPlayersSection,"PLAYER TELEPORT","Everyone in the server — live. Updated the moment players join or leave.")

local TeleportLivePill=RegisterTeleportObject(Create("TextLabel",{
    Name="TeleportLivePill",
    AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-12,0,51),
    Size=UDim2.fromOffset(170,14),
    BackgroundTransparency=1,
    Text="● LIVE — 0 OTHERS",
    TextColor3=UIAccent,
    TextSize=8,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Right
},TeleportPlayersSection))

local TeleportPlayerList=Create("ScrollingFrame",{
    Name="TeleportPlayerList",
    Position=UDim2.fromOffset(12,72),
    Size=UDim2.new(1,-24,1,-80),
    BackgroundTransparency=1,
    BorderSizePixel=0,
    ScrollBarThickness=3,
    ScrollBarImageColor3=UIAccent,
    ScrollingDirection=Enum.ScrollingDirection.Y,
    CanvasSize=UDim2.new(0,0,0,0),
    AutomaticCanvasSize=Enum.AutomaticSize.Y
},TeleportPlayersSection)
TeleportPlayerList.ScrollBarImageTransparency=0.15

Create("UIListLayout",{
    SortOrder=Enum.SortOrder.LayoutOrder,
    Padding=UDim.new(0,5)
},TeleportPlayerList)

local TeleportEmptyLabel=RegisterTeleportObject(Create("TextLabel",{
    Name="TeleportEmptyLabel",
    Size=UDim2.new(1,0,0,60),
    BackgroundTransparency=1,
    Text="You are the only player in this server.",
    TextColor3=CurrentTheme.Muted,
    TextSize=9,
    Font=Enum.Font.Gotham,
    TextWrapped=true
},TeleportPlayerList))
TeleportEmptyLabel:SetAttribute("MutedText",true)
TeleportEmptyLabel.Visible=false

------------------------------------------------------------
-- SECTION 2 | VIEW PLAYER (inspect + camera panel)
------------------------------------------------------------
local TeleportViewSection=CreateTeleportSection(178,2,"TeleportViewSection")
CreateTeleportSectionTitle(TeleportViewSection,"VIEW PLAYER","Inspect a player, point your camera at them, or jump straight to them.")

local TeleportViewEmpty=RegisterTeleportObject(Create("TextLabel",{
    Name="TeleportViewEmpty",
    Position=UDim2.fromOffset(13,52),
    Size=UDim2.new(1,-26,0,110),
    BackgroundTransparency=1,
    Text="No player selected.\n\nPress VIEW on a player row to inspect them — their name, distance, and camera controls appear here.",
    TextColor3=CurrentTheme.Muted,
    TextSize=9,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,
    TextWrapped=true
},TeleportViewSection))
TeleportViewEmpty:SetAttribute("MutedText",true)

local TeleportViewSelected=RegisterTeleportObject(Create("Frame",{
    Name="TeleportViewSelected",
    Position=UDim2.fromOffset(12,46),
    Size=UDim2.new(1,-24,1,-56),
    BackgroundTransparency=1,
    Visible=false
},TeleportViewSection))

local TeleportViewMonogram=RegisterTeleportObject(Create("TextLabel",{
    Name="TeleportViewMonogram",
    Position=UDim2.fromOffset(2,2),
    Size=UDim2.fromOffset(44,44),
    BackgroundColor3=CurrentTheme.Background,
    BorderSizePixel=0,
    Text="?",
    TextColor3=CurrentTheme.Accent,
    TextSize=20,
    Font=Enum.Font.GothamBold
},TeleportViewSelected))
Round(TeleportViewMonogram,100)
RegisterTeleportObject(Stroke(TeleportViewMonogram,CurrentTheme.Accent,0.4,1))

local TeleportViewName=RegisterTeleportObject(Create("TextLabel",{
    Name="TeleportViewName",
    Position=UDim2.fromOffset(56,4),
    Size=UDim2.new(1,-300,0,16),
    BackgroundTransparency=1,
    Text="—",
    TextColor3=CurrentTheme.Text,
    TextSize=13,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd
},TeleportViewSelected))

local TeleportViewSub=RegisterTeleportObject(Create("TextLabel",{
    Name="TeleportViewSub",
    Position=UDim2.fromOffset(56,24),
    Size=UDim2.new(1,-300,0,13),
    BackgroundTransparency=1,
    Text="@—",
    TextColor3=CurrentTheme.Muted,
    TextSize=8,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd
},TeleportViewSelected))
TeleportViewSub:SetAttribute("MutedText",true)

local TeleportViewStatus=RegisterTeleportObject(Create("TextLabel",{
    Name="TeleportViewStatus",
    AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-4,0,6),
    Size=UDim2.fromOffset(240,16),
    BackgroundTransparency=1,
    Text="",
    TextColor3=UIAccent,
    TextSize=9,
    Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Right
},TeleportViewSelected))

local TeleportViewViewButton=CreateTeleportButton(TeleportViewSelected,UDim2.new(0,2,0,50),UDim2.new(0.6575,0,0,26),26,"VIEW",false,"TeleportViewViewButton")
local TeleportViewResetButton=CreateTeleportButton(TeleportViewSelected,UDim2.new(0.685,2,0,50),UDim2.new(0.313,-6,0,26),26,"RESET CAMERA",false,"TeleportViewResetButton")
local TeleportViewTeleportButton=CreateTeleportButton(TeleportViewSelected,UDim2.new(0,2,0,82),UDim2.new(0.315,0,0,26),26,"TELEPORT",true,"TeleportViewTeleportButton")
local TeleportViewWalkButton=CreateTeleportButton(TeleportViewSelected,UDim2.new(0.3425,2,0,82),UDim2.new(0.315,0,0,26),26,"WALK",false,"TeleportViewWalkButton")

local TeleportViewHint=RegisterTeleportObject(Create("TextLabel",{
    Name="TeleportViewHint",
    Position=UDim2.new(0.685,6,0,78),
    Size=UDim2.new(0.313,-10,0,44),
    BackgroundTransparency=1,
    Text="VIEW points your camera at them. RESET CAMERA puts it straight back on you.",
    TextColor3=CurrentTheme.Muted,
    TextSize=8,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,
    TextWrapped=true
},TeleportViewSelected))
TeleportViewHint:SetAttribute("MutedText",true)

------------------------------------------------------------
-- SECTION 3 | QUICK TELEPORT (spawn / waypoint / random)
------------------------------------------------------------
local TeleportQuickSection=CreateTeleportSection(138,4,"TeleportQuickSection")
CreateTeleportSectionTitle(TeleportQuickSection,"QUICK TELEPORT","Spawn, saved spots, and surprise jumps.")

local TeleportSpawnButton=CreateTeleportButton(TeleportQuickSection,UDim2.fromOffset(12,50),330,26,"TELEPORT TO SPAWN",false,"TeleportSpawnButton")
local TeleportSaveButton=CreateTeleportButton(TeleportQuickSection,UDim2.fromOffset(350,50),330,26,"SAVE THIS SPOT",false,"TeleportSaveButton")
local TeleportReturnButton=CreateTeleportButton(TeleportQuickSection,UDim2.fromOffset(12,82),330,26,"RETURN TO SAVED SPOT",false,"TeleportReturnButton")
local TeleportRandomButton=CreateTeleportButton(TeleportQuickSection,UDim2.fromOffset(350,82),330,26,"RANDOM PLAYER",false,"TeleportRandomButton")

local TeleportStatusLine=RegisterTeleportObject(Create("TextLabel",{
    Name="TeleportStatusLine",
    Position=UDim2.fromOffset(13,114),
    Size=UDim2.new(1,-26,0,17),
    BackgroundTransparency=1,
    Text="No saved spot yet — press SAVE THIS SPOT anywhere worth returning to.",
    TextColor3=CurrentTheme.Muted,
    TextSize=8,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd
},TeleportQuickSection))
TeleportStatusLine:SetAttribute("MutedText",true)

------------------------------------------------------------
-- SECTION 3 | CLICK TELEPORT (click anywhere in the world)
------------------------------------------------------------
local TeleportClickSection=CreateTeleportSection(106,3,"TeleportClickSection")
CreateTeleportSectionTitle(TeleportClickSection,"CLICK TELEPORT","Toggle it on — then click any spot in the world to warp straight there.")

local TeleportClickRow=RegisterTeleportObject(Create("Frame",{
    Name="TeleportClickRow",
    Position=UDim2.fromOffset(12,48),
    Size=UDim2.new(1,-24,0,39),
    BackgroundColor3=CurrentTheme.Background,
    BorderSizePixel=0
},TeleportClickSection))
Round(TeleportClickRow,6)

RegisterTeleportObject(Create("TextLabel",{
    Name="TeleportClickRowLabel",
    Position=UDim2.fromOffset(10,0),
    Size=UDim2.new(1,-100,1,0),
    BackgroundTransparency=1,
    Text="CLICK ANYWHERE TO WARP",
    TextColor3=CurrentTheme.Text,
    TextSize=9,
    Font=Enum.Font.GothamSemibold,
    TextXAlignment=Enum.TextXAlignment.Left
},TeleportClickRow))

local TeleportClickToggle=RegisterTeleportObject(Create("TextButton",{
    Name="TeleportClickToggle",
    AnchorPoint=Vector2.new(1,0.5),
    Position=UDim2.new(1,-7,0.5,0),
    Size=UDim2.fromOffset(75,27),
    BackgroundColor3=ButtonColor(),
    BorderSizePixel=0,
    Text="DISABLED",
    TextColor3=CurrentTheme.Text,
    TextSize=8,
    Font=Enum.Font.GothamBold,
    AutoButtonColor=false
},TeleportClickRow))
Round(TeleportClickToggle,5)
RegisterTeleportObject(Stroke(TeleportClickToggle,CurrentTheme.Accent,0.7,1))

local TeleportClickStatus=RegisterTeleportObject(Create("TextLabel",{
    Name="TeleportClickStatus",
    Position=UDim2.fromOffset(13,90),
    Size=UDim2.new(1,-26,0,14),
    BackgroundTransparency=1,
    Text="OFF — click warping is disabled. Toggle it on to use it.",
    TextColor3=CurrentTheme.Muted,
    TextSize=8,
    Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd
},TeleportClickSection))
TeleportClickStatus:SetAttribute("MutedText",true)

------------------------------------------------------------
-- UI STATE UPDATES
------------------------------------------------------------

local function UpdateTeleportStatusLine()
    if not TeleportStatusLine or not TeleportStatusLine.Parent then return end
    if TeleportWalking and TeleportWalkTarget then
        local targetName=TeleportWalkTarget.DisplayName or TeleportWalkTarget.Name or "player"
        local distance=GetTeleportDistance(TeleportWalkTarget)
        TeleportStatusLine.Text="● WALKING TO "..string.upper(tostring(targetName)).."  "..(distance~=nil and (tostring(distance).."m away — ") or "").."press WALK again to stop"
        TeleportStatusLine.TextColor3=UIAccent
    elseif TeleportSavedWaypoint then
        TeleportStatusLine.Text="SAVED SPOT: "..FormatTeleportPosition(TeleportSavedWaypoint)
        TeleportStatusLine.TextColor3=CurrentTheme.Muted
    else
        TeleportStatusLine.Text="No saved spot yet — press SAVE THIS SPOT anywhere worth returning to."
        TeleportStatusLine.TextColor3=CurrentTheme.Muted
    end
end

local function UpdateTeleportViewPanel()
    local plr=TeleportSelected
    if not (plr and plr.Parent and plr~=Player) then
        TeleportSelected=nil
        if TeleportViewEmpty and TeleportViewEmpty.Parent then TeleportViewEmpty.Visible=true end
        if TeleportViewSelected and TeleportViewSelected.Parent then TeleportViewSelected.Visible=false end
        return
    end

    if TeleportViewEmpty.Parent then TeleportViewEmpty.Visible=false end
    if TeleportViewSelected.Parent then TeleportViewSelected.Visible=true end

    local displayName=plr.DisplayName or plr.Name or "?"
    local userName=plr.Name or "?"
    local distance=GetTeleportDistance(plr)
    local humanoid=GetTeleportTargetHumanoid(plr)
    local health=humanoid and humanoid.Health or 0

    TeleportViewMonogram.Text=string.upper(string.sub(tostring(displayName),1,1))
    TeleportViewName.Text=tostring(displayName)
    TeleportViewSub.Text="@"..tostring(userName).."  •  "..(distance~=nil and (tostring(distance).."m away") or "distance unknown").."  •  "..((humanoid and health>0) and "ALIVE" or "NO CHARACTER")

    TeleportViewStatus.Text=(TeleportViewing==plr) and "● VIEWING" or ""
end

------------------------------------------------------------
-- VIEW ENGINE (camera subject swap)
------------------------------------------------------------

local function CaptureTeleportCameraState()
    local camera=workspace.CurrentCamera
    if not camera then return end
    if TeleportOriginalCameraType==nil then
        local ok,currentType=pcall(function()
            return camera.CameraType
        end)
        if ok then
            TeleportOriginalCameraType=currentType
        end
    end
end

local function RestoreTeleportCamera()
    local camera=workspace.CurrentCamera
    if not camera then return end
    local humanoid=GetHumanoid()
    pcall(function()
        if TeleportOriginalCameraType then
            camera.CameraType=TeleportOriginalCameraType
        else
            camera.CameraType=Enum.CameraType.Custom
        end
        if humanoid then
            camera.CameraSubject=humanoid
        end
    end)
    TeleportOriginalCameraType=nil
end

local function StopViewingPlayer(announce)
    local wasWatching=TeleportViewing~=nil
    TeleportViewing=nil
    if wasWatching then
        RestoreTeleportCamera()
    end
    UpdateTeleportViewPanel()
    if announce then
        ShowTeleportToast("Stopped viewing — camera is back on you")
    end
end

local function ViewPlayerNow(plr)
    if unloading then return end
    if not IsTeleportTargetValid(plr) then
        ShowTeleportToast("That player just left")
        return
    end
    local camera=workspace.CurrentCamera
    local humanoid=GetTeleportTargetHumanoid(plr)
    if not camera then
        ShowTeleportToast("Camera is unavailable right now")
        return
    end
    if not humanoid then
        ShowTeleportToast((plr.DisplayName or plr.Name).." has no character to view yet")
        return
    end

    CaptureTeleportCameraState()
    TeleportViewing=plr
    pcall(function()
        camera.CameraSubject=humanoid
    end)
    ShowTeleportToast("Viewing "..(plr.DisplayName or plr.Name))
    UpdateTeleportViewPanel()
end

local function ResetTeleportCamera()
    if TeleportViewing then
        StopViewingPlayer(true)
    else
        ShowTeleportToast("Camera is already back on you")
    end
end

------------------------------------------------------------
-- MOVEMENT ENGINE (teleport + walking)
------------------------------------------------------------

local function TeleportToPlayer(plr)
    if unloading then return false end
    if not IsTeleportTargetValid(plr) then
        ShowTeleportToast("That player just left")
        return false
    end
    local myRoot=GetTeleportRoot(Player)
    local targetRoot=GetTeleportRoot(plr)
    if not myRoot then
        ShowTeleportToast("Your character is not spawned yet")
        return false
    end
    if not targetRoot then
        ShowTeleportToast((plr.DisplayName or plr.Name).." has no character yet")
        return false
    end

    -- land a few studs behind the target so you never spawn inside them
    local ok=pcall(function()
        myRoot.CFrame=targetRoot.CFrame*CFrame.new(0,0,3)
    end)

    if ok then
        ShowTeleportToast("Teleported to "..(plr.DisplayName or plr.Name))
    else
        ShowTeleportToast("Teleport was blocked by the game")
    end
    return ok
end

local function StopTeleportWalk()
    TeleportWalking=false
    TeleportWalkTarget=nil
    UpdateTeleportStatusLine()
end

local function WalkToPlayer(plr)
    if unloading then return end

    -- same target: WALK acts as a stop button
    if TeleportWalking and TeleportWalkTarget==plr then
        StopTeleportWalk()
        ShowTeleportToast("Stopped walking")
        return
    end

    if not IsTeleportTargetValid(plr) then
        ShowTeleportToast("That player just left")
        return
    end
    if not GetTeleportRoot(Player) then
        ShowTeleportToast("Your character is not spawned yet")
        return
    end
    if not GetTeleportRoot(plr) then
        ShowTeleportToast((plr.DisplayName or plr.Name).." has no character yet")
        return
    end

    -- switching targets: silently retire the old walk first
    StopTeleportWalk()
    TeleportWalking=true
    TeleportWalkTarget=plr
    ShowTeleportToast("Walking to "..(plr.DisplayName or plr.Name).."...")
    UpdateTeleportStatusLine()

    task.spawn(function()
        local missingStreak=0
        while TeleportWalking and not unloading and ScreenGui.Parent do
            local target=TeleportWalkTarget

            if not target or not target.Parent then
                TeleportWalking=false
                TeleportWalkTarget=nil
                if not unloading then
                    ShowTeleportToast("Walk cancelled — the player left")
                    UpdateTeleportStatusLine()
                end
                break
            end

            local myRoot=GetTeleportRoot(Player)
            local targetRoot=GetTeleportRoot(target)

            if not myRoot or not targetRoot then
                -- waiting on a (re)spawn: give it ~10 seconds before giving up
                missingStreak+=1
                if missingStreak>=40 then
                    TeleportWalking=false
                    TeleportWalkTarget=nil
                    ShowTeleportToast("Walk cancelled — no path to the player")
                    UpdateTeleportStatusLine()
                    break
                end
                task.wait(0.25)
            else
                missingStreak=0
                local myPosition=myRoot.Position
                local targetPosition=targetRoot.Position
                local delta=targetPosition-myPosition
                local distance=delta and delta.Magnitude or 0

                if distance<=TELEPORT_ARRIVE_DISTANCE then
                    TeleportWalking=false
                    TeleportWalkTarget=nil
                    ShowTeleportToast("Arrived at "..(target.DisplayName or target.Name))
                    UpdateTeleportStatusLine()
                    break
                end

                local humanoid=GetHumanoid()
                if humanoid then
                    pcall(function()
                        humanoid:MoveTo(targetPosition)
                    end)
                end
                task.wait(0.1)
            end
        end
    end)
end

------------------------------------------------------------
-- QUICK TELEPORT ACTIONS
------------------------------------------------------------

local function TeleportToSpawn()
    if unloading then return end
    local myRoot=GetTeleportRoot(Player)
    if not myRoot then
        ShowTeleportToast("Your character is not spawned yet")
        return
    end

    local spawnLocation=nil
    pcall(function()
        spawnLocation=workspace:FindFirstChildOfClass("SpawnLocation")
    end)

    if not spawnLocation or not spawnLocation.Position then
        ShowTeleportToast("This map has no spawn location")
        return
    end

    local ok=pcall(function()
        myRoot.CFrame=spawnLocation.CFrame*CFrame.new(0,4,0)
    end)

    if ok then
        ShowTeleportToast("Teleported to spawn")
    else
        ShowTeleportToast("Spawn teleport was blocked by the game")
    end
end

local function SaveTeleportWaypoint()
    if unloading then return end
    local myRoot=GetTeleportRoot(Player)
    if not myRoot then
        ShowTeleportToast("Your character is not spawned yet")
        return
    end
    TeleportSavedWaypoint=myRoot.CFrame
    ShowTeleportToast("Spot saved: "..FormatTeleportPosition(TeleportSavedWaypoint))
    UpdateTeleportStatusLine()
end

local function ReturnToTeleportWaypoint()
    if unloading then return end
    if not TeleportSavedWaypoint then
        ShowTeleportToast("No saved spot yet")
        return
    end
    local myRoot=GetTeleportRoot(Player)
    if not myRoot then
        ShowTeleportToast("Your character is not spawned yet")
        return
    end
    local ok=pcall(function()
        myRoot.CFrame=TeleportSavedWaypoint
    end)
    if ok then
        ShowTeleportToast("Returned to your saved spot")
    else
        ShowTeleportToast("Return was blocked by the game")
    end
end

local function TeleportToRandomPlayer()
    if unloading then return end
    local candidates={}
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=Player and plr.Parent and GetTeleportRoot(plr) then
            table.insert(candidates,plr)
        end
    end
    if #candidates==0 then
        ShowTeleportToast("No players with characters to jump to")
        return
    end
    local pick=candidates[math.random(1,#candidates)]
    TeleportToPlayer(pick)
end

-- keeps the selected player's row lit across every list rebuild
local function RefreshTeleportRowSelection()
    for _,entry in ipairs(TeleportRows) do
        if entry.SetSelected then
            entry.SetSelected(entry.Player==TeleportSelected and true or false)
        end
    end
end

local function TeleportSelectPlayer(plr)
    if not IsTeleportTargetValid(plr) then return end
    TeleportSelected=plr
    UpdateTeleportViewPanel()
    RefreshTeleportRowSelection()
end

------------------------------------------------------------
-- PLAYER LIST (rows rebuilt on every refresh)
------------------------------------------------------------

local function CreateTeleportRow(plr,index)
    local row=RegisterTeleportObject(Create("Frame",{
        Name="TeleportPlayerRow",
        Size=UDim2.new(1,-6,0,36),
        BackgroundColor3=CurrentTheme.Panel,
        BorderSizePixel=0,
        LayoutOrder=index
    },TeleportPlayerList))
    Round(row,7)
    local rowStroke=RegisterTeleportObject(Stroke(row,CurrentTheme.Accent,0.8,1))

    local monogram=RegisterTeleportObject(Create("TextLabel",{
        Name="TeleportRowMonogram",
        Position=UDim2.fromOffset(6,5),
        Size=UDim2.fromOffset(26,26),
        BackgroundColor3=CurrentTheme.Background,
        BorderSizePixel=0,
        Text=string.upper(string.sub(tostring(plr.DisplayName or plr.Name or "?"),1,1)),
        TextColor3=CurrentTheme.Accent,
        TextSize=12,
        Font=Enum.Font.GothamBold
    },row))
    Round(monogram,100)

    local nameLabel=RegisterTeleportObject(Create("TextLabel",{
        Name="TeleportRowName",
        Position=UDim2.fromOffset(40,4),
        Size=UDim2.new(1,-280,0,14),
        BackgroundTransparency=1,
        Text=tostring(plr.DisplayName or plr.Name or "?"),
        TextColor3=CurrentTheme.Text,
        TextSize=10,
        Font=Enum.Font.GothamSemibold,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd
    },row))

    local subLabel=RegisterTeleportObject(Create("TextLabel",{
        Name="TeleportRowSub",
        Position=UDim2.fromOffset(40,20),
        Size=UDim2.new(1,-280,0,12),
        BackgroundTransparency=1,
        Text="@...",
        TextColor3=CurrentTheme.Muted,
        TextSize=8,
        Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd
    },row))
    subLabel:SetAttribute("MutedText",true)

    -- clicking a player's row selects them (VIEW PLAYER panel opens)
    local selectButton=RegisterTeleportObject(Create("TextButton",{
        Name="TeleportRowSelect",
        Position=UDim2.fromOffset(40,2),
        Size=UDim2.new(1,-280,0,32),
        BackgroundTransparency=1,
        Text="",
        AutoButtonColor=false
    },row))
    selectButton.Activated:Connect(function()
        TeleportSelectPlayer(plr)
    end)

    -- action buttons are anchored to the right edge so they can never be
    -- pushed off the row (the old VIEW button sat past the edge and got
    -- clipped — that is fixed here)
    local tpButton=CreateTeleportButton(row,UDim2.new(1,-108,0,5),44,26,"TP",true,"TeleportRowTP")
    local walkButton=CreateTeleportButton(row,UDim2.new(1,-58,0,5),44,26,"WALK",false,"TeleportRowWalk")
    local viewButton=CreateTeleportButton(row,UDim2.new(1,-8,0,5),44,26,"VIEW",false,"TeleportRowView")
    tpButton.AnchorPoint=Vector2.new(1,0)
    walkButton.AnchorPoint=Vector2.new(1,0)
    viewButton.AnchorPoint=Vector2.new(1,0)

    tpButton.Activated:Connect(function()
        TeleportSelectPlayer(plr)
        TeleportToPlayer(plr)
    end)
    walkButton.Activated:Connect(function()
        WalkToPlayer(plr)
    end)
    viewButton.Activated:Connect(function()
        TeleportSelectPlayer(plr)
        ViewPlayerNow(plr)
    end)

    row.MouseEnter:Connect(function()
        if not unloading then
            Tween(row,{BackgroundColor3=CurrentTheme.PanelLight},0.15)
        end
    end)
    row.MouseLeave:Connect(function()
        if not unloading then
            if TeleportSelected==plr then
                Tween(row,{BackgroundColor3=CurrentTheme.PanelLight},0.15)
            else
                Tween(row,{BackgroundColor3=CurrentTheme.Panel},0.15)
            end
        end
    end)

    local distance=GetTeleportDistance(plr)
    subLabel.Text="@"..tostring(plr.Name or "?").."  •  "..(distance~=nil and (tostring(distance).."m") or "no character")

    local entry={Frame=row,Sub=subLabel,Monogram=monogram,NameLabel=nameLabel,Stroke=rowStroke,Player=plr}

    -- selection highlight: the selected row lights up across rebuilds
    function entry.SetSelected(selected)
        if not (row and row.Parent) then return end
        if selected then
            row.BackgroundColor3=CurrentTheme.PanelLight
            rowStroke.Transparency=0.25
            monogram.BackgroundColor3=UIAccent:Lerp(Color3.new(0,0,0),0.25)
            monogram.TextColor3=CurrentTheme.Text
            nameLabel.TextColor3=UIAccent
        else
            row.BackgroundColor3=CurrentTheme.Panel
            rowStroke.Transparency=0.8
            monogram.BackgroundColor3=CurrentTheme.Background
            monogram.TextColor3=CurrentTheme.Accent
            nameLabel.TextColor3=CurrentTheme.Text
        end
    end

    table.insert(TeleportRows,entry)
    return entry
end

local function UpdateTeleportDistances()
    for _,entry in ipairs(TeleportRows) do
        local plr=entry.Player
        if entry.Sub and entry.Sub.Parent and plr and plr.Parent then
            local distance=GetTeleportDistance(plr)
            if distance~=nil then
                entry.Sub.Text="@"..tostring(plr.Name or "?").."  •  "..tostring(distance).."m"
            else
                entry.Sub.Text="@"..tostring(plr.Name or "?").."  •  no character"
            end
        end
    end
    if TeleportSelected and IsTeleportTargetValid(TeleportSelected) then
        UpdateTeleportViewPanel()
    end
end

local function RefreshTeleportPlayers()
    if unloading or not TeleportPage.Parent then return end

    -- retire the old rows (the layout itself survives)
    for _,entry in ipairs(TeleportRows) do
        if entry.Frame and entry.Frame.Parent then
            entry.Frame:Destroy()
        end
    end
    for i=#TeleportRows,1,-1 do
        TeleportRows[i]=nil
    end

    -- purge destroyed objects out of the theme registry so it never
    -- grows stale between refreshes
    local aliveObjects={}
    for _,object in ipairs(TeleportThemeObjects) do
        if object and object.Parent then
            table.insert(aliveObjects,object)
        end
    end
    TeleportThemeObjects=aliveObjects

    -- live feed: everyone in the server right now, no typing required.
    -- players mid-removal are dropped immediately so leaving players
    -- never linger in the list (that is what bugged the old system)
    local candidates={}
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=Player and plr.Parent and not TeleportPendingLeaves[plr] then
            table.insert(candidates,plr)
        end
    end

    table.sort(candidates,function(a,b)
        local distanceA=GetTeleportDistance(a) or math.huge
        local distanceB=GetTeleportDistance(b) or math.huge
        if distanceA~=distanceB then
            return distanceA<distanceB
        end
        return string.lower(tostring(a.DisplayName or a.Name or ""))<string.lower(tostring(b.DisplayName or b.Name or ""))
    end)

    for index,plr in ipairs(candidates) do
        CreateTeleportRow(plr,index)
    end

    if TeleportEmptyLabel and TeleportEmptyLabel.Parent then
        if #candidates==0 then
            TeleportEmptyLabel.Text="You are the only player in this server."
            TeleportEmptyLabel.Visible=true
        else
            TeleportEmptyLabel.Visible=false
        end
    end

    local total=#Players:GetPlayers()
    if TeleportPlayerPill and TeleportPlayerPill.Parent then
        TeleportPlayerPill.Text="●  "..total..(total==1 and " PLAYER" or " PLAYERS")
    end
    if TeleportLivePill and TeleportLivePill.Parent then
        TeleportLivePill.Text="● LIVE — "..#candidates..(#candidates==1 and " OTHER" or " OTHERS")
    end

    -- release pending-leave markers once the player object is truly gone
    for pending in pairs(TeleportPendingLeaves) do
        if not pending or not pending.Parent then
            TeleportPendingLeaves[pending]=nil
        end
    end

    if TeleportSelected and not IsTeleportTargetValid(TeleportSelected) then
        TeleportSelected=nil
    end
    UpdateTeleportViewPanel()
    UpdateTeleportDistances()
    RefreshTeleportRowSelection()
end

------------------------------------------------------------
-- WIRING (buttons, events, live loops)
------------------------------------------------------------

-- live feed: one queued rebuild per frame, so join/leave bursts never
-- double-build the list and it always matches the server exactly
local TeleportRefreshQueued=false
local function QueueTeleportRefresh(feedKind,feedName)
    if unloading then return end

    -- join / leave announcements only while the teleport tab is on screen
    if TeleportPage.Visible then
        local who=tostring(feedName or "A player")
        if feedKind=="join" then
            ShowTeleportToast(who.." joined — player list updated")
        elseif feedKind=="leave" then
            ShowTeleportToast(who.." left — player list updated")
        end
    end

    if TeleportRefreshQueued then return end
    TeleportRefreshQueued=true
    task.defer(function()
        TeleportRefreshQueued=false
        RefreshTeleportPlayers()
    end)
end

TeleportViewViewButton.Activated:Connect(function()
    if IsTeleportTargetValid(TeleportSelected) then
        ViewPlayerNow(TeleportSelected)
    end
end)

TeleportViewResetButton.Activated:Connect(function()
    ResetTeleportCamera()
end)

TeleportViewTeleportButton.Activated:Connect(function()
    if IsTeleportTargetValid(TeleportSelected) then
        TeleportToPlayer(TeleportSelected)
    end
end)

TeleportViewWalkButton.Activated:Connect(function()
    if IsTeleportTargetValid(TeleportSelected) then
        WalkToPlayer(TeleportSelected)
    end
end)

TeleportSpawnButton.Activated:Connect(function()
    TeleportToSpawn()
end)

TeleportSaveButton.Activated:Connect(function()
    SaveTeleportWaypoint()
end)

TeleportReturnButton.Activated:Connect(function()
    ReturnToTeleportWaypoint()
end)

TeleportRandomButton.Activated:Connect(function()
    TeleportToRandomPlayer()
end)

------------------------------------------------------------
-- CLICK TELEPORT ENGINE (toggle + raycast warp)
------------------------------------------------------------

local function SpawnClickTeleportMarker(position)
    -- a quick accent ring that fades where you clicked (local only)
    pcall(function()
        local marker=Instance.new("Part")
        marker.Name="BubbaClickTPMarker"
        marker.Anchored=true
        marker.CanCollide=false
        marker.CanQuery=false
        marker.CanTouch=false
        marker.CastShadow=false
        marker.Material=Enum.Material.Neon
        marker.Shape=Enum.PartType.Cylinder
        marker.Size=Vector3.new(0.3,10,10)
        marker.CFrame=CFrame.new(position+Vector3.new(0,0.2,0))*CFrame.Angles(0,0,math.rad(90))
        marker.Color=CurrentTheme.Accent
        marker.Transparency=0.2
        marker.Parent=workspace

        Tween(marker,{Transparency=1,Size=Vector3.new(0.3,2.5,2.5)},0.45)
        task.delay(0.5,function()
            if marker and marker.Parent then
                marker:Destroy()
            end
        end)
    end)
end

local function UpdateClickTeleportStatus()
    if TeleportClickStatus and TeleportClickStatus.Parent then
        if ClickTeleportOn then
            TeleportClickStatus.Text="ON — click the map to teleport there. Clicks on this menu are ignored."
            TeleportClickStatus.TextColor3=UIAccent
        else
            TeleportClickStatus.Text="OFF — click warping is disabled. Toggle it on to use it."
            TeleportClickStatus.TextColor3=CurrentTheme.Muted
        end
    end
end

local function SetClickTeleport(enabled,announce)
    ClickTeleportOn=enabled and true or false
    SetTeleportButtonAccent(TeleportClickToggle,ClickTeleportOn)
    TeleportClickToggle.Text=ClickTeleportOn and "ENABLED" or "DISABLED"
    UpdateClickTeleportStatus()
    if announce then
        if ClickTeleportOn then
            ShowTeleportToast("Click teleport ON — click anywhere to warp")
        else
            ShowTeleportToast("Click teleport OFF")
        end
    end
end

TeleportClickToggle.MouseButton1Click:Connect(function()
    if unloading then return end
    SetClickTeleport(not ClickTeleportOn,true)
end)

UIS.InputBegan:Connect(function(input,gameProcessed)
    if unloading or not ClickTeleportOn then return end
    -- clicks that land on this menu (or any Roblox UI) never teleport
    if gameProcessed then return end

    local inputType=input.UserInputType
    if inputType~=Enum.UserInputType.MouseButton1 and inputType~=Enum.UserInputType.Touch then
        return
    end

    task.defer(function()
        if unloading or not ClickTeleportOn then return end

        local camera=workspace.CurrentCamera
        local myRoot=GetTeleportRoot(Player)
        if not camera then
            ShowTeleportToast("Camera is unavailable right now")
            return
        end
        if not myRoot then
            ShowTeleportToast("Your character is not spawned yet")
            return
        end

        local rayOrigin=nil
        local rayDirection=nil
        local rayOk=pcall(function()
            local unitRay=camera:ViewportPointToRay(input.Position.X,input.Position.Y)
            rayOrigin=unitRay.Origin
            rayDirection=unitRay.Direction*1200
        end)
        if not rayOk or not rayOrigin or not rayDirection then
            return
        end

        -- ray through every character (yours included) so clicks always
        -- land on the world itself, never on a player's body
        local filter={myRoot}
        pcall(function()
            local character=Player.Character
            if character then
                table.insert(filter,character)
            end
            for _,otherPlayer in ipairs(Players:GetPlayers()) do
                if otherPlayer~=Player and otherPlayer.Character then
                    table.insert(filter,otherPlayer.Character)
                end
            end
        end)

        local result=nil
        local raycastOk=pcall(function()
            local raycastParams=RaycastParams.new()
            raycastParams.FilterType=Enum.RaycastFilterType.Exclude
            raycastParams.FilterDescendantsInstances=filter
            raycastParams.IgnoreWater=false
            result=workspace:Raycast(rayOrigin,rayDirection,raycastParams)
        end)

        if not raycastOk then
            ShowTeleportToast("Click teleport was blocked by the game")
            return
        end
        if not result or not result.Position then
            ShowTeleportToast("Nothing to teleport to there — aim at the map")
            return
        end

        local hitPosition=result.Position
        local okSet=pcall(function()
            local keepFacing=myRoot.CFrame.Rotation
            myRoot.CFrame=CFrame.new(hitPosition+Vector3.new(0,3,0))*keepFacing
        end)

        if okSet then
            SpawnClickTeleportMarker(hitPosition)
            ShowTeleportToast("Click teleported to "..FormatTeleportPosition(CFrame.new(hitPosition)))
        else
            ShowTeleportToast("Click teleport was blocked by the game")
        end
    end)
end)

Players.PlayerAdded:Connect(function(plr)
    if unloading then return end
    QueueTeleportRefresh("join",plr and (plr.DisplayName or plr.Name))
end)

Players.PlayerRemoving:Connect(function(plr)
    if unloading then return end

    -- mark them as leaving so the very next rebuild drops them instantly
    -- (GetPlayers still lists them for a moment after this event fires)
    if plr then
        TeleportPendingLeaves[plr]=true
    end

    -- queue the generic "left the server" toast first so any more
    -- specific toast below (e.g. view ended) shows on top of it
    QueueTeleportRefresh("leave",plr and (plr.DisplayName or plr.Name))

    -- release every system holding the leaving player so nothing ever
    -- acts on a dead reference (selection, viewing, walking)
    if TeleportSelected==plr then
        TeleportSelected=nil
        UpdateTeleportViewPanel()
    end
    if TeleportViewing==plr then
        TeleportViewing=nil
        RestoreTeleportCamera()
        UpdateTeleportViewPanel()
        ShowTeleportToast("View ended — the player left")
    end
    if TeleportWalkTarget==plr then
        TeleportWalking=false
        TeleportWalkTarget=nil
        UpdateTeleportStatusLine()
    end
end)

TeleportPage:GetPropertyChangedSignal("Visible"):Connect(function()
    if TeleportPage.Visible and not unloading then
        RefreshTeleportPlayers()
    end
end)

-- keep distances + status live while the tab is open
task.spawn(function()
    while ScreenGui.Parent and not unloading do
        if TeleportPage.Visible then
            UpdateTeleportDistances()
            UpdateTeleportStatusLine()
        end
        task.wait(1)
    end
end)

-- camera safety: if Bubba unloads while you are viewing someone, hand
-- the camera back to your own character before the ui dies
RunService.RenderStepped:Connect(function()
    if unloading and TeleportViewing then
        TeleportViewing=nil
        RestoreTeleportCamera()
    end
end)

-- final safety net: if the hub is destroyed mid-view, hand the
-- camera back before the ui dies
ScreenGui.Destroying:Connect(function()
    TeleportWalking=false
    TeleportWalkTarget=nil
    ClickTeleportOn=false
    if TeleportViewing then
        TeleportViewing=nil
        RestoreTeleportCamera()
    end
end)

------------------------------------------------------------
-- TELEPORT THEME SYNC (chained onto the master theme pipeline)
------------------------------------------------------------

local function UpdateTeleportTheme(theme)
    if TeleportScroll and TeleportScroll.Parent then
        TeleportScroll.ScrollBarImageColor3=theme.Accent
    end
    if TeleportPlayerList and TeleportPlayerList.Parent then
        TeleportPlayerList.ScrollBarImageColor3=theme.Accent
    end

    if TeleportTitle then TeleportTitle.TextColor3=theme.Text end
    if TeleportSubtitle then TeleportSubtitle.TextColor3=theme.Muted end

    if TeleportToast and TeleportToast.Parent then
        TeleportToast.BackgroundColor3=theme.PanelLight
        TeleportToastStroke.Color=theme.Accent
        TeleportToastBar.BackgroundColor3=theme.Accent
        TeleportToastLabel.TextColor3=theme.Text
    end

    -- restyle everything registered, and purge dead rows while we walk
    local alive={}
    for _,object in ipairs(TeleportThemeObjects) do
        if object and object.Parent then
            table.insert(alive,object)
            if object:IsA("Frame") then
                if object.Name=="TeleportPlayersSection" or object.Name=="TeleportViewSection" or object.Name=="TeleportQuickSection" or object.Name=="TeleportClickSection" then
                    object.BackgroundColor3=theme.PanelLight
                elseif object.Name=="TeleportPlayerRow" then
                    object.BackgroundColor3=theme.Panel
                elseif object.Name=="TeleportClickRow" then
                    object.BackgroundColor3=theme.Background
                end
            elseif object:IsA("TextLabel") then
                if object.Name=="TeleportRowMonogram" or object.Name=="TeleportViewMonogram" then
                    object.BackgroundColor3=theme.Background
                    object.TextColor3=theme.Accent
                else
                    object.TextColor3=object:GetAttribute("MutedText") and theme.Muted or theme.Text
                end
            elseif object:IsA("TextButton") then
                if object:GetAttribute("TeleportAccentButton") then
                    object.BackgroundColor3=theme.Accent:Lerp(Color3.new(0,0,0),0.45)
                else
                    object.BackgroundColor3=ButtonColor()
                end
                object.TextColor3=theme.Text
            elseif object:IsA("TextBox") then
                object.BackgroundColor3=theme.Background
                object.TextColor3=theme.Text
                object.PlaceholderColor3=theme.Muted
            elseif object:IsA("UIStroke") then
                object.Color=theme.Accent
            end
        end
    end
    TeleportThemeObjects=alive

    -- accent overrides that the generic pass above would stomp: pills,
    -- the viewing badge, and the quick-teleport status line
    if TeleportPlayerPill then TeleportPlayerPill.TextColor3=theme.Accent end
    if TeleportLivePill then TeleportLivePill.TextColor3=theme.Accent end
    if TeleportViewStatus then TeleportViewStatus.TextColor3=theme.Accent end
    if TeleportStatusLine and TeleportStatusLine.Parent then
        TeleportStatusLine.TextColor3=TeleportWalking and theme.Accent or theme.Muted
    end

    -- re-apply the row selection highlight + click status on top of the
    -- fresh colors
    RefreshTeleportRowSelection()
    UpdateClickTeleportStatus()
end

local BaseApplyThemeTeleport=ApplyTheme
ApplyTheme=function(theme)
    BaseApplyThemeTeleport(theme)
    UpdateTeleportTheme(theme)
end

-- build the first live list immediately so the tab is ready the moment
-- it is clicked
RefreshTeleportPlayers()
UpdateTeleportStatusLine()

end)

if not TeleportBuildOk then
    warn("[BUBBA TELEPORT TAB ERROR]:",TeleportBuildError)
end

local dragStart
local startPosition

Header.InputBegan:Connect(function(input)
    if unloading then return end
    if input.UserInputType==Enum.UserInputType.MouseButton1
        or input.UserInputType==Enum.UserInputType.Touch then

        dragging=true
        dragStart=input.Position
        startPosition=Main.Position

        input.Changed:Connect(function()
            if input.UserInputState==Enum.UserInputState.End then
                dragging=false
            end
        end)
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and not unloading then
        if input.UserInputType==Enum.UserInputType.MouseMovement
            or input.UserInputType==Enum.UserInputType.Touch then

            local delta=input.Position-dragStart
            Main.Position=UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset+delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset+delta.Y
            )
        end
    end
end)

ResizeHandle=Create("TextButton",{
    Name="ResizeHandle",
    AnchorPoint=Vector2.new(1,1),
    Position=UDim2.new(1,-5,1,-5),
    Size=UDim2.fromOffset(23,23),
    BackgroundColor3=CurrentTheme.PanelLight,
    BorderSizePixel=0,
    Text="◢",
    TextColor3=CurrentTheme.Accent,
    TextSize=16,
    Font=Enum.Font.GothamBold,
    AutoButtonColor=false,
    ZIndex=5
},Main)
Round(ResizeHandle,6)

ResizeHandleStroke=Stroke(ResizeHandle,CurrentTheme.Accent,0.35)

local resizeStart
local originalSize

ResizeHandle.InputBegan:Connect(function(input)
    if unloading then return end
    if input.UserInputType==Enum.UserInputType.MouseButton1
        or input.UserInputType==Enum.UserInputType.Touch then

        resizing=true
        resizeStart=input.Position
        originalSize=Main.AbsoluteSize

        input.Changed:Connect(function()
            if input.UserInputState==Enum.UserInputState.End then
                resizing=false
            end
        end)
    end
end)

UIS.InputChanged:Connect(function(input)
    if resizing and not unloading then
        if input.UserInputType==Enum.UserInputType.MouseMovement
            or input.UserInputType==Enum.UserInputType.Touch then

            local delta=input.Position-resizeStart
            local width=math.clamp(originalSize.X+delta.X,MIN_WIDTH,MAX_WIDTH)
            local height=math.clamp(originalSize.Y+delta.Y,MIN_HEIGHT,MAX_HEIGHT)
            Main.Size=UDim2.fromOffset(width,height)
        end
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1
        or input.UserInputType==Enum.UserInputType.Touch then
        resizing=false
        dragging=false
    end
end)

local function PlayCinematicLoading()
    if LoadingStarted or not LoadingScreen.Parent then return end
    LoadingStarted=true

    local theme=CurrentTheme

    ----------------------------------------------------------------
    -- BEAT 1: CRT POWER-ON (the mirror of the unload crt death)
    ----------------------------------------------------------------
    LoadingScreen.BackgroundColor3=Color3.fromRGB(4,4,8)

    local PowerDot=Create("Frame",{
        Name="PowerDot",
        AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(2,2),
        BackgroundColor3=Color3.fromRGB(255,255,255),
        BorderSizePixel=0,
        ZIndex=300
    },LoadingScreen)
    Round(PowerDot,100)
    Tween(PowerDot,{Size=UDim2.fromOffset(8,8)},0.16,Enum.EasingStyle.Back)
    task.wait(0.2)

    -- the dot tears open into a horizontal line
    Tween(PowerDot,{Size=UDim2.fromOffset(520,3)},0.14,Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
    task.wait(0.16)

    -- the line rips open into a full screen of light
    Tween(PowerDot,{Size=UDim2.fromScale(1,1)},0.22,Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
    task.wait(0.24)

    -- the light burns off and reveals the bubba void
    Tween(PowerDot,{BackgroundTransparency=1},0.3,Enum.EasingStyle.Quart)
    Tween(LoadingScreen,{BackgroundColor3=theme.Background},0.5,Enum.EasingStyle.Quart)
    task.delay(0.4,function()
        if PowerDot.Parent then PowerDot:Destroy() end
    end)

    task.wait(0.15)

    StartLoadingAnimations()

    ----------------------------------------------------------------
    -- BEAT 2: BOOT TERMINAL decrypts the startup log
    ----------------------------------------------------------------
    task.spawn(function()
        task.wait(0.1)
        if not LoadingScreen.Parent or LoadingCancelled then return end
        Tween(BootTerminal,{BackgroundTransparency=0.25},0.3)
        Tween(BootTerminalStroke,{Transparency=0.7},0.3)

        local bootLines={
            {Text="> BUBBA ENGINE v2.4"},
            {Text="> mounting interface core",Ok="[OK]"},
            {Text="> auto-detected game: "..string.lower(DetectedGame.Name or "resolving"),Ok="[OK]",Game=true},
            {Text="> injecting 24 themes",Ok="[OK]"},
            {Text="> arming modules",Ok="[OK]"},
            {Text="> handshake: session verified",Ok="[OK]"},
            {Text="> rendering interface",Ok="[OK]"}
        }

        local gameLineLabel=nil

        for _,line in ipairs(bootLines) do
            if not LoadingScreen.Parent or LoadingCancelled then return end
            local label=AddBootLine(line.Text,line.Ok)
            if line.Game then
                gameLineLabel=label
                -- if the marketplace lookup lands mid-boot, retarget the
                -- terminal line so the detection always reads accurate
                OnGameResolved(function(name)
                    if gameLineLabel and gameLineLabel.Parent and LoadingScreen.Parent and not LoadingCancelled then
                        LoadingScramble(gameLineLabel,"> auto-detected game: "..string.lower(name)," <font color=\""..LoadingAccentHex(CurrentTheme).."\">[OK]</font>")
                    end
                end)
            end
            task.wait(0.22)
        end

        -- the terminal parks in the corner while the interface builds
        task.wait(2.4)
        if BootTerminal.Parent and not LoadingCancelled then
            Tween(BootTerminal,{BackgroundTransparency=1},0.4)
            Tween(BootTerminalStroke,{Transparency=1},0.4)
            for _,entry in ipairs(BootLines) do
                Tween(entry.Label,{TextTransparency=1},0.35)
            end
            task.delay(0.5,function()
                if BootTerminal.Parent then BootTerminal.Visible=false end
            end)
        end
    end)

    task.wait(1.7)

    ----------------------------------------------------------------
    -- BEAT 4: the BUBBA title slams in letter by letter
    ----------------------------------------------------------------
    for index,letter in ipairs(BubbaTitleLetters) do
        task.delay((index-1)*0.06,function()
            if letter.Parent then
                Tween(letter,{TextTransparency=0,TextSize=30},0.4,Enum.EasingStyle.Back)
            end
        end)
    end

    task.wait(0.42)
    Tween(TitleUnderline,{Size=UDim2.new(0,132,0,2)},0.45,Enum.EasingStyle.Quart)
    Tween(BubbaSubtitle,{TextTransparency=0},0.5)

    task.wait(0.35)

    ----------------------------------------------------------------
    -- BEAT 5: progress run with decrypting statuses
    ----------------------------------------------------------------
    Tween(LoadingStatus,{TextTransparency=0},0.4)
    Tween(LoadingPercent,{TextTransparency=0},0.4)
    Tween(LoadingFooter,{TextTransparency=0},0.5)

    local displayed=0
    local target=0

    task.spawn(function()
        while LoadingScreen.Parent and not LoadingCancelled do
            displayed+=(target-displayed)*0.16
            if target-displayed<0.4 then displayed=target end
            LoadingPercent.Text=tostring(math.floor(displayed+0.5)).."%"
            task.wait(0.045)
        end
    end)

    local statuses={
        {Percent=12,Text="INITIALIZING BUBBA"},
        {Percent=28,Text="LOADING INTERFACE"},
        {Percent=45,Text="PREPARING THEMES"},
        {Percent=62,Text=DetectedGame.Name and ("SYNCING WITH "..string.upper(DetectedGame.Name)) or "DETECTING GAME"},
        {Percent=79,Text="CONNECTING INTERFACE"},
        {Percent=92,Text="FINALIZING"},
        {Percent=100,Text="BUBBA READY"}
    }

    for _,step in ipairs(statuses) do
        if not LoadingScreen.Parent or LoadingCancelled then return end
        LoadingScramble(LoadingStatus,step.Text)
        target=step.Percent

        local progressTween=Tween(ProgressFill,{
            Size=UDim2.new(step.Percent/100,0,1,0)
        },0.5,Enum.EasingStyle.Quart)

        if progressTween then progressTween.Completed:Wait() end
        if not LoadingScreen.Parent or LoadingCancelled then return end
        task.wait(0.08)
    end

    LoadingStatus.Text="BUBBA READY"
    target=100
    LoadingPercent.Text="100%"
    ProgressFill.Size=UDim2.new(1,0,1,0)

    ----------------------------------------------------------------
    -- BEAT 6: ready pulse
    ----------------------------------------------------------------
    local ReadyRing=Create("Frame",{
        AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.new(0.5,0,0.34,0),
        Size=UDim2.fromOffset(90,90),
        BackgroundTransparency=1,
        BorderSizePixel=0,
        ZIndex=209
    },LoadingScreen)
    Round(ReadyRing,100)
    local ReadyRingStroke=Stroke(ReadyRing,theme.Accent,0.1,3)
    Tween(ReadyRing,{Size=UDim2.fromOffset(430,430)},0.55,Enum.EasingStyle.Quart)
    Tween(ReadyRingStroke,{Transparency=1},0.55)

    Tween(LoadingStatus,{TextColor3=theme.Accent},0.3)

    task.wait(0.6)
    LoadingFinished=true
    LoadingCancelled=true
    FadeLoadingScreen()

    if not ScreenGui.Parent then return end

    ----------------------------------------------------------------
    -- BEAT 7: the main window rises out of the core
    ----------------------------------------------------------------
    local RevealRing=Create("Frame",{
        AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(140,140),
        BackgroundTransparency=1,
        BorderSizePixel=0,
        ZIndex=0
    },ScreenGui)
    Round(RevealRing,100)
    local RevealRingStroke=Stroke(RevealRing,theme.Accent,0.2,3)
    Tween(RevealRing,{Size=UDim2.fromOffset(1000,800)},0.6,Enum.EasingStyle.Quart)
    Tween(RevealRingStroke,{Transparency=1},0.6)
    task.delay(0.65,function()
        if RevealRing.Parent then RevealRing:Destroy() end
    end)

    -- veil so the window materializes before the contents show
    local RevealVeil=Create("Frame",{
        Name="RevealVeil",
        Size=UDim2.fromScale(1,1),
        BackgroundColor3=theme.Background,
        BorderSizePixel=0,
        ZIndex=60
    },Main)
    Round(RevealVeil,12)

    Main.Visible=true
    Main.BackgroundTransparency=1
    Main.Position=UDim2.new(0.5,-380,0.5,-170)
    Main.Rotation=-2

    local mainTween=Tween(Main,{
        BackgroundTransparency=0,
        Position=UDim2.new(0.5,-380,0.5,-230),
        Rotation=0
    },0.65,Enum.EasingStyle.Quart)

    Tween(RevealVeil,{BackgroundTransparency=1},0.65,Enum.EasingStyle.Quart)
    task.delay(0.7,function()
        if RevealVeil.Parent then RevealVeil:Destroy() end
    end)

    if mainTween then mainTween.Completed:Wait() end

    if Main and Main.Parent then
        Main.BackgroundTransparency=0
        Main.Position=UDim2.new(0.5,-380,0.5,-230)
        Main.Rotation=0
        Main.Visible=true
    end

    -- device chrome: cache transparencies for the hide/show fades on every
    -- platform (Right Shift / B on PC, minus / B on mobile); the corner
    -- notification itself only fires on PC
    CacheMobileTransparency()
    if MobileToggle then
        MobileToggle.Visible=false
    end
    ShowMobileNotification()
end

task.spawn(function()
    local success,errorMessage=pcall(PlayCinematicLoading)

    if not success then
        warn("[BUBBA LOADING ERROR]:",errorMessage)
        LoadingCancelled=true
        LoadingFinished=true

        if LoadingScreen and LoadingScreen.Parent then
            LoadingScreen:Destroy()
        end

        if Main and Main.Parent then
            Main.Visible=true
            Main.BackgroundTransparency=0
            Main.Position=UDim2.new(0.5,-380,0.5,-230)
        end

        CacheMobileTransparency()
        ShowMobileNotification()
    end
end)

-- watchdog: if anything stopped the loading sequence from starting, force it to run
if not LoadingStarted then
    task.delay(1,function()
        if not LoadingStarted and ScreenGui.Parent and LoadingScreen.Parent then
            task.spawn(function()
                pcall(PlayCinematicLoading)
            end)
        end
    end)
end

-- ABSOLUTE BOOT GUARANTEE: whatever happens above, the hub window appears.
-- If the intro stalled in a way its own error fallback did not cover (for
-- example an executor that never fired a tween Completed event, leaving the
-- fade locked), force the window on screen so the UI is never invisible.
task.delay(26,function()
    if unloading or MobileUIHidden then return end
    if ScreenGui and ScreenGui.Parent and Main and Main.Parent and not Main.Visible then
        warn("[BUBBA BOOT WATCHDOG]: intro stalled, force-showing the hub window")

        if LoadingScreen and LoadingScreen.Parent then
            LoadingScreen:Destroy()
        end

        Main.Visible=true
        Main.BackgroundTransparency=0
        Main.Position=UDim2.new(0.5,-380,0.5,-230)
        Main.Rotation=0

        CacheMobileTransparency()
        if MobileToggle and MobileToggle.Parent then
            MobileToggle.Visible=false
        end
        ShowMobileNotification()
    end
end)

print("BUBBA SCRIPTS | BUBBA UI loaded — auto-boot on join (drop in auto-execute), game auto-detected: "..tostring(DetectedGame.Name or "still resolving")..", 24 themes, mobile B/minus controls + PC Right Shift hide/show with the draggable B bubble, PC-only device-detection notification, teleport menu (players / walking / spawn / waypoints / random) with view player inspection, unlimited numeric settings, session configs, and a boot supervisor that force-reveals the window if any build step ever errors.")




