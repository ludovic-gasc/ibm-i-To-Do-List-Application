**FREE
// ============================================================
// CGITTEST - CGI diagnostic : dump env vars en UTF-8
//
// Technique de conversion EBCDIC -> UTF-8 :
//   EXEC SQL SET :wUtf8 = CAST(:wEbcdic AS VARCHAR(4096) CCSID 1208)
//
// Le body JSON est emis en UTF-8.
// Les headers CGI utilisent x'15' (NL EBCDIC) comme separateur,
// conformement a la doc IBM (pas x'0D0A' ni x'0D25').
//
// Lie a QHTTPSVR/QZHBCGI pour QtmhWrStout + QtmhGetEnv.
// ============================================================
ctl-opt dftactgrp(*no)
        actgrp(*new)
        option(*srcstmt: *nodebugio)
        bnddir('TODOLIB/CGITESTBD');

// --- Prototypes APIs IBM i CGI (QHTTPSVR/QZHBCGI) -----------
dcl-pr QtmhWrStout extproc('QtmhWrStout');
  buffer    char(65535) options(*varsize: *omit);
  bufLen    int(10);
  errorCode char(256)   options(*varsize);
end-pr;

// Version accepting a pointer (pour passer le buffer UTF-8 brut)
dcl-pr QtmhWrStoutP extproc('QtmhWrStout');
  buffer    pointer value;
  bufLen    int(10);
  errorCode char(256)   options(*varsize);
end-pr;

dcl-pr QtmhGetEnv extproc('QtmhGetEnv');
  receiver  char(1024) options(*varsize);
  recvLen   int(10);
  valueLen  int(10);
  varName   char(128)  options(*varsize);
  nameLen   int(10);
  errorCode char(256)  options(*varsize);
end-pr;

// --- Prototype interne ---
dcl-pr getEnv varchar(1024);
  name varchar(64) const;
end-pr;

// --- Variables globales ---
// NL en EBCDIC 037 = x'15' : separateur de headers CGI (doc IBM)
dcl-c NL      x'15';

dcl-s wEbcdic varchar(4096) ccsid(*jobrun) inz;
dcl-s wUtf8   varchar(4096) ccsid(1208)    inz;
dcl-s wHdr    varchar(512)  ccsid(*jobrun) inz;
dcl-s wBuf    char(65535)                  inz(*blanks);
dcl-s wErrDs  char(256)                    inz(*blanks);
dcl-s wLen    int(10)                      inz(0);
// Longueur en bytes du body UTF-8 (peut etre > %len si multi-byte)
dcl-s wByteLen int(10)                     inz(0);

// ============================================================
// Mainline
// ============================================================
dcl-s wMethod      varchar(32);
dcl-s wPathInfo    varchar(1024);
dcl-s wQueryString varchar(1024);
dcl-s wScriptName  varchar(1024);

wMethod      = getEnv('REQUEST_METHOD');
wPathInfo    = getEnv('PATH_INFO');
wQueryString = getEnv('QUERY_STRING');
wScriptName  = getEnv('SCRIPT_NAME');

// 1. Construire le body JSON en EBCDIC
wEbcdic = '{"REQUEST_METHOD":"'   + %trimr(wMethod)      + '",'
        + '"PATH_INFO":"'         + %trimr(wPathInfo)    + '",'
        + '"QUERY_STRING":"'      + %trimr(wQueryString) + '",'
        + '"SCRIPT_NAME":"'       + %trimr(wScriptName)  + '"}';

// 2. Convertir EBCDIC -> UTF-8 via CAST SQL (CCSID 1208)
exec sql SET :wUtf8 = CAST(:wEbcdic AS VARCHAR(4096) CCSID 1208);

// 3. Headers CGI en EBCDIC avec NL (x'15') comme separateur
//    Apache lit ces headers en EBCDIC et les traduit lui-meme
wHdr = 'Status: 200 OK'                          + NL
     + 'Content-Type: application/json;'
     + ' charset=utf-8'                           + NL
     + NL;

// 4. Ecrire les headers (EBCDIC, Apache les parse)
wLen = %len(wHdr);
%subst(wBuf: 1: wLen) = wHdr;
QtmhWrStout(wBuf: wLen: wErrDs);

// 5. Ecrire le body UTF-8 directement via pointeur
//    %len(wUtf8) = nb de caracteres; pour UTF-8 on veut les bytes bruts
//    On passe l'adresse des donnees du varchar (pas le header 2-octet)
wByteLen = %len(wUtf8);
QtmhWrStoutP(%addr(wUtf8 : *data): wByteLen: wErrDs);

*inlr = *on;

// ============================================================
// getEnv - lire une variable CGI via QtmhGetEnv
// ============================================================
dcl-proc getEnv;
  dcl-pi *n varchar(1024);
    name varchar(64) const;
  end-pi;
  dcl-s r    char(1024) inz(*blanks);
  dcl-s rLen int(10);
  dcl-s vLen int(10);
  dcl-s n    char(128)  inz(*blanks);
  dcl-s nLen int(10);
  dcl-s err  char(256)  inz(*blanks);

  rLen = 1024;
  n    = name;
  nLen = %len(%trimr(name));
  QtmhGetEnv(r: rLen: vLen: n: nLen: err);
  if vLen > 0;
    return %subst(r: 1: %min(vLen: 1024));
  endif;
  return '(empty)';
end-proc;
