**FREE
// ============================================================
// TODOAPI - REST/JSON handler for the To-Do List application
//
// Routes (mimics docs/api.yaml):
//   GET    /todos          -> getAllTodos
//   GET    /todo/pending   -> notDoneTodos
//   GET    /todo/done      -> getDoneTodos
//   POST   /todo           -> addTodo
//   PUT    /todo/status/{id}/{status} -> updateTodoStatus
//   DELETE /todo/delete?id=n -> removeTodo
//
// Compile: CRTSQLRPGI OBJ(*CURLIB/TODOAPI) SRCSTMF('.../todoapi.sqlrpgle')
//          BNDDIR(*CURLIB/TODOSVC_BD) OPTION(*EVENTF) DBGVIEW(*SOURCE)
// ============================================================
ctl-opt dftactgrp(*no)
        actgrp('QILE')
        option(*srcstmt: *nodebugio)
        datfmt(*iso)
        bnddir('TODOSVC_BD');

// ---- HTTP/IWS CGI APIs (QHTTPSVR/QTMHCGI) ------------------
// QtmhGetEnv - get CGI environment variable
dcl-pr QtmhGetEnv extproc('QtmhGetEnv');
  receiver   char(1024) options(*varsize);  // value returned here
  recvLen    int(10);                       // length of receiver
  valueLen   int(10);                       // actual length returned
  varName    char(128)  options(*varsize);  // env var name
  nameLen    int(10);                       // length of name
  errorCode  char(256)  options(*varsize);  // error code DS
end-pr;

// QtmhRdStin - read from stdin (request body)
dcl-pr QtmhRdStin extproc('QtmhRdStin');
  receiver  char(65535) options(*varsize);  // data receiver
  recvLen   int(10);                        // receiver length
  bytesRead int(10);                        // bytes actually read
  errorCode char(256)   options(*varsize);  // error code DS
end-pr;

// QtmhWrStout - write to stdout (response)
dcl-pr QtmhWrStout extproc('QtmhWrStout');
  buffer    char(65535) options(*varsize);  // data to write
  bufLen    int(10);                        // length to write
  errorCode char(256)   options(*varsize);  // error code DS
end-pr;

// QtmhWrStoutP - meme API via pointeur (pour body UTF-8 brut)
dcl-pr QtmhWrStoutP extproc('QtmhWrStout');
  buffer    pointer value;
  bufLen    int(10);
  errorCode char(256)   options(*varsize);
end-pr;

// memcpy : copie brute de bytes sans conversion CCSID (ILE C runtime)
dcl-pr memcpy pointer extproc('memcpy');
  dest  pointer value;
  src   pointer value;
  count uns(10)  value;
end-pr;

// ---- Service program procedures ----------------------------
/include 'qcpysrc/todosvc_h.rpgle'

// ---- Working variables -------------------------------------
dcl-s reqMethod   varchar(10);
dcl-s pathInfo    varchar(1024);
dcl-s queryString varchar(1024);
dcl-s contentType varchar(256);

dcl-ds todos      likeds(TodoDS) dim(TODOS_MAX_ROWS);
dcl-s  todoCount  int(10);
dcl-s  i          int(10);
dcl-ds wTodo      likeds(TodoDS);

// Variables globales pour sendResponse et readStdin
// Placees ici pour que le precompilateur SQL les voie
// VARCHAR max 32704 en EXEC SQL embarque
dcl-s gBodyEbc   varchar(32704) ccsid(*jobrun);
dcl-s gBodyUtf8  varchar(32704) ccsid(1208);
// Pour la conversion ASCII (stdin) -> EBCDIC
// On utilise char (pas varchar) pour eviter la conversion implicite lors du %subst
dcl-s gStdinAscC char(32704)    ccsid(819);
dcl-s gStdinAsc  varchar(32704) ccsid(819);
dcl-s gStdinEbc  varchar(32704) ccsid(*jobrun);

// ============================================================
// Main entry point
// ============================================================
reqMethod   = getEnvStr('REQUEST_METHOD': 10);
pathInfo    = getEnvStr('PATH_INFO': 1024);
queryString = getEnvStr('QUERY_STRING': 1024);
contentType = getEnvStr('CONTENT_TYPE': 256);

// Avec ScriptAliasMatch, PATH_INFO est vide et la route est dans SCRIPT_NAME
if pathInfo = '';
  pathInfo = getEnvStr('SCRIPT_NAME': 1024);
endif;

select;
  when reqMethod = 'GET' and pathInfo = '/todos';
    handleGetAll();
  when reqMethod = 'GET' and pathInfo = '/todo/pending';
    handleGetPending();
  when reqMethod = 'GET' and pathInfo = '/todo/done';
    handleGetDone();
  when reqMethod = 'POST' and pathInfo = '/todo';
    handlePost();
  when reqMethod = 'PUT' and startsWith(pathInfo: '/todo/status/');
    handlePutStatus();
  when reqMethod = 'DELETE' and pathInfo = '/todo/delete';
    handleDelete();
  other;
    sendResponse('404 Not Found': 'application/json':
                 '{"error":"Not Found"}');
endsl;

*inlr = *on;
return;

// ============================================================
// handleGetAll - GET /todos
// ============================================================
dcl-proc handleGetAll;
  todoCount = GetAllsTodos(todos);
  sendResponse('200 OK': 'application/json': buildJsonArray(todoCount));
end-proc;

// ============================================================
// handleGetPending - GET /todo/pending
// ============================================================
dcl-proc handleGetPending;
  todoCount = GetPendingTodos(todos);
  sendResponse('200 OK': 'application/json': buildJsonArray(todoCount));
end-proc;

// ============================================================
// handleGetDone - GET /todo/done
// ============================================================
dcl-proc handleGetDone;
  todoCount = GetDoneTodos(todos);
  sendResponse('200 OK': 'application/json': buildJsonArray(todoCount));
end-proc;

// ============================================================
// handlePost - POST /todo
// ============================================================
dcl-proc handlePost;
  dcl-s rawBody   varchar(65535);
  dcl-s nameVal   varchar(200);
  dcl-s statusVal varchar(10);
  dcl-s rc        int(10);

  rawBody = readStdin();
  nameVal   = jsonExtract(rawBody: 'name');
  statusVal = jsonExtract(rawBody: 'todoDoneStatus');

  if nameVal = '';
    sendResponse('400 Bad Request': 'application/json':
                 '{"error":"name is required"}');
    return;
  endif;

  clear wTodo;
  wTodo.name       = nameVal;
  wTodo.doneStatus = (statusVal = 'true');
  rc = AddTodo(wTodo);

  if rc = 1;
    sendResponse('200 OK': 'application/json': '"New Todo Added"');
  else;
    sendResponse('500 Internal Server Error': 'application/json':
                 '{"error":"Insert failed"}');
  endif;
end-proc;

// ============================================================
// handlePutStatus - PUT /todo/status/{id}/{status}
// ============================================================
dcl-proc handlePutStatus;
  dcl-s parts varchar(1024);
  dcl-s seg4  varchar(20);
  dcl-s seg5  varchar(20);
  dcl-s wId   int(10);
  dcl-s wDone ind;
  dcl-s rc    int(10);

  parts = pathInfo;
  seg4  = getPathSegment(parts: 3);  // /todo/status/{id}/{status} -> seg3=id
  seg5  = getPathSegment(parts: 4);  // seg4=status

  if seg4 = '' or seg5 = '';
    sendResponse('400 Bad Request': 'application/json':
                 '{"error":"id and status are required in path"}');
    return;
  endif;

  wId   = %int(seg4);
  wDone = (seg5 = 'true');
  rc    = UpdateTodoStatus(wId: wDone);

  if rc = 1;
    sendResponse('200 OK': 'application/json':
                 '"Status updated for id: ' + %trim(seg4) + '"');
  else;
    sendResponse('200 OK': 'application/json': '"Todo Id not Found"');
  endif;
end-proc;

// ============================================================
// handleDelete - DELETE /todo/delete?id=n
// ============================================================
dcl-proc handleDelete;
  dcl-s wId varchar(20);
  dcl-s rc  int(10);

  wId = getQueryParam(queryString: 'id');

  if wId = '';
    sendResponse('400 Bad Request': 'application/json':
                 '{"error":"id query parameter is required"}');
    return;
  endif;

  rc = RemoveTodo(%int(wId));

  if rc = 1;
    sendResponse('200 OK': 'application/json': '"Todo deleted"');
  else;
    sendResponse('200 OK': 'application/json':
                 '"The Todo does not exist"');
  endif;
end-proc;

// ============================================================
// buildJsonArray - serialize todos to JSON array
// ============================================================
dcl-proc buildJsonArray;
  dcl-pi *n varchar(65535);
    count int(10) const;
  end-pi;

  dcl-s json varchar(65535);
  dcl-s i    int(10);

  json = '[';
  for i = 1 to count;
    if i > 1;
      json += ',';
    endif;
    json += '{"todoId":' + %char(todos(i).todoId)
          + ',"name":"'  + jsonEscape(todos(i).name) + '"'
          + ',"todoDoneStatus":' + %char(%int(todos(i).doneStatus = *on))
          + '}';
  endfor;
  json += ']';
  return json;
end-proc;

// ============================================================
// sendResponse - write HTTP headers + body via QtmhWrStout
// ============================================================
dcl-proc sendResponse;
  dcl-pi *n;
    status  varchar(200)   const;
    ctype   varchar(256)   const;
    body    varchar(65535) const;
  end-pi;

  // NL en EBCDIC 037 = x'15' : separateur CGI headers (doc IBM)
  dcl-c  NL       x'15';
  dcl-s  hdrEbc   varchar(1024) ccsid(*jobrun);
  dcl-s  hdrBuf   char(1024);
  dcl-s  errDs    char(256);
  dcl-s  hdrLen   int(10);
  dcl-s  bodyLen  int(10);

  // 1. Headers en EBCDIC avec NL comme separateur
  hdrEbc = 'Status: '        + status          + NL
         + 'Content-Type: '  + ctype
         + '; charset=utf-8' + NL
         + NL;
  hdrLen = %len(hdrEbc);
  %subst(hdrBuf: 1: hdrLen) = hdrEbc;
  QtmhWrStout(hdrBuf: hdrLen: errDs);

  // 2. Body : convertir EBCDIC -> UTF-8 via CAST SQL, puis ecrire
  gBodyEbc = %subst(body: 1: %min(%len(body): 32704));
  exec sql SET :gBodyUtf8 = CAST(:gBodyEbc AS VARCHAR(32704) CCSID 1208);
  bodyLen = %len(gBodyUtf8);
  QtmhWrStoutP(%addr(gBodyUtf8 : *data): bodyLen: errDs);
end-proc;

// ============================================================
// readStdin - read request body via QtmhRdStin
// ============================================================
dcl-proc readStdin;
  dcl-pi *n varchar(65535);
  end-pi;

  dcl-s buf       char(65535);
  dcl-s bufLen    int(10);
  dcl-s bytesRead int(10);
  dcl-s errDs     char(256);
  dcl-s safeLen   int(10);

  bufLen = %size(buf);
  QtmhRdStin(buf: bufLen: bytesRead: errDs);
  if bytesRead = 0;
    return '';
  endif;

  // Le stdin arrive en ASCII (CGIConvMode EBCDIC ne convertit pas application/json).
  // On utilise memcpy pour copier les bytes bruts SANS conversion CCSID,
  // puis CAST SQL ccsid 37 pour traduire ASCII 819 -> EBCDIC 37.
  safeLen = %min(bytesRead: 32704);
  %len(gStdinAsc) = safeLen;
  memcpy(%addr(gStdinAsc : *data): %addr(buf): %uns(safeLen));
  exec sql SET :gStdinEbc = CAST(:gStdinAsc AS VARCHAR(32704) CCSID 37);
  return %trimr(gStdinEbc);
end-proc;

// ============================================================
// getEnvStr - read a CGI environment variable via QtmhGetEnv
// ============================================================
dcl-proc getEnvStr;
  dcl-pi *n varchar(1024);
    varName  varchar(128) const;
    maxLen   int(10)      const;
  end-pi;

  dcl-s receiver  char(1024);
  dcl-s recvLen   int(10);
  dcl-s valueLen  int(10);
  dcl-s nameBuf   char(128);
  dcl-s nameLen   int(10);
  dcl-s errDs     char(256);

  clear receiver;
  recvLen = maxLen;
  nameBuf = varName;
  nameLen = %len(varName);

  QtmhGetEnv(receiver: recvLen: valueLen: nameBuf: nameLen: errDs);

  if valueLen > 0;
    return %subst(receiver: 1: %min(valueLen: maxLen));
  endif;
  return '';
end-proc;

// ============================================================
// jsonExtract - naive JSON value extractor
// ============================================================
dcl-proc jsonExtract;
  dcl-pi *n varchar(200);
    json varchar(65535) const;
    key  varchar(64)    const;
  end-pi;

  dcl-s search varchar(70);
  dcl-s pos1   int(10);
  dcl-s pos2   int(10);
  dcl-s val    varchar(200);

  search = '"' + key + '":';
  pos1 = %scan(search: json);
  if pos1 = 0;
    return '';
  endif;
  pos1 += %len(search);

  dow pos1 <= %len(json) and %subst(json: pos1: 1) = ' ';
    pos1 += 1;
  enddo;

  if %subst(json: pos1: 1) = '"';
    pos1 += 1;
    pos2 = %scan('"': json: pos1);
    if pos2 > 0;
      val = %subst(json: pos1: pos2 - pos1);
    endif;
  else;
    pos2 = %scan(',': json: pos1);
    if pos2 = 0;
      pos2 = %scan('}': json: pos1);
    endif;
    if pos2 > 0;
      val = %trimr(%subst(json: pos1: pos2 - pos1));
    endif;
  endif;
  return val;
end-proc;

// ============================================================
// jsonEscape - escape double-quotes and backslashes
// EBCDIC 037: x'7F'=double-quote  x'E0'=backslash
// ============================================================
dcl-proc jsonEscape;
  dcl-pi *n varchar(400);
    str varchar(200) const;
  end-pi;

  dcl-s result varchar(400);
  dcl-s i      int(10);
  dcl-s ch     char(1);
  dcl-c DQUOTE x'7F';
  dcl-c BSLASH x'E0';

  result = '';
  for i = 1 to %len(str);
    ch = %subst(str: i: 1);
    select;
      when ch = DQUOTE;
        result += BSLASH + DQUOTE;
      when ch = BSLASH;
        result += BSLASH + BSLASH;
      other;
        result += ch;
    endsl;
  endfor;
  return result;
end-proc;

// ============================================================
// getPathSegment - Nth segment of a /slash/delimited/path
// ============================================================
dcl-proc getPathSegment;
  dcl-pi *n varchar(64);
    path   varchar(1024) const;
    segNum int(10)       const;
  end-pi;

  dcl-s remaining varchar(1024);
  dcl-s seg       varchar(64);
  dcl-s slash     int(10);
  dcl-s count     int(10) inz(0);

  remaining = path;
  if %subst(remaining: 1: 1) = '/';
    remaining = %subst(remaining: 2);
  endif;

  dow remaining <> '';
    slash = %scan('/': remaining);
    if slash = 0;
      seg = remaining;
      remaining = '';
    else;
      seg = %subst(remaining: 1: slash - 1);
      remaining = %subst(remaining: slash + 1);
    endif;
    count += 1;
    if count = segNum;
      return seg;
    endif;
  enddo;
  return '';
end-proc;

// ============================================================
// getQueryParam - extract ?key=value from query string
// ============================================================
dcl-proc getQueryParam;
  dcl-pi *n varchar(200);
    qs  varchar(1024) const;
    key varchar(64)   const;
  end-pi;

  dcl-s search varchar(70);
  dcl-s pos1   int(10);
  dcl-s pos2   int(10);

  search = key + '=';
  pos1 = %scan(search: qs);
  if pos1 = 0;
    return '';
  endif;
  pos1 += %len(search);

  pos2 = %scan('&': qs: pos1);
  if pos2 = 0;
    return %subst(qs: pos1);
  else;
    return %subst(qs: pos1: pos2 - pos1);
  endif;
end-proc;

// ============================================================
// startsWith - return *ON if str begins with prefix
// ============================================================
dcl-proc startsWith;
  dcl-pi *n ind;
    str    varchar(1024) const;
    prefix varchar(64)   const;
  end-pi;

  if %len(str) < %len(prefix);
    return *off;
  endif;
  return (%subst(str: 1: %len(prefix)) = prefix);
end-proc;
