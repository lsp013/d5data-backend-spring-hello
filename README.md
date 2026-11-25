# Spring Hello

**Languages:** English (this file) · [中文说明](README.zh-CN.md)

Repository: <https://github.com/lsp013/d5data-backend-spring-hello>

A small Spring Boot 3.2.0 + Spring Security service that demonstrates:

- username/password login with a seeded in-memory user (`test` / `123456`);
- stateless HS256 JWT authentication;
- a protected `GET /api/hello` endpoint that returns `Hello World`;
- JSON 401 responses instead of an HTML login redirect.

## Tech stack

| Item | Version |
| --- | --- |
| Java | 17 |
| Spring Boot | 3.2.0 |
| Spring Security | 6.2.x (managed by Boot 3.2.0) |
| JJWT | 0.12.6 |
| Build | Maven Wrapper 3.10.1 |

No Lombok, no database, and no globally installed Maven is required.

## How this project was generated

`start.spring.io` was used for the skeleton, but at the time of implementation
(2026-11-26) it rejected Spring Boot 3.2.0 because its compatibility range was
`>=4.0.0`:

```json
{"status":400,"error":"Bad Request","message":"Invalid Spring Boot version '3.2.0', Spring Boot compatibility range is >=4.0.0"}
```

The skeleton was therefore downloaded from Initializr with Boot 4.0.10 and the
`pom.xml` was then explicitly pinned to **Spring Boot 3.2.0** with Java 17. The
Boot 4-specific starter names were replaced by the standard Boot 3.2 starters
(`spring-boot-starter-web`, `spring-boot-starter-security`,
`spring-boot-starter-validation`). The result was built and tested with
Boot 3.2.0, as shown below.

## Requirements

- JDK 17+
- Windows, macOS or Linux
- Internet access on the first build so Maven can download dependencies

If `JAVA_HOME` is not configured on Windows, point it at the JDK 17 installation
before running the wrapper:

```powershell
$env:JAVA_HOME = "E:\jdv17"
```

## Build and run

```powershell
# From the project root
.\mvnw.cmd -q -DskipTests package
java -jar target\spring-hello-0.0.1-SNAPSHOT.jar
```

On Linux/macOS use `./mvnw` instead of `.\mvnw.cmd`.

The service listens on port **8080** by default. Override it with either:

```powershell
$env:SERVER_PORT = "8081"
java -jar target\spring-hello-0.0.1-SNAPSHOT.jar
```

or:

```powershell
java -jar target\spring-hello-0.0.1-SNAPSHOT.jar --server.port=8081
```

Configuration is in `src/main/resources/application.yaml`:

| Setting | Default | Override |
| --- | --- | --- |
| `server.port` | `8080` | `SERVER_PORT` |
| `app.jwt.secret` | development-only 46-byte secret | `JWT_SECRET` |
| `app.jwt.expiration-seconds` | `3600` | `JWT_EXPIRATION_SECONDS` |

The default JWT secret exists only to make the exercise runnable out of the
box. **Always set `JWT_SECRET` to a random secret of at least 32 bytes outside
local development.**

## API contract

| Method | Path | Auth | Request | Success | Errors |
| --- | --- | --- | --- | --- | --- |
| POST | `/api/auth/login` | Public | `{"username":"test","password":"123456"}` | `200` `{"token":"...","tokenType":"Bearer","expiresIn":3600}` | `401` bad credentials, `400` invalid body |
| GET | `/api/hello` | `Authorization: Bearer <token>` | none | `200` `text/plain` body `Hello World` | `401` missing/invalid/expired/forged token |

Unauthenticated protected requests return JSON, for example:

```json
{"status":401,"error":"Unauthorized","message":"Authentication is required to access this resource","path":"/api/hello"}
```

Bad login credentials return:

```json
{"status":401,"error":"Unauthorized","message":"Invalid username or password","path":"/api/auth/login"}
```

## Security design

- **Stateless sessions.** `SessionCreationPolicy.STATELESS` is used, so no HTTP
  session is created and every request must present a JWT.
- **JWT.** `JwtService` signs tokens with HS256 using a key derived from
  `app.jwt.secret`. The token subject is the username and it expires after
  `app.jwt.expiration-seconds` (3600 by default).
- **JWT filter.** `JwtAuthenticationFilter` runs before
  `UsernamePasswordAuthenticationFilter`, reads `Authorization: Bearer ...`,
  verifies the signature and expiry, loads the user, and populates the
  `SecurityContext`. Invalid, malformed, expired, or forged tokens simply leave
  the request unauthenticated.
- **JSON 401.** `RestAuthenticationEntryPoint` writes the JSON 401 response, so
  Spring Security never redirects to a login page. `RestAccessDeniedHandler`
  provides a JSON 403 for authorization failures.
- **Users and passwords.** `InMemoryUserDetailsManager` seeds the single user
  `test`; its password is BCrypt-encoded at startup by `BCryptPasswordEncoder`.
  The plaintext password is not stored as a hash literal in the source.
- **Endpoints.** `POST /api/auth/login` is public. All other `/api/**` routes are
  authenticated. `httpBasic`, `formLogin`, and `logout` are explicitly disabled.
  CSRF is disabled because this is a stateless, header-token API and no
  cookie-based authentication is used.
- **Validation.** `LoginRequest` uses Bean Validation (`@NotBlank`), and a
  `@RestControllerAdvice` converts validation/body errors into JSON 400
  responses.

## Usage examples

### PowerShell

```powershell
$body = @{ username = "test"; password = "123456" } | ConvertTo-Json
$login = Invoke-RestMethod -Method Post `
    -Uri "http://localhost:8080/api/auth/login" `
    -ContentType "application/json" -Body $body

$token = $login.token
$login | Format-List token, tokenType, expiresIn

Invoke-RestMethod -Method Get -Uri "http://localhost:8080/api/hello" `
    -Headers @{ Authorization = "Bearer $token" }
```

Inspect a 401 without triggering a PowerShell exception:

```powershell
Invoke-WebRequest -Uri "http://localhost:8080/api/hello" -SkipHttpErrorCheck |
    Select-Object StatusCode, Content
```

### curl

```bash
# No token -> 401
curl -i http://localhost:8080/api/hello

# Login -> 200 and a token
curl -s -X POST http://localhost:8080/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"test","password":"123456"}'

# Use the returned token
curl -i http://localhost:8080/api/hello \
  -H 'Authorization: Bearer <paste-token-here>'
```

Windows PowerShell strips embedded double quotes from native command arguments.
For `curl.exe` there, put the body in a file (or use `Invoke-RestMethod` above):

```powershell
Set-Content -Path login.json -Value '{"username":"test","password":"123456"}' -NoNewline
curl.exe -s -X POST "http://localhost:8080/api/auth/login" `
  -H "Content-Type: application/json" --data-binary "@login.json"
```

## Verification record (actually executed)

Environment: Windows, PowerShell 7, JDK 17.0.4.1, 2026-11-26.

### 1. Build

```text
PS> .\mvnw.cmd -q -DskipTests package
PS> $LASTEXITCODE
0

PS> Get-ChildItem target\*.jar | Select-Object Name,Length
Name                              Length
----                              ------
spring-hello-0.0.1-SNAPSHOT.jar 24994660
```

### 2. Startup

```text
2026-11-26T01:36:01.800+08:00  INFO ... Starting SpringHelloApplication v0.0.1-SNAPSHOT using Java 17.0.4.1 with PID 157480
2026-11-26T01:36:05.566+08:00  INFO ... Tomcat initialized with port 8080 (http)
2026-11-26T01:36:06.921+08:00  INFO ... Tomcat started on port 8080 (http) with context path ''
2026-11-26T01:36:06.951+08:00  INFO ... Started SpringHelloApplication in 6.448 seconds (process running for 8.794)
```

### 3. HTTP checks

**No token -> 401**

```text
GET /api/hello
HTTP_STATUS=401
{"status":401,"error":"Unauthorized","message":"Authentication is required to access this resource","path":"/api/hello"}
```

**Correct login -> 200 and a token**

```text
POST /api/auth/login
{"username":"test","password":"123456"}

HTTP_STATUS=200
BODY={"token":"eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZX... (token truncated for display)
TOKEN_TYPE=Bearer EXPIRES_IN=3600 TOKEN_LENGTH=129
```

**Valid token -> 200 Hello World**

```text
GET /api/hello
Authorization: Bearer <token>

HTTP/1.1 200
Content-Type: text/plain;charset=UTF-8
Content-Length: 11

Hello World
```

**Wrong password -> 401**

```text
POST /api/auth/login
{"username":"test","password":"wrong-password"}

HTTP_STATUS=401
{"status":401,"error":"Unauthorized","message":"Invalid username or password","path":"/api/auth/login"}
```

**Forged token -> 401**

```text
GET /api/hello
Authorization: Bearer abc.def.ghi

HTTP_STATUS=401
{"status":401,"error":"Unauthorized","message":"Authentication is required to access this resource","path":"/api/hello"}
```

**Expired but validly signed token -> 401**

```text
GET /api/hello
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpX... (exp = now - 1 hour)

HTTP_STATUS=401
{"status":401,"error":"Unauthorized","message":"Authentication is required to access this resource","path":"/api/hello"}
```

**Missing password -> 400**

```text
POST /api/auth/login
{"username":"test"}

HTTP_STATUS=400
{"status":400,"error":"Bad Request","message":"password: password is required","path":"/api/auth/login"}
```

### 4. Automated tests

```text
PS> .\mvnw.cmd test
...
[INFO] Tests run: 5, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
TEST_EXIT=0
```

The test suite covers: no-token 401, successful login + `Hello World`, wrong
password 401, and malformed Bearer token 401.

## Project layout

```text
spring-hello/
├── pom.xml
├── mvnw / mvnw.cmd
├── src/main/java/com/d5data/springhello/
│   ├── SpringHelloApplication.java
│   ├── config/SecurityConfig.java
│   ├── security/JwtService.java
│   ├── security/JwtAuthenticationFilter.java
│   ├── security/RestAuthenticationEntryPoint.java
│   ├── security/RestAccessDeniedHandler.java
│   ├── dto/LoginRequest.java
│   ├── dto/TokenResponse.java
│   ├── dto/ErrorResponse.java
│   ├── service/AuthService.java
│   └── web/{AuthController,HelloController,GlobalExceptionHandler}.java
├── src/main/resources/application.yaml
└── src/test/java/com/d5data/springhello/AuthFlowIntegrationTest.java
```

## Deployment options

GitHub Pages can only host static files, so it cannot run this service. Three
options are in the repository:

1. **Local**: `java -jar target/spring-hello-0.0.1-SNAPSHOT.jar`.
2. **Docker**: `docker build -t spring-hello .` then
   `docker run --rm -p 8080:8080 spring-hello`. The `Dockerfile` is a standard
   two-stage build (JDK build stage → JRE runtime stage, non-root user), but it
   was **not built locally** because Docker is not installed on the authoring
   machine — treat it as a reasonable recipe, not a verified result.
3. **Managed host**: `render.yaml` is a Render Blueprint; "New → Blueprint" on
   Render against this repository produces a free instance. The container reads
   the injected `PORT`; `JWT_SECRET` is generated by the platform.

Configuration is read from `JWT_SECRET` and `SERVER_PORT` (see
`src/main/resources/application.yaml`).

## Known limitations

- This is a single-user demo. The user is in memory and there is no registration,
  user store, password reset, account lockout, or MFA.
- JWTs cannot be revoked before expiry and there is no refresh token, key
  rotation, or token blacklist. A production design would add these.
- The default JWT secret is development-only. Production must inject a strong
  `JWT_SECRET` through the environment or a secret manager.
- No CORS policy, rate limiting, audit log, HTTPS termination, or Docker setup is
  included. Deploy behind TLS and a reverse proxy if this were more than an
  exercise.
- JSON error text is intentionally generic so failed authentication does not
  reveal whether a username exists.
- Tested with JDK 17.0.4.1. The first Maven build downloads dependencies and
  can take several minutes depending on the local `~/.m2` cache.
- Initializr's current generator only supports Boot 4.x; the pinned 3.2.0 build
  was verified locally by the compile, test, and HTTP runs above.
