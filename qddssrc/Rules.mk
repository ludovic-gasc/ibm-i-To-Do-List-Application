# qddssrc/Rules.mk
# TODODSPF.FILE - compiled directly from TODOLIB/QDDSSRC member.
# The IFS stream file (tododspf.dspf) is kept for git history only.
# CPD7812 lesson: SFCTL footprint spans first-to-last constant row;
# any SFCTL constant below the subfile page triggers the overlap.
# Fix: use a separate SFFOOT OVERLAY record for below-subfile content.

TODODSPF.FILE:
	system "CRTDSPF FILE($(OBJLIB)/TODODSPF) SRCFILE($(OBJLIB)/QDDSSRC) SRCMBR(TODODSPF) ENHDSP(*YES) RSTDSP(*YES) DFRWRT(*YES) OPTION(*EVENTF *SRC *LIST) TEXT('Todo List 5250 display file')"
