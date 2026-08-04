# qrpglesrc/Rules.mk
# TODOMAIN.PGM – 5250 interactive program.
# Depends on TODODSPF display file and the TODOSVC_BD binding directory.

TODOMAIN.PGM: private BNDDIR := TODOSVC_BD
TODOMAIN.PGM: todomain.pgm.rpgle TODODSPF.FILE TODOSVC_BD.BNDDIR
