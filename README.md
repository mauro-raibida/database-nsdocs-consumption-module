# nsdocs - Módulo de Consumo de Documentos

Este projeto faz parte do banco de dados do **nsdocs**, um gerenciador de documentos fiscais. Este módulo é responsável pelo controle do consumo de documentos fiscais dos clientes. Cada cliente possui uma quantidade de documentos que pode importar por mês e essa parte do DB faz o controle do consumo.

## Estrutura do Projeto

### Scripts

#### `ddl.sql`
Este script contém a definição do banco de dados e suas tabelas, além de uma procedure e triggers para gerenciar o consumo de documentos. Abaixo está uma descrição detalhada:

- **Tabelas**:
  - `documents`: Armazena os documentos fiscais importados pelos clientes. Contém informações como:
    - `id_company`: Identificador da empresa.
    - `access_key`: Chave de acesso única do documento.
    - `request_date`: Data de importação do documento.
    - `origin`: Origem do documento (`file`, `email`, `ws`).
    - `document_type`: Tipo do documento (`nfe`, `cte`, etc.).
    - `status`: Status do documento (`ok`, `pending`, `error`, `non-existing`).
    - **UNIQUE KEY**:
      - `uk_access_key_company`: Garante que não existam dois documentos com a mesma `access_key` para a mesma empresa (`id_company`).

  - `consumption`: Gerencia o consumo de documentos por cliente. Contém informações como:
    - `id_company`: Identificador da empresa.
    - `consumption_date`: Data do consumo.
    - `origin`, `document_type`, `status`: Detalhes do consumo.
    - `quantity`: Quantidade de documentos consumidos.
    - `total`: Total acumulado de documentos.
    - **UNIQUE KEY**:
      - `uk_company_type_origin_date_status`: Garante que não existam registros duplicados para a mesma combinação de `id_company`, `consumption_date`, `origin`, `document_type` e `status`.

- **Procedures**:
  - `update_company_consumption`: Atualiza o consumo de documentos de uma empresa com base nos documentos importados.

- **Triggers**:
  - `trg_documents_ai`: Atualiza o consumo ao inserir um novo documento.
  - `trg_documents_au`: Atualiza o consumo ao alterar um documento.
  - `trg_documents_ad`: Atualiza o consumo ao excluir um documento.

#### `dml.sql`
Este script contém exemplos de dados e operações para popular e manipular o banco de dados:

- **Inserts**:
  - Exemplos de inserção de documentos na tabela `documents`, com diferentes combinações de empresas, tipos de documentos, origens e status.

- **Updates**:
  - Exemplos de atualização do status de documentos, como alterar de `pending` para `ok`.

- **Deletes**:
  - Exemplos de exclusão de documentos, o que impacta diretamente no consumo registrado.

### Subindo o Ambiente com Docker

Para configurar o ambiente, siga os passos abaixo:

1. **Subir o container Docker**:
   - Certifique-se de que o Docker está instalado e em execução.
   - Navegue até o diretório do projeto e execute:
     ```bash
     docker-compose up -d
     ```

2. **Acessar o banco de dados**:
   - Após o container estar em execução, você pode se conectar no DB utilizando o usuário `root`. Como o ambiente está configurado com `MYSQL_ALLOW_EMPTY_PASSWORD=yes`, não é necessário senha.

3. **Executar os scripts manualmente**:
   - Após acessar o banco de dados, execute os scripts `ddl.sql` e `dml.sql` nessa ordem.


## Desafios no Controle de Consumo em Banco de Dados

Embora o controle de consumo em banco de dados seja uma solução funcional, ele apresenta alguns desafios que devem ser considerados:

### 1. **Locks em Registros**
- Quando múltiplos documentos são enviados simultaneamente por uma mesma empresa, especialmente em cenários de alta concorrência, podem ocorrer **locks** nos registros da tabela `consumption`.
- Esses locks podem causar atrasos no processamento de novos documentos, impactando a performance geral do sistema.
- Em casos extremos, podem ocorrer **deadlocks**, exigindo reprocessamento ou intervenção manual.

### 2. **Processamento Síncrono**
- O sistema depende de triggers e procedures para atualizar o consumo automaticamente. Como essas operações são executadas de forma síncrona, ocorre bastante lentidão ao gravar o documento.
- Além disso, erros em triggers ou procedures podem ser difíceis de rastrear e corrigir, já que são executados automaticamente pelo banco de dados.

### 3. **Dificuldade de Escalabilidade**
- À medida que o número de empresas e documentos cresce, o banco de dados pode se tornar um gargalo. Consultas complexas, como as que envolvem `GROUP BY` e agregações, podem impactar o desempenho.
- Escalar horizontalmente (adicionar mais servidores) é mais difícil em um banco de dados relacional, especialmente quando há dependência de triggers e procedures.

### 4. **Manutenção e Adição de Funcionalidades**
- Alterar ou adicionar novas funcionalidades, como novos tipos de documentos ou origens, pode ser complicado. Isso geralmente exige alterações em múltiplas partes do sistema, incluindo tabelas, triggers e procedures.
- Testar essas alterações em um ambiente de produção pode ser arriscado, já que erros podem impactar diretamente os dados existentes.

### 5. **Monitoramento e Depuração**
- Monitorar o consumo e depurar problemas em tempo real pode ser desafiador. Por exemplo:
  - Identificar por que um registro específico não foi atualizado corretamente.
  - Rastrear o impacto de um erro em uma trigger ou procedure.
- Logs detalhados são necessários, mas podem aumentar a complexidade do sistema.

### Considerações Finais
Embora o controle de consumo em banco de dados seja uma abordagem centralizada e eficiente para sistemas de pequeno a médio porte, é importante considerar esses desafios ao projetar e escalar o sistema. Em cenários de alta carga ou requisitos complexos, pode ser necessário explorar alternativas, como:
- Processamento em filas (ex.: RabbitMQ, Kafka) para gerenciar atualizações de consumo.
- Uso de bancos de dados especializados em alta concorrência ou escalabilidade horizontal (ex.: NoSQL).
- Separação da lógica de consumo para um serviço dedicado fora do banco de dados.
