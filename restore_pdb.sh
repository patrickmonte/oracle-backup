#!/bin/bash
# =================================================================================
# SCRIPT: restore_pdb.sh
# DESCRIÇÃO: Restaura e recupera um único PDB a partir de um backup
#            localizado em um storage NFS.
# AUTOR: Especialista de Banco de Dados Gemini
# VERSÃO: 1.0
# DATA: 01/10/2025
# USO: ./restore_pdb.sh <NOME_DO_PDB> <CAMINHO_COMPLETO_DO_BACKUP_NO_NFS>
# Exemplo: ./restore_pdb.sh PDBFINANCEIRO /mnt/oracle_nfs_backup/CDB19C/20251001_230000
# =================================================================================

# --- Configurações do Ambiente ---
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=SEU_CDB_SID # Ex: CDB19C
export PATH=$ORACLE_HOME/bin:$PATH

# --- Validação dos Argumentos ---
if [ "$#" -ne 2 ]; then
    echo "USO: $0 <NOME_DO_PDB> <CAMINHO_COMPLETO_DO_BACKUP_NO_NFS>"
    echo "Exemplo: $0 PDBFINANCEIRO /mnt/oracle_nfs_backup/CDB19C/20251001_230000"
    exit 1
fi

PDB_TO_RESTORE=$1
BACKUP_NFS_PATH=$2
LOG_FILE="/tmp/restore_${PDB_TO_RESTORE}_$(date +%Y%m%d).log"

# --- Lógica de Restauração ---

echo "Iniciando a restauração do PDB: ${PDB_TO_RESTORE}" > ${LOG_FILE}
echo "Localização do Backup: ${BACKUP_NFS_PATH}" >> ${LOG_FILE}
echo "Para detalhes, veja o log em: ${LOG_FILE}"

rman target / log=${LOG_FILE} append <<EOF
RUN {
    # Catalogar os arquivos de backup do diretório NFS
    # Isso informa ao RMAN sobre a localização dos backups
    CATALOG START WITH '${BACKUP_NFS_PATH}';

    # Colocar o PDB em modo de manutenção (fechado)
    ALTER PLUGGABLE DATABASE ${PDB_TO_RESTORE} CLOSE;

    # Executar a restauração
    RESTORE PLUGGABLE DATABASE ${PDB_TO_RESTORE};

    # Executar a recuperação (aplicar archivelogs)
    RECOVER PLUGGABLE DATABASE ${PDB_TO_RESTORE};

    # Abrir o PDB
    ALTER PLUGGABLE DATABASE ${PDB_TO_RESTORE} OPEN;
}
EXIT;
EOF

if [ $? -eq 0 ]; then
    echo "Restauração do PDB ${PDB_TO_RESTORE} concluída com SUCESSO."
    echo "Verifique o PDB e o log ${LOG_FILE} para confirmação."
else
    echo "ERRO: A restauração do PDB ${PDB_TO_RESTORE} FALHOU."
    echo "Verifique o log ${LOG_FILE} para identificar a causa do erro."
fi

exit 0