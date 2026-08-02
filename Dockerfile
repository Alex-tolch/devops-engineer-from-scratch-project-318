# syntax=docker/dockerfile:1

FROM node:24-alpine AS frontend-build
WORKDIR /frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

FROM eclipse-temurin:25-jdk-alpine AS backend-build
WORKDIR /app
COPY gradle gradle
COPY gradlew gradlew.bat settings.gradle.kts build.gradle.kts versions.properties ./
RUN chmod +x gradlew
COPY src src
RUN rm -rf src/main/resources/static && mkdir -p src/main/resources/static
COPY --from=frontend-build /frontend/dist/ src/main/resources/static/
RUN ./gradlew bootJar -x test --no-daemon

FROM eclipse-temurin:25-jre-alpine
WORKDIR /app
RUN addgroup -S app && adduser -S app -G app
USER app
COPY --from=backend-build /app/build/libs/project-devops-deploy-*.jar /app/app.jar
EXPOSE 8080 9090
ENV JAVA_OPTS="-XX:+UseContainerSupport"
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
