#!/QOpenSys/pkgs/bin/bash
# postbuild.sh - Apply runtime fixes after a TOBI build.
# Patches TODODSPF parameters that TOBI compiles with defaults
# incompatible with tn5250/ACS sessions:
#   ENHDSP(*NO)  - enhanced display not supported by all 5250 emulators
#   RSTDSP(*NO)  - restore-screen not supported by all 5250 emulators
#   DFRWRT(*NO)  - deferred-write triggers "Session or device error (CGDF)"

LIB=${1:-TODOLIB}

echo "=== Post-build fix: CHGDSPF $LIB/TODODSPF ENHDSP(*NO) RSTDSP(*NO) DFRWRT(*NO) ==="

/QOpenSys/usr/bin/system "CHGDSPF FILE($LIB/TODODSPF) ENHDSP(*NO) RSTDSP(*NO) DFRWRT(*NO)" \
  && echo "=== OK ===" \
  || echo "=== CHGDSPF failed (check that TODODSPF exists in $LIB) ==="
