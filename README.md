# Fable Forever

It turns out that the Xbox classic video game hit "Fable: The Lost Chapters" shares a lot of similarities with World of Warcraft, when it comes to music and ambiance. At least, that's been my experience with the WoW: Forever Beta.  
For that reason, I've created this client-side music addon for **WoW: Forever**. This addon _intelligently_ chooses Fable soundtrack cues from the current zone's mood, fades between tracks, and can even play combat and quest-completion cues.

> Unofficial fan project. It is not affiliated with or endorsed by Activision Blizzard, WoW: Forever, or Fable.

## Audio and distribution

This public repository contains the addon source and documentation only. It does **not** include the Fable soundtrack MP3 files. The addon expects the files listed in [`Music/README.md`](Music/README.md), but this project does not grant permission to copy or redistribute those recordings.

To use the addon, provide compatible audio files that you are legally allowed to use and place them in `FableForever/Music/` with the exact filenames documented there. Without those files, the addon has no soundtrack to play. Do not upload or redistribute the Fable recordings unless you have explicit rights to do so.

## Features

- Selects music by zone, subzone, instance, and mood.
- Fades tracks out and in, with adjustable fade durations and zone-change delay.
- Offers separate battle cues and a manual **Next track** control.
- Adds exclusive epilogue cues for Orgrimmar and Stormwind.
- Optionally replaces WoW's quest-complete sound.
- Includes a draggable settings window, status display, and configurable music level.
- Restores the WoW music volume when the override is disabled or on logout.

The music override starts **off**. Enable it from the settings window when you are ready.

## Install

1. Download the repository using **Code → Download ZIP** and extract it.
2. Rename the extracted `FableForever-main` directory to `FableForever`, then copy that folder into the WoW: Forever client's `Interface\AddOns` directory. `FableForever.toc` must be directly inside that folder.
3. Put your legally usable audio files in `FableForever\Music\`, using the exact names in [`Music/README.md`](Music/README.md).
4. Start or reload the client and enable **Fable Forever** in the AddOns list.
5. Open the settings with `/fableforever` or `/ff`, then turn on the music override.

The TOC currently declares interface version `16001` and targets the WoW: Forever client. Compatibility with other WoW clients is not claimed.

If upgrading from the earlier **Fable OST** addon folder, remove `Interface\AddOns\FableOST` first. Fable Forever has its own saved settings, so review the options after upgrading.

## Settings

The settings window controls the zone music override, combat cues, quest-complete sound replacement, target music volume (0–100%), fade-out and fade-in durations, zone-change delay, and quiet time between automatic tracks. A read-only current-output meter shows the live music level as fades run. It also shows the current area, mood, and cue. **Next track** skips the quiet interlude while retaining the configured fade.

The target music volume is saved by the add-on and applied through WoW's `Sound_MusicVolume` value. This keeps the target intact if the client saves a temporary fade level during logout. The add-on fades the live value during transitions, and changes to WoW's Music slider also update the target. The add-on does not change `Sound_EnableMusic`.

Automatic cues play once and then leave a quiet interlude (3 minutes by default; configurable from 0 to 10 minutes). A mood change or combat can start a cue early. The replacement quest-complete cue is optional and off by default.

## Commands

| Command | Action |
| --- | --- |
| `/fableforever` or `/ff` | Open settings |
| `/fableforever on` / `off` | Enable or disable the zone music override |
| `/fableforever status` | Show the current zone, mood, and cue |
| `/fableforever next` | Start another cue for the current mood |
| `/fableforever volume 85` | Set Fable music level to 85% |
| `/fableforever fade 3` | Set both fade durations in seconds |
| `/fableforever silence 3` | Set the quiet interlude in minutes (0–10) |
| `/fableforever combat on` / `off` | Enable or disable battle cues |
| `/fableforever questwin on` / `off` | Enable or disable quest-complete sound replacement |

## Project files

- `FableForever.lua` — playback, events, saved settings, and slash commands.
- `Options.lua` — settings window.
- `Tracks.lua` — audio filenames, durations, and mood playlists.
- `Zones.lua` — zone, subzone, and instance mood mappings.
- `FableForever.toc` — addon metadata and load order.
- `Music/README.md` — expected audio filenames and asset notice.

## License

The original addon source code in this repository is licensed under the [MIT License](LICENSE). This permissive license lets others use, modify, and redistribute the code, including in forks, as long as they retain the copyright and license notice.

The MIT License applies only to the addon code identified as this project's original work. It does not cover the Fable soundtrack recordings, Blizzard or WoW assets, or any other third-party content. Those materials retain their respective rights, and the soundtrack MP3s are not included here.

## Support and contributions

When reporting an issue, include the WoW: Forever client version, the affected zone, and any relevant error from the in-game Lua error display. Zone mood mappings live in `Zones.lua`; track pools and durations live in `Tracks.lua`.
