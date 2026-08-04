-- =============================================================
-- IBM i To-Do List Application
-- SQL Schema – TODOS table
-- Library TODOLIB is created by iproj.json setIBMiEnvCmd (CRTLIB).
-- =============================================================

-- Main table (CREATE OR REPLACE is safe on re-runs)
CREATE OR REPLACE TABLE TODOLIB.TODOS (
    TODOID     INTEGER        NOT NULL GENERATED ALWAYS AS IDENTITY
                                       (START WITH 1 INCREMENT BY 1),
    NAME       VARCHAR(200)   NOT NULL,
    DONESTATUS SMALLINT       NOT NULL DEFAULT 0
                              CONSTRAINT TODOS_STATUS_CHK
                              CHECK (DONESTATUS IN (0, 1)),
    CONSTRAINT TODOS_PK PRIMARY KEY (TODOID)
);

LABEL ON TABLE TODOLIB.TODOS IS 'To-Do List';
LABEL ON COLUMN TODOLIB.TODOS (
    TODOID     IS 'Todo ID',
    NAME       IS 'Task description',
    DONESTATUS IS 'Done status (0=pending, 1=done)'
);

-- Seed data (only insert if table is empty)
INSERT INTO TODOLIB.TODOS (NAME, DONESTATUS)
  SELECT 'Buy groceries', 0 FROM SYSIBM.SYSDUMMY1
  WHERE NOT EXISTS (SELECT 1 FROM TODOLIB.TODOS);

INSERT INTO TODOLIB.TODOS (NAME, DONESTATUS)
  SELECT 'Read a book', 1 FROM SYSIBM.SYSDUMMY1
  WHERE NOT EXISTS (SELECT 1 FROM TODOLIB.TODOS WHERE TODOID > 1);
