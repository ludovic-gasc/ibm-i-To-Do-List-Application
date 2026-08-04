**FREE
// ============================================================
// TODOSVC - Service program module
// Business logic for the IBM i To-Do List application
//
// All database access is via embedded SQL against TODOLIB.TODOS
// Compiled as: CRTSQLRPGI OBJ(*CURLIB/TODOSVC) OBJTYPE(*MODULE)
// Bound into:  CRTSRVPGM  SRVPGM(*CURLIB/TODOSVC)
// ============================================================
ctl-opt nomain
        option(*srcstmt: *nodebugio)
        datfmt(*iso)
        timfmt(*iso)
        alwnull(*usrctl);

/include 'qcpysrc/todosvc_h.rpgle'

// ============================================================
// GetAllsTodos - return every row from TODOS
// ============================================================
dcl-proc GetAllsTodos export;
  dcl-pi *n int(10);
    todos   likeds(TodoDS) dim(TODOS_MAX_ROWS) options(*varsize);
  end-pi;

  dcl-s  idx       int(10) inz(0);
  dcl-s  hTodoId   int(10);
  dcl-s  hName     varchar(200);
  dcl-s  hDone     int(10);

  exec sql
    DECLARE c_all CURSOR FOR
      SELECT TODOID, NAME, DONESTATUS
      FROM   TODOLIB.TODOS
      ORDER  BY TODOID;

  exec sql OPEN c_all;

  exec sql FETCH c_all INTO :hTodoId, :hName, :hDone;

  dow sqlcode = 0 and idx < TODOS_MAX_ROWS;
    idx += 1;
    todos(idx).todoId     = hTodoId;
    todos(idx).name       = hName;
    todos(idx).doneStatus = (hDone = 1);
    exec sql FETCH c_all INTO :hTodoId, :hName, :hDone;
  enddo;

  exec sql CLOSE c_all;

  return idx;
end-proc;

// ============================================================
// GetPendingTodos - return todos where DONESTATUS = 0
// ============================================================
dcl-proc GetPendingTodos export;
  dcl-pi *n int(10);
    todos   likeds(TodoDS) dim(TODOS_MAX_ROWS) options(*varsize);
  end-pi;

  dcl-s  idx       int(10) inz(0);
  dcl-s  hTodoId   int(10);
  dcl-s  hName     varchar(200);
  dcl-s  hDone     int(10);

  exec sql
    DECLARE c_pend CURSOR FOR
      SELECT TODOID, NAME, DONESTATUS
      FROM   TODOLIB.TODOS
      WHERE  DONESTATUS = 0
      ORDER  BY TODOID;

  exec sql OPEN c_pend;

  exec sql FETCH c_pend INTO :hTodoId, :hName, :hDone;

  dow sqlcode = 0 and idx < TODOS_MAX_ROWS;
    idx += 1;
    todos(idx).todoId     = hTodoId;
    todos(idx).name       = hName;
    todos(idx).doneStatus = *off;
    exec sql FETCH c_pend INTO :hTodoId, :hName, :hDone;
  enddo;

  exec sql CLOSE c_pend;

  return idx;
end-proc;

// ============================================================
// GetDoneTodos - return todos where DONESTATUS = 1
// ============================================================
dcl-proc GetDoneTodos export;
  dcl-pi *n int(10);
    todos   likeds(TodoDS) dim(TODOS_MAX_ROWS) options(*varsize);
  end-pi;

  dcl-s  idx       int(10) inz(0);
  dcl-s  hTodoId   int(10);
  dcl-s  hName     varchar(200);
  dcl-s  hDone     int(10);

  exec sql
    DECLARE c_done CURSOR FOR
      SELECT TODOID, NAME, DONESTATUS
      FROM   TODOLIB.TODOS
      WHERE  DONESTATUS = 1
      ORDER  BY TODOID;

  exec sql OPEN c_done;

  exec sql FETCH c_done INTO :hTodoId, :hName, :hDone;

  dow sqlcode = 0 and idx < TODOS_MAX_ROWS;
    idx += 1;
    todos(idx).todoId     = hTodoId;
    todos(idx).name       = hName;
    todos(idx).doneStatus = *on;
    exec sql FETCH c_done INTO :hTodoId, :hName, :hDone;
  enddo;

  exec sql CLOSE c_done;

  return idx;
end-proc;

// ============================================================
// AddTodo - insert a new todo row
// Returns 1 on success, 0 on failure
// ============================================================
dcl-proc AddTodo export;
  dcl-pi *n int(10);
    todo    likeds(TodoDS) const;
  end-pi;

  dcl-s hName   varchar(200);
  dcl-s hStatus int(10);

  hName   = todo.name;
  hStatus = %int(todo.doneStatus);

  exec sql
    INSERT INTO TODOLIB.TODOS (NAME, DONESTATUS)
    VALUES (:hName, :hStatus);

  if sqlcode = 0;
    return 1;
  else;
    return 0;
  endif;
end-proc;

// ============================================================
// UpdateTodoStatus - toggle done/pending for a specific id
// Returns 1 on success, 0 if id not found
// ============================================================
dcl-proc UpdateTodoStatus export;
  dcl-pi *n int(10);
    todoId  int(10) const;
    done    ind     const;
  end-pi;

  dcl-s hStatus int(10);
  dcl-s hId     int(10);

  hId     = todoId;
  hStatus = %int(done);

  exec sql
    UPDATE TODOLIB.TODOS
    SET    DONESTATUS = :hStatus
    WHERE  TODOID     = :hId;

  if sqlcode = 0 and sqlerrd(3) > 0;
    return 1;
  else;
    return 0;
  endif;
end-proc;

// ============================================================
// RemoveTodo - delete a todo by id
// Returns 1 on success, 0 if id not found
// ============================================================
dcl-proc RemoveTodo export;
  dcl-pi *n int(10);
    todoId  int(10) const;
  end-pi;

  dcl-s hId int(10);

  hId = todoId;

  exec sql
    DELETE FROM TODOLIB.TODOS
    WHERE  TODOID = :hId;

  if sqlcode = 0 and sqlerrd(3) > 0;
    return 1;
  else;
    return 0;
  endif;
end-proc;
