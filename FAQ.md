# Frequently asked questions

## Does this add Pokemon on its own?

No. Expanded Species is infrastructure. Install a compatible species pack as
well.

## Does it replace MissingNo. or a vanilla Pokemon?

No. Gold's original 251 keep their records and numeric identities. Custom
species are allocated from 252 upward.

## How can it go beyond 255?

Gold's optional registry `index` is capped because it represents a Game Boy
byte. gen1recomp's live party, boxes, battles, and save data identify Pokemon by
string ID. Expanded Species waits until content validation is complete, then
adds deterministic runtime-only indices for systems that need ordering.

## Can I export custom Pokemon to a cartridge save?

No. The original `.sav` format only has room for the original byte-sized
species representation. Engine-native gen1recomp saves are the supported path.

## Can I use this in Red?

No. Expanded Species is deliberately Gold-only and uses Gold's six-stat species,
Pokedex, icon, palette, breeding, and save structures.

## What happens if a species pack is removed?

Expanded Species moves Pokemon whose definitions are missing into private
framework save data before Gold opens the world. This internal **MISSING**
storage is not shown in the PC and cannot be interacted with. Re-enable or
reinstall the pack and reload the save; complete records are restored to their
original locations when possible, with an ordinary box used as a safe fallback.
Keep Expanded Species itself enabled, because its guardian cannot run when the
framework is also disabled or fails to load.

## Can I see or withdraw Pokemon from MISSING storage?

No. It is intentionally not a real PC box. A missing definition is not safe to
render, battle, breed, trade, or edit. The framework preserves the record and
only returns it to normal gameplay after its species definition exists again.

## Does link play work?

Only when both sides have matching framework and species-pack data. Species
packs should declare `affects_link` in their manifests.

## Can a species pack add more than seven grass or three swimming entries?

Yes. Expanded Species gives packs weighted grass and water placement
helpers with no fixed row-count ceiling. The original slots remain intact, the
map's encounter rate does not change, and enabled packs compose into one custom
pool. Practical memory and load time are the only slot-count boundary.

## How do custom encounter weights compare with vanilla slots?

Vanilla as a whole has weight 100. If all custom entries on a route total 20,
custom species collectively appear in 20/120 of triggered encounters. The
original Gold slot ratios stay unchanged inside the remaining 100/120.

## Can custom species appear while fishing, during swarms, or in the Bug Contest?

Yes. Expanded Species has owned helpers for fishing rods, swarm-only
grass/water rows, and the global Bug-Catching Contest pool. Headbutt, Rock
Smash, and additional roaming slots are not exposed because Gold 0.1.94 does
not provide safe registry-based runtime seams for them.

## Why did the Pokédex AREA page show no nest marker or route name?

On older Gold builds the AREA renderer found grass and swimming nests
correctly but read the Gen 1 landmark field instead of Gold's `gen2Landmarks`
registry, so neither the marker nor the route name appeared.

**Current gen1recomp releases fix this in the engine**, and no bridge is
involved on those builds. On the older versions this mod still supports,
Expanded Species bridges the lookup so the flashing marker and route name
appear for both vanilla and custom species. If you are on a recent engine and
the AREA page misbehaves, that is worth reporting rather than assuming it is
this mod.

## How do I give a custom Pokemon its own colors?

Add `palette = { normal = {...}, shiny = {...} }` to its Expanded Species
definition. Each form supplies two RGB triples; Gold adds white and black.
Use `paletteFallback = "TANGELA"` to borrow a vanilla palette, or omit both to
use Ditto. A `trueColor = true` species uses the PNG's colors instead.

## Can one species have cosmetic forms?

Yes. Expanded Species stores a named form on each individual Pokemon and
routes it through battles, Summary, PC preview, evolution, NPC trades, Hall of
Fame, egg hatching, Photo Studio, and party/trade icons. The Pokedex displays
the species' `defaultForm` because it has no individual Pokemon record.
True-color form art bypasses palette remapping, but Gold still cannot choose a
separate palette table or cry per individual.

## How can a pack report compatibility or protect checkpoints?

Run `formatCompatibilityReport(mod)` after `game.ready` for a copyable summary
of species, placements, trainer patches, engine versions, and hidden records.
Checkpoint tools can store `checkpointProfile()` and compare it before restore.
Expanded Species reruns Save Guardian after a successful restore, but Gold
0.1.94 has no pre-restore event, so automatic preflight requires an upstream
engine addition.

## Can a species pack split Pokemon into separate Lua files?

Yes. Keep registration in `main.lua`, place definitions under `species/`, and
load them with the documented `mod:read` helper pattern. This works with
imported ZIPs and keeps cries, sprites, palettes and stats grouped by species.
On gen1recomp 0.1.94, `mod:list("species")` can discover the files inside both
folder and packaged mods.

## Can trainers, gifts, stationary encounters, and trades use custom species?

Yes. Expanded Species has provider-owned helpers for all four. They pass
registry string IDs directly to Gold's runtime systems, including IDs above
#255, and keep
one-time completion in the calling pack's `mod.save` namespace. Do not put a
virtual numeric index into Gold's original one-byte `givepoke`, `loadwildmon`,
`loadtrainer`, or trade operands.

## Can I add a custom Pokemon to an existing vanilla trainer?

Yes. Expanded Species' `patchVanillaTrainer` helper can insert a custom
member before any current party position, append one at the end, or replace a
position without changing party size. The trainer's normal NPC, dialogue,
defeated flag, rematches, music and reward rules remain intact. Parties stay capped
at six, and multiple packs are composed in a stable order with replacement
conflicts reported by `diagnoseTrainerPatches`.

## How do I test evolutions and shiny palettes quickly?

Get the individual you need directly into the party or a box rather than
hunting for it — most developer spawn tools can hand over a specific species,
level and shiny state. Then level it, use its evolution item, save and reload,
and send it into battle to check the back sprite. Starting a battle with it is
the fastest front-sprite and catch test.

## Troubleshooting

### I installed it and nothing happened

That is the expected behaviour. **Expanded Species adds no Pokemon on its own** —
it is the framework packs are built on. Install a species pack that declares it
as a dependency and the pack's Pokemon appear.

### It is acting like the old version

The mod hot-reloaded instead of loading fresh. **Fully quit** the app — swipe it
away, do not just background it — then relaunch and check the version in the
load log.

### An NPC turns to face me and then nothing happens

That is the signature of a script error being swallowed, not a missing
interaction. It is a real bug: please report it with the `[ERRS]` output below.

### Where do I find error messages?

Open the mod manager's **`[ERRS]`** screen. On a phone there is no console, so
this is the only place errors appear. Copy or screenshot anything there — even
if it looks unrelated — and include it with a bug report, along with the version
from the load log and which other mods were enabled.

### A pack's Pokemon vanished after I disabled the pack

They are not gone. Expanded Species quarantines Pokemon whose species pack is
missing and restores them when the pack returns — see "What happens if a species
pack is removed?" above. Do not edit `modData` by hand.

