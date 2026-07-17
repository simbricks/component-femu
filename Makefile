# MIT License

# Copyright (c) 2026 SimBricks

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Compilers and python interpreter (overridable by conda / the environment).
CC                ?= cc
CXX               ?= c++
PYTHON            ?= python

# Where "make femu-install" places the femu binary. Inside a conda build this is
# the build prefix; for a local dev build override it, e.g. PREFIX=$(pwd)/out.
PREFIX            ?= $(CURDIR)/out

# Location of the SimBricks headers/libraries the femu build links against.
# Headers (included as <simbricks/...>) live under $(PREFIX)/include; the
# libnicif/libpcie/libbase/libparser libraries live under $(PREFIX)/lib/simbricks.
# These come from the simbricks-lib package; override for a local dev build that
# installs simbricks-lib elsewhere.
SIMBRICKS_INC_DIR ?= $(PREFIX)/include
SIMBRICKS_LIB_DIR ?= $(PREFIX)/lib/simbricks

# Python packages
FEMU_PY_SIM       := femu_sim_py

# Optional: redirect conda-build output, e.g. OUTPUT_FOLDER=./conda-out.
OUTPUT_FOLDER     ?=
OUTPUT_FLAG       := $(if $(OUTPUT_FOLDER),--output-folder $(OUTPUT_FOLDER))
# Conda channels searched by `conda build`. The SimBricks channel hosts external
# deps not built here (e.g. simbricks-lib, simbricks-orchestration); conda-forge
# provides the rest. Override to point at a different channel if needed.
SIMB_CONDA_CHANNEL:= -c https://conda.simbricks.io/latest
BASE_BUILD_CMD    := conda build $(SIMB_CONDA_CHANNEL) -m conda-recipes/conda_build_config.yaml $(OUTPUT_FLAG)

.PHONY: all conda-packages pypi-build pypi-publish clean femu-python-develop \
	femu-sim-py-conda femu-build femu-install femu-bin-conda

## --- femu simulator (C sources in femu/) -----------------------------------

# Build the femu-simbricks binary. The stamp file tracks a completed build so
# repeated invocations are cheap. The leading '+' forwards the make jobserver to
# the nested femu build. EXTRA_CPPFLAGS/EXTRA_LDFLAGS point it at the SimBricks
# headers and libraries.
femu/ready: femu
	+$(MAKE) -C femu \
		CC="$(CC)" \
		EXTRA_CPPFLAGS="-I$(SIMBRICKS_INC_DIR)" \
		EXTRA_LDFLAGS="-L$(SIMBRICKS_LIB_DIR)"
	touch $@

# Build femu (clean named alias for the stamp target).
femu-build: femu/ready

# Install the built femu binary into $(PREFIX)/bin.
femu-install: femu/ready
	install -D femu/femu-simbricks $(PREFIX)/bin/femu-simbricks

## --- Python packages -------------------------------------------------------

# Editable installs for local development.
femu-python-develop:
	$(PYTHON) -m pip install -e ./$(FEMU_PY_SIM)

## --- Conda packages --------------------------------------------------------

femu-sim-py-conda:
	$(BASE_BUILD_CMD) conda-recipes/simbricks-femu-sim-py

# Build the compiled femu conda package. It depends at runtime on the python
# package, so build that first and let conda resolve it from the local channel.
femu-bin-conda: femu-sim-py-conda
	$(BASE_BUILD_CMD) conda-recipes/simbricks-femu-sim-bin

conda-packages: femu-sim-py-conda femu-bin-conda

## --- PyPI packages ---------------------------------------------------------

pypi-build:
	poetry build -C $(FEMU_PY_SIM)

pypi-publish: pypi-build
	poetry publish -C $(FEMU_PY_SIM)

## --- Default target ----------------------------------------------------------

# Default: local dev build of both halves.
all: conda-packages

## --- Housekeeping ----------------------------------------------------------

clean:
	rm -f femu/ready
	-$(MAKE) -C femu clean
	rm -rf $(FEMU_PY_SIM)/dist
