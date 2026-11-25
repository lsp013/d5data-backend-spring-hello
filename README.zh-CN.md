# Spring Hello · 后端题

> English version: [README.md](README.md) · 仓库：<https://github.com/lsp013/d5data-backend-spring-hello>

Spring Boot **3.2.0** + Spring Security 的最小认证服务：

- 用户名密码登录（内存用户 `test` / `123456`），签发 JWT；
- `GET /api/hello` 需要携带 `Authorization: Bearer <token>`，通过后返回纯文本 `Hello World`；
- 未认证时返回 **JSON 401**，而不是跳转到 HTML 登录页。

## 技术栈

| 项 | 版本 |
| --- | --- |
| Java | 17 |
| Spring Boot | 3.2.0 |
| Spring Security | 6.2.x（由 Boot 3.2.0 管理） |
| JJWT | 0.12.6 |
| 构建 | Maven Wrapper 3.10.1 |

无 Lombok、无数据库、不要求全局安装 Maven。

## 关于骨架的生成过程（如实说明）

骨架初版来自 `start.spring.io`，但**现在它已经拒绝 Spring Boot 3.2.0**，返回：

```json
{"status":400,"error":"Bad Request","message":"Invalid Spring Boot version '3.2.0', Spring Boot compatibility range is >=4.0.0"}
```

于是先用 Initializr 下载 Boot 4.0.10 骨架，再把 `pom.xml` 显式钉回 **Spring Boot 3.2.0 / Java 17**，
同时把 Boot 4 的 starter 名改回 Boot 3.2 的 `spring-boot-starter-web` / `-security` / `-validation`。
最终产物就是用 3.2.0 构建并测试的（见下）。

## 运行要求

- JDK 17+
- Windows / macOS / Linux 均可
- 首次构建需要联网下载依赖

Windows 上若没配 `JAVA_HOME`：

```powershell
$env:JAVA_HOME = "E:\jdv17"   # 换成你机器上的 JDK 17
```

## 构建与运行

```powershell
cd spring-hello

# 跑测试（5 个）
.\mvnw.cmd test

# 打包（产出 target/spring-hello-0.0.1-SNAPSHOT.jar）
.\mvnw.cmd -DskipTests package

# 直接起服务
.\mvnw.cmd spring-boot:run
# 或者
java -jar target/spring-hello-0.0.1-SNAPSHOT.jar
```

默认监听 `8080`。

## 接口契约

| 方法 | 路径 | 鉴权 | 请求体 | 成功 | 失败 |
| --- | --- | --- | --- | --- | --- |
| POST | `/api/auth/login` | 公开 | `{"username":"test","password":"123456"}` | `200` `{"token":"…","tokenType":"Bearer","expiresIn":3600}` | 密码错 `401`；请求体不合法 `400` |
| GET | `/api/hello` | `Authorization: Bearer <token>` | 无 | `200`，`text/plain` 内容 `Hello World` | token 缺失/非法/过期/伪造 → `401` |

未认证访问受保护接口返回 JSON：

```json
{"status":401,"error":"Unauthorized","message":"Authentication is required to access this resource","path":"/api/hello"}
```

登录失败返回：

```json
{"status":401,"error":"Unauthorized","message":"Invalid username or password","path":"/api/auth/login"}
```

## 安全设计要点

- **完全无状态**：`SessionCreationPolicy.STATELESS`，不建 HTTP 会话，每个请求都必须带 JWT。
- **JWT**：`JwtService` 用 HS256 签名，密钥来自 `app.jwt.secret`；subject 是用户名，有效期 `app.jwt.expiration-seconds`（默认 3600 秒）。
- **过滤器**：`JwtAuthenticationFilter` 排在 `UsernamePasswordAuthenticationFilter` 之前，读 `Authorization: Bearer …`、校验签名与过期、装载用户并写入 `SecurityContext`；任何异常都只是"未认证"，不抛 500。
- **JSON 401**：`RestAuthenticationEntryPoint` 直接写 JSON，所以 Security 不会重定向到登录页；`RestAccessDeniedHandler` 负责 403。
- **用户与密码**：`InMemoryUserDetailsManager` 只种一个用户 `test`，密码在启动时用 `BCryptPasswordEncoder` 编码，源码里不出现明文口令的散列字面量。
- **路由**：只有 `POST /api/auth/login` 公开，其余 `/api/**` 都需要认证；显式关闭 `httpBasic`、`formLogin`、`logout`；因为是纯 header-token 的无状态 API、不用 Cookie，所以关闭 CSRF。
- **参数校验**：`LoginRequest` 用 Bean Validation（`@NotBlank`），`@RestControllerAdvice` 把校验错误与请求体错误统一成 JSON 400。

## 实测记录（真的跑过）

| 步骤 | 结果 |
| --- | --- |
| `.\mvnw.cmd -q test` | 5 个测试全绿（`AuthFlowIntegrationTest` + `SpringHelloApplicationTests`） |
| `.\mvnw.cmd -q -DskipTests package` | 成功，产出 23.8 MB 的可执行 jar |
| 启动 | 端口 8080 起服，Security 过滤器链加载正常 |
| `POST /api/auth/login`（test/123456） | `200`，token 长度 129 |
| `GET /api/hello`（带 token） | `200`，正文 `Hello World` |
| `GET /api/hello`（无 token / 伪造 / 过期） | `401` + 上述 JSON |
| `POST /api/auth/login`（错密码） | `401 Invalid username or password` |
| `POST /api/auth/login`（缺 password） | `400 password: password is required` |

## 目录结构

```text
src/main/java/com/d5data/springhello/
  SpringHelloApplication.java
  config/SecurityConfig.java                    # 过滤器链、路由规则、密码编码器
  security/JwtService.java                      # 签发/解析 JWT
  security/JwtAuthenticationFilter.java         # Bearer 解析与上下文装载
  security/RestAuthenticationEntryPoint.java    # JSON 401
  security/RestAccessDeniedHandler.java         # JSON 403
  service/AuthService.java                      # 登录校验 → 发 token
  web/AuthController.java                       # POST /api/auth/login
  web/HelloController.java                      # GET /api/hello
  web/GlobalExceptionHandler.java               # 校验/请求体错误 → JSON 400
  dto/{LoginRequest,TokenResponse,ErrorResponse}.java
src/main/resources/application.yaml             # 端口、JWT 密钥与有效期
src/test/java/...                               # 端到端认证流程测试
```

## 关于部署

GitHub Pages 只能托管静态资源，**跑不了 Spring Boot**。本仓库给出了三种可选方案：

1. **本机**：`java -jar target/*.jar`（最快，见上文）。
2. **Docker**（本机装了 Docker 的话）：
   ```powershell
   docker build -t spring-hello .
   docker run --rm -p 8080:8080 spring-hello
   ```
   说明：`Dockerfile` 是标准的两阶段构建（JDK 构建 → JRE 运行、非 root 用户），但**本机没有装 Docker，
   因此这条路径没有在当地实测过**——它是照着可运行的最小写法给的，不是"已验证"。
3. **托管平台**：仓库根目录的 `render.yaml` 是 Render 的 Blueprint，登录 Render 后用 "New → Blueprint"
   指到这个仓库，即可一键起一个免费实例；容器会读注入的 `PORT` 环境变量，`JWT_SECRET` 由平台随机生成。

> 环境变量名就是 `application.yaml` 里写的那两个：`JWT_SECRET`（覆盖演示密钥）、`SERVER_PORT`（默认 8080）。

## 已知限制

- 用户是内存里的单账号，重启即回到初始状态；生产环境应换 JDBC/OAuth2 用户源。
- JWT 密钥来自配置文件，仓库里放的是演示值；真实部署必须用环境变量覆盖（`APP_JWT_SECRET`）。
- 没有刷新令牌、没有登出吊销列表——题目只要求"认证后返回 Hello World"，这些属于额外设计。
- 没有限流与审计日志。
