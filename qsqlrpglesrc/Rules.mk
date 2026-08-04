# qsqlrpglesrc/Rules.mk
# TODOSVC.MODULE  – compiled from todosvc.sqlrpgle
# TODOAPI.PGM     – compiled from todoapi.pgm.sqlrpgle, depends on TODOSVC_BD.BNDDIR

TODOSVC.MODULE: todosvc.sqlrpgle

TODOAPI.PGM: private BNDDIR := TODOSVC_BD
TODOAPI.PGM: todoapi.pgm.sqlrpgle TODOSVC_BD.BNDDIR
