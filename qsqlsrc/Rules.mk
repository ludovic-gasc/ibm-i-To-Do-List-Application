# qsqlsrc/Rules.mk
# Creates the TODOS table from the SQL DDL source.
# TOBI runs RUNSQLSTM on todos.table and creates TODOS (*FILE) in TODOLIB.
TODOS.FILE: todos.table
