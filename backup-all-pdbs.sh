#!/bin/bash
# =================================================================================
# SCRIPT: backup_all_pdbs.sh
# DESCRIÇÃO: Realiza o backup online e compactado de todos os PDBs abertos
#            em um Oracle Database 19c, e move os backups para um storage NFS.
# AUTOR: Especialista de Banco de Dados Gemini
# VERSÃO: 1.0
# DATA: 01/10/2025
# =================================================================================

# --- INÍCIO: Seção de Configuração (MODIFIQUE AS VARIÁVEIS ABAIXO) ---

# Definições do Ambiente Oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=SEU_CDB_SID  # Ex: CDB19C
export PATH=$ORACLE_HOME/bin:$PATH

# Diretórios
BACKUP_LOCAL_BASE="/u01/oracle/backup/pdbs"   # Diretório local temporário para os backups
NFS_MOUNT_POINT="/mnt/oracle_nfs_backup"       # Ponto de montagem do storage NFS

# Política de Retenção (em dias)
RETENTION_DAYS=7

# --- FIM: Seção de Configuração ---


# --- LÓGICA DO SCRIPT (NÃO MODIFICAR) ---

# Variáveis de Controle
DATE_FORMAT=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_LOCAL_BASE}/${DATE_FORMAT}"
NFS_DEST_DIR="${NFS_MOUNT_POINT}/${ORACLE_SID}/${DATE_FORMAT}"
LOG_DIR="${BACKUP_LOCAL_BASE}/logs"
LOG_FILE="${LOG_DIR}/backup_pdbs_${DATE_FORMAT}.log"

# Função de Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a ${LOG_FILE}
}

# 1. Preparação dos Diretórios
mkdir -p ${BACKUP_DIR}
if [ $? -ne 0 ]; then
    echo "ERRO: Não foi possível criar o diretório de backup local: ${BACKUP_DIR}. Verifique as permissões."
    exit 1
fi
mkdir -p ${LOG_DIR}

log "================================================================="
log "Iniciando processo de backup dos PDBs para o SID: ${ORACLE_SID}"
log "================================================================="

# 2. Verificar se o ponto de montagem NFS está ativo
if ! mountpoint -q "${NFS_MOUNT_POINT}"; then
    log "ERRO CRÍTICO: O diretório NFS (${NFS_MOUNT_POINT}) não está montado. Abortando o backup."
    exit 1
fi

log "Diretório de backup local: ${BACKUP_DIR}"
log "Destino final no NFS: ${NFS_DEST_DIR}"

# 3. Obter a lista de PDBs abertos em modo READ WRITE
log "Identificando PDBs abertos para backup..."
PDB_LIST=$(sqlplus -s / as sysdba <<EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SELECT name FROM v\$pdbs WHERE name != 'PDB\$SEED' AND open_mode = 'READ WRITE';
EXIT;
EOF
)

if [ -z "${PDB_LIST}" ]; then
    log "AVISO: Nenhum PDB em modo 'READ WRITE' encontrado para backup."
    exit 0
fi

log "PDBs a serem backupeados: ${PDB_LIST}"

# 4. Loop para fazer backup de cada PDB
for PDB_NAME in ${PDB_LIST}; do
    log "--- Iniciando backup para o PDB: ${PDB_NAME} ---"
    rman target / log=${LOG_FILE} append <<EOF
    RUN {
        BACKUP AS COMPRESSED BACKUPSET
        PLUGGABLE DATABASE ${PDB_NAME}
        FORMAT '${BACKUP_DIR}/backup_${PDB_NAME}_${DATE_FORMAT}_%U.bkp'
        TAG 'BKP_PDB_${PDB_NAME}';
    }
    EXIT;
EOF
    if [ $? -ne 0 ]; then
        log "ERRO: Falha no backup do RMAN para o PDB: ${PDB_NAME}. Verifique o log para detalhes."
    else
        log "--- Backup do PDB ${PDB_NAME} concluído com sucesso. ---"
    fi
done

# 5. Fazer backup dos ARCHIVELOGS do container
log "Iniciando backup dos ARCHIVELOGS..."
rman target / log=${LOG_FILE} append <<EOF
RUN {
    BACKUP AS COMPRESSED BACKUPSET
    ARCHIVELOG ALL
    FORMAT '${BACKUP_DIR}/arch_${ORACLE_SID}_${DATE_FORMAT}_%U.arc'
    TAG 'BKP_ARCHIVELOG';
}
EXIT;
EOF
if [ $? -ne 0 ]; then
    log "ERRO: Falha no backup dos ARCHIVELOGS."
else
    log "Backup dos ARCHIVELOGS concluído com sucesso."
fi

# 6. Mover arquivos para o NFS
log "Movendo arquivos de backup para o storage NFS..."
mkdir -p "${NFS_DEST_DIR}"
if [ $? -ne 0 ]; then
    log "ERRO: Não foi possível criar o diretório de destino no NFS: ${NFS_DEST_DIR}."
else
    mv ${BACKUP_DIR}/*.bkp ${NFS_DEST_DIR}/
    mv ${BACKUP_DIR}/*.arc ${NFS_DEST_DIR}/
    log "Arquivos movidos com sucesso para ${NFS_DEST_DIR}."
fi

# 7. Limpeza de backups antigos
log "Iniciando processo de limpeza de backups com mais de ${RETENTION_DAYS} dias."
log "Limpando diretório local: ${BACKUP_LOCAL_BASE}"
find ${BACKUP_LOCAL_BASE} -maxdepth 1 -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} \; -print
log "Limpando diretório NFS: ${NFS_MOUNT_POINT}/${ORACLE_SID}"
find ${NFS_MOUNT_POINT}/${ORACLE_SID} -maxdepth 1 -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} \; -print
log "Processo de limpeza concluído."


log "================================================================="
log "Processo de backup finalizado."
log "================================================================="

exit 0