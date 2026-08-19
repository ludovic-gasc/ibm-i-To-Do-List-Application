#!/bin/bash
# =============================================================================
# deploy.sh — Déploiement complet de l'IBM i To-Do List API
#
# Prérequis :
#   - Exécuter depuis un shell PASE sur l'IBM i (ssh user@ibmi)
#   - L'utilisateur doit avoir *ALLOBJ ou être propriétaire de TODOLIB
#   - Le répertoire source doit être cloné dans $SRC_DIR
#
# Usage :
#   chmod +x deploy.sh
#   ./deploy.sh
#
# Variables personnalisables :
#   SRC_DIR   : chemin IFS vers le répertoire source du projet
#   LIB       : librairie IBM i cible
#   HTTP_INST : nom de l'instance Apache HTTP Server
#   HTTP_PORT : port d'écoute
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SRC_DIR="${SRC_DIR:-/home/ITZUSER/builds/ibm-i-To-Do-List-Application}"
LIB="${LIB:-TODOLIB}"
HTTP_INST="${HTTP_INST:-TODOAPI}"
HTTP_PORT="${HTTP_PORT:-8080}"
HTTP_ROOT="/www/${HTTP_INST,,}"   # ex: /www/todoapi

# Profils utilisateur des jobs CGI Apache (à adapter selon l'instance)
# Vérifier avec : SELECT AUTHORIZATION_NAME FROM TABLE(QSYS2.ACTIVE_JOB_INFO())
#                 WHERE SUBSYSTEM = 'QHTTPSVR' AND JOB_NAME LIKE '%<INST>%'
CGI_PROFILES="QTMHHTP1 QTMHHTTP"

# ---------------------------------------------------------------------------
# Fonctions utilitaires
# ---------------------------------------------------------------------------
log()  { echo "[$(date '+%H:%M:%S')] $*"; }
run()  { log "CL: $*"; system "$*"; }
fail() { echo "ERREUR: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Vérifications préalables
# ---------------------------------------------------------------------------
log "=== ÉTAPE 1 : Vérifications préalables ==="

[ -d "$SRC_DIR" ] || fail "Répertoire source introuvable : $SRC_DIR"
[ -f "$SRC_DIR/qsqlrpglesrc/todosvc.sqlrpgle" ]      || fail "todosvc.sqlrpgle introuvable"
[ -f "$SRC_DIR/qsqlrpglesrc/todoapi.pgm.sqlrpgle" ]  || fail "todoapi.pgm.sqlrpgle introuvable"
[ -f "$SRC_DIR/qsrvsrc/TODOSVC.bnd" ]                || fail "TODOSVC.bnd introuvable"

log "Sources trouvés dans $SRC_DIR"

# ---------------------------------------------------------------------------
# 2. Création de la librairie (si inexistante)
# ---------------------------------------------------------------------------
log "=== ÉTAPE 2 : Librairie $LIB ==="

system "QSYS/CRTLIB LIB($LIB) AUT(*EXCLUDE)" 2>/dev/null \
  && log "Librairie $LIB créée" \
  || log "Librairie $LIB existe déjà"

# ---------------------------------------------------------------------------
# 3. Création de la table TODOS (si inexistante)
# ---------------------------------------------------------------------------
log "=== ÉTAPE 3 : Table ${LIB}.TODOS ==="

system "QSYS/RUNSQL SQL('CREATE TABLE IF NOT EXISTS ${LIB}.TODOS ( \
  TODOID     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY, \
  NAME       VARCHAR(200) NOT NULL, \
  DONESTATUS SMALLINT NOT NULL DEFAULT 0 \
) RCDFMT TODOS') COMMIT(*NONE)" 2>/dev/null \
  && log "Table TODOS créée ou déjà existante"

# ---------------------------------------------------------------------------
# 4. Autorisations sur la table TODOS
#    - *PUBLIC *USE : lecture publique (GET)
#    - Profils CGI *CHANGE : nécessaire pour INSERT, UPDATE, DELETE
# ---------------------------------------------------------------------------
log "=== ÉTAPE 4 : Autorisations table TODOS ==="

run "QSYS/GRTOBJAUT OBJ(${LIB}/TODOS) OBJTYPE(*FILE) USER(*PUBLIC) AUT(*USE)"

for profile in $CGI_PROFILES; do
  # Vérifie si le profil existe avant d'accorder l'autorité
  if system "QSYS/CHKOBJ OBJ(QSYS/${profile}) OBJTYPE(*USRPRF)" 2>/dev/null; then
    run "QSYS/GRTOBJAUT OBJ(${LIB}/TODOS) OBJTYPE(*FILE) USER(${profile}) AUT(*CHANGE)"
    log "Autorité *CHANGE accordée à ${profile} sur ${LIB}/TODOS"
  else
    log "AVERTISSEMENT: profil ${profile} inexistant, ignoré"
  fi
done

# ---------------------------------------------------------------------------
# 5. Binding directory TODOSVC_BD
# ---------------------------------------------------------------------------
log "=== ÉTAPE 5 : Binding directory TODOSVC_BD ==="

system "QSYS/CRTBNDDIR BNDDIR(${LIB}/TODOSVC_BD) AUT(*EXCLUDE)" 2>/dev/null \
  && log "BNDDIR TODOSVC_BD créé" \
  || log "BNDDIR TODOSVC_BD existe déjà"

# Ajoute QTMHCGI (APIs CGI : QtmhWrStout, QtmhGetEnv, QtmhRdStin)
system "QSYS/ADDBNDDIRE BNDDIR(${LIB}/TODOSVC_BD) OBJ((QHTTPSVR/QTMHCGI *SRVPGM *IMMED))" 2>/dev/null \
  || log "QTMHCGI déjà dans TODOSVC_BD"

# ---------------------------------------------------------------------------
# 6. Compilation de TODOSVC (module)
# ---------------------------------------------------------------------------
log "=== ÉTAPE 6 : Compilation TODOSVC module ==="

run "QSYS/CRTSQLRPGI \
  OBJ(${LIB}/TODOSVC) \
  OBJTYPE(*MODULE) \
  SRCSTMF('${SRC_DIR}/qsqlrpglesrc/todosvc.sqlrpgle') \
  COMMIT(*NONE) \
  OPTION(*EVENTF) \
  DBGVIEW(*SOURCE) \
  CLOSQLCSR(*ENDMOD) \
  CVTCCSID(*JOB) \
  RPGPPOPT(*LVL2)"

# ---------------------------------------------------------------------------
# 7. Création de TODOSVC (service program)
# ---------------------------------------------------------------------------
log "=== ÉTAPE 7 : Création TODOSVC service program ==="

run "QSYS/CRTSRVPGM \
  SRVPGM(${LIB}/TODOSVC) \
  MODULE(${LIB}/TODOSVC) \
  SRCSTMF('${SRC_DIR}/qsrvsrc/TODOSVC.bnd') \
  ACTGRP(*CALLER) \
  AUT(*EXCLUDE)"

# Ajoute TODOSVC dans le binding directory
system "QSYS/ADDBNDDIRE BNDDIR(${LIB}/TODOSVC_BD) OBJ((${LIB}/TODOSVC *SRVPGM *IMMED))" 2>/dev/null \
  || log "TODOSVC déjà dans TODOSVC_BD"

# ---------------------------------------------------------------------------
# 8. Compilation de TODOAPI (programme CGI)
# ---------------------------------------------------------------------------
log "=== ÉTAPE 8 : Compilation TODOAPI ==="

run "QSYS/CRTSQLRPGI \
  OBJ(${LIB}/TODOAPI) \
  SRCSTMF('${SRC_DIR}/qsqlrpglesrc/todoapi.pgm.sqlrpgle') \
  OPTION(*EVENTF) \
  DBGVIEW(*SOURCE) \
  CLOSQLCSR(*ENDMOD) \
  CVTCCSID(*JOB) \
  COMPILEOPT('TGTCCSID(*JOB)') \
  RPGPPOPT(*LVL2)"

# ---------------------------------------------------------------------------
# 9. Configuration Apache HTTP Server
# ---------------------------------------------------------------------------
log "=== ÉTAPE 9 : Instance Apache $HTTP_INST ==="

# Crée l'instance si elle n'existe pas
system "QSYS/CRTDIR DIR('${HTTP_ROOT}')" 2>/dev/null || true
system "QSYS/CRTDIR DIR('${HTTP_ROOT}/conf')" 2>/dev/null || true
system "QSYS/CRTDIR DIR('${HTTP_ROOT}/htdocs')" 2>/dev/null || true
system "QSYS/CRTDIR DIR('${HTTP_ROOT}/logs')" 2>/dev/null || true

# Crée l'instance Apache si elle n'existe pas
system "QSYS/QTMHHTTP CRTSVR SVRNM(${HTTP_INST}) \
  SVRDSC('ToDo List REST API') \
  CFGFILE('${HTTP_ROOT}/conf/httpd.conf')" 2>/dev/null \
  && log "Instance $HTTP_INST créée" \
  || log "Instance $HTTP_INST existe déjà"

# Dépose le fichier httpd.conf
cat > "${HTTP_ROOT}/conf/httpd.conf" << HTTPD_EOF
# ${HTTP_INST} HTTP Server - port ${HTTP_PORT}
# Généré par deploy.sh le $(date '+%Y-%m-%d')

Listen *:${HTTP_PORT}
HotBackup Off
HostNameLookups Off
UseCanonicalName On
TraceEnable Off
KeepAlive Off
TimeOut 30000
ThreadsPerChild 5
DefaultFsCCSID 37
DefaultNetCCSID 819

CustomLog logs/access_log common
ErrorLog logs/error_log
LogLevel warn
LogMaint logs/access_log 7 0
LogMaint logs/error_log 7 0

DocumentRoot ${HTTP_ROOT}/htdocs

# Ajoute ${LIB} à la library list du job CGI
SetEnv QIBM_CGI_LIBRARY_LIST ${LIB}

<Directory />
  Require all denied
</Directory>

# Route toutes les URLs /todo* vers le programme CGI TODOAPI
# Note : ScriptAliasMatch place la route dans SCRIPT_NAME (pas PATH_INFO)
ScriptAliasMatch ^/(todo.*) /QSYS.LIB/${LIB}.LIB/TODOAPI.PGM

<Directory /QSYS.LIB/${LIB}.LIB/>
  Require all granted
  Options +ExecCGI
</Directory>
HTTPD_EOF

log "httpd.conf écrit dans ${HTTP_ROOT}/conf/"

# ---------------------------------------------------------------------------
# 10. Démarrage du serveur HTTP
# ---------------------------------------------------------------------------
log "=== ÉTAPE 10 : Démarrage du serveur HTTP ==="

# Arrêt propre si déjà actif
system "QSYS/ENDTCPSVR SERVER(*HTTP) HTTPSVR(${HTTP_INST})" 2>/dev/null || true
sleep 2

run "QSYS/STRTCPSVR SERVER(*HTTP) HTTPSVR(${HTTP_INST})"
sleep 3

# ---------------------------------------------------------------------------
# 11. Smoke test
# ---------------------------------------------------------------------------
log "=== ÉTAPE 11 : Smoke test GET /todos ==="

HTTP_RESP=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:${HTTP_PORT}/todos)
if [ "$HTTP_RESP" = "200" ]; then
  log "✅ GET /todos → HTTP 200 — déploiement réussi"
  curl -s http://127.0.0.1:${HTTP_PORT}/todos
  echo ""
else
  fail "GET /todos a retourné HTTP $HTTP_RESP — vérifier les logs : ${HTTP_ROOT}/logs/error_log"
fi

log "=== DÉPLOIEMENT TERMINÉ ==="
log "API disponible sur http://$(hostname):${HTTP_PORT}"
log "Logs Apache : ${HTTP_ROOT}/logs/"
