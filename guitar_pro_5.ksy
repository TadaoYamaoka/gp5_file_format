meta:
  id: guitar_pro_5
  title: Guitar Pro 5 (.gp5)
  file-extension: gp5
  endian: le

doc: |
  A practical Kaitai Struct definition for Guitar Pro 5 (.gp5) files,
  based on the parsing logic implemented in alphaTab:
  packages/alphatab/src/importer/Gp3To5Importer.ts

  Notes / limitations:
  - This spec now models tracks and the bar/voice/beat/note hierarchy.
  - Some substructures are still approximations of the importer behavior.
  - Version detection is heuristic and targets GP3/GP4/GP5-style headers.

seq:
  - id: version
    type: gp_version(30)
  - id: score_info
    type: score_information
  - id: global_triplet_feel_pre_gp5
    type: u1
    if: version.version_number < 500
    doc: "Pre-GP5 global triplet feel flag (bool in importer)."
  - id: lyrics
    type: lyrics_block
    if: version.version_number >= 400
  - id: rse_master_settings
    size: 19
    if: version.version_number >= 510
    doc: "RSE master settings block (skipped by importer)."
  - id: page_setup
    type: page_setup_block
    if: version.version_number >= 500
  - id: tempo_label
    type: gp_string_int_byte
    if: version.version_number >= 500
  - id: tempo
    type: u4
  - id: hide_tempo
    type: u1
    if: version.version_number >= 510
  - id: key_signature_and_octave_raw
    type: u4
    doc: "Importer reads and ignores this 32-bit field."
  - id: octave_extra
    type: u1
    if: version.version_number >= 400
  - id: playback_infos
    type: playback_information_block
  - id: directions
    type: directions_block
    if: version.version_number >= 500
  - id: bar_count
    type: u4
  - id: track_count
    type: u4
  - id: master_bars
    type: master_bar
    repeat: expr
    repeat-expr: bar_count
  - id: tracks
    type: track
    repeat: expr
    repeat-expr: track_count
  - id: bars
    type: bar_set
    repeat: expr
    repeat-expr: bar_count
  - id: remaining
    size-eos: true
    doc: |
      Any bytes left after the parsed structure.

types:
  gp_bool:
    seq:
      - id: value
        type: u1
    instances:
      as_bool:
        value: value != 0

  gp_version:
    doc: |
      Version header. Implemented as a byte array (instead of a string)
      so that Kaitai expressions can index into it reliably in ksv.
      The derived `version_number` is a GP3/GP4/GP5 heuristic.
    params:
      - id: fixed_len
        type: u4
    seq:
      - id: str_len
        type: u1
      - id: raw_bytes
        type: u1
        repeat: expr
        repeat-expr: str_len
      - id: padding
        size: fixed_len - str_len
        if: fixed_len > str_len
    instances:
      version_number:
        value: "(str_len >= 24) ? (((raw_bytes[20] - 48) * 100) + ((raw_bytes[22] - 48) * 10) + (raw_bytes[23] - 48)) : 500"
        doc: |
          Heuristic version detection without string ops, based on the common
          header "FICHIER GUITAR PRO vX.YY":
          - raw_bytes[20] => major digit X
          - raw_bytes[22..23] => minor digits YY
          Examples: 3.00 -> 300, 4.06 -> 406, 5.10 -> 510.
          If the header is unexpectedly short (str_len < 24), this falls back
          to 500.

  gp_color:
    doc: "Color as read by GpBinaryHelpers.gpReadColor(readAlpha = false)."
    seq:
      - id: r
        type: u1
      - id: g
        type: u1
      - id: b
        type: u1
      - id: unused_alpha
        type: u1

  gp_string_byte_length:
    doc: |
      Reads a byte-sized string length, then reads that many bytes, and
      skips the remaining padding up to the fixed length.
      Mirrors GpBinaryHelpers.gpReadStringByteLength.
    params:
      - id: fixed_len
        type: u4
    seq:
      - id: str_len
        type: u1
      - id: raw
        size: str_len
      - id: padding
        size: fixed_len - str_len
        if: fixed_len > str_len
    instances:
      value:
        value: raw.to_s("UTF-8")

  gp_string_int:
    doc: "Reads a 32-bit length, then that many bytes."
    seq:
      - id: str_len
        type: u4
      - id: raw
        size: str_len
    instances:
      value:
        value: raw.to_s("UTF-8")

  gp_string_int_byte:
    doc: |
      Reads a 32-bit size, skips one byte, then reads (size - 1) bytes.
      Mirrors GpBinaryHelpers.gpReadStringIntByte.
    seq:
      - id: str_len_with_byte
        type: u4
      - id: unused_byte
        type: u1
      - id: raw
        size: str_len_with_byte - 1
        if: str_len_with_byte > 0
    instances:
      value:
        value: raw.to_s("UTF-8")

  gp_string_int_unused:
    doc: |
      Skips a 32-bit integer, then reads a byte-sized string.
      Mirrors GpBinaryHelpers.gpReadStringIntUnused.
    seq:
      - id: unused_len
        type: u4
      - id: str_len
        type: u1
      - id: raw
        size: str_len
    instances:
      value:
        value: raw.to_s("UTF-8")

  score_information:
    seq:
      - id: title
        type: gp_string_int_unused
      - id: subtitle
        type: gp_string_int_unused
      - id: artist
        type: gp_string_int_unused
      - id: album
        type: gp_string_int_unused
      - id: words
        type: gp_string_int_unused
      - id: music
        type: gp_string_int_unused
        if: _root.version.version_number >= 500
      - id: copyright
        type: gp_string_int_unused
      - id: tab
        type: gp_string_int_unused
      - id: instructions
        type: gp_string_int_unused
      - id: notice_line_count
        type: u4
      - id: notice_lines
        type: gp_string_int_unused
        repeat: expr
        repeat-expr: notice_line_count

  lyrics_line:
    seq:
      - id: start_bar_1_based
        type: u4
      - id: text
        type: gp_string_int

  lyrics_block:
    doc: "Lyrics block present since GP4."
    seq:
      - id: lyrics_track_1_based
        type: u4
      - id: lines
        type: lyrics_line
        repeat: expr
        repeat-expr: 5

  page_setup_block:
    doc: "Page setup block present since GP5."
    seq:
      - id: page_metrics_raw
        size: 28
        doc: "Page width/height/padding/size proportion (skipped by importer)."
      - id: flags
        type: u2
      - id: title_template
        type: gp_string_int_byte
      - id: subtitle_template
        type: gp_string_int_byte
      - id: artist_template
        type: gp_string_int_byte
      - id: album_template
        type: gp_string_int_byte
      - id: words_template
        type: gp_string_int_byte
      - id: music_template
        type: gp_string_int_byte
      - id: words_and_music_template
        type: gp_string_int_byte
      - id: copyright_template
        type: gp_string_int_byte
      - id: copyright_second_line_template
        type: gp_string_int_byte
      - id: page_number_format
        type: gp_string_int_byte

  playback_information:
    doc: "One of 64 playback channel entries."
    seq:
      - id: program
        type: u4
      - id: volume
        type: u1
      - id: balance
        type: u1
      - id: reserved
        size: 6

  playback_information_block:
    seq:
      - id: entries
        type: playback_information
        repeat: expr
        repeat-expr: 64

  directions_block:
    doc: |
      Direction indices (1-based, -1 means not set) appear since GP5.
      The importer reads 19 s16 values and then skips 4 unknown bytes.
    seq:
      - id: direction_indices
        type: s2
        repeat: expr
        repeat-expr: 19
      - id: unknown_after_directions
        size: 4

  master_bar:
    doc: "Master bar header. This follows the importer closely."
    seq:
      - id: flags
        type: u1
      - id: time_sig_numerator
        type: u1
        if: (flags & 0x01) != 0
      - id: time_sig_denominator
        type: u1
        if: (flags & 0x02) != 0
      - id: repeat_count_raw
        type: u1
        if: (flags & 0x08) != 0
      - id: alternate_endings_pre_gp5_mask
        type: u1
        if: (_root.version.version_number < 500) and ((flags & 0x10) != 0)
        doc: |
          Pre-GP5 alternate endings value. Despite the name, alphaTab treats
          this more like a repeat-count-style value than a strict bit mask.
      - id: section
        type: master_bar_section
        if: (flags & 0x20) != 0
      - id: key_signature
        type: master_bar_key_signature
        if: (flags & 0x40) != 0
      - id: time_sig_padding_gp5
        size: 4
        if: (_root.version.version_number >= 500) and ((flags & 0x03) != 0)
      - id: alternate_endings_gp5
        type: u1
        if: _root.version.version_number >= 500
      - id: triplet_feel_gp5
        type: u1
        if: _root.version.version_number >= 500
      - id: unknown_after_triplet_feel_gp5
        type: u1
        if: _root.version.version_number >= 500

  master_bar_section:
    seq:
      - id: text
        type: gp_string_int_byte
      - id: color
        type: gp_color

  master_bar_key_signature:
    seq:
      - id: key_signature
        type: s1
      - id: key_signature_type
        type: u1

  track:
    doc: "Track header as parsed by readTrack."
    seq:
      - id: flags
        type: u1
      - id: name
        type: gp_string_byte_length(40)
      - id: string_count
        type: u4
      - id: tunings_all
        type: s4
        repeat: expr
        repeat-expr: 7
      - id: port
        type: s4
      - id: channel_index_1_based
        type: s4
      - id: effect_channel_index_1_based
        type: s4
      - id: fret_count
        type: s4
      - id: capo
        type: s4
      - id: color
        type: gp_color
      - id: gp5_extras
        type: track_gp5_extras
        if: _root.version.version_number >= 500
    instances:
      name_str:
        value: name.value

  track_gp5_extras:
    doc: "Additional GP5/GP5.1 track fields."
    seq:
      - id: staff_flags
        type: u1
      - id: midi_auto_flags
        type: u1
      - id: rse_auto_accentuation
        type: u1
      - id: bank
        type: u1
      - id: human_playing
        type: u1
      - id: clef_mode
        type: s4
      - id: unknown_a
        type: s4
      - id: unknown_b
        type: s4
      - id: unknown_10
        size: 10
      - id: unknown_c
        type: u1
      - id: unknown_d
        type: u1
      - id: rse_bank
        type: rse_bank
      - id: gp51_extras
        type: track_gp51_extras
        if: _root.version.version_number >= 510

  track_gp51_extras:
    doc: "GP5.1 track extras."
    seq:
      - id: eq_3_band
        size: 4
      - id: effect_name
        type: gp_string_int_byte
      - id: effect_category
        type: gp_string_int_byte

  rse_bank:
    doc: "RSE bank descriptor (4x int32, skipped by importer)."
    seq:
      - id: instrument
        type: s4
      - id: variation
        type: s4
      - id: soundbank
        type: s4
      - id: unknown
        type: s4

  bar_set:
    doc: "One master bar worth of per-track bars."
    seq:
      - id: tracks
        type: bar_for_track(_root.tracks[_index])
        repeat: expr
        repeat-expr: _root.track_count

  bar_for_track:
    doc: |
      Per-track bar payload. In GP5+, a single voice header byte is present
      but alphaTab currently reads and ignores it; we expose its bits.
    params:
      - id: track
        type: track
    seq:
      - id: voice_header_gp5
        type: u1
        if: _root.version.version_number >= 500
      - id: voices
        type: voice(track)
        repeat: expr
        repeat-expr: voice_count
    instances:
      voice_count:
        value: "(_root.version.version_number >= 500) ? 2 : 1"
      voice_header_is_zero:
        value: voice_header_gp5 == 0
        if: _root.version.version_number >= 500
        doc: "Observation helper: header byte is zero."
      has_voice_1_guess_bit0:
        value: (voice_header_gp5 & 0x01) != 0
        if: _root.version.version_number >= 500
        doc: "Hypothesis: bit0 indicates voice 1 present."
      has_voice_2_guess_bit1:
        value: (voice_header_gp5 & 0x02) != 0
        if: _root.version.version_number >= 500
        doc: "Hypothesis: bit1 indicates voice 2 present."
      has_both_voices_guess_bits01:
        value: has_voice_1_guess_bit0 and has_voice_2_guess_bit1
        if: _root.version.version_number >= 500
        doc: "Hypothesis: both voices present when bits 0 and 1 are set."
      voice_header_low_nibble:
        value: voice_header_gp5 & 0x0f
        if: _root.version.version_number >= 500
        doc: "Observation helper: low nibble."
      voice_header_high_nibble:
        value: (voice_header_gp5 >> 4) & 0x0f
        if: _root.version.version_number >= 500
        doc: "Observation helper: high nibble."
      voice_header_bit_0:
        value: (voice_header_gp5 & 0x01) != 0
        if: _root.version.version_number >= 500
        doc: "Unknown meaning."
      voice_header_bit_1:
        value: (voice_header_gp5 & 0x02) != 0
        if: _root.version.version_number >= 500
        doc: "Unknown meaning."
      voice_header_bit_2:
        value: (voice_header_gp5 & 0x04) != 0
        if: _root.version.version_number >= 500
        doc: "Unknown meaning."
      voice_header_bit_3:
        value: (voice_header_gp5 & 0x08) != 0
        if: _root.version.version_number >= 500
        doc: "Unknown meaning."
      voice_header_bit_4:
        value: (voice_header_gp5 & 0x10) != 0
        if: _root.version.version_number >= 500
        doc: "Unknown meaning."
      voice_header_bit_5:
        value: (voice_header_gp5 & 0x20) != 0
        if: _root.version.version_number >= 500
        doc: "Unknown meaning."
      voice_header_bit_6:
        value: (voice_header_gp5 & 0x40) != 0
        if: _root.version.version_number >= 500
        doc: "Unknown meaning."
      voice_header_bit_7:
        value: (voice_header_gp5 & 0x80) != 0
        if: _root.version.version_number >= 500
        doc: "Unknown meaning."

  voice:
    params:
      - id: track
        type: track
    seq:
      - id: beat_count
        type: u4
      - id: beats
        type: beat(track)
        repeat: expr
        repeat-expr: beat_count
        if: beat_count > 0

  beat:
    params:
      - id: track
        type: track
    doc: "Beat body with flag-dependent optional sections."
    seq:
      - id: flags
        type: u1
      - id: beat_type
        type: u1
        if: (flags & 0x40) != 0
      - id: duration
        type: s1
      - id: tuplet_numerator
        type: u4
        if: (flags & 0x20) != 0
      - id: chord
        type: chord
        if: (flags & 0x02) != 0
      - id: text
        type: gp_string_int_unused
        if: (flags & 0x04) != 0
      - id: beat_effects
        type: beat_effects
        if: (flags & 0x08) != 0
      - id: mix_table_change
        type: mix_table_change
        if: (flags & 0x10) != 0
      - id: string_flags
        type: u1
      - id: note_0
        type: note
        if: (track.string_count > 0) and ((string_flags & (1 << 6)) != 0)
      - id: note_1
        type: note
        if: (track.string_count > 1) and ((string_flags & (1 << 5)) != 0)
      - id: note_2
        type: note
        if: (track.string_count > 2) and ((string_flags & (1 << 4)) != 0)
      - id: note_3
        type: note
        if: (track.string_count > 3) and ((string_flags & (1 << 3)) != 0)
      - id: note_4
        type: note
        if: (track.string_count > 4) and ((string_flags & (1 << 2)) != 0)
      - id: note_5
        type: note
        if: (track.string_count > 5) and ((string_flags & (1 << 1)) != 0)
      - id: note_6
        type: note
        if: (track.string_count > 6) and ((string_flags & (1 << 0)) != 0)
      - id: flags2_gp5
        type: u2
        if: _root.version.version_number >= 500
      - id: break_secondary_beams
        type: u1
        if: (_root.version.version_number >= 500) and ((flags2_gp5 & 0x800) != 0)
    instances:
      flags2_break_beams:
        value: (flags2_gp5 & 0x0001) != 0
        if: _root.version.version_number >= 500
        doc: "1 - Break beams (affects previous beat)."
      flags2_force_beams_down:
        value: (flags2_gp5 & 0x0002) != 0
        if: _root.version.version_number >= 500
        doc: "2 - Force beams down."
      flags2_force_beams:
        value: (flags2_gp5 & 0x0004) != 0
        if: _root.version.version_number >= 500
        doc: "4 - Force beams (merge with next; affects previous beat)."
      flags2_force_beams_up:
        value: (flags2_gp5 & 0x0008) != 0
        if: _root.version.version_number >= 500
        doc: "8 - Force beams up."
      flags2_ottava_8va:
        value: (flags2_gp5 & 0x0010) != 0
        if: _root.version.version_number >= 500
        doc: "16 - Ottava 8va."
      flags2_ottava_8vb:
        value: (flags2_gp5 & 0x0020) != 0
        if: _root.version.version_number >= 500
        doc: "32 - Ottava 8vb."
      flags2_ottava_15ma:
        value: (flags2_gp5 & 0x0040) != 0
        if: _root.version.version_number >= 500
        doc: "64 - Ottava 15ma."
      flags2_unknown_0x0080:
        value: (flags2_gp5 & 0x0080) != 0
        if: _root.version.version_number >= 500
        doc: "128 - Unknown."
      flags2_ottava_15mb:
        value: (flags2_gp5 & 0x0100) != 0
        if: _root.version.version_number >= 500
        doc: "256 - Ottava 15mb."
      flags2_unknown_0x0200:
        value: (flags2_gp5 & 0x0200) != 0
        if: _root.version.version_number >= 500
        doc: "512 - Unknown."
      flags2_unknown_0x0400:
        value: (flags2_gp5 & 0x0400) != 0
        if: _root.version.version_number >= 500
        doc: "1024 - Unknown."
      flags2_break_secondary_beams_flag:
        value: (flags2_gp5 & 0x0800) != 0
        if: _root.version.version_number >= 500
        doc: "2048 - Break secondary beams flag present."
      flags2_unknown_0x1000:
        value: (flags2_gp5 & 0x1000) != 0
        if: _root.version.version_number >= 500
        doc: "4096 - Unknown."
      flags2_unknown_0x2000:
        value: (flags2_gp5 & 0x2000) != 0
        if: _root.version.version_number >= 500
        doc: "8192 - Possibly force tuplet bracket (per importer comment)."
      flags2_unknown_0x4000:
        value: (flags2_gp5 & 0x4000) != 0
        if: _root.version.version_number >= 500
        doc: "16384 - Unknown."
      flags2_unknown_0x8000:
        value: (flags2_gp5 & 0x8000) != 0
        if: _root.version.version_number >= 500
        doc: "32768 - Unknown."
      ottava_code:
        value: |
          flags2_ottava_8va ? "8va" :
          flags2_ottava_8vb ? "8vb" :
          flags2_ottava_15ma ? "15ma" :
          flags2_ottava_15mb ? "15mb" :
          ""
        if: _root.version.version_number >= 500

  chord:
    doc: "Chord diagram data. GP5 path modeled explicitly."
    seq:
      - id: chord_block_gp5
        type: chord_gp5
        if: _root.version.version_number >= 500
      - id: chord_block_legacy
        type: chord_legacy
        if: _root.version.version_number < 500

  chord_gp5:
    seq:
      - id: header_skip
        size: 17
      - id: name
        type: gp_string_byte_length(21)
      - id: skip_after_name
        size: 4
      - id: first_fret
        type: s4
      - id: frets
        type: s4
        repeat: expr
        repeat-expr: 7
      - id: number_of_barres
        type: u1
      - id: barre_frets_raw
        type: u1
        repeat: expr
        repeat-expr: 5
      - id: skip_tail
        size: 26
    instances:
      name_str:
        value: name.value
      number_of_barres_clamped:
        value: "(number_of_barres > 5) ? 5 : number_of_barres"
        doc: "Clamped to available raw entries (5)."
      barre_fret_0:
        value: barre_frets_raw[0]
        if: number_of_barres_clamped > 0
      barre_fret_1:
        value: barre_frets_raw[1]
        if: number_of_barres_clamped > 1
      barre_fret_2:
        value: barre_frets_raw[2]
        if: number_of_barres_clamped > 2
      barre_fret_3:
        value: barre_frets_raw[3]
        if: number_of_barres_clamped > 3
      barre_fret_4:
        value: barre_frets_raw[4]
        if: number_of_barres_clamped > 4

  chord_legacy:
    doc: |
      Pre-GP5 chord variants as parsed by readChord:
      - format_flag != 0 and version >= 400: GP4-style extended block
      - format_flag != 0 and version < 400: legacy extended block
      - format_flag == 0: compact block (GP3/4/early 5)
    seq:
      - id: format_flag
        type: u1
      - id: gp4_extended
        type: chord_legacy_gp4
        if: (format_flag != 0) and (_root.version.version_number >= 400)
      - id: gp3_extended
        type: chord_legacy_gp3
        if: (format_flag != 0) and (_root.version.version_number < 400)
      - id: compact
        type: chord_legacy_compact
        if: format_flag == 0

  chord_legacy_gp4:
    doc: "GP4-style extended chord block."
    seq:
      - id: header_skip
        size: 16
      - id: name
        type: gp_string_byte_length(21)
      - id: skip_after_name
        size: 4
      - id: first_fret
        type: s4
      - id: frets
        type: s4
        repeat: expr
        repeat-expr: 7
      - id: number_of_barres
        type: u1
      - id: barre_frets_raw
        type: u1
        repeat: expr
        repeat-expr: 5
      - id: tail_skip
        size: 26
    instances:
      name_str:
        value: name.value
      number_of_barres_clamped:
        value: "(number_of_barres > 5) ? 5 : number_of_barres"
        doc: "Clamped to available raw entries (5)."
      barre_fret_0:
        value: barre_frets_raw[0]
        if: number_of_barres_clamped > 0
      barre_fret_1:
        value: barre_frets_raw[1]
        if: number_of_barres_clamped > 1
      barre_fret_2:
        value: barre_frets_raw[2]
        if: number_of_barres_clamped > 2
      barre_fret_3:
        value: barre_frets_raw[3]
        if: number_of_barres_clamped > 3
      barre_fret_4:
        value: barre_frets_raw[4]
        if: number_of_barres_clamped > 4

  chord_legacy_gp3:
    doc: "Legacy extended chord block used before GP4."
    seq:
      - id: header_skip
        size: 25
      - id: name
        type: gp_string_byte_length(34)
      - id: first_fret
        type: s4
      - id: frets
        type: s4
        repeat: expr
        repeat-expr: 6
      - id: tail_skip
        size: 36
    instances:
      name_str:
        value: name.value

  chord_legacy_compact:
    doc: "Compact chord block when format_flag == 0."
    seq:
      - id: name
        type: gp_string_int_byte
      - id: first_fret
        type: s4
      - id: frets
        type: s4
        repeat: expr
        repeat-expr: string_count_for_version
        if: first_fret > 0
    instances:
      string_count_for_version:
        value: "(_root.version.version_number >= 406) ? 7 : 6"
      name_str:
        value: name.value

  beat_effects:
    doc: "Beat-level effects as read by readBeatEffects."
    seq:
      - id: flags
        type: u1
      - id: flags2
        type: u1
        if: _root.version.version_number >= 400
      - id: slap_pop
        type: s1
        if: (flags & 0x20) != 0
      - id: slap_pop_padding_pre_gp4
        size: 4
        if: (_root.version.version_number < 400) and ((flags & 0x20) != 0)
      - id: tremolo_bar
        type: bend_effect
        if: (_root.version.version_number >= 400) and ((flags2 & 0x04) != 0)
      - id: stroke_down_pre_gp5
        type: u1
        if: (_root.version.version_number < 500) and ((flags & 0x40) != 0)
      - id: stroke_up_pre_gp5
        type: u1
        if: (_root.version.version_number < 500) and ((flags & 0x40) != 0)
      - id: stroke_up_gp5
        type: u1
        if: (_root.version.version_number >= 500) and ((flags & 0x40) != 0)
      - id: stroke_down_gp5
        type: u1
        if: (_root.version.version_number >= 500) and ((flags & 0x40) != 0)
      - id: pick_stroke
        type: s1
        if: (_root.version.version_number >= 400) and ((flags2 & 0x02) != 0)
    instances:
      stroke_up:
        value: "(_root.version.version_number < 500) ? stroke_up_pre_gp5 : stroke_up_gp5"
        if: (flags & 0x40) != 0
      stroke_down:
        value: "(_root.version.version_number < 500) ? stroke_down_pre_gp5 : stroke_down_gp5"
        if: (flags & 0x40) != 0
      pre_gp4_all_notes_harmonic_natural:
        value: (flags & 0x04) != 0
        if: _root.version.version_number < 400
        doc: "Pre-GP4: importer applies natural harmonics to all notes."
      pre_gp4_all_notes_harmonic_artificial:
        value: (flags & 0x08) != 0
        if: _root.version.version_number < 400
        doc: "Pre-GP4: importer applies artificial harmonics to all notes."

  mix_table_change:
    doc: "Mix table change event."
    seq:
      - id: instrument
        type: s1
      - id: rse_bank
        type: rse_bank
        if: _root.version.version_number >= 500
      - id: volume
        type: s1
      - id: balance
        type: s1
      - id: chorus
        type: s1
      - id: reverb
        type: s1
      - id: phaser
        type: s1
      - id: tremolo
        type: s1
      - id: tempo_name
        type: gp_string_int_byte
        if: _root.version.version_number >= 500
      - id: tempo
        type: s4
      - id: duration_volume
        type: u1
        if: volume >= 0
      - id: duration_balance
        type: u1
        if: balance >= 0
      - id: duration_chorus
        type: u1
        if: chorus >= 0
      - id: duration_reverb
        type: u1
        if: reverb >= 0
      - id: duration_phaser
        type: u1
        if: phaser >= 0
      - id: duration_tremolo
        type: u1
        if: tremolo >= 0
      - id: tempo_duration
        type: s1
        if: tempo >= 0
      - id: tempo_hide
        type: u1
        if: (_root.version.version_number >= 510) and (tempo >= 0)
      - id: mix_table_flags
        type: u1
        if: _root.version.version_number >= 400
      - id: wah_type
        type: s1
        if: _root.version.version_number >= 500
      - id: unknown_gp51_a
        type: gp_string_int_byte
        if: _root.version.version_number >= 510
      - id: unknown_gp51_b
        type: gp_string_int_byte
        if: _root.version.version_number >= 510

  note:
    doc: "Single note entry controlled by note flags."
    seq:
      - id: flags
        type: u1
      - id: note_type
        type: u1
        if: (flags & 0x20) != 0
      - id: duration_pre_gp5
        type: u1
        if: (_root.version.version_number < 500) and ((flags & 0x01) != 0)
      - id: tuplet_pre_gp5
        type: u1
        if: (_root.version.version_number < 500) and ((flags & 0x01) != 0)
      - id: dynamic
        type: s1
        if: (flags & 0x10) != 0
      - id: fret
        type: s1
        if: (flags & 0x20) != 0
      - id: left_hand_finger
        type: s1
        if: (flags & 0x80) != 0
      - id: right_hand_finger
        type: s1
        if: (flags & 0x80) != 0
      - id: duration_percent
        type: f8be
        if: (_root.version.version_number >= 500) and ((flags & 0x01) != 0)
      - id: flags2_gp5
        type: u1
        if: _root.version.version_number >= 500
      - id: effects
        type: note_effects
        if: (flags & 0x08) != 0

  note_effects:
    doc: "Note effects flags and their optional payloads."
    seq:
      - id: flags
        type: u1
      - id: flags2
        type: u1
        if: _root.version.version_number >= 400
      - id: bend
        type: bend_effect
        if: (flags & 0x01) != 0
      - id: grace
        type: grace_effect
        if: (flags & 0x10) != 0
      - id: tremolo_picking
        type: tremolo_picking_effect
        if: (_root.version.version_number >= 400) and ((flags2 & 0x04) != 0)
      - id: slide
        type: slide_effect
        if: (_root.version.version_number >= 400) and ((flags2 & 0x08) != 0)
      - id: artificial_harmonic
        type: artificial_harmonic_effect
        if: (_root.version.version_number >= 400) and ((flags2 & 0x10) != 0)
      - id: trill
        type: trill_effect
        if: (_root.version.version_number >= 400) and ((flags2 & 0x20) != 0)
    instances:
      pre_gp4_slide_shift_flag:
        value: (flags & 0x04) != 0
        if: _root.version.version_number < 400
        doc: |
          Pre-GP4: if this flag is set and no slide payload exists, alphaTab
          implies a shift slide-out.

  bend_effect:
    doc: "Bend / tremolo bar effect with point list."
    seq:
      - id: effect_type
        type: u1
      - id: value
        type: s4
      - id: point_count
        type: u4
      - id: points
        type: bend_point
        repeat: expr
        repeat-expr: point_count
        if: point_count > 0

  bend_point:
    seq:
      - id: offset
        type: s4
      - id: value_raw
        type: s4
      - id: vibrato
        type: gp_bool

  grace_effect:
    seq:
      - id: fret
        type: s1
      - id: dynamic
        type: s1
      - id: transition
        type: s1
      - id: duration_ignored
        type: u1
      - id: flags_gp5
        type: u1
        if: _root.version.version_number >= 500

  tremolo_picking_effect:
    seq:
      - id: marks
        type: u1

  slide_effect:
    seq:
      - id: slide_type
        type: s1

  artificial_harmonic_effect:
    seq:
      - id: harmonic_type
        type: u1
      - id: harmonic_tone
        type: u1
        if: (_root.version.version_number >= 500) and (harmonic_type == 2)
      - id: harmonic_key
        type: u1
        if: (_root.version.version_number >= 500) and (harmonic_type == 2)
      - id: harmonic_octave_offset
        type: u1
        if: (_root.version.version_number >= 500) and (harmonic_type == 2)
      - id: tap_fret
        type: u1
        if: (_root.version.version_number >= 500) and (harmonic_type == 3)

  trill_effect:
    seq:
      - id: trill_fret
        type: u1
      - id: trill_speed
        type: u1
