# ms-email-web3 — Email Service + Frontend

Este repositório contém **dois** componentes do projeto de microsserviços com Spring Boot e RabbitMQ:

| Componente | Pasta | Tecnologia | Porta |
| ---------- | ----- | ---------- | ----- |
| **Email Service** | `src/` (raiz) | Java 17+ · Spring Boot · RabbitMQ | `8082` |
| **Frontend** | `frontend/` | Node.js · Express · Axios | `3000` |

> O **User Service** (porta `8081`) vive no repositório separado [`ms-user-web3`](https://github.com/markinog/ms-user-web3) e precisa estar rodando para o fluxo completo funcionar.

---

## Visão geral da arquitetura

```
[Usuário] ──→ Frontend (3000)
                 │
                 ├──→ POST /auth/request-code ──→ User Service (8081)
                 │         └── publica na fila RabbitMQ (CloudAMQP)
                 │                   └──→ Email Service (8082) consome fila
                 │                               └── envia e-mail via Gmail SMTP
                 │
                 └──→ POST /auth/verify-code  ──→ User Service (8081)
                           └── retorna token JWT
```

---

## Pré-requisitos

- **JDK 17+** (o Maven Wrapper `mvnw` já está incluso)
- **Node.js 18+** e **npm**
- **MySQL 8** rodando localmente na porta `3306`
- Conta no **CloudAMQP** (plano gratuito *Little Lemur*) com a URI AMQP em mãos
- Conta **Gmail** com **senha de aplicativo** gerada (não use a senha normal da conta)
  - Acesse: *Conta Google → Segurança → Verificação em duas etapas → Senhas de app*

---

## 1. Banco de dados

Crie o schema no MySQL antes de subir o Email Service:

```sql
CREATE DATABASE ms_email;
```

> As tabelas são criadas automaticamente pelo Hibernate (`ddl-auto=update`) na primeira execução. A tabela principal é `emails`, com colunas: `email_id`, `user_id`, `email_from`, `email_to`, `subject`, `text`, `send_date_email`, `status` (`SENT` ou `ERROR`).

---

## 2. Configuração

### 2.1 Email Service — variáveis de ambiente

Crie um arquivo `.env` na **raiz do repositório** (há um modelo em `.env.example` se existir, senão crie do zero):

```env
RABBITMQ_ADDRESS=amqps://usuario:senha@beaver.rmq.cloudamqp.com/vhost
EMAIL_USERNAME=seuemail@gmail.com
EMAIL_PASSWORD=xxxx xxxx xxxx xxxx
```

> O arquivo `.env` está no `.gitignore` e **não deve ser versionado**.

O `application.properties` do Email Service deve referenciar essas variáveis:

```properties
server.port=8082

# MySQL
spring.datasource.url=jdbc:mysql://localhost:3306/ms_email?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true
spring.datasource.username=root
spring.datasource.password=SUA_SENHA_MYSQL
spring.jpa.hibernate.ddl-auto=update

# RabbitMQ (CloudAMQP)
spring.rabbitmq.addresses=${RABBITMQ_ADDRESS}
broker.queue.email.name=default.email

# Gmail SMTP
spring.mail.host=smtp.gmail.com
spring.mail.port=587
spring.mail.username=${EMAIL_USERNAME}
spring.mail.password=${EMAIL_PASSWORD}
spring.mail.properties.mail.smtp.auth=true
spring.mail.properties.mail.smtp.starttls.enable=true
```

### 2.2 Frontend

O frontend aponta para o User Service via variável `USER_SERVICE_URL` (padrão `http://localhost:8081`). Para sobrescrever:

```bash
# Linux/macOS
export USER_SERVICE_URL=http://localhost:8081

# Windows PowerShell
$env:USER_SERVICE_URL = "http://localhost:8081"
```

---

## 3. Executando

### Opção A — Script automático (Windows PowerShell)

Na raiz do repositório, execute:

```powershell
.\iniciar.ps1
```

O script carrega o `.env`, abre terminais separados para o Email Service e o Frontend, e lembra de subir o User Service manualmente.

### Opção B — Manual (todos os sistemas)

**Terminal 1 — Email Service**

Linux/macOS:
```bash
set -a; source .env; set +a
./mvnw spring-boot:run
```

Windows (PowerShell):
```powershell
Get-Content .env | Where-Object { $_ -match '=' } | ForEach-Object {
    $p = $_ -split '=', 2
    [Environment]::SetEnvironmentVariable($p[0].Trim(), $p[1].Trim())
}
.\mvnw.cmd spring-boot:run
```

**Terminal 2 — Frontend**

```bash
cd frontend
npm install       # apenas na primeira vez
npm start
```

Frontend disponível em **http://localhost:3000**.

---

## 4. Fluxo completo (teste manual)

Com os três serviços rodando (User Service, Email Service e Frontend):

1. Acesse **http://localhost:3000**
2. Digite um **e-mail real** e clique em *Enviar código*
3. Aguarde o e-mail chegar na caixa de entrada (contém um código de 6 dígitos)
4. Digite o código na tela de verificação → o sistema valida e retorna um token JWT
5. Preencha **nome** e escolha o **cargo** (`ROLE_CUSTOMER` ou `ROLE_ADMINISTRATOR`)
6. No **dashboard**:
   - **Testar endpoint protegido** → chama `/api/protected` (proxy para `GET /users/test/customer`)
   - **Meu perfil** → chama `/api/me` (proxy para `GET /users/me`) e exibe os dados
   - **Sair** → limpa o `sessionStorage` e volta para `/`

---

## 5. Estrutura do Email Service

```
src/main/java/
└── com/exemplo/msemail/
    ├── config/
    │   └── RabbitMQConfig.java        # Declara a fila default.email + conversor JSON
    ├── consumer/
    │   └── EmailConsumer.java         # @RabbitListener — consome mensagens da fila
    ├── dto/
    │   └── EmailRecordDto.java        # userId, emailTo, subject, text
    ├── model/
    │   ├── EmailModel.java            # Entidade JPA persistida no ms_email
    │   └── StatusEmail.java (enum)    # SENT | ERROR
    ├── repository/
    │   └── EmailRepository.java
    ├── service/
    │   └── EmailService.java          # sendEmail(): tenta enviar, salva status
    └── EmailServiceApplication.java
```

### Como o envio funciona

1. O `EmailConsumer` recebe um `EmailRecordDto` da fila `default.email`.
2. Repassa para `EmailService.sendEmail()`.
3. O serviço popula um `EmailModel`, tenta enviar via `JavaMailSender` (Gmail SMTP).
4. Persiste o modelo no banco com status `SENT` (sucesso) ou `ERROR` (falha).

---

## 6. Estrutura do Frontend

```
frontend/
├── package.json
├── server.js (ou index.js)       # Express — rotas e proxy
└── public/
    ├── index.html                # Tela: solicitar código por e-mail
    ├── verify.html               # Tela: digitar o código recebido
    ├── register.html             # Tela: cadastrar nome e cargo
    └── dashboard.html            # Painel protegido pós-login
```

### Rotas do Frontend

| Rota | Método | Descrição |
| ---- | ------ | --------- |
| `/` | `GET` | Tela de solicitação de código (`index.html`) |
| `/send-code` | `POST` | Proxy → `POST /auth/request-code` no User Service |
| `/verify` | `GET` | Tela de validação de código (`verify.html`) |
| `/verify-code` | `POST` | Proxy → `POST /auth/verify-code`; salva JWT em `sessionStorage` |
| `/register` | `GET` | Tela de cadastro de nome/cargo (`register.html`) |
| `/register` | `POST` | Proxy → `POST /users/update-profile` com JWT no header |
| `/dashboard` | `GET` | Painel protegido (`dashboard.html`) |
| `/api/protected` | `GET` | Proxy → `GET /users/test/customer` |
| `/api/me` | `GET` | Proxy → `GET /users/me` |

O token JWT viaja sempre no header `Authorization: Bearer <token>`, lido do `sessionStorage` no cliente e repassado pelo Express ao User Service.

---

## 7. Endpoints dependentes do User Service

O frontend depende dos seguintes endpoints expostos pelo `ms-user-web3`:

| Método | Endpoint | Finalidade |
| ------ | -------- | ---------- |
| `POST` | `/auth/request-code` | Gera e armazena código OTP, publica na fila |
| `POST` | `/auth/verify-code` | Valida código e retorna token JWT |
| `POST` | `/users/update-profile` | Atualiza nome e role do usuário autenticado |
| `GET`  | `/users/me` | Retorna perfil do usuário autenticado |
| `GET`  | `/users/test/customer` | Endpoint protegido de teste |

---

## 8. Solução de problemas

| Sintoma | Causa provável | Solução |
| ------- | -------------- | ------- |
| `/send-code` retorna erro de conexão | User Service não está rodando | Suba o `ms-user-web3` na porta `8081` |
| E-mail não chega | Credenciais Gmail ou CloudAMQP erradas | Confirme `EMAIL_USERNAME`, `EMAIL_PASSWORD` (senha de **app**, não a pessoal) e `RABBITMQ_ADDRESS` |
| Email Service não sobe | MySQL indisponível ou banco inexistente | Verifique se o MySQL está rodando e crie `ms_email` |
| `/api/protected` retorna `401` | Token expirado ou ausente | Refaça o fluxo a partir de `/` |
| Mensagem fica na fila sem ser consumida | Email Service não está rodando | Suba o Email Service antes de solicitar códigos |
| `npm start` falha | Dependências não instaladas | Execute `npm install` dentro da pasta `frontend/` |
