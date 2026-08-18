-- =============================================================
-- IBM i To-Do List Application
-- Seed data for TODOS table
-- Inserts sample rows only if the table is empty.
-- Executed by TOBI via RUNSQLSTM after TODOS.FILE is built.
-- =============================================================

INSERT INTO TODOS (NAME, DONESTATUS)
  SELECT 'Buy groceries', 0 FROM SYSIBM.SYSDUMMY1
  WHERE NOT EXISTS (SELECT 1 FROM TODOS);

INSERT INTO TODOS (NAME, DONESTATUS)
  SELECT 'Read a book', 1 FROM SYSIBM.SYSDUMMY1
  WHERE NOT EXISTS (SELECT 1 FROM TODOS WHERE TODOID > 1);
