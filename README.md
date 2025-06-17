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
WOFF2 format using [fonttools](https://github.com/behdad/fonttools), which may perform additional
optimizations. It is expected that all the transformations preserve
[Functional Equivalence](http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=OFL_web_fonts_and_RFNs#33301a9c)
and so Reserved Font Names remain unchanged. 

The build system features:
- **Multi-threaded compilation**: Fonts are downloaded and processed in parallel for faster builds
- **Automatic LICENSE standardization**: All font licenses are automatically detected and standardized to a common `LICENSE` file format
- **Release-based distribution**: Compiled fonts are distributed through GitHub Releases rather than being stored in the repository
- **Optimized for web**: Only WOFF2 files and LICENSE files are included in releases for minimal size

The .woff2 fonts are optimized for web use and provide the best compression and performance.

**Repository Policy**: This repository contains only the build system and documentation. Compiled fonts are distributed through [GitHub Releases](https://github.com/pde-rent/MathFonts/releases) to maintain a clean repository without large binary files.

Getting the Fonts
------------------

### Option 1: Download Pre-built Releases (Recommended)

Download the latest font collection from the [Releases page](https://github.com/pde-rent/MathFonts/releases):

1. Go to [https://github.com/pde-rent/MathFonts/releases](https://github.com/pde-rent/MathFonts/releases)
2. Download either:
   - `mathfonts-X.Y.Z.zip` (ZIP archive)
   - `mathfonts-X.Y.Z.tar.gz` (TAR.GZ archive)
3. Extract the archive to your desired location

Each release contains all fonts organized by family, with LICENSE files included.

### Option 2: Build from Source

If you need to customize the build or want the latest changes:

```bash
git clone https://github.com/pde-rent/MathFonts.git
cd MathFonts
make all-parallel  # Build all fonts
```

See the "Build Instructions" section below for detailed build information.

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

After downloading fonts from a release, choose one family for your web site and place 
the corresponding subdirectory somewhere accessible on your web server.

Make your pages link to the `mathfonts.css` stylesheet. The MathML formulas
will then render with the specified font. It's good to make them consistent
with the surrounding text, especially for inline expressions. To do that,
use the `htmlmathparagraph` class, e.g. `<body class="htmlmathparagraph">`.
By default, the local fonts installed on the system will be used. For open
source fonts, Web fonts in WOFF2 format will be used as a fallback.

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
pyftsubset font.woff2 --unicodes="U+0100-017F,U+2200-22FF,U+27C0-27EF,U+2980-29FF,U+2A00-2AFF,U+1D400-1D7FF,U+1EE00-1EEFF" --output-file=font-subset.woff2
```

**Using `fonttools`:**
```bash
fonttools subset font.woff2 --unicodes="U+0100-017F,U+2200-22FF,U+27C0-27EF,U+2980-29FF,U+2A00-2AFF,U+1D400-1D7FF,U+1EE00-1EEFF"
```

### Size Benefits

Typical size reductions when using mathematical subsets:
- **Original WOFF2 fonts**: 200KB - 500KB per font file
- **Subsetted WOFF2 fonts**: 50KB - 200KB per font file
- **Size reduction**: 40-70% smaller files

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
│   ├── AsanaMath.woff2  # WOFF2 version (optimized for web)
│   ├── AsanaMath.otf    # Original OpenType font
│   └── AsanaMath.woff   # WOFF version
├── DejaVu/
│   ├── LICENSE
│   ├── DejaVuMath.woff2
│   └── ...
└── ...
```

**Note**: The `dist/` directory is excluded from version control. All compiled fonts are distributed through GitHub Releases instead.

### Cleaning

- `make clean` - Remove build artifacts (`tmp/` directory)
- `make distclean` - Remove all generated files including test outputs

Creating Releases
-----------------

This repository includes scripts to create versioned releases with pre-built font packages:

### Simple Release (Shell Script)

```bash
./release.sh [version]
```

This will:
1. Build all fonts using `make all-parallel`
2. Create ZIP and TAR.GZ archives in the `tmp/` directory
3. Create a git tag for the version
4. Provide instructions for manual GitHub release creation

### Automated Release (Python Script)

For fully automated releases with GitHub integration:

```bash
# Install dependencies
pip install requests

# Create release (requires GitHub token)
export GITHUB_TOKEN=your_personal_access_token
python release.py [--version v1.2.3] [--dry-run]
```

This will:
1. Build all fonts
2. Create versioned archives
3. Automatically create a GitHub release with detailed release notes
4. Upload the font archives as release assets
5. Create and push git tags

### Release Script Options

- `--version v1.2.3` - Specify exact version (default: auto-increment patch version)
- `--dry-run` - Show what would be done without executing
- `--token TOKEN` - GitHub personal access token (or use `GITHUB_TOKEN` environment variable)

### GitHub Token Setup

To use automated releases, create a GitHub personal access token:

1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Generate a new token with `repo` scope
3. Set it as an environment variable: `export GITHUB_TOKEN=your_token`

### Manual Release Process

If you prefer manual control:

1. Build fonts: `make all-parallel`
2. Create archives: `./release.sh`
3. Go to [GitHub Releases](https://github.com/pde-rent/MathFonts/releases)
4. Create a new release and upload the generated archives from `tmp/`

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
