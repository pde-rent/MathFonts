Mathematical Open Type fonts
============================

License
-------

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, you can obtain one at
[http://mozilla.org/MPL/2.0/](http://mozilla.org/MPL/2.0/).

Description
-----------

This repository contains a build system to fetch various open source OpenType fonts
with a MATH table as well as the corresponding fonts to use for the surrounding
text (if any). The fonts are automatically downloaded, processed, and converted into 
WOFF (with zopfli compression) and WOFF2 formats using
[fonttools](https://github.com/behdad/fonttools), which may perform additional
optimizations. It is expected that all the transformations preserve
[Functional Equivalence](http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=OFL_web_fonts_and_RFNs#33301a9c)
and so Reserved Font Names remain unchanged. 

The build system features:
- **Multi-threaded compilation**: Fonts are downloaded and processed in parallel for faster builds
- **Automatic LICENSE standardization**: All font licenses are automatically detected and standardized to a common `LICENSE` file format
- **Organized output**: Processed fonts (source .ttf and/or .otf, optimized .woff and .woff2 and license) are organized in the `./dist` directory with consistent structure

The .woff and .woff2 fonts are optimized for web use.

Warning
-------

This page uses features that may not be supported by legacy web rendering engines:

- MathML and the OpenType MATH table.
- the WOFF2 format.
- CSS rules from the [CSS Fonts Module Level](http://dev.w3.org/csswg/css-fonts/)
  that are used by some fonts to provide old style numbers and
  calligraphic letters.

Using Math fonts on your Web site
---------------------------------

After building the fonts (see Build Instructions below), the processed fonts will be
available in the `./dist` directory. Choose one family for your web site and place 
the corresponding subdirectory somewhere accessible.

Make your pages link to the `mathfonts.css` stylesheet. The MathML formulas
will then render with the specified font. It's good to make them consistent
with the surrounding text, especially for inline expressions. To do that,
use the `htmlmathparagraph` class, e.g. `<body class="htmlmathparagraph">`.
By default, the local fonts installed on the system will be used. For open
source fonts, Web fonts in WOFF2 or WOFF format will be used as a fallback.

Most families provide old style numbers in the text font. You can use them via
the `oldstylenumbers` class, e.g.
`<span class="oldstylenumbers">0123456789</span>`. Some of the math fonts also
provide calligraphic style for the script characters, that you can select
with the `calligraphic` class e.g.
`<math><mi mathvariant="script" class="calligraphic">A</mi></math>` or
equivalently `<math><mi class="calligraphic">𝒜</mi></math>`.

Font Subsetting for Size Optimization
--------------------------------------

For web deployment, you can significantly reduce font file sizes by subsetting fonts to include only the characters you need. The fonts can be cut to Latin Extended A plus mathematical symbols for an extensive subset with noticeable size gains.

### Recommended Unicode Ranges

For optimal coverage of mathematical content with Latin scripts, use these Unicode ranges:

```
U+0100–U+017F,U+2200–U+22FF,U+27C0–U+27EF,U+2980–U+29FF,U+2A00–U+2AFF,U+1D400–U+1D7FF,U+1EE00–U+1EEFF
```

This includes:
- **U+0100–U+017F**: Latin Extended-A (àáâãäå, čďě, etc.)
- **U+2200–U+22FF**: Mathematical Operators (∀∃∇∈∉∋, ∑∏∫, ≤≥≠≡, etc.)
- **U+27C0–U+27EF**: Miscellaneous Mathematical Symbols-A (⟀⟁⟂, etc.)
- **U+2980–U+29FF**: Miscellaneous Mathematical Symbols-B (⦀⦁⦂, etc.)
- **U+2A00–U+2AFF**: Supplemental Mathematical Operators (⨀⨁⨂, etc.)
- **U+1D400–U+1D7FF**: Mathematical Alphanumeric Symbols (𝒜ℬ𝒞, 𝔞𝔟𝔠, etc.)
- **U+1EE00–U+1EEFF**: Arabic Mathematical Alphabetic Symbols

### Subsetting Tools

You can use various tools to subset fonts:

**Using `pyftsubset` (from fonttools):**
```bash
pyftsubset font.otf --unicodes="U+0100-017F,U+2200-22FF,U+27C0-27EF,U+2980-29FF,U+2A00-2AFF,U+1D400-1D7FF,U+1EE00-1EEFF" --output-file=font-subset.otf
```

**Using `fonttools`:**
```bash
fonttools subset font.woff2 --unicodes="U+0100-017F,U+2200-22FF,U+27C0-27EF,U+2980-29FF,U+2A00-2AFF,U+1D400-1D7FF,U+1EE00-1EEFF"
```

### Size Benefits

Typical size reductions when using mathematical subsets:
- **Original fonts**: 200KB - 2MB per font file
- **Subsetted fonts**: 50KB - 500KB per font file
- **Size reduction**: 60-80% smaller files

This dramatically improves web page loading times while maintaining full mathematical typesetting capabilities.

Build Instructions
------------------

### Prerequisites

You need the following system tools:
- [GNU Core Utilities](https://en.wikipedia.org/wiki/GNU_Core_Utilities) (or equivalent on UNIX systems)
- `curl` or `wget` for downloading
- `unzip` for archive extraction
- `grep`, `sed` for text processing
- [Python ≥ 3.8](https://www.python.org/)

### Python Dependencies

Install the required Python packages:

```bash
pip install fonttools zopfli brotli
```

For development and testing (optional):
```bash
pip install fontforge  # Note: May require system-level installation on some platforms
```

### Building Fonts

The build system supports both sequential and parallel compilation:

#### Parallel Build (Recommended)
```bash
make all-parallel
```
This automatically detects your system's CPU cores and uses at least 4 parallel jobs for optimal performance.

#### Sequential Build
```bash
make all
```

#### Building Specific Fonts
```bash
make Asana DejaVu Euler  # Build only specific fonts
```

#### Parallel Build with Custom Job Count
```bash
make -j8 all  # Use 8 parallel jobs
```

### Build Performance Notes

**Mirror Throttling**: Some font mirrors (particularly `gust.org` and `ctan.org`) may throttle connections when downloading multiple fonts simultaneously or in rapid succession. This can slow down parallel builds. If you experience slow downloads, you may want to:
- Use sequential builds: `make all`
- Reduce parallelism: `make -j2 all`
- Build fonts in smaller batches

### Output Structure

After building, fonts will be organized in the `./dist` directory:
```
dist/
├── Asana/
│   ├── LICENSE          # Standardized license file
│   ├── AsanaMath.otf    # Original OpenType font
│   ├── AsanaMath.woff   # WOFF version (zopfli compressed)
│   └── AsanaMath.woff2  # WOFF2 version
├── DejaVu/
│   ├── LICENSE
│   ├── DejaVuMath.otf
│   └── ...
└── ...
```

### Cleaning

- `make clean` - Remove build artifacts (`tmp/` and `dist/` directories)
- `make distclean` - Remove all generated files including test outputs

### Available Fonts

The build system supports the following mathematical fonts:
- Asana Math
- DejaVu Math
- Euler Math
- Fira Math
- EB Garamond + Garamond Math
- GFS NeoHellenic + GFS NeoHellenic Math
- Latin Modern + Latin Modern Math
- Lete Sans Math
- Libertinus Math
- New Computer Modern + New Computer Modern Math
- New Computer Modern Sans
- Noto Sans + Noto Sans Math
- IBM Plex Serif + IBM Plex Math
- STIX Two Math
- TeX Gyre Bonum + TeX Gyre Bonum Math
- TeX Gyre Pagella + TeX Gyre Pagella Math
- TeX Gyre Schola + TeX Gyre Schola Math
- TeX Gyre Termes + TeX Gyre Termes Math
- XITS Math

### Troubleshooting

If you encounter issues:
1. Ensure all prerequisites are installed
2. Check that Python dependencies are available
3. For network issues, try sequential builds or reduce parallelism
4. Use `make clean` and retry if builds fail partway through
