# syntax=docker/dockerfile:1

# Build the application from source
FROM golang:1.22-alpine AS build-stage

WORKDIR /app

# Descargar los módulos de Go
COPY go.mod go.sum ./
RUN go mod download

# Copiar el código fuente
COPY *.go ./

# Construir la aplicación
RUN CGO_ENABLED=0 GOOS=linux go build -o /docker-gs-ping

# Run the tests in the container
FROM build-stage AS run-test-stage
RUN go test -v ./...

# Deploy the application binary into a lean image
FROM alpine:latest AS release-stage

# Configurar variables de entorno
ARG DT_API_URL=""
ARG DT_API_TOKEN=""
ARG DT_ONEAGENT_OPTIONS="flavor=default&include=java"
ENV DT_HOME="/opt/dynatrace/oneagent"
ENV LD_PRELOAD="/opt/dynatrace/oneagent/agent/lib64/liboneagentproc.so"

# Instalar paquetes necesarios y el agente Dynatrace
RUN apk --no-cache add wget unzip ca-certificates && \
    mkdir -p "$DT_HOME"

# Descargar el archivo ZIP
RUN wget -O "$DT_HOME/oneagent.zip" "$DT_API_URL/v1/deployment/installer/agent/unix/paas/latest?Api-Token=$DT_API_TOKEN&$DT_ONEAGENT_OPTIONS" || exit 1

# Verificar y descomprimir el archivo ZIP
RUN unzip -t "$DT_HOME/oneagent.zip" || exit 1 && \
    unzip -d "$DT_HOME" "$DT_HOME/oneagent.zip" && \
    rm "$DT_HOME/oneagent.zip"

# Copiar el binario desde la etapa de construcción
COPY --from=build-stage /docker-gs-ping /docker-gs-ping

# Exponer el puerto en el que la aplicación escuchará
EXPOSE 8080

# Crear un usuario no root para ejecutar la aplicación
RUN adduser -D devops
USER devops

# Comando para ejecutar la aplicación
ENTRYPOINT ["/docker-gs-ping"]
