# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

# --- Config ---
PYTHON_CMD := $(shell if [ -d ".venv" ] && [ -f ".venv/bin/python" ]; then echo "$(PWD)/.venv/bin/python"; else echo "python3"; fi)
TMP_DIR := tmp
DIST_DIR := dist
FONTS := Asana DejaVu Euler FiraMath Garamond GFS_NeoHellenic LatinModern LeteSansMath Libertinus NewComputerModern NewComputerModernSans NotoSans Plex STIX TeXGyreBonum TeXGyrePagella TeXGyreSchola TeXGyreTermes XITS

# Export for utils.sh
export PYTHON_CMD TMP_DIR DIST_DIR

# --- Font URLs and Arguments ---
ASANA_URLS := "http://mirrors.ctan.org/fonts/Asana-Math.zip"
ASANA_OFL_ARGS := "2007-2015" "Apostolos Syropoulos" "Asana Math"
DEJAVU_URLS := "http://sourceforge.net/projects/dejavu/files/dejavu/2.36/dejavu-fonts-ttf-2.36.zip"
EULER_URLS := "http://mirrors.ctan.org/fonts/euler-math.zip"
EULER_OFL_ARGS := "2024" "Daniel Flipo" "Euler Math"
FIRAMATH_URLS := "https://raw.githubusercontent.com/firamath/firamath/main/LICENSE" "https://github.com/firamath/firamath/releases/download/v0.3.4/FiraMath-Regular.otf"
GARAMOND_URLS := "https://bitbucket.org/georgd/eb-garamond/downloads/EBGaramond-0.016.zip" "http://mirrors.ctan.org/fonts/garamond-math.zip"
GFS_NEOHELLENIC_URLS := "https://greekfontsociety-gfs.gr/_assets/fonts/GFS_NeoHellenic.zip" "https://greekfontsociety-gfs.gr/_assets/fonts/GFS_NeoHellenic_Math.zip"
LATINMODERN_URLS := "http://www.gust.org.pl/projects/e-foundry/latin-modern/download/lm2.004otf.zip" "http://www.gust.org.pl/projects/e-foundry/lm-math/download/latinmodern-math-1959.zip"
LETESANSMATH_URLS := "http://mirrors.ctan.org/fonts/lete-sans-math.zip"
LETESANSMATH_OFL_ARGS := "2024" "Chenjing Bu, Daniel Flipo" "Lete Sans Math"
LIBERTINUS_URLS := "https://github.com/khaledhosny/libertinus/releases/download/v6.2/libertinus-6.2.zip"
NEWCOMPUTERMODERN_URLS := "http://mirrors.ctan.org/fonts/newcomputermodern.zip"
NEWCOMPUTERMODERNSANS_URLS := "http://mirrors.ctan.org/fonts/newcomputermodern.zip"
NOTOSANS_URLS := "https://notofonts.github.io/math/fonts/NotoSansMath/full/otf/NotoSansMath-Regular.otf" "https://cdn.jsdelivr.net/gh/notofonts/notofonts.github.io/fonts/NotoSans/full/otf/NotoSans-Regular.otf" "https://cdn.jsdelivr.net/gh/notofonts/notofonts.github.io/fonts/NotoSans/full/otf/NotoSans-Bold.otf" "https://cdn.jsdelivr.net/gh/notofonts/notofonts.github.io/fonts/NotoSans/full/otf/NotoSans-Italic.otf" "https://cdn.jsdelivr.net/gh/notofonts/notofonts.github.io/fonts/NotoSans/full/otf/NotoSans-BoldItalic.otf" "https://raw.githubusercontent.com/notofonts/notofonts.github.io/refs/heads/main/fonts/LICENSE"
PLEX_URLS := "https://github.com/IBM/plex/releases/download/%40ibm%2Fplex-math%401.1.0/ibm-plex-math.zip" "https://github.com/IBM/plex/releases/download/%40ibm%2Fplex-serif%401.1.0/ibm-plex-serif.zip"
STIX_URLS := "https://github.com/stipub/stixfonts/blob/master/zipfiles/STIX2_13-all.zip?raw=true"
TEXGYREBONUM_URLS := "http://www.gust.org.pl/projects/e-foundry/tex-gyre/bonum/qbk2.004otf.zip" "http://www.gust.org.pl/projects/e-foundry/tg-math/download/texgyrebonum-math-1005.zip"
TEXGYREPAGELLA_URLS := "http://www.gust.org.pl/projects/e-foundry/tex-gyre/pagella/qpl2_501otf.zip" "http://www.gust.org.pl/projects/e-foundry/tg-math/download/texgyrepagella-math-1632.zip"
TEXGYRESCHOLA_URLS := "http://www.gust.org.pl/projects/e-foundry/tex-gyre/schola/qcs2.005otf.zip" "http://www.gust.org.pl/projects/e-foundry/tg-math/download/texgyreschola-math-1533.zip"
TEXGYRETERMES_URLS := "http://www.gust.org.pl/projects/e-foundry/tex-gyre/termes/qtm2.004otf.zip" "http://www.gust.org.pl/projects/e-foundry/tg-math/download/texgyretermes-math-1543.zip"
XITS_URLS := "http://mirrors.ctan.org/fonts/xits.zip"
XITS_OFL_ARGS := "2007" "Khaled Hosny" "XITS"

# --- Build System ---
.PHONY: all all-parallel check-deps clean distclean help release release-dry-run $(FONTS)

# Stamp files to track downloads
DOWNLOAD_STAMPS := $(patsubst %,$(TMP_DIR)/%-downloaded,$(FONTS))

help:
	@echo "MathFonts Build System"
	@echo "Usage: make [target]"
	@echo
	@echo "Main Targets:"
	@echo "  all-parallel  - Build all fonts in parallel (e.g., 'make -j4 all-parallel')"
	@echo "  all           - Build all fonts sequentially"
	@echo "  [FontName]    - Build a specific font"
	@echo
	@echo "Other Targets:"
	@echo "  clean         - Remove all build artifacts"
	@echo "  distclean     - Remove all build artifacts and other generated files"
	@echo "  check-deps    - Check for required dependencies"
	@echo
	@echo "Release Targets:"
	@echo "  release       - Build fonts and create release archives"
	@echo "  release-dry-run - Test release process without building fonts"

# 'all' and 'all-parallel' are now functionally identical.
# Parallelism is controlled by the -j flag, e.g., 'make -j all'
all: check-deps $(FONTS)
	@source utils.sh && display_font_summary "$(DIST_DIR)"

all-parallel: check-deps
	@echo "[INFO] Building fonts in parallel..."
	@max_jobs=$$(echo "4 $$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)" | tr ' ' '\n' | sort -nr | head -1); \
	echo "[INFO] Using $$max_jobs parallel jobs"; \
	for font in $(FONTS); do \
		while [ $$(jobs -r | wc -l) -ge $$max_jobs ]; do sleep 0.1; done; \
		MAKEFLAGS= $(MAKE) $$font & \
	done; \
	wait; \
	source utils.sh && display_font_summary "$(DIST_DIR)"

check-deps:
	@source utils.sh && check_deps

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf "$(TMP_DIR)" "$(DIST_DIR)"

distclean: clean
	@echo "Cleaning all generated files..."
	@rm -rf webextension *.txt *.html CheckFont*

# --- Font Build Rules ---

# Download stamp rules - explicit for each font
$(TMP_DIR)/Asana-downloaded:
	@source utils.sh && download_and_setup "Asana" $(ASANA_URLS)
	@touch $@

$(TMP_DIR)/DejaVu-downloaded:
	@source utils.sh && download_and_setup "DejaVu" $(DEJAVU_URLS)
	@touch $@

$(TMP_DIR)/Euler-downloaded:
	@source utils.sh && download_and_setup "Euler" $(EULER_URLS)
	@touch $@

$(TMP_DIR)/FiraMath-downloaded:
	@source utils.sh && download_and_setup "FiraMath" $(FIRAMATH_URLS)
	@touch $@

$(TMP_DIR)/Garamond-downloaded:
	@source utils.sh && download_and_setup "Garamond" $(GARAMOND_URLS)
	@touch $@

$(TMP_DIR)/GFS_NeoHellenic-downloaded:
	@source utils.sh && download_and_setup "GFS_NeoHellenic" $(GFS_NEOHELLENIC_URLS)
	@touch $@

$(TMP_DIR)/LatinModern-downloaded:
	@source utils.sh && download_and_setup "LatinModern" $(LATINMODERN_URLS)
	@touch $@

$(TMP_DIR)/LeteSansMath-downloaded:
	@source utils.sh && download_and_setup "LeteSansMath" $(LETESANSMATH_URLS)
	@touch $@

$(TMP_DIR)/Libertinus-downloaded:
	@source utils.sh && download_and_setup "Libertinus" $(LIBERTINUS_URLS)
	@touch $@

$(TMP_DIR)/NewComputerModern-downloaded:
	@source utils.sh && download_and_setup "NewComputerModern" $(NEWCOMPUTERMODERN_URLS)
	@touch $@

$(TMP_DIR)/NewComputerModernSans-downloaded:
	@source utils.sh && download_and_setup "NewComputerModernSans" $(NEWCOMPUTERMODERNSANS_URLS)
	@touch $@

$(TMP_DIR)/NotoSans-downloaded:
	@source utils.sh && download_and_setup "NotoSans" $(NOTOSANS_URLS)
	@touch $@

$(TMP_DIR)/Plex-downloaded:
	@source utils.sh && download_and_setup "Plex" $(PLEX_URLS)
	@touch $@

$(TMP_DIR)/STIX-downloaded:
	@source utils.sh && download_and_setup "STIX" $(STIX_URLS)
	@touch $@

$(TMP_DIR)/TeXGyreBonum-downloaded:
	@source utils.sh && download_and_setup "TeXGyreBonum" $(TEXGYREBONUM_URLS)
	@touch $@

$(TMP_DIR)/TeXGyrePagella-downloaded:
	@source utils.sh && download_and_setup "TeXGyrePagella" $(TEXGYREPAGELLA_URLS)
	@touch $@

$(TMP_DIR)/TeXGyreSchola-downloaded:
	@source utils.sh && download_and_setup "TeXGyreSchola" $(TEXGYRESCHOLA_URLS)
	@touch $@

$(TMP_DIR)/TeXGyreTermes-downloaded:
	@source utils.sh && download_and_setup "TeXGyreTermes" $(TEXGYRETERMES_URLS)
	@touch $@

$(TMP_DIR)/XITS-downloaded:
	@source utils.sh && download_and_setup "XITS" $(XITS_URLS)
	@touch $@

# Each font target depends on its download stamp file
Asana: $(TMP_DIR)/Asana-downloaded
	@source utils.sh && process_and_finalize_simple "Asana" $(ASANA_OFL_ARGS)

DejaVu: $(TMP_DIR)/DejaVu-downloaded
	@source utils.sh && process_and_finalize "DejaVu"

Euler: $(TMP_DIR)/Euler-downloaded
	@source utils.sh && process_and_finalize_simple "Euler" $(EULER_OFL_ARGS)

FiraMath: $(TMP_DIR)/FiraMath-downloaded
	@source utils.sh && process_and_finalize "FiraMath"

Garamond: $(TMP_DIR)/Garamond-downloaded
	@source utils.sh && process_and_finalize "Garamond"

GFS_NeoHellenic: $(TMP_DIR)/GFS_NeoHellenic-downloaded
	@source utils.sh && process_and_finalize "GFS_NeoHellenic"

LatinModern: $(TMP_DIR)/LatinModern-downloaded
	@source utils.sh && process_and_finalize "LatinModern"

LeteSansMath: $(TMP_DIR)/LeteSansMath-downloaded
	@source utils.sh && process_and_finalize_simple "LeteSansMath" $(LETESANSMATH_OFL_ARGS)

Libertinus: $(TMP_DIR)/Libertinus-downloaded
	@source utils.sh && process_and_finalize "Libertinus"

NewComputerModern: $(TMP_DIR)/NewComputerModern-downloaded
	@source utils.sh && process_and_finalize "NewComputerModern"

NewComputerModernSans: $(TMP_DIR)/NewComputerModernSans-downloaded
	@source utils.sh && process_and_finalize "NewComputerModernSans"

NotoSans: $(TMP_DIR)/NotoSans-downloaded
	@source utils.sh && process_and_finalize "NotoSans"

Plex: $(TMP_DIR)/Plex-downloaded
	@source utils.sh && process_and_finalize "Plex"

STIX: $(TMP_DIR)/STIX-downloaded
	@source utils.sh && process_and_finalize "STIX"

TeXGyreBonum: $(TMP_DIR)/TeXGyreBonum-downloaded
	@source utils.sh && process_and_finalize "TeXGyreBonum"

TeXGyrePagella: $(TMP_DIR)/TeXGyrePagella-downloaded
	@source utils.sh && process_and_finalize "TeXGyrePagella"

TeXGyreSchola: $(TMP_DIR)/TeXGyreSchola-downloaded
	@source utils.sh && process_and_finalize "TeXGyreSchola"

TeXGyreTermes: $(TMP_DIR)/TeXGyreTermes-downloaded
	@source utils.sh && process_and_finalize "TeXGyreTermes"

XITS: $(TMP_DIR)/XITS-downloaded
	@source utils.sh && process_and_finalize_simple "XITS" $(XITS_OFL_ARGS)

# --- Release Targets ---

release:
	@echo "Creating MathFonts release..."
	@./release.sh

release-dry-run:
	@echo "Testing MathFonts release process..."
	@./release.sh --dry-run
