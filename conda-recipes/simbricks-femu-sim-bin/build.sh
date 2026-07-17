#!/bin/bash
set -e

# Build and install the femu binary via the top-level Makefile. femu-install
# depends on the build (femu/ready) stamp, so this single invocation builds and
# installs into ${PREFIX}/bin. simbricks-lib (a host dep) provides the SimBricks
# headers under ${PREFIX}/include and libs under ${PREFIX}/lib/simbricks -- the
# defaults the Makefile derives from PREFIX -- so they need not be passed here.
make femu-install \
    CC="${CC}" \
    PREFIX="${PREFIX}"
