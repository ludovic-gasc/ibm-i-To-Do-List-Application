**FREE
// ============================================================
// TODOSVC_H – Prototype copybook for the TODOSVC service prog
// Include with: /copy qcpysrc,todosvc_h
// ============================================================

// ----- Data structure: one Todo item -------------------------
dcl-ds TodoDS qualified template;
  todoId     int(10);              // Unique identifier
  name       varchar(200);         // Task description
  doneStatus ind;                  // *ON = done, *OFF = pending
end-ds;

// Maximum rows returned in list operations
dcl-c TODOS_MAX_ROWS 500;

// Return array type (simple array of DS)
// Caller must pass an array of TODOS_MAX_ROWS elements
// and an integer receiving the actual count

// ----- Procedure prototypes ----------------------------------

// Get all todos regardless of status
// Returns: count of todos populated in the output array
dcl-pr GetAllsTodos int(10) extproc('GETALLSTODOS');
  todos    likeds(TodoDS) dim(TODOS_MAX_ROWS) options(*varsize);
end-pr;

// Get pending (not done) todos
dcl-pr GetPendingTodos int(10) extproc('GETPENDINGTODOS');
  todos    likeds(TodoDS) dim(TODOS_MAX_ROWS) options(*varsize);
end-pr;

// Get done todos
dcl-pr GetDoneTodos int(10) extproc('GETDONETODOS');
  todos    likeds(TodoDS) dim(TODOS_MAX_ROWS) options(*varsize);
end-pr;

// Add a new todo
// Returns 1 on success, 0 if duplicate id
dcl-pr AddTodo int(10) extproc('ADDTODO');
  todo     likeds(TodoDS) const;
end-pr;

// Update the done/pending status of a todo
// Returns 1 on success, 0 if id not found
dcl-pr UpdateTodoStatus int(10) extproc('UPDATETODOSTATUS');
  todoId   int(10)  const;
  done     ind      const;
end-pr;

// Delete a todo by id
// Returns 1 on success, 0 if id not found
dcl-pr RemoveTodo int(10) extproc('REMOVETODO');
  todoId   int(10)  const;
end-pr;
