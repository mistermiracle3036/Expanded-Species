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

Expanded Species 0.5 moves Pokemon whose definitions are missing into private
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

## How do I give a custom Pokemon its own colors?

Add `palette = { normal = {...}, shiny = {...} }` to its Expanded Species
definition. Each form supplies two RGB triples; Gold adds white and black.
Use `paletteFallback = "TANGELA"` to borrow a vanilla palette, or omit both to
use Ditto. A `trueColor = true` species uses the PNG's colors instead.

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

Yes. Expanded Species 0.4's `patchVanillaTrainer` helper can insert a custom
member before any current party position, append one at the end, or replace a
position without changing party size. The trainer's normal NPC, dialogue,
defeated flag, rematches, music and reward rules remain intact. Parties stay capped
at six, and multiple packs are composed in a stable order with replacement
conflicts reported by `diagnoseTrainerPatches`.

## How do I test evolutions and shiny palettes quickly?

Battle Spawner 0.4.0 adds `ACTION = GIVE MON` and `FORM = SHINY`. Give the mon
to the party or box, then level it, use its evolution item, save/reload, and
send it into battle to check the back sprite. Its normal battle action remains
the fastest front-sprite and catch test.
