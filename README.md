# Como rodar — Email Service + Frontend

Este repositório contém **dois** componentes do projeto:

| Componente        | Pasta        | Tecnologia        | Porta padrão |
|-------------------|--------------|-------------------|--------------|
| **Email Service** | raiz / `src` | Java + Spring Boot| `8082`       |
| **Frontend**      | `frontend/`  | Node.js + Express | `3000`       |

> O **User Service** (porta `8081`) é um projeto **separado** e precisa estar rodando
> para o fluxo completo funcionar. Veja a seção [Dependência do User Service](#dependência-do-user-service).

---

## 1. Pré-requisitos

- **JDK 17+** (Maven Wrapper já incluso — não precisa instalar Maven)
- **Node.js 18+** e **npm**
- **MySQL 8** rodando em `localhost:3306`
- Conta **CloudAMQP** (RabbitMQ na nuvem) — string de conexão `amqps://...`
- Conta **Gmail** com **senha de aplicativo** (não use a senha normal da conta)

---

## 2. Configuração

### 2.1 Banco de dados (MySQL)

Crie o banco usado pelo Email Service:

```sql
CREATE DATABASE ms_email;
```

> O `spring.jpa.hibernate.ddl-auto=update` cria as tabelas automaticamente na primeira execução.

Confira usuário/senha em `src/main/resources/application.properties`:

```properties
spring.datasource.url=jdbc:mysql://localhost:3306/ms_email?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true
spring.datasource.username=root
spring.datasource.password=SUA_SENHA_MYSQL
```

### 2.2 Variáveis de ambiente (Email Service)

O Email Service lê as credenciais do RabbitMQ e do Gmail de variáveis de ambiente.
Crie um arquivo `.env` na raiz do repositório (já existe um modelo):

```env
RABBITMQ_ADDRESS=amqps://usuario:senha@host.rmq.cloudamqp.com/vhost
EMAIL_USERNAME=seuemail@gmail.com
EMAIL_PASSWORD=suasenhadeaplicativo
```

> **Importante:** o `.env` está no `.gitignore` e **não** deve ser versionado.
> No Windows (PowerShell), exporte as variáveis antes de subir o serviço (o `iniciar.ps1` já faz isso).

### 2.3 Frontend

O frontend aponta para o User Service via variável `USER_SERVICE_URL`
(padrão `http://localhost:8081`). Para mudar, defina antes de subir:

```powershell
$env:USER_SERVICE_URL = "http://localhost:8081"
```

---

## 3. Executando

### Opção A — Script automático (Windows)

Na raiz do repositório:

```powershell
.\iniciar.ps1
```

Ele abre **terminais separados** para o Email Service e o Frontend
(e lembra de iniciar o User Service, que mora em outro repositório).

### Opção B — Manual (passo a passo)

**Terminal 1 — Email Service**

```powershell
# carrega as variáveis do .env para a sessão atual
Get-Content .env | Where-Object { $_ -match '=' } | ForEach-Object {
    $p = $_ -split '=', 2
    [Environment]::SetEnvironmentVariable($p[0].Trim(), $p[1].Trim())
}
.\mvnw.cmd spring-boot:run
```

> Em Linux/Mac: `set -a; source .env; set +a && ./mvnw spring-boot:run`

**Terminal 2 — Frontend**

```powershell
cd frontend
npm install        # apenas na primeira vez
npm start
```

Frontend disponível em **http://localhost:3000**.

---

## 4. Dependência do User Service

O frontend e o fluxo de autenticação dependem do **User Service** (porta `8081`),
que está em **outro repositório**. Ele precisa expor os seguintes endpoints:

| Método | Endpoint                  | Uso pelo frontend                          |
|--------|---------------------------|--------------------------------------------|
| POST   | `/auth/request-code`      | Solicita o código por e-mail               |
| POST   | `/auth/verify-code`       | Valida o código e devolve o token JWT      |
| POST   | `/users/update-profile`   | Cadastro de **nome** e **role** (Etapa 4)  |
| GET    | `/users/me`               | Botão "Meu perfil" do dashboard            |
| GET    | `/users/test/customer`    | Chamado pelo `/api/protected` do frontend  |

> **Etapa 4 no User Service** (implementar lá, não neste repo):
> - `UpdateProfileDto` (`name`, `role: RoleName`)
> - `UserService.updateProfile(email, dto)` — atualiza `name` e substitui a lista de roles
> - `UserController` com `@PostMapping("/update-profile")` usando `authentication.getName()`
> - Liberar `/users/update-profile` (autenticado) no `SecurityConfiguration`

---

## 5. Fluxo completo (teste manual)

1. Acesse **http://localhost:3000**
2. Digite um **e-mail real** → clique em *Enviar código*
3. Confira a caixa de entrada (e-mail enviado pelo Email Service via Gmail) e copie o **código de 6 dígitos**
4. Digite o código → ao validar, o token JWT é salvo em `sessionStorage` e você é levado à **página de cadastro** (`/register`)
5. Preencha **nome** e escolha o **cargo** (`ROLE_CUSTOMER` ou `ROLE_ADMINISTRATOR`) → *Salvar e continuar*
6. No **dashboard** (`/dashboard`):
   - **Testar endpoint protegido** → chama `GET /api/protected` (proxy para `/users/test/customer`)
   - **Meu perfil** → chama `GET /api/me` (proxy para `/users/me`) e exibe os dados
   - **Sair** → limpa o `sessionStorage` e volta para `/`

---

## 6. Rotas do Frontend (resumo)

| Rota                  | Método | Descrição                                              |
|-----------------------|--------|--------------------------------------------------------|
| `/`                   | GET    | Tela de solicitação de código (`index.html`)           |
| `/send-code`          | POST   | Repassa para `POST /auth/request-code`                 |
| `/verify`             | GET    | Tela de validação de código (`verify.html`)            |
| `/verify-code`        | POST   | Repassa para `POST /auth/verify-code`, devolve o token |
| `/register`           | GET    | Tela de cadastro de nome/cargo (`register.html`)       |
| `/register`           | POST   | Repassa para `POST /users/update-profile` com o JWT    |
| `/dashboard`          | GET    | Painel protegido (`dashboard.html`)                    |
| `/api/protected`      | GET    | Proxy para `GET /users/test/customer`                  |
| `/api/me`             | GET    | Proxy para `GET /users/me`                             |

O token JWT viaja sempre no header `Authorization: Bearer <token>`, lido do `sessionStorage` no cliente.

---

## 7. Solução de problemas

- **`/send-code` retorna erro** → o User Service não está rodando em `http://localhost:8081`.
- **E-mail não chega** → confira `EMAIL_USERNAME`/`EMAIL_PASSWORD` (senha de **aplicativo** do Gmail) e a conexão CloudAMQP.
- **`/api/protected` retorna 401** → token expirado/ausente; refaça o login a partir do `/`.
- **Email Service não sobe** → verifique se o MySQL está ativo e o banco `ms_email` existe.
