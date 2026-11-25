# --- build stage -------------------------------------------------------
FROM eclipse-temurin:17-jdk AS build
WORKDIR /app

# 先只拷贝构建描述，让依赖层可以命中缓存
COPY mvnw mvnw.cmd pom.xml ./
COPY .mvn .mvn
RUN chmod +x mvnw && ./mvnw -q -B -DskipTests dependency:go-offline || true

COPY src src
RUN ./mvnw -q -B -DskipTests package

# --- runtime stage -----------------------------------------------------
FROM eclipse-temurin:17-jre
WORKDIR /app

# 非 root 用户运行
RUN useradd --system --create-home --uid 10001 app
COPY --from=build /app/target/*.jar /app/app.jar
RUN chown -R app:app /app
USER app

EXPOSE 8080
# 托管平台（Render / Railway / Fly）会注入 PORT，本地默认 8080
ENTRYPOINT ["sh", "-c", "exec java -jar /app/app.jar --server.port=${PORT:-8080}"]
