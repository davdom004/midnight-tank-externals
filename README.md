# TankExternals

TankExternals is a World of Warcraft addon that tracks defensive externals available for your group and shows them as a compact icon bar. It is aimed at tanks and raid leaders who want a fast view of which externals are currently ready, recharging, or unavailable.

## What It Does

- Tracks configured external defensive cooldowns from party or raid members.
- Shows a movable icon bar with class-colored owner labels.
- Supports spell filtering by class/spec and per-spell enable toggles.
- Models cooldown modifiers and extra charges where the addon has talent or config support.
- Lets you override cooldown modifier assumptions globally by spec and per player from the active roster.
- Resets tracked timers after a failed encounter ends.

## How It Works

TankExternals builds a live roster of players who can provide tracked externals, watches their combat events, and estimates cooldown availability from successful casts plus aura updates. The UI then renders one icon per tracked spell-owner pair, including cooldown swipes and charge counters for multi-charge spells.

By default, the addon stays conservative about unknown talents. Spec-level cooldown modifiers can be enabled in the Spells tab, and roster-specific overrides can be adjusted in the Roster tab when you know a player is using a relevant talent setup.

## Current Scope

Tracked spells currently focus on common tank externals such as:

- Pain Suppression
- Guardian Spirit
- Ironbark
- Blessing of Sacrifice
- Life Cocoon
- Time Dilation

## Configuration

Use `/te` to open the configuration window.

From there you can:

- Change icon layout, spacing, size, and lock state.
- Adjust owner name text placement and truncation.
- Enable or disable tracked spells.
- Toggle default spec-based cooldown modifiers.
- Override modifier assumptions for players in your active roster.

## Known Issues

## TODO
