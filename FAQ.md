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

Its species definitions disappear. Remove its custom Pokemon from your party
and boxes before disabling the pack, and keep a backup of the save.

## Does link play work?

Only when both sides have matching framework and species-pack data. Species
packs should declare `affects_link` in their manifests.

## Can a species pack add more than seven grass or three swimming entries?

Yes. Expanded Species 0.2.0 gives packs weighted grass and water placement
helpers with no fixed row-count ceiling. The original slots remain intact, the
map's encounter rate does not change, and enabled packs compose into one custom
pool. Practical memory and load time are the only slot-count boundary.

## How do custom encounter weights compare with vanilla slots?

Vanilla as a whole has weight 100. If all custom entries on a route total 20,
custom species collectively appear in 20/120 of triggered encounters. The
original Gold slot ratios stay unchanged inside the remaining 100/120.
