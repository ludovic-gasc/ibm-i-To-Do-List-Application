#!/QOpenSys/pkgs/bin/bash
# clean.sh - Delete all TODOLIB compiled objects so the next build
# recompiles everything from scratch.
# Each DLTOBJ is run independently; errors are ignored (object may not exist).

LIB=${1:-TODOLIB}

echo "=== Cleaning $LIB ==="

/QOpenSys/usr/bin/system "DLTOBJ OBJ($LIB/EVFEVENT) OBJTYPE(*FILE)" || true
/QOpenSys/usr/bin/system "DLTOBJ OBJ($LIB/TODOS) OBJTYPE(*FILE)" || true
/QOpenSys/usr/bin/system "DLTOBJ OBJ($LIB/TODODSPF) OBJTYPE(*FILE)" || true
/QOpenSys/usr/bin/system "DLTOBJ OBJ($LIB/TODOMAIN) OBJTYPE(*PGM)" || true
/QOpenSys/usr/bin/system "DLTOBJ OBJ($LIB/TODOAPI) OBJTYPE(*PGM)" || true
/QOpenSys/usr/bin/system "DLTOBJ OBJ($LIB/TODOSVC) OBJTYPE(*SRVPGM)" || true
/QOpenSys/usr/bin/system "DLTOBJ OBJ($LIB/TODOSVC) OBJTYPE(*MODULE)" || true
/QOpenSys/usr/bin/system "DLTOBJ OBJ($LIB/TODOSVC_BD) OBJTYPE(*BNDDIR)" || true

echo "=== Clean done ==="
