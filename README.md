# Automação de Backup e Restore de PDBs Oracle 19c

Este projeto fornece um conjunto de scripts para automatizar o backup de múltiplos Pluggable Databases (PDBs) em um ambiente Oracle Database 19c Enterprise. A solução realiza backups compactados, os transfere para um storage NFS e oferece um método simplificado para a restauração individual de PDBs.

## Índice

1.  [Visão Geral e Funcionalidades](https://www.google.com/search?q=%231-vis%C3%A3o-geral-e-funcionalidades)
2.  [Pré-requisitos](https://www.google.com/search?q=%232-pr%C3%A9-requisitos)
3.  [Estrutura de Arquivos](https://www.google.com/search?q=%233-estrutura-de-arquivos)
4.  [Configuração e Uso do Script de Backup (`backup_all_pdbs.sh`)](https://www.google.com/search?q=%234-configura%C3%A7%C3%A3o-e-uso-do-script-de-backup-backup_all_pdbssh)
      * [Passo 1: Edição das Variáveis de Configuração](https://www.google.com/search?q=%23passo-1-edi%C3%A7%C3%A3o-das-vari%C3%A1veis-de-configura%C3%A7%C3%A3o)
      * [Passo 2: Conceder Permissão de Execução](https://www.google.com/search?q=%23passo-2-conceder-permiss%C3%A3o-de-execu%C3%A7%C3%A3o)
      * [Passo 3: Agendamento com Cron](https://www.google.com/search?q=%23passo-3-agendamento-com-cron)
      * [Passo 4: Verificação dos Logs](https://www.google.com/search?q=%23passo-4-verifica%C3%A7%C3%A3o-dos-logs)
5.  [Configuração e Uso do Script de Restauração (`restore_pdb.sh`)](https://www.google.com/search?q=%235-configura%C3%A7%C3%A3o-e-uso-do-script-de-restaura%C3%A7%C3%A3o-restore_pdbsh)
      * [Passo 1: Identificar o PDB e o Backup](https://www.google.com/search?q=%23passo-1-identificar-o-pdb-e-o-backup)
      * [Passo 2: Ajustar Variáveis e Permissão](https://www.google.com/search?q=%23passo-2-ajustar-vari%C3%A1veis-e-permiss%C3%A3o)
      * [Passo 3: Executar a Restauração](https://www.google.com/search?q=%23passo-3-executar-a-restaura%C3%A7%C3%A3o)
      * [Passo 4: Monitorar o Log de Restauração](https://www.google.com/search?q=%23passo-4-monitorar-o-log-de-restaura%C3%A7%C3%A3o)
6.  [Melhores Práticas e Considerações](https://www.google.com/search?q=%236-melhores-pr%C3%A1ticas-e-considera%C3%A7%C3%B5es)

## 1\. Visão Geral e Funcionalidades

  * **Backup Automatizado:** Descobre e faz backup de todos os PDBs abertos (`READ WRITE`).
  * **Compressão Nativa:** Utiliza a compressão do RMAN para economizar espaço em disco.
  * **Armazenamento Centralizado:** Move os arquivos de backup para um storage NFS de forma organizada, em pastas datadas.
  * **Logging Detalhado:** Cada execução de backup gera um arquivo de log para fácil auditoria e troubleshooting.
  * **Retenção Configurável:** Exclui automaticamente backups antigos (locais e no NFS) para gerenciar o espaço de armazenamento.
  * **Restauração Simplificada:** Script dedicado para restaurar um PDB individualmente a partir dos backups no NFS.

## 2\. Pré-requisitos

Antes de utilizar os scripts, garanta que seu ambiente atenda aos seguintes requisitos:

  * **Banco de Dados:** Oracle Database 19c Enterprise Edition.
  * **Sistema Operacional:** Um sistema operacional baseado em Linux/Unix.
  * **Storage NFS:** Um compartilhamento NFS deve estar configurado e montado permanentemente no servidor de banco de dados (ex: via `/etc/fstab`).
  * **Usuário Oracle:** O usuário do sistema operacional que gerencia o Oracle (ex: `oracle`) deve ter permissões de leitura e escrita tanto no diretório de backup local quanto no ponto de montagem NFS.
  * **Modo Archivelog:** O Container Database (CDB) **deve** estar em modo `ARCHIVELOG` para permitir backups online e recuperação point-in-time.

## 3\. Estrutura de Arquivos

Recomenda-se organizar os scripts em um diretório dedicado no servidor.

```
/home/oracle/scripts/
├── backup_all_pdbs.sh
└── restore_pdb.sh
```

## 4\. Configuração e Uso do Script de Backup (`backup_all_pdbs.sh`)

Este script é o coração da automação. Siga os passos abaixo para configurá-lo.

### Passo 1: Edição das Variáveis de Configuração

Abra o arquivo `backup_all_pdbs.sh` em um editor de texto e modifique **apenas** a seção de configuração no início do arquivo.

```bash
# --- INÍCIO: Seção de Configuração (MODIFIQUE AS VARIÁVEIS ABAIXO) ---

# Definições do Ambiente Oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=CDB19C  # <-- IMPORTANTE: Coloque o SID do seu Container DB aqui

# Diretórios
BACKUP_LOCAL_BASE="/u01/oracle/backup/pdbs"   # Diretório local temporário para os backups
NFS_MOUNT_POINT="/mnt/oracle_nfs_backup"       # Ponto de montagem do storage NFS

# Política de Retenção (em dias)
RETENTION_DAYS=7 # Backups com mais de 7 dias serão excluídos

# --- FIM: Seção de Configuração ---
```

  * `ORACLE_HOME`: Verifique se corresponde ao diretório de instalação do seu Oracle.
  * `ORACLE_SID`: **Fundamental.** Altere para o SID do seu Container Database (CDB).
  * `BACKUP_LOCAL_BASE`: Diretório no servidor local onde os backups serão gerados antes de serem movidos. O usuário `oracle` precisa de permissão de escrita aqui.
  * `NFS_MOUNT_POINT`: O caminho exato onde o seu storage NFS está montado.
  * `RETENTION_DAYS`: Número de dias que os backups serão mantidos. Após este período, serão automaticamente removidos.

### Passo 2: Conceder Permissão de Execução

Torne o script executável com o seguinte comando:

```bash
chmod +x /home/oracle/scripts/backup_all_pdbs.sh
```

### Passo 3: Agendamento com Cron

Para automatizar a execução, agende o script usando o `cron`.

1.  Logado como usuário `oracle`, abra o editor de crontab:

    ```bash
    crontab -e
    ```

2.  Adicione a linha a seguir para agendar o backup para ser executado todos os dias às 23:00.

    ```
    # Minuto Hora Dia Mês DiaDaSemana Comando
    0 23 * * * /home/oracle/scripts/backup_all_pdbs.sh >/dev/null 2>&1
    ```

      * `>/dev/null 2>&1` redireciona a saída padrão, evitando o envio de e-mails pelo cron. O logging já é tratado pelo próprio script.

### Passo 4: Verificação dos Logs

Após a execução do backup, você pode verificar o resultado no diretório de logs definido na variável `LOG_DIR`.

  * **Localização:** `/u01/oracle/backup/pdbs/logs/` (baseado no exemplo de configuração).
  * **Nome do Arquivo:** `backup_pdbs_YYYYMMDD_HHMMSS.log`.

Você pode usar o comando `tail` para ver as últimas linhas de um log:

```bash
tail -f /u01/oracle/backup/pdbs/logs/backup_pdbs_20251001_230000.log
```

## 5\. Configuração e Uso do Script de Restauração (`restore_pdb.sh`)

Este script deve ser usado **manualmente por um DBA** em caso de necessidade de restauração.

### Passo 1: Identificar o PDB e o Backup

Primeiro, determine qual PDB precisa ser restaurado e de qual backup. Navegue até o diretório NFS para encontrar o backup desejado. A estrutura será:

```
/mnt/oracle_nfs_backup/SEU_CDB_SID/YYYYMMDD_HHMMSS/
```

Por exemplo, para o CDB `CDB19C` e um backup de 01 de Outubro de 2025, o caminho seria:
`/mnt/oracle_nfs_backup/CDB19C/20251001_230000/`

### Passo 2: Ajustar Variáveis e Permissão

1.  Abra o script `restore_pdb.sh` e certifique-se de que as variáveis `ORACLE_HOME` and `ORACLE_SID` estão corretas, assim como no script de backup.
2.  Dê permissão de execução:
    ```bash
    chmod +x /home/oracle/scripts/restore_pdb.sh
    ```

### Passo 3: Executar a Restauração

Execute o script a partir da linha de comando, passando dois argumentos:

1.  O nome do PDB a ser restaurado.
2.  O caminho completo para a pasta do backup no NFS.

**Sintaxe:**

```bash
./restore_pdb.sh <NOME_DO_PDB> <CAMINHO_COMPLETO_DO_BACKUP_NO_NFS>
```

**Exemplo Prático:**
Para restaurar o PDB chamado `PDBFINANCEIRO` usando o backup localizado em `/mnt/oracle_nfs_backup/CDB19C/20251001_230000`, o comando seria:

```bash
/home/oracle/scripts/restore_pdb.sh PDBFINANCEIRO /mnt/oracle_nfs_backup/CDB19C/20251001_230000
```

O script irá:

1.  Catalogar os backups no local informado.
2.  Fechar o PDB.
3.  Restaurar os datafiles.
4.  Recuperar o PDB aplicando os archivelogs.
5.  Abrir o PDB.

### Passo 4: Monitorar o Log de Restauração

O progresso da restauração é salvo em um arquivo de log no diretório `/tmp/`. O nome do arquivo será no formato `restore_NOME_DO_PDB_YYYYMMDD.log`.

Use o comando `tail` para acompanhar a operação em tempo real:

```bash
tail -f /tmp/restore_PDBFINANCEIRO_20251001.log
```

## 6\. Melhores Práticas e Considerações

  * **Teste de Restauração:** Agende testes de restauração periódicos em um ambiente de desenvolvimento ou homologação para garantir que seus backups são válidos e que o procedimento funciona como esperado.
  * **Segurança do NFS:** Garanta que as permissões no compartilhamento NFS sejam restritas, permitindo acesso apenas ao servidor de banco de dados e usuários autorizados.
  * **Monitoramento:** Integre a verificação dos logs de backup ao seu sistema de monitoramento (Nagios, Zabbix, etc.) para ser alertado em caso de falhas.
  * **Backup do Controlfile e SPFILE:** O RMAN geralmente inclui um autobackup do controlfile e spfile em cada operação de backup. Certifique-se de que o `CONTROLFILE AUTOBACKUP` está habilitado (`CONFIGURE CONTROLFILE AUTOBACKUP ON;`) para uma recuperação de desastre mais robusta. Os scripts atuais funcionarão com essa configuração habilitada.
