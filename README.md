# Guitar Pro 5 (.gp5) File Format

A practical, reverse-engineered specification and Kaitai Struct definition for Guitar Pro 5/5.1 binary files. The goal is to document the format as observed in real files and to provide a machine-readable parser description.

## Contents

- [gp5_file_format.md](gp5_file_format.md): human-readable format notes and field-by-field details.
- [guitar_pro_5.ksy](guitar_pro_5.ksy): Kaitai Struct definition for parsing .gp5 files.

## Scope

- Primary target: Guitar Pro 5 / 5.1 (version number >= 500)
- Compatibility notes for GP3/GP4 are included where relevant
- Some fields are intentionally conservative where semantics are unclear

## Using the Kaitai Struct

1. Install Kaitai Struct compiler: https://kaitai.io/
2. Generate a parser for your language:
   - Example (Python):
     - `ksc -t python guitar_pro_5.ksy`
3. Parse a file using the generated code.

Refer to the Kaitai documentation for language-specific usage details.

## Notes

- Version detection uses a heuristic based on the standard GP header string.

## License

This project is licensed under the Mozilla Public License 2.0. See [LICENSE](LICENSE).
