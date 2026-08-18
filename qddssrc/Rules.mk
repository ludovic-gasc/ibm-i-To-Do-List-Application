# qddssrc/Rules.mk
# TODODSPF.FILE - compiled by TOBI via CRTDSPF from tododspf.dspf.
#
# TOBI defaults: ENHDSP(*YES) RSTDSP(*YES) DFRWRT(*YES)
# These are incompatible with tn5250/ACS sessions and cause:
#   "Session or device error occurred in file TODODSPF (C G D F)"
#
# Fix: override ENHDSP, RSTDSP, DFRWRT via target-specific variables.
# TOBI injects these directly into CRTDSPFFLAGS — no post-build step needed.

TODODSPF.FILE: tododspf.dspf
TODODSPF.FILE: ENHDSP = *NO
TODODSPF.FILE: RSTDSP = *NO
TODODSPF.FILE: DFRWRT = *NO
