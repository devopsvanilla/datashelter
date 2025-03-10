# mysql-k8s-backup
K8S automation for MySQL backups

## Objetivos da Solução

A solução de backup de MySQL utilizando Helm tem como objetivo automatizar o processo de backup de bancos de dados MySQL em um ambiente Kubernetes. A solução oferece suporte a diferentes tipos de backup, agendamento flexível, notificações por e-mail, múltiplos destinos de backup, criptografia de dados e gerenciamento de retenção de backups.

## Documentação

A documentação completa da solução está disponível no diretório `/docs`. A documentação inclui:

- Arquitetura da solução
- Funcionalidades
- Detalhes de configuração
- Como implantar a solução
- Como verificar se a implantação ocorreu com sucesso
- Como monitorar a execução dos backups
- Como excluir a solução
- Como configurar as dependências da solução, como buckets na AWS e Digital Ocean
- Como gerar chaves de criptografia
- Outras dicas e referências importantes

## Arquitetura

A solução de backup de MySQL é composta pelos seguintes componentes:

- **Job e CronJob**: Recursos do Kubernetes para executar tarefas de backup
- **ConfigMap**: Armazena a configuração do backup
- **Secret**: Armazena credenciais sensíveis do MySQL
- **PersistentVolumeClaim**: Armazena os arquivos de backup
- **Job de Notificação**: Envia notificações por e-mail

## Funcionalidades

A solução oferece as seguintes funcionalidades:

- **Tipos de Backup**: Suporte a backups de esquema total, esquema incremental, servidor total e servidor incremental.
- **Agendamento**: Permite configurar múltiplos agendamentos de backup com diferentes frequências e horários de execução.
- **Notificações por E-mail**: Envia notificações por e-mail sobre a conclusão e erros dos backups, com suporte a múltiplos destinatários.
- **Destinos de Backup**: Suporte a armazenamento de backups no Digital Ocean Spaces e AWS S3.
- **Criptografia**: Criptografa os backups utilizando chaves públicas RSA.
- **Retenção**: Gerencia a retenção de backups, excluindo automaticamente backups antigos após um período especificado.

## Detalhes de Configuração

A configuração da solução de backup de MySQL é gerenciada através do arquivo `values.yaml`. Aqui estão as principais seções de configuração:

- **Detalhes de Conexão MySQL**: Configure o host, porta, nome de usuário e senha do MySQL.
  ```yaml
  mysql:
    host: localhost
    port: 3306
    username: root
    password: password
  ```

- **Tipos de Backup**: Habilite ou desabilite diferentes tipos de backups.
  ```yaml
  backupTypes:
    schemaTotal: true
    schemaIncremental: true
    serverTotal: true
    serverIncremental: true
  ```

- **Agendamento**: Configure os parâmetros de agendamento para cada tipo de backup.
  ```yaml
  scheduling:
    schemaTotal:
      frequency: daily
      time: "02:00"
      maxExecutionTime: 60
    schemaIncremental:
      frequency: daily
      time: "04:00"
      maxExecutionTime: 30
    serverTotal:
      frequency: weekly
      dayOfWeek: "Sunday"
      time: "03:00"
      maxExecutionTime: 120
    serverIncremental:
      frequency: daily
      time: "06:00"
      maxExecutionTime: 45
  ```

- **Notificações por E-mail**: Configure os parâmetros de notificação por e-mail.
  ```yaml
  notifications:
    email:
      enabled: true
      smtp:
        host: smtp.example.com
        port: 587
        username: user@example.com
        password: password
      recipients: recipient1@example.com,recipient2@example.com
  ```

- **Destinos de Backup**: Configure as configurações para Digital Ocean Spaces e AWS S3.
  ```yaml
  backupDestinations:
    digitalOceanSpaces:
      enabled: true
      accessKey: DO_ACCESS_KEY
      secretKey: DO_SECRET_KEY
      region: nyc3
      bucket: my-backups
    awsS3:
      enabled: false
      accessKey: AWS_ACCESS_KEY
      secretKey: AWS_SECRET_KEY
      region: us-west-2
      bucket: my-backups
  ```

- **Criptografia**: Configure a chave pública RSA para criptografia.
  ```yaml
  encryption:
    rsaPublicKeyPath: /path/to/public.key
  ```

- **Retenção**: Configure o período de retenção dos backups.
  ```yaml
  retention:
    days: 30
  ```

## Casos de Uso

A solução de backup de MySQL pode ser utilizada em diversos cenários para garantir backups confiáveis e automatizados de bancos de dados MySQL. Aqui estão alguns casos de uso:

- **Backups Incrementais Diários**: Configure backups incrementais diários para capturar as alterações feitas no banco de dados ao longo do dia.
- **Backups Completos Semanais**: Agende backups completos semanais para criar um snapshot completo do banco de dados, incluindo dados e estrutura.
- **Notificações por E-mail**: Configure notificações por e-mail para receber alertas sobre a conclusão e erros dos backups, garantindo a conscientização oportuna sobre o status dos backups.
- **Backups em Múltiplos Destinos**: Armazene backups em múltiplos destinos, como Digital Ocean Spaces e AWS S3, para redundância e recuperação de desastres.
- **Backups Criptografados**: Criptografe os backups utilizando chaves públicas RSA para garantir a segurança dos dados e conformidade com requisitos regulatórios.
- **Retenção de Backups**: Gerencie a retenção de backups excluindo automaticamente backups antigos após um período especificado, otimizando o uso de armazenamento.
