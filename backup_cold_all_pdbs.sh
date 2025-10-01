#!/bin/bash
# SCRIPT: backup_cold_all_pdbs.sh
# DESCRIÇÃO: Realiza um backup a frio (consistente) de todo o CDB e seus PDBs.
# ATENÇÃO: ESTE SCRIPT CAUSA DOWNTIME TOTAL DO BANCO DE DADOS.
# ==============================================================================

# --- Configuração ---
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=SEU_CDB_SID
export PATH=$ORACLE_HOME/bin:$PATH

NFS_MOUNT_POINT="/mnt/oracle_nfs_backup"
DATE_FORMAT=$(date +%Y%m%d)
NFS_DEST_DIR="${NFS_MOUNT_POINT}/${ORACLE_SID}_COLD/${DATE_FORMAT}"
LOG_FILE="/tmp/backup_cold_${ORACLE_SID}_${DATE_FORMAT}.log"

# Função de Log
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a ${LOG_FILE}
}

# --- Lógica do Backup ---
log "INICIANDO BACKUP A FRIO. O BANCO DE DADOS FICARÁ INDISPONÍVEL."

# Obter lista de arquivos antes de parar o banco
log "Coletando lista de datafiles, controlfiles e spfile..."
FILE_LIST=$(sqlplus -s / as sysdba <<EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
select file_name from dba_data_files;
select name from v\$controlfile;
select value from v\$parameter where name = 'spfile';
EXIT;
EOF
)
if [ -z "${FILE_LIST}" ]; then
    log "ERRO: Não foi possível obter a lista de arquivos do banco."
    exit 1
fi

# 1. Parar o banco de dados
log "Parando o banco de dados (SHUTDOWN IMMEDIATE)..."
sqlplus / as sysdba <<EOF
SHUTDOWN IMMEDIATE;
EXIT;
EOF

# 2. Criar diretório de destino e copiar os arquivos
log "Banco de dados parado. Iniciando a cópia dos arquivos para ${NFS_DEST_DIR}..."
mkdir -p ${NFS_DEST_DIR}
for FILE_PATH in ${FILE_LIST}; do
    log "Copiando ${FILE_PATH}..."
    cp -v ${FILE_PATH} ${NFS_DEST_DIR}/ >> ${LOG_FILE} 2>&1
done

log "Cópia dos arquivos concluída."

# 3. Iniciar o banco de dados
log "Iniciando o banco de dados..."
sqlplus / as sysdba <<EOF
STARTUP;
EXIT;
EOF

log "BACKUP A FRIO FINALIZADO. O BANCO DE DADOS ESTÁ ONLINE."