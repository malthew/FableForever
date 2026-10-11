local addonName, ns = ...

-- These entries match the user-supplied MP3s in Music/ exactly. Durations
-- are rounded from the MP3 frame stream and are used for fade-before-next-cue
-- transitions, followed by the configured quiet interlude.
ns.TrackCatalog = {
    BanditCamp = { file = "Music Bandit Camp.mp3", duration = 248 },
    Bowerstone = { file = "Music Bowerstone.mp3", duration = 275 },
    ChapelOfEvil = { file = "Music Chapel Of Evil.mp3", duration = 149 },
    Danger01 = { file = "Music Danger 01.mp3", duration = 256 },
    Danger02 = { file = "Music Danger 02.mp3", duration = 128 },
    DangerArena = { file = "Music Danger Arena.mp3", duration = 127 },
    Darkwood = { file = "Music Darkwood.mp3", duration = 245 },
    ExecutionTree = { file = "Music Execution Tree.mp3", duration = 228 },
    EpilogueBad = { file = "Music Fresco 09 Epilogue Bad.mp3", duration = 47 },
    EpilogueGood = { file = "Music Fresco 10 Epilogue Good.mp3", duration = 47 },
    GibbetWoods = { file = "Music Gibbet Woods.mp3", duration = 244 },
    GraveyardPassage = { file = "Music Graveyard Passage.mp3", duration = 270 },
    Graveyard = { file = "Music Graveyard.mp3", duration = 270 },
    Greatwood = { file = "Music Greatwood.mp3", duration = 198 },
    GuildDay = { file = "Music Guild Day.mp3", duration = 217 },
    GuildNight = { file = "Music Guild Night.mp3", duration = 252 },
    HobbesCave = { file = "Music Hobbes Cave.mp3", duration = 237 },
    HookCoast = { file = "Music Hook Coast.mp3", duration = 205 },
    Interlude = { file = "Music Interlude.mp3", duration = 161 },
    Intro = { file = "Music Intro.mp3", duration = 210 },
    KnotholeGlade = { file = "Music Knothole Glade.mp3", duration = 205 },
    KrakenChamber = { file = "Music Kraken Chamber.mp3", duration = 235 },
    LookoutPoint = { file = "Music Lookout Point.mp3", duration = 239 },
    Oakvale = { file = "Music Oakvale.mp3", duration = 202 },
    Prison = { file = "Music Prison.mp3", duration = 235 },
    TempleOfLight = { file = "Music Temple Of Light.mp3", duration = 167 },
    Witchwood = { file = "Music Witchwood.mp3", duration = 187 },
}

ns.QuestWinSoundFile = "Music Quest Win.mp3"
-- Duration reported by the bundled MP3's media metadata; used to keep the
-- zone soundtrack quiet for the full replacement quest-complete cue.
ns.QuestWinSoundDuration = 8.34

-- Mood pools keep each cue with broad environment types. The two ending
-- cues have single-track pools and are selected only in their assigned cities.
ns.TrackPools = {
    pastoral = { "Intro", "Interlude", "Oakvale", "Greatwood", "LookoutPoint" },
    verdant = { "Greatwood", "Oakvale", "KnotholeGlade", "LookoutPoint" },
    civilized = { "Bowerstone", "GuildDay", "GuildNight", "KnotholeGlade" },
    haunted = { "Darkwood", "ExecutionTree", "GibbetWoods", "GraveyardPassage", "Graveyard", "Prison", "Witchwood" },
    wild = { "BanditCamp", "Greatwood", "GibbetWoods", "HookCoast", "LookoutPoint", "Witchwood" },
    arid = { "BanditCamp", "Danger01", "Danger02", "Witchwood" },
    snow = { "HookCoast", "LookoutPoint" },
    cave = { "ChapelOfEvil", "HobbesCave", "KrakenChamber", "GraveyardPassage" },
    sacred = { "TempleOfLight", "GuildDay", "Interlude" },
    battle = { "Danger01", "Danger02", "DangerArena", "ChapelOfEvil", "KrakenChamber" },
    epilogueBad = { "EpilogueBad" },
    epilogueGood = { "EpilogueGood" },
}
