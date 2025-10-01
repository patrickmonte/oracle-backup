#!/bin/bash
# SCRIPT: backup_datapump_pdbs.sh
# DESCRIÇÃO: Realiza um backup lógico (export) de todos os PDBs abertos.
# ==============================================================================

# --- Configuração ---
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=SEU_CDB_SID
export PATH=$ORACLE_HOME/bin:$PATH

NFS_MOUNT_POINT="/mnt/oracle_nfs_backup"
DATE_FORMAT=$(date +%Y%m%d)
NFS_DEST_DIR="${NFS_MOUNT_POINT}/${ORACLE_SID}_DATAPUMP/${DATE_FORMAT}"

# É necessário um DIRECTORY object no Oracle apontando para o destino do backup
# Ex: CREATE OR REPLACE DIRECTORY NFS_BACKUP_DP AS '/mnt/oracle_nfs_backup/SEU_CDB_SID_DATAPUMP/';
#     GRANT READ, WRITE ON DIRECTORY NFS_BACKUP_DP TO system;
ORACLE_DIRECTORY_NAME="NFS_BACKUP_DP"

mkdir -p ${NFS_DEST_DIR}

# --- Lógica do Backup ---

# Obter lista de PDBs
PDB_LIST=$(sqlplus -s / as sysdba <<EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SELECT name FROM v\$pdbs WHERE name != 'PDB\$SEED' AND open_mode = 'READ WRITE';
EXIT;
EOF
)

for PDB in ${PDB_LIST}; do
    echo "Iniciando export do PDB: ${PDB}"
    DUMP_FILE="${PDB}_${DATE_FORMAT}.dmp"
    LOG_FILE="${PDB}_${DATE_FORMAT}.log"
    
    expdp system/sua_senha@${PDB} \
    FULL=Y \
    DIRECTORY=${ORACLE_DIRECTORY_NAME} \
    DUMPFILE=${DUMP_FILE} \
    LOGFILE=${LOG_FILE} \
    COMPRESSION=ALL
    
    if [ $? -eq 0 ]; then
        echo "Export do PDB ${PDB} concluído com sucesso."
    else
        echo "ERRO no export do PDB ${PDB}. Verifique o log: ${LOG_FILE}"
    fi
done

echo "Processo de Data Pump finalizado."