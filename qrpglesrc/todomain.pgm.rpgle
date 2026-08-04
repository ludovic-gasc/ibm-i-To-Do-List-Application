**FREE
// ============================================================
// TODOMAIN – 5250 interactive front-end for the To-Do List
//
// Uses the same TODOSVC service program as TODOAPI,
// so all data access logic is shared.
//
// Display file: TODODSPF
// Service prog: TODOSVC
//
// Navigation:
//   F3 / F12 = Exit
//   F5       = Refresh list
//   F6       = Add new todo
//   F8       = Show pending only
//   F9       = Show done only
//   F10      = Show all todos
//   Sel col  = 1-Toggle status, 4-Delete, 5-View name
//
// Compile: CRTBNDRPG PGM(*CURLIB/TODOMAIN)
//          SRCSTMF('.../todomain.rpgle')
//          BNDDIR(*CURLIB/TODOSVC_BD)
// ============================================================
ctl-opt dftactgrp(*no)
        actgrp(*new)
        option(*srcstmt: *nodebugio)
        datfmt(*iso)
        bnddir('TODOSVC_BD');

// ---- Display file ------------------------------------------
dcl-f TODODSPF workstn
               indds(wsInd)
               sfile(SFRCD: sflRrn);

// ---- Indicator data structure ------------------------------
dcl-ds wsInd;
  in01  ind pos(1);   // Subfile SFLEND
  in02  ind pos(2);   // Subfile has data
  in03  ind pos(3);   // Subfile empty message
  in10  ind pos(10);  // Show add screen
  in20  ind pos(20);  // Error colour for message field
  in21  ind pos(21);  // Info colour
  in71  ind pos(71);  // F5 Refresh
  in72  ind pos(72);  // F6 Add / F12 Cancel
  in73  ind pos(73);  // F8 Pending
  in74  ind pos(74);  // F9 Done
  in75  ind pos(75);  // F10 All
  in98  ind pos(98);  // Page Down pressed
  in99  ind pos(99);  // F3 Exit
end-ds;

// ---- Service program copybook ------------------------------
/include 'qcpysrc/todosvc_h.rpgle'

// ---- Working variables -------------------------------------
dcl-s  sflRrn     int(10) inz(0);   // Subfile relative record number
dcl-ds todos      likeds(TodoDS) dim(TODOS_MAX_ROWS);
dcl-s  todoCount  int(10);
dcl-s  i          int(10);
dcl-s  exitNow    ind inz(*off);

// Filter mode: 'A'=all, 'P'=pending, 'D'=done
dcl-s  filterMode char(1) inz('A');

// Subfile fields (must match DSPF record format field names)
dcl-s  SFSEL     char(1);
dcl-s  SFTODOID  packed(5: 0);
dcl-s  SFNAME    char(40);
dcl-s  SFDONE    char(1);
dcl-s  SFMSG     char(79);

// Add screen fields
dcl-s  ADDNAME   char(40);
dcl-s  ADDDONE   char(1);
dcl-s  ADDERR    char(79);

// ============================================================
// Main loop
// ============================================================
loadSubfile();

dow not exitNow;

  // Display subfile + control
  exfmt SFCTL;

  // Check exit first
  if in99;
    exitNow = *on;
    iter;
  endif;

  // Function key routing
  if in71;                 // F5 Refresh
    loadSubfile();
    iter;
  endif;

  if in72;                 // F6 Add
    doAddScreen();
    loadSubfile();
    iter;
  endif;

  if in73;                 // F8 Pending only
    filterMode = 'P';
    loadSubfile();
    iter;
  endif;

  if in74;                 // F9 Done only
    filterMode = 'D';
    loadSubfile();
    iter;
  endif;

  if in75;                 // F10 All
    filterMode = 'A';
    loadSubfile();
    iter;
  endif;

  // Process selection column entries
  processSelections();

enddo;

*inlr = *on;
return;

// ============================================================
// loadSubfile – populate the subfile from the service program
// ============================================================
dcl-proc loadSubfile;

  dcl-s rc int(10);

  // Clear subfile
  in02 = *off;
  in03 = *off;
  sflRrn = 0;
  write SFCTL;  // SFLCLR

  // Call appropriate service procedure based on filter
  select;
    when filterMode = 'P';
      todoCount = GetPendingTodos(todos);
    when filterMode = 'D';
      todoCount = GetDoneTodos(todos);
    other;
      todoCount = GetAllsTodos(todos);
  endsl;

  if todoCount = 0;
    in02 = *off;
    in03 = *on;
    SFMSG = 'No records found.';
    return;
  endif;

  in03 = *off;
  SFMSG = '';

  for i = 1 to todoCount;
    SFSEL    = ' ';
    SFTODOID = todos(i).todoId;
    SFNAME   = %subst(todos(i).name: 1:
                 %min(40: %len(%trim(todos(i).name))));
    SFDONE   = %char(%int(todos(i).doneStatus = *on));
    if todos(i).doneStatus = *on;
      SFDONE = 'Y';
    else;
      SFDONE = 'N';
    endif;
    sflRrn += 1;
    write SFRCD;
  endfor;

  in02 = *on;
  in01 = *on;   // SFLEND
end-proc;

// ============================================================
// processSelections – walk subfile and act on non-blank SEL
// ============================================================
dcl-proc processSelections;

  dcl-s rrn   int(10) inz(1);
  dcl-s rc    int(10);
  dcl-s newDone ind;

  SFMSG = '';
  in20  = *off;

  dow rrn <= sflRrn;
    chain rrn SFRCD;
    if not %found;
      rrn += 1;
      iter;
    endif;

    select;
      when SFSEL = '1';
        // Toggle done status
        newDone = (SFDONE = 'N');   // flip: N->done, Y->pending
        rc = UpdateTodoStatus(%int(SFTODOID): newDone);
        if rc = 1;
          SFMSG = 'Status updated for ID: ' + %char(SFTODOID);
        else;
          SFMSG = 'ID not found: ' + %char(SFTODOID);
          in20 = *on;
        endif;

      when SFSEL = '4';
        // Delete
        rc = RemoveTodo(%int(SFTODOID));
        if rc = 1;
          SFMSG = 'Todo deleted: ' + %char(SFTODOID);
        else;
          SFMSG = 'Delete failed - ID not found: ' + %char(SFTODOID);
          in20 = *on;
        endif;

      when SFSEL = '5';
        // View (just display name in message bar)
        SFMSG = 'Task: ' + %trim(SFNAME);
    endsl;

    // Clear selection
    SFSEL = ' ';
    update SFRCD;

    rrn += 1;
  enddo;

  // Reload after any changes
  if SFMSG <> '';
    loadSubfile();
  endif;

end-proc;

// ============================================================
// doAddScreen – handle the add new todo screen
// ============================================================
dcl-proc doAddScreen;

  dcl-s exitAdd ind inz(*off);
  dcl-ds newTodo likeds(TodoDS);
  dcl-s rc      int(10);

  ADDNAME = '';
  ADDDONE = 'N';
  ADDERR  = '';
  in20    = *off;

  dow not exitAdd;
    exfmt ADDSCR;

    if in99 or in72;      // F3 or F12 = cancel
      exitAdd = *on;
      iter;
    endif;

    // Validate
    if %trim(ADDNAME) = '';
      ADDERR = 'Task description is required.';
      in20   = *on;
      iter;
    endif;

    // Build todo DS and call service proc
    clear newTodo;
    newTodo.name       = %trim(ADDNAME);
    newTodo.doneStatus = (%upper(ADDDONE) = 'Y');

    rc = AddTodo(newTodo);

    if rc = 1;
      SFMSG  = 'New todo added: ' + %trim(ADDNAME);
      exitAdd = *on;
    else;
      ADDERR = 'Insert failed. Check logs.';
      in20   = *on;
    endif;

  enddo;

end-proc;
