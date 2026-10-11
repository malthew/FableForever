local addonName, ns = ...

ns.DefaultMood = "pastoral"

-- Keys are lower-case zone names from the English client. Map IDs are also
-- shown by /fableforever debug; more exact IDs and localized aliases can be added
-- here as they are collected in-game.
ns.ZoneMoods = {
    ["elwynn forest"] = "pastoral",
    ["westfall"] = "pastoral",
    ["loch modan"] = "pastoral",
    ["mulgore"] = "pastoral",
    ["teldrassil"] = "pastoral",
    ["durotar"] = "pastoral",
    ["tirisfal glades"] = "haunted",
    ["silverpine forest"] = "haunted",
    ["duskwood"] = "haunted",
    ["western plaguelands"] = "haunted",
    ["eastern plaguelands"] = "haunted",
    ["felwood"] = "haunted",
    ["darkshore"] = "verdant",
    ["ashenvale"] = "verdant",
    ["stonetalon mountains"] = "verdant",
    ["feralas"] = "verdant",
    ["the hinterlands"] = "verdant",
    ["wetlands"] = "verdant",
    ["redridge mountains"] = "verdant",
    ["stranglethorn vale"] = "wild",
    ["tanaris"] = "arid",
    ["thousand needles"] = "arid",
    ["desolace"] = "arid",
    ["badlands"] = "arid",
    ["blasted lands"] = "arid",
    ["searing gorge"] = "arid",
    ["burning steppes"] = "arid",
    ["dun morogh"] = "snow",
    ["winterspring"] = "snow",
    ["stormwind city"] = "epilogueGood",
    ["stormwind"] = "epilogueGood",
    ["ironforge"] = "civilized",
    ["darnassus"] = "civilized",
    ["orgrimmar"] = "epilogueBad",
    ["thunder bluff"] = "civilized",
    ["undercity"] = "haunted",
    ["booty bay"] = "civilized",
    ["gadgetzan"] = "civilized",
    ["ratchet"] = "civilized",
    ["everlook"] = "civilized",
    ["exodar"] = "sacred",
    ["azuremyst isle"] = "sacred",
    ["bloodmyst isle"] = "wild",
    ["eversong woods"] = "sacred",
    ["ghostlands"] = "haunted",
    ["silithus"] = "arid",
    ["ungoro crater"] = "wild",
    ["moonglade"] = "sacred",

    -- Forever adds new areas over time. These older zones make good initial
    -- mood matches when encountered on the current beta map.
    ["zephras isle"] = "verdant",
    ["shipwreck cove"] = "wild",
    ["city of dalaran"] = "civilized",
}

ns.SubzoneMoods = {
    ["goldshire"] = "civilized",
    ["northshire valley"] = "sacred",
    ["darkshire"] = "haunted",
    ["stormwind keep"] = "sacred",
    ["the barrens"] = "arid",
    ["crossroads"] = "civilized",
    ["the sepulcher"] = "haunted",
    ["lights hope chapel"] = "sacred",
    ["light's hope chapel"] = "sacred",
}

ns.InstanceMoods = {
    ["ragefire chasm"] = "cave",
    ["wailing caverns"] = "cave",
    ["the deadmines"] = "cave",
    ["blackfathom deeps"] = "cave",
    ["shadowfang keep"] = "haunted",
    ["the stockade"] = "cave",
    ["gnomeregan"] = "cave",
    ["razorfen kraul"] = "cave",
    ["razorfen downs"] = "haunted",
    ["scarlet monastery"] = "sacred",
    ["ruins of lordaeron"] = "haunted",
    ["hall of thanes"] = "cave",
    ["excavation site: wetlands"] = "cave",
    ["uldaman"] = "cave",
    ["city of dalaran"] = "civilized",
}

local function Normalize(text)
    if type(text) ~= "string" then
        return ""
    end
    return string.lower(string.gsub(string.gsub(text, "^%s+", ""), "%s+$", ""))
end

function ns.ResolveMood(zone, subzone, instanceName)
    local zoneMood = ns.ZoneMoods[Normalize(zone)]
    -- These city assignments are deliberate single-track overrides. Check
    -- them before subzones (for example, Stormwind Keep) so the ending cue
    -- remains exclusive to its requested city.
    if zoneMood == "epilogueBad" or zoneMood == "epilogueGood" then
        return zoneMood
    end

    local instanceMood = ns.InstanceMoods[Normalize(instanceName)]
    if instanceMood then
        return instanceMood
    end

    local subzoneMood = ns.SubzoneMoods[Normalize(subzone)]
    if subzoneMood then
        return subzoneMood
    end

    return zoneMood or ns.DefaultMood
end
