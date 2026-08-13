# syntax=docker/dockerfile:1
# Application source is NOT in this repo — cloned at build time from upstream.
# Override: docker build --build-arg APP_REPO=https://github.com/<you>/project-devops-deploy.git

ARG APP_REPO=https://github.com/hexlet-components/project-devops-deploy.git
ARG APP_REF=main

FROM alpine:3.21 AS app-src
ARG APP_REPO
ARG APP_REF
RUN apk add --no-cache git \
  && git clone --depth 1 --branch "${APP_REF}" "${APP_REPO}" /src

FROM node:24-alpine AS frontend-build
WORKDIR /frontend
COPY --from=app-src /src/frontend/package.json /src/frontend/package-lock.json ./
RUN npm ci
COPY --from=app-src /src/frontend/ ./
RUN npm run build

FROM eclipse-temurin:25-jdk-alpine AS backend-build
WORKDIR /app
COPY --from=app-src /src/gradle gradle
COPY --from=app-src /src/gradlew /src/gradlew.bat /src/settings.gradle.kts /src/build.gradle.kts ./
RUN chmod +x gradlew
COPY --from=app-src /src/src src
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
