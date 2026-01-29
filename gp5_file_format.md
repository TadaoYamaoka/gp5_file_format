# Guitar Pro 5 (.gp5) Binary Format Specification

## Scope and Notes

* This document primarily targets **Guitar Pro 5 / 5.1** files
  (`version_number >= 500`)
* Where required, **GP3 / GP4 compatibility branches** are described
* Field semantics beyond what can be inferred structurally are intentionally conservative
* The structure and conditions follow `Gp3To5Importer.ts` and `guitar_pro_5.ksy`

---

## 1. Endianness and Primitive Types

* **Default endianness**: **Little-endian**
* **Exception**:

  * `note.duration_percent` → **`f8be`** (64-bit floating point, **big-endian**)

### Primitive Types (Kaitai → Meaning)

| Type        | Meaning                               |
| ----------- | ------------------------------------- |
| `u1` / `s1` | 1-byte unsigned / signed integer      |
| `u2` / `s2` | 2-byte unsigned / signed integer (LE) |
| `u4` / `s4` | 4-byte unsigned / signed integer (LE) |
| `f8be`      | 8-byte floating point (BE)            |

---

## 2. String Encoding and Utility Structures

All strings are interpreted as **UTF-8** in this document.
Note: the importer uses a configurable encoding at runtime.

### 2.1 `gp_string_int`

```
u4 length
byte[length] raw
```

---

### 2.2 `gp_string_int_byte`

```
u4 length_with_byte
u1 unused
byte[length_with_byte - 1] raw
```

---

### 2.3 `gp_string_int_unused`

```
u4 unused_length
u1 length
byte[length] raw
```

---

### 2.4 `gp_string_byte_length(fixed_len)`

```
u1 length
byte[length] raw
byte[fixed_len - length] padding
```

---

## 3. Top-Level File Structure

A `.gp5` file is parsed sequentially as follows:

1. `version` → `gp_version(30)`
2. `score_info` → `score_information`
3. `global_triplet_feel_pre_gp5` (`u1`, GP3/GP4: `version_number < 500`)
4. `lyrics` → `lyrics_block` (GP4+)
5. `rse_master_settings` (19 bytes, GP5.1+)
6. `page_setup` → `page_setup_block`
7. `tempo_label` → `gp_string_int_byte` (GP5+)
8. `tempo` → `u4`
9. `hide_tempo` → `u1` (GP5.1+)
10. `key_signature_and_octave_raw` → `u4`
11. `octave_extra` → `u1` (GP4+)
12. `playback_infos` → `playback_information_block`
13. `directions` → `directions_block` (GP5+)
14. `bar_count` → `u4`
15. `track_count` → `u4`
16. `master_bars[bar_count]`
17. `tracks[track_count]`
18. `bars[bar_count]` (`bar_set`)
19. `remaining` → uninterpreted tail

---

## 4. Version Header (`gp_version`)

Fixed length: **30 bytes**

```
u1 length
byte[length] raw
byte[30 - length] padding
```

### Derived Value: `version_number`

Parsed from the standard header string:

```
"FICHIER GUITAR PRO vX.YY"
```

```
version_number = X * 100 + YY
```

Examples:

| Header | version_number |
| ------ | -------------- |
| v3.00  | 300            |
| v4.06  | 406            |
| v5.10  | 510            |

Implementation note: in `guitar_pro_5.ksy`, version detection is heuristic
and may fall back to `500` if the header is unexpectedly short.

---

## 5. Score Metadata (`score_information`)

All fields are `gp_string_int_unused`, in order:

1. Title
2. Subtitle
3. Artist
4. Album
5. Words
6. Music *(GP5+)*
7. Copyright
8. Tab
9. Instructions
10. `u4 notice_line_count`
11. `notice_lines[]`

---

## 6. Lyrics (`lyrics_block`) – GP4+

```
u4 lyrics_track_1_based
lyrics_line[5]
```

### `lyrics_line`

```
u4 start_bar_1_based
gp_string_int text
```

---

## 7. Page Setup (`page_setup_block`)

```
byte[28] page_metrics_raw
u2 flags
gp_string_int_byte title_template
gp_string_int_byte subtitle_template
gp_string_int_byte artist_template
gp_string_int_byte album_template
gp_string_int_byte words_template
gp_string_int_byte music_template
gp_string_int_byte words_and_music_template
gp_string_int_byte copyright_template
gp_string_int_byte copyright_second_line_template
gp_string_int_byte page_number_format
```

---

## 8. Tempo

* `tempo_label` → `gp_string_int_byte` (GP5+)
* `tempo` → `u4`
* `hide_tempo` → `u1` (GP5.1+)

---

## 9. Playback Channels (`playback_information_block`)

Fixed array of **64 entries**.

### `playback_information`

```
u4 program
u1 volume
u1 balance
byte[6] reserved
```

---

## 10. Directions (`directions_block`) – GP5+

```
s2 direction_indices[19]
byte[4] unknown_after_directions
```

Indices are 1-based; `-1` may indicate unused.

---

## 11. Master Bars (`master_bar`)

Represents **global bar attributes** (time signature, key, repeats).

### Fields

```
u1 flags
[conditional fields]
byte[4] time_sig_padding_gp5 (if GP5+ and flags & 0x03)
u1 alternate_endings_gp5
u1 triplet_feel_gp5
u1 unknown_after_triplet_feel_gp5
```

### Conditional Fields (by `flags`)

| Bit    | Field                                   |
| ------ | --------------------------------------- |
| `0x01` | `time_sig_numerator`                    |
| `0x02` | `time_sig_denominator`                  |
| `0x04` | repeat start                            |
| `0x08` | `repeat_count_raw`                      |
| `0x10` | `alternate_endings_pre_gp5_mask` (GP4−) |
| `0x20` | `section`                               |
| `0x40` | `key_signature`                         |
| `0x80` | double bar                              |

Additional GP5+ details:

* If `version_number >= 500` and `(flags & 0x03) != 0`, 4 bytes are skipped
* `alternate_endings_gp5` and `triplet_feel_gp5` are always read in GP5+
* Repeat count interpretation (as used by alphaTab):
  * GP3/4: `repeat_count_raw + 1`
  * GP5+: `repeat_count_raw` as-is
* Pre-GP5 alternate endings mask is not a strict bitmask in practice:
  * alphaTab derives the actual endings by scanning back to the repeat start and
    only enabling still-unused alternatives.

---

## 12. Tracks (`track`)

### Core Fields

```
u1 flags
gp_string_byte_length(40) name
u4 string_count
s4 tunings[7]
s4 port
s4 channel_index_1_based
s4 effect_channel_index_1_based
s4 fret_count
s4 capo
gp_color color
```

Track flag bits (observed in importer comments):

* `0x01`: percussion track
* `0x08`: visible on multi-track view (GP5+)
* `0x10`: solo (via playback info)
* `0x20`: mute (via playback info)
* `0x80`: show tuning

### GP5+ Extensions

Includes staff flags, RSE parameters, clef mode, and opaque blocks:

```
u1 staff_flags
u1 midi_auto_flags
u1 rse_auto_accentuation
u1 bank
u1 human_playing
s4 clef_mode
s4 unknown_a
s4 unknown_b
byte[10] unknown_10
u1 unknown_c
u1 unknown_d
rse_bank
[GP5.1+] eq_3_band (4 bytes)
[GP5.1+] effect_name (gp_string_int_byte)
[GP5.1+] effect_category (gp_string_int_byte)
```

`staff_flags` (as interpreted by the importer):

* `0x01`: show tablature
* `0x02`: show standard notation
* `(staff_flags & 0x64) != 0`: show chord diagrams on top (heuristic)

---

## 13. Bars → Voices → Beats → Notes

### 13.1 `bar_set`

Contains one `bar_for_track` per track.

---

### 13.2 `bar_for_track`

* GP5+: always **2 voices**
* Pre-GP5: **1 voice**
* GP5+: a leading `u1 voice_header_gp5` byte exists (semantics unknown)

---

### 13.3 `voice`

```
u4 beat_count
beat[beat_count]
```

If `beat_count == 0`, the voice has no payload.

---

### 13.4 `beat`

```
u1 flags
[if flags & 0x40] u1 beat_type
s1 duration
[if flags & 0x20] u4 tuplet_numerator
[if flags & 0x02] chord
[if flags & 0x04] text
[if flags & 0x08] beat_effects
[if flags & 0x10] mix_table_change
u1 string_flags
[notes from string_flags]
[if GP5+] u2 flags2_gp5
[if GP5+ and flags2_gp5 & 0x800] u1 break_secondary_beams
```

Additional beat details:

* `flags & 0x01`: dotted beat (dots = 1)
* `duration` maps as: `-2=whole, -1=half, 0=quarter, 1=eighth, 2=sixteenth, 3=32nd, 4=64th`
* Tuplet denominators are derived from the numerator by importer logic
* `beat_type` (when present): bit `0x02` set ⇒ non-empty beat, otherwise treated as rest

#### `beat.flags`

| Bit    | Meaning          |
| ------ | ---------------- |
| `0x02` | chord            |
| `0x04` | text             |
| `0x08` | beat effects     |
| `0x10` | mix table change |
| `0x20` | tuplet           |
| `0x40` | beat type        |

#### String Mask

Bits 6..0 correspond to strings 0..6.

Only strings within the staff tuning length are materialized as notes.

---

### 13.5 `note`

```
u1 flags
[conditional fields]
```

#### `note.flags`

| Bit    | Meaning          |
| ------ | ---------------- |
| `0x01` | duration info    |
| `0x02` | heavy accent     |
| `0x04` | ghost note       |
| `0x08` | note effects     |
| `0x10` | dynamic          |
| `0x20` | note type + fret |
| `0x40` | normal accent    |
| `0x80` | fingering        |

* GP5+: `duration_percent` (`f8be`)
* Pre-GP5: discrete duration + tuplet

Additional GP5+ detail:

* After `duration_percent` (if present), a `u1 flags2_gp5` byte is read
  (used by the importer for accidental swapping)
* Observed `note_type` values:
  * `2`: tie destination
  * `3`: dead note

---

## 14. Chords

### GP5 Format

Contains fixed-layout fret and barre definitions with name and padding:

```
byte[17] skip
gp_string_byte_length(21) name
byte[4] skip
s4 first_fret
s4 frets[7]
u1 number_of_barres
u1 barre_frets[5]
byte[26] skip
```

### Legacy Format

Used in GP3/GP4, format determined by leading flag byte:

* `format_flag != 0` and GP4+: extended GP4 block
* `format_flag != 0` and pre-GP4: legacy extended block
* `format_flag == 0`: compact block

---

## 15. Mix Table Change

Per-beat parameter automation (instrument, volume, effects, tempo).

Supports:

* Per-parameter duration
* Tempo name + hide flag (GP5.1+)
* RSE bank overrides

Structure (simplified, GP5+ branches shown explicitly):

```
s1 instrument
[GP5+] rse_bank
s1 volume
s1 balance
s1 chorus
s1 reverb
s1 phaser
s1 tremolo
[GP5+] gp_string_int_byte tempo_name
s4 tempo
[conditional per-parameter durations]
[if tempo >= 0] s1 tempo_duration
[GP5.1+ and tempo >= 0] u1 tempo_hide
[GP4+] u1 mix_table_flags
[GP5+] s1 wah_type
[GP5.1+] gp_string_int_byte unknown_a
[GP5.1+] gp_string_int_byte unknown_b
```

Notes (alphaTab behavior):
* Parameter values are `-1` when no change is requested.
* `volume` / `balance` are often in `0..15` and are scaled for MIDI (e.g. `value * 8`).
* `wah_type`: `>=100` => closed, `>=0` => open, `-1` => off.

---

## 16. Beat Effects

Includes:

* Slap / pop
* Tremolo bar
* Stroke direction
* Pick stroke

Version-dependent ordering and flags apply.

Important ordering details:

* `flags` is always read; `flags2` exists in GP4+
* In pre-GP4, slap/pop includes an additional 4-byte padding block
* Stroke byte order differs:
  * pre-GP5: `stroke_down` then `stroke_up`
  * GP5+: `stroke_up` then `stroke_down`
* In pre-GP4, `flags & 0x04/0x08` implies harmonics applied to all notes
* Beat vibrato:
  * Pre-GP4 uses `flags & 0x01`
  * GP4+ uses `flags & 0x02`
  * GP5 does not encode “wide” vibrato; it is treated as “slight” in alphaTab
* `flags2` (GP4+) observed bits:
  * `0x01`: rasgueado (used for rapid brush-style strums)

---

## 17. Note Effects

Includes:

* Bend
* Grace note
* Tremolo picking
* Slide
* Artificial harmonic
* Trill

Each effect has its own structured payload.

Ordering summary:

```
u1 flags
[GP4+] u1 flags2
[if flags & 0x01] bend_effect
[if flags & 0x10] grace_effect
[GP4+ and flags2 & 0x04] tremolo_picking
[GP4+ and flags2 & 0x08] slide
[GP4+ and flags2 & 0x10] artificial_harmonic
[GP4+ and flags2 & 0x20] trill
```

Pre-GP4 nuance:

* If no slide payload exists and `flags & 0x04` is set, the importer implies a shift slide-out
* Note vibrato (GP4+): `flags2 & 0x40` indicates slight vibrato only (no “wide” in GP5)
* `flags2` (GP4+) observed bits:
  * `0x01`: staccato
  * `0x02`: palm mute
  * `0x40`: vibrato (slight)

Grace note (GP5) detail:

* `grace.flags_gp5 & 0x02` ⇒ on-beat grace (otherwise before-beat)

---

## 18. Percussion Articulations (GP5)

For percussion tracks, `note.fret` encodes a **percussion articulation ID**, not a MIDI key.
alphaTab maps this ID to the final MIDI note via its `PercussionMapper` lookup.

---

## 18. Remaining Data

Any unread bytes are preserved as `remaining`.

This allows forward compatibility with:

* Extended RSE data
* Vendor-specific additions

---

## Appendix A: Flag Summary

### Master Bar Flags

| Bit  | Meaning                    |
| ---- | -------------------------- |
| 0x01 | Time signature numerator   |
| 0x02 | Time signature denominator |
| 0x04 | Repeat start               |
| 0x08 | Repeat count               |
| 0x10 | Alternate endings (pre-GP5) |
| 0x20 | Section                    |
| 0x40 | Key signature              |
| 0x80 | Double bar                 |

---

### Beat Flags

| Bit  | Meaning      |
| ---- | ------------ |
| 0x02 | Chord        |
| 0x04 | Text         |
| 0x08 | Beat effects |
| 0x10 | Mix change   |
| 0x20 | Tuplet       |
| 0x40 | Beat type    |

---

### Note Flags

| Bit  | Meaning     |
| ---- | ----------- |
| 0x01 | Duration    |
| 0x02 | Heavy accent |
| 0x04 | Ghost note  |
| 0x08 | Effects     |
| 0x10 | Dynamic     |
| 0x20 | Fret / type |
| 0x40 | Normal accent |
| 0x80 | Fingering   |

---

### Beat Flags2 (GP5+)

`flags2_gp5` (u2) is read after notes in GP5+:

* `0x0001`: break beams (affects previous beat)
* `0x0002`: force beams down
* `0x0004`: force beams / merge with next (affects previous beat)
* `0x0008`: force beams up
* `0x0010`: ottava 8va
* `0x0020`: ottava 8vb
* `0x0040`: ottava 15ma
* `0x0100`: ottava 15mb
* `0x0800`: break secondary beams flag present → read `u1 break_secondary_beams`
