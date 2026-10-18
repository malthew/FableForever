local addonName, ns = ...

local frame = CreateFrame("Frame")
-- FileDataID for Sound/Interface/iQuestComplete.ogg in the Forever client.
local QUEST_COMPLETE_SOUND_FILE_ID = 567439
local state = {
    initialized = false,
    enabled = false,
    inCombat = false,
    zone = "",
    subzone = "",
    mapID = nil,
    mood = nil,
    trackID = nil,
    baseMusicVolume = nil,
    currentGain = 1,
    questDuckGain = 1,
    questPauseActive = false,
    questPauseTimer = nil,
    questDuckTicker = nil,
    questDuckGeneration = 0,
    questPauseGeneration = 0,
    addonMusicVolumeWrites = {},
    fade = nil,
    silent = false,
    refreshTimer = nil,
    cycleTimer = nil,
    playGeneration = 0,
}

local DEFAULTS = {
    enabled = false,
    combatMusic = true,
    questWinSound = false,
    fadeOut = 2.5,
    fadeIn = 3.5,
    zoneDelay = 0.8,
    silenceMinutes = 3,
    volume = 0.85,
    lastTrackByMood = {},
}

local QUEST_COMPLETE_SOUND_DURATION = 2.5
local QUEST_MUSIC_DUCK_IN = 0.12
local QUEST_MUSIC_DUCK_OUT = 0.28

local function Clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

local function Chat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff9b6cffFable Forever|r: " .. tostring(message))
    end
end

local function GetCVarValue(name)
    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar(name)
    end
    if GetCVar then
        return GetCVar(name)
    end
    return nil
end

local function SetCVarValue(name, value)
    local stringValue = string.format("%.3f", Clamp(value, 0, 1))
    if name == "Sound_MusicVolume" then
        -- CVAR_UPDATE may be delivered after the next frame has already
        -- written a different fade value. Remember recent writes so delayed
        -- addon events are not mistaken for the user's volume-slider input.
        local now = GetTime and GetTime() or 0
        state.addonMusicVolumeWrites[stringValue] = now + 2
    end
    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar(name, stringValue)
    elseif SetCVar then
        SetCVar(name, stringValue)
    end
    if name == "Sound_MusicVolume" and ns.RefreshVolumeControl then
        ns.RefreshVolumeControl()
    end
end

local function IsMusicEnabled()
    local value = GetCVarValue("Sound_EnableMusic")
    return value == nil or (value ~= "0" and value ~= "false")
end

local function CancelTimer(timer)
    if timer and timer.Cancel then
        timer:Cancel()
    end
end

local function CancelCycle()
    CancelTimer(state.cycleTimer)
    state.cycleTimer = nil
end

local function EnsureBaseVolume()
    if state.baseMusicVolume == nil then
        local targetValue = tonumber(FableForeverDB and FableForeverDB.volume)
        local liveValue = tonumber(GetCVarValue("Sound_MusicVolume"))
        -- The saved target survives a logout even if the client persisted the
        -- addon's temporary fade value (often zero) to its Music CVar.
        state.baseMusicVolume = Clamp(targetValue or liveValue or 0.4, 0, 1)
        state.currentGain = Clamp(liveValue or state.baseMusicVolume, 0, 1)
    end
end

local function ApplyEffectiveGain()
    EnsureBaseVolume()
    if state.baseMusicVolume == nil then return end
    SetCVarValue("Sound_MusicVolume", state.currentGain * state.questDuckGain)
end

local function ApplyGain(gain)
    EnsureBaseVolume()
    if state.baseMusicVolume == nil then
        return
    end
    state.currentGain = Clamp(gain, 0, 1)
    ApplyEffectiveGain()
end

local function HandleMusicVolumeUpdate(value)
    -- CVAR_UPDATE can arrive after another fade step has already written a
    -- newer value. Read the live CVar so an older event cannot replace the
    -- saved game volume with one of the addon's temporary fade levels.
    local liveValue = tonumber(GetCVarValue("Sound_MusicVolume")) or tonumber(value)
    if liveValue == nil then return end

    local now = GetTime and GetTime() or 0
    local function IsRecentAddonWrite(volume)
        volume = tonumber(volume)
        if volume == nil then return false end
        local key = string.format("%.3f", Clamp(volume, 0, 1))
        local expiresAt = state.addonMusicVolumeWrites[key]
        if expiresAt and now <= expiresAt then return true end
        if expiresAt then state.addonMusicVolumeWrites[key] = nil end
        return false
    end
    if IsRecentAddonWrite(liveValue) then
        return
    end

    if state.baseMusicVolume == nil then
        -- With the override off, the game's Music slider is authoritative.
        FableForeverDB.volume = Clamp(liveValue, 0, 1)
        if ns.RefreshVolumeControl then ns.RefreshVolumeControl() end
        return
    end

    local effectiveGain = state.currentGain * state.questDuckGain
    local expectedValue = Clamp(effectiveGain, 0, 1)
    if math.abs(liveValue - expectedValue) < 0.002 then
        return -- This update reflects the addon's current gain/fade.
    end

    -- A real change from the game's Music slider becomes both the Fable target
    -- and the value restored when the override is disabled.
    state.baseMusicVolume = Clamp(liveValue, 0, 1)
    FableForeverDB.volume = state.baseMusicVolume
    if state.questDuckGain > 0.001 then
        state.currentGain = Clamp(liveValue / state.questDuckGain, 0, 1)
    end
    if state.fade then
        local fade = state.fade
        fade.from = state.currentGain
        if fade.to > 0 then fade.to = FableForeverDB.volume end
        fade.elapsed = 0
        fade.updateElapsed = 0
    end
    ApplyGain(state.currentGain)
    if ns.RefreshVolumeControl then ns.RefreshVolumeControl() end
end

local function TweenQuestDuck(target, duration)
    state.questDuckGeneration = state.questDuckGeneration + 1
    local generation = state.questDuckGeneration
    CancelTimer(state.questDuckTicker)
    state.questDuckTicker = nil
    target = Clamp(target, 0, 1)
    duration = Clamp(duration, 0, 2)

    if duration <= 0 or math.abs(state.questDuckGain - target) < 0.001 then
        state.questDuckGain = target
        ApplyEffectiveGain()
        return
    end

    local from = state.questDuckGain
    local elapsed = 0
    local function TickDuck()
        if generation ~= state.questDuckGeneration then return end
        elapsed = math.min(duration, elapsed + 0.05)
        local progress = elapsed / duration
        local eased = progress * progress * (3 - (2 * progress))
        state.questDuckGain = from + ((target - from) * eased)
        ApplyEffectiveGain()
        if progress >= 1 then
            state.questDuckTicker = nil
        else
            state.questDuckTicker = C_Timer.NewTimer(0.05, TickDuck)
        end
    end
    state.questDuckTicker = C_Timer.NewTimer(0.05, TickDuck)
end

local function CancelQuestPause(keepDucked)
    state.questPauseGeneration = state.questPauseGeneration + 1
    CancelTimer(state.questPauseTimer)
    state.questPauseTimer = nil
    state.questPauseActive = false
    state.questDuckGeneration = state.questDuckGeneration + 1
    CancelTimer(state.questDuckTicker)
    state.questDuckTicker = nil
    state.questDuckGain = keepDucked and 0 or 1
end

local function PauseMusicForQuest(duration)
    if not FableForeverDB.enabled or not state.trackID or state.silent or not IsMusicEnabled() then return end

    state.questPauseGeneration = state.questPauseGeneration + 1
    local generation = state.questPauseGeneration
    CancelTimer(state.questPauseTimer)
    state.questPauseActive = true
    TweenQuestDuck(0, QUEST_MUSIC_DUCK_IN)

    state.questPauseTimer = C_Timer.NewTimer(duration, function()
        state.questPauseTimer = nil
        if generation ~= state.questPauseGeneration or not state.questPauseActive then return end
        state.questPauseActive = false
        -- WoW's PlayMusic stream cannot be paused in place. Duck it for the
        -- quest sound, then bring its current position back smoothly.
        TweenQuestDuck(1, QUEST_MUSIC_DUCK_OUT)
    end)
end

local function StopFade()
    state.fade = nil
    frame:SetScript("OnUpdate", nil)
end

local function FadeTo(targetGain, duration, after)
    EnsureBaseVolume()
    targetGain = Clamp(targetGain, 0, 1)
    duration = Clamp(duration, 0, 15)

    if duration <= 0 or math.abs(state.currentGain - targetGain) < 0.001 then
        StopFade()
        ApplyGain(targetGain)
        if after then after() end
        return
    end

    state.fade = {
        from = state.currentGain,
        to = targetGain,
        duration = duration,
        elapsed = 0,
        updateElapsed = 0,
        after = after,
    }
    frame:SetScript("OnUpdate", function(_, elapsed)
        local fade = state.fade
        if not fade then
            frame:SetScript("OnUpdate", nil)
            return
        end

        fade.elapsed = math.min(fade.duration, fade.elapsed + elapsed)
        fade.updateElapsed = fade.updateElapsed + elapsed
        if fade.updateElapsed < 0.05 and fade.elapsed < fade.duration then
            return
        end
        fade.updateElapsed = 0

        local progress = fade.elapsed / fade.duration
        -- Smoothstep gives a gentle start and finish to each volume ramp.
        local eased = progress * progress * (3 - (2 * progress))
        ApplyGain(fade.from + ((fade.to - fade.from) * eased))

        if progress >= 1 then
            local callback = fade.after
            local finalGain = fade.to
            StopFade()
            ApplyGain(finalGain)
            if callback then callback() end
        end
    end)
end

local function SnapshotLocation()
    local zone = ""
    if GetRealZoneText then zone = GetRealZoneText() or "" end
    if zone == "" and GetZoneText then zone = GetZoneText() or "" end
    local subzone = GetSubZoneText and (GetSubZoneText() or "") or ""
    local instanceName = ""
    if GetInstanceInfo then
        instanceName = GetInstanceInfo() or ""
    end
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil

    state.zone = zone
    state.subzone = subzone
    state.mapID = mapID
    return zone, subzone, instanceName, mapID
end

local function ChooseTrack(mood, avoidTrack)
    local pool = ns.TrackPools[mood] or ns.TrackPools[ns.DefaultMood]
    local choices = {}
    for _, trackID in ipairs(pool or {}) do
        if ns.TrackCatalog[trackID] and trackID ~= avoidTrack then
            choices[#choices + 1] = trackID
        end
    end

    if #choices == 0 then
        for _, trackID in ipairs(pool or {}) do
            if ns.TrackCatalog[trackID] then choices[#choices + 1] = trackID end
        end
    end
    if #choices == 0 then return nil end

    local previous = FableForeverDB.lastTrackByMood[mood]
    if #choices > 1 and previous then
        local filtered = {}
        for _, trackID in ipairs(choices) do
            if trackID ~= previous then filtered[#filtered + 1] = trackID end
        end
        if #filtered > 0 then choices = filtered end
    end

    local selected = choices[math.random(1, #choices)]
    FableForeverDB.lastTrackByMood[mood] = selected
    return selected
end

local RefreshMusic

local function ScheduleNextTrack(trackID, generation)
    CancelCycle()
    local track = ns.TrackCatalog[trackID]
    if not track or not track.duration then return end

    local delay = track.duration - FableForeverDB.fadeOut
    if delay < 15 then return end

    state.cycleTimer = C_Timer.NewTimer(delay, function()
        state.cycleTimer = nil
        if generation ~= state.playGeneration or not FableForeverDB.enabled or not IsMusicEnabled() then
            return
        end
        state.playGeneration = state.playGeneration + 1
        local nextGeneration = state.playGeneration
        FadeTo(0, FableForeverDB.fadeOut, function()
            if nextGeneration ~= state.playGeneration or not FableForeverDB.enabled or not IsMusicEnabled() then
                return
            end
            if StopMusic then StopMusic() end
            state.silent = true

            local silenceSeconds = FableForeverDB.silenceMinutes * 60
            state.cycleTimer = C_Timer.NewTimer(silenceSeconds, function()
                state.cycleTimer = nil
                if nextGeneration ~= state.playGeneration or not FableForeverDB.enabled or not IsMusicEnabled() then
                    return
                end
                -- Resolve the mood again after the quiet interlude so a zone
                -- or combat change during silence selects the current cue.
                -- Reassert the quiet endpoint as well: a CVar change while
                -- silent can leave the remembered gain out of sync, causing
                -- the next fade to believe it has already reached its target.
                state.currentGain = 0
                ApplyEffectiveGain()
                RefreshMusic(true)
            end)
        end)
    end)
end

local function TransitionToTrack(mood, trackID)
    local track = ns.TrackCatalog[trackID]
    if not track then
        Chat("No track is configured for mood '" .. tostring(mood) .. "'.")
        return
    end

    state.playGeneration = state.playGeneration + 1
    local generation = state.playGeneration
    CancelCycle()
    state.mood = mood
    state.silent = false

    FadeTo(0, FableForeverDB.fadeOut, function()
        if generation ~= state.playGeneration or not FableForeverDB.enabled or not IsMusicEnabled() then
            return
        end
        local path = "Interface\\AddOns\\FableForever\\Music\\" .. track.file
        PlayMusic(path)
        state.trackID = trackID
        ScheduleNextTrack(trackID, generation)
        local fadeInDuration = FableForeverDB.fadeIn
        FadeTo(FableForeverDB.volume, fadeInDuration)

        -- Reassert the completed fade target. CVAR_UPDATE can race with the
        -- frame-driven fade and leave its remembered gain at an intermediate
        -- value even when the client reports the latest CVar write.
        if C_Timer and C_Timer.After then
            C_Timer.After(fadeInDuration + 0.5, function()
                if generation ~= state.playGeneration or not FableForeverDB.enabled
                    or state.trackID ~= trackID or state.baseMusicVolume == nil then
                    return
                end
                StopFade()
                ApplyGain(FableForeverDB.volume)
            end)
        end
    end)
end

local function CurrentMood()
    local zone, subzone, instanceName = SnapshotLocation()
    if state.inCombat and FableForeverDB.combatMusic then
        return "battle", zone, subzone, instanceName
    end
    return ns.ResolveMood(zone, subzone, instanceName), zone, subzone, instanceName
end

RefreshMusic = function(force)
    if not FableForeverDB or not FableForeverDB.enabled then return end
    if not IsMusicEnabled() then return end

    local mood = CurrentMood()
    local pool = ns.TrackPools[mood] or ns.TrackPools[ns.DefaultMood]
    if not force and state.mood == mood and state.trackID then
        for _, trackID in ipairs(pool) do
            if trackID == state.trackID then return end
        end
    end

    local trackID = ChooseTrack(mood, state.trackID)
    if trackID then
        TransitionToTrack(mood, trackID)
    end
end

local function QueueRefresh(delay)
    CancelTimer(state.refreshTimer)
    state.refreshTimer = C_Timer.NewTimer(delay or FableForeverDB.zoneDelay, function()
        state.refreshTimer = nil
        RefreshMusic(false)
    end)
end

local function RestoreMusic()
    local questPauseWasActive = state.questPauseActive or state.questDuckGain < 0.999
    CancelQuestPause(questPauseWasActive)
    if questPauseWasActive then
        state.currentGain = 0
        ApplyEffectiveGain()
    end
    state.playGeneration = state.playGeneration + 1
    CancelCycle()
    CancelTimer(state.refreshTimer)
    state.refreshTimer = nil
    local generation = state.playGeneration
    local function finish()
        if generation ~= state.playGeneration then return end
        if StopMusic then StopMusic() end
        state.trackID = nil
        state.mood = nil
        state.silent = false
        StopFade()
        if state.baseMusicVolume ~= nil then
            local volume = state.baseMusicVolume
            state.baseMusicVolume = nil
            state.currentGain = 1
            FableForeverDB.volume = volume
            SetCVarValue("Sound_MusicVolume", volume)
            if ns.RefreshVolumeControl then ns.RefreshVolumeControl() end
        end
    end

    if state.baseMusicVolume ~= nil and state.trackID then
        FadeTo(0, FableForeverDB.fadeOut, finish)
    else
        finish()
    end
end

local function EnableMusic()
    FableForeverDB.enabled = true
    state.enabled = true
    if not PlayMusic or not StopMusic then
        Chat("This client did not expose the expected music playback functions.")
        return
    end
    if not IsMusicEnabled() then
        Chat("Game music is turned off. Turn it on in Sound settings to hear Fable tracks.")
        return
    end
    QueueRefresh(0.1)
    Chat("Fable music override enabled.")
end

local function DisableMusic()
    FableForeverDB.enabled = false
    state.enabled = false
    RestoreMusic()
    Chat("Fable music override disabled; your music volume has been restored.")
end

local function SetMusicLevel(value)
    FableForeverDB.volume = Clamp(value, 0, 1)
    if state.baseMusicVolume == nil then
        -- While the override is off, the add-on control mirrors and sets the
        -- same Music CVar as WoW's own audio settings.
        SetCVarValue("Sound_MusicVolume", FableForeverDB.volume)
        return
    end
    state.baseMusicVolume = FableForeverDB.volume
    if state.silent then return end
    if state.fade then
        -- Preserve an in-progress transition callback while changing the
        -- destination of an active fade-in.
        if state.fade.to > 0 then state.fade.to = FableForeverDB.volume end
    elseif state.trackID and not state.silent then
        FadeTo(FableForeverDB.volume, 0.2)
    end
end

local function SetCombatMusic(enabled)
    FableForeverDB.combatMusic = not not enabled
    QueueRefresh(0.1)
end

local function SetQuestWinSound(enabled)
    enabled = not not enabled
    if enabled then
        if not MuteSoundFile or not UnmuteSoundFile or not PlaySoundFile then
            FableForeverDB.questWinSound = false
            Chat("This client does not expose the sound replacement APIs required for the quest-win cue.")
            return
        end
        MuteSoundFile(QUEST_COMPLETE_SOUND_FILE_ID)
        FableForeverDB.questWinSound = true
    else
        if UnmuteSoundFile then
            UnmuteSoundFile(QUEST_COMPLETE_SOUND_FILE_ID)
        end
        FableForeverDB.questWinSound = false
    end
end

local function PlayQuestWinSound()
    if not FableForeverDB.questWinSound or not PlaySoundFile then return false end
    local path = "Interface\\AddOns\\FableForever\\Music\\" .. ns.QuestWinSoundFile
    return PlaySoundFile(path, "SFX")
end

local function GetCurrentStatus()
    local mood, zone, subzone = CurrentMood()
    return {
        enabled = FableForeverDB.enabled,
        combatMusic = FableForeverDB.combatMusic,
        questWinSound = FableForeverDB.questWinSound,
        silenceMinutes = FableForeverDB.silenceMinutes,
        volume = FableForeverDB.volume,
        fadeIn = FableForeverDB.fadeIn,
        fadeOut = FableForeverDB.fadeOut,
        zoneDelay = FableForeverDB.zoneDelay,
        zone = zone,
        subzone = subzone,
        mapID = state.mapID,
        mood = mood,
        trackID = state.trackID,
        silent = state.silent,
    }
end

-- Options.lua uses this narrow controller instead of editing SavedVariables
-- directly, so UI changes pass through the same playback logic as slash commands.
ns.Controller = {
    GetSettings = function()
        return {
            enabled = FableForeverDB.enabled,
            combatMusic = FableForeverDB.combatMusic,
            questWinSound = FableForeverDB.questWinSound,
            silenceMinutes = FableForeverDB.silenceMinutes,
            volume = FableForeverDB.volume,
            currentVolume = Clamp(tonumber(GetCVarValue("Sound_MusicVolume")) or 0, 0, 1),
            fadeIn = FableForeverDB.fadeIn,
            fadeOut = FableForeverDB.fadeOut,
            zoneDelay = FableForeverDB.zoneDelay,
        }
    end,
    GetStatus = GetCurrentStatus,
    SetEnabled = function(enabled)
        if enabled then EnableMusic() else DisableMusic() end
    end,
    SetCombatMusic = SetCombatMusic,
    SetQuestWinSound = SetQuestWinSound,
    SetVolume = SetMusicLevel,
    SetFadeIn = function(value) FableForeverDB.fadeIn = Clamp(value, 0, 15) end,
    SetFadeOut = function(value) FableForeverDB.fadeOut = Clamp(value, 0, 15) end,
    SetZoneDelay = function(value) FableForeverDB.zoneDelay = Clamp(value, 0, 5) end,
    SetSilenceMinutes = function(value) FableForeverDB.silenceMinutes = Clamp(value, 0, 10) end,
    NextTrack = function()
        if FableForeverDB.enabled and IsMusicEnabled() then
            -- Manual skips cancel a quiet interlude and start the next cue now.
            -- The normal fade between the outgoing and incoming tracks remains.
            CancelCycle()
            CancelTimer(state.refreshTimer)
            state.refreshTimer = nil
            state.silent = false
            RefreshMusic(true)
        end
    end,
    Refresh = function() QueueRefresh(0.1) end,
}

local function GetStatus()
    local status = GetCurrentStatus()
    Chat(string.format("enabled=%s | zone=%s | subzone=%s | mapID=%s | mood=%s | track=%s",
        tostring(status.enabled), status.zone ~= "" and status.zone or "?",
        status.subzone ~= "" and status.subzone or "?", tostring(status.mapID or "?"),
        tostring(status.mood), status.silent and "quiet interlude" or tostring(status.trackID or "none")))
end

local function PrintHelp()
    Chat("Commands: /fableforever (or /ff) [options] | on | off | toggle | status | next | volume 0-100 | fade 0-15 | silence 0-10 | combat on|off | questwin on|off")
    Chat("Audio files belong in Interface\\AddOns\\FableForever\\Music\\.")
end

local function HandleSlashCommand(message)
    local command, argument = (message or ""):match("^(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    argument = string.lower(argument or "")

    if command == "" or command == "options" then
        if ns.OpenOptions then
            ns.OpenOptions()
        else
            PrintHelp()
        end
    elseif command == "on" then
        EnableMusic()
    elseif command == "off" then
        DisableMusic()
    elseif command == "toggle" then
        if FableForeverDB.enabled then DisableMusic() else EnableMusic() end
    elseif command == "status" or command == "debug" then
        GetStatus()
    elseif command == "next" then
        if FableForeverDB.enabled then
            RefreshMusic(true)
        else
            Chat("Enable the addon first with /fableforever on.")
        end
    elseif command == "volume" then
        local volume = tonumber(argument)
        if not volume then
            Chat("Current Fable music level: " .. string.format("%.0f%%", FableForeverDB.volume * 100) .. ".")
            return
        end
        SetMusicLevel(volume / 100)
        Chat("Fable music level set to " .. string.format("%.0f%%", FableForeverDB.volume * 100) .. ".")
    elseif command == "fade" then
        local duration = tonumber(argument)
        if not duration then
            Chat("Current transition fade: " .. tostring(FableForeverDB.fadeOut) .. " seconds.")
            return
        end
        FableForeverDB.fadeOut = Clamp(duration, 0, 15)
        FableForeverDB.fadeIn = FableForeverDB.fadeOut
        Chat("Fade-in and fade-out set to " .. string.format("%.1f", FableForeverDB.fadeOut) .. " seconds.")
    elseif command == "silence" then
        local minutes = tonumber(argument)
        if not minutes then
            Chat("Quiet time between tracks: " .. string.format("%.1f", FableForeverDB.silenceMinutes) .. " minutes.")
            return
        end
        FableForeverDB.silenceMinutes = Clamp(minutes, 0, 10)
        Chat("Quiet time between tracks set to " .. string.format("%.1f", FableForeverDB.silenceMinutes) .. " minutes.")
    elseif command == "combat" then
        if argument == "on" then
            SetCombatMusic(true)
            Chat("Combat music enabled.")
        elseif argument == "off" then
            SetCombatMusic(false)
            Chat("Combat music disabled.")
        else
            Chat("Combat music is " .. (FableForeverDB.combatMusic and "on" or "off") .. ". Use /fableforever combat on|off.")
        end
    elseif command == "questwin" then
        if argument == "on" then
            SetQuestWinSound(true)
        elseif argument == "off" then
            SetQuestWinSound(false)
        else
            Chat("Quest-win sound replacement is " .. (FableForeverDB.questWinSound and "on" or "off") .. ". Use /fableforever questwin on|off.")
        end
    else
        PrintHelp()
    end
end

SLASH_FABLEFOREVER1 = "/fableforever"
SLASH_FABLEFOREVER2 = "/ff"
SlashCmdList.FABLEFOREVER = HandleSlashCommand

local function InitializeDatabase()
    FableForeverDB = FableForeverDB or {}
    local savedVolume = tonumber(FableForeverDB.volume)
    for key, value in pairs(DEFAULTS) do
        if FableForeverDB[key] == nil then
            if type(value) == "table" then
                FableForeverDB[key] = {}
            else
                FableForeverDB[key] = value
            end
        end
    end
    FableForeverDB.lastTrackByMood = FableForeverDB.lastTrackByMood or {}
    FableForeverDB.fadeOut = Clamp(FableForeverDB.fadeOut, 0, 15)
    FableForeverDB.fadeIn = Clamp(FableForeverDB.fadeIn, 0, 15)
    FableForeverDB.zoneDelay = Clamp(FableForeverDB.zoneDelay, 0, 5)
    FableForeverDB.silenceMinutes = Clamp(FableForeverDB.silenceMinutes, 0, 10)
    local gameMusicVolume = tonumber(GetCVarValue("Sound_MusicVolume"))
    -- Keep the addon's saved target across sessions. The live CVar may still
    -- contain the zero written by the final fade before PLAYER_LOGOUT ran.
    FableForeverDB.volume = Clamp(savedVolume or gameMusicVolume or DEFAULTS.volume, 0, 1)
    state.enabled = FableForeverDB.enabled
    if FableForeverDB.questWinSound then
        -- MuteSoundFile's mute list is session-local, so reapply the saved
        -- preference after every addon load/reload.
        SetQuestWinSound(true)
    end
    state.initialized = true
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= addonName then return end
        InitializeDatabase()
        if math.randomseed and GetTime then math.randomseed(math.floor(GetTime() * 1000)) end
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("ZONE_CHANGED")
        frame:RegisterEvent("ZONE_CHANGED_INDOORS")
        frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        frame:RegisterEvent("QUEST_TURNED_IN")
        frame:RegisterEvent("CVAR_UPDATE")
        frame:RegisterEvent("PLAYER_LOGOUT")
        return
    end

    if not state.initialized then return end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
        if event == "PLAYER_ENTERING_WORLD" and FableForeverDB.questWinSound then
            SetQuestWinSound(true)
        end
        QueueRefresh()
    elseif event == "PLAYER_REGEN_DISABLED" then
        state.inCombat = true
        QueueRefresh(0.15)
    elseif event == "PLAYER_REGEN_ENABLED" then
        state.inCombat = false
        QueueRefresh(0.15)
    elseif event == "QUEST_TURNED_IN" then
        local replacementPlayed = PlayQuestWinSound()
        if FableForeverDB.enabled then
            local duration = replacementPlayed and ns.QuestWinSoundDuration or QUEST_COMPLETE_SOUND_DURATION
            PauseMusicForQuest(duration)
        end
    elseif event == "CVAR_UPDATE" then
        local cvarName, value = ...
        if cvarName == "Sound_MusicVolume" then
            HandleMusicVolumeUpdate(value)
        elseif cvarName == "Sound_EnableMusic" then
            if not IsMusicEnabled() then
                CancelQuestPause(false)
                state.playGeneration = state.playGeneration + 1
                CancelCycle()
                CancelTimer(state.refreshTimer)
                state.refreshTimer = nil
                StopFade()
                if StopMusic then StopMusic() end
                state.trackID = nil
                state.mood = nil
                state.silent = false
                if state.baseMusicVolume ~= nil then
                    local volume = state.baseMusicVolume
                    state.baseMusicVolume = nil
                    state.currentGain = 1
                    FableForeverDB.volume = volume
                    SetCVarValue("Sound_MusicVolume", volume)
                    if ns.RefreshVolumeControl then ns.RefreshVolumeControl() end
                end
            else
                QueueRefresh(0.1)
            end
        end
    elseif event == "PLAYER_LOGOUT" then
        CancelQuestPause(false)
        if FableForeverDB.questWinSound and UnmuteSoundFile then
            -- Do not leave this session-only mute behind if the user reloads
            -- with the addon disabled. It is reapplied on world entry.
            UnmuteSoundFile(QUEST_COMPLETE_SOUND_FILE_ID)
        end
        state.playGeneration = state.playGeneration + 1
        CancelCycle()
        CancelTimer(state.refreshTimer)
        StopFade()
        if StopMusic then StopMusic() end
        state.silent = false
        if state.baseMusicVolume ~= nil then
            local volume = state.baseMusicVolume
            state.baseMusicVolume = nil
            state.currentGain = 1
            FableForeverDB.volume = volume
            SetCVarValue("Sound_MusicVolume", volume)
        end
    end
end)

frame:RegisterEvent("ADDON_LOADED")
