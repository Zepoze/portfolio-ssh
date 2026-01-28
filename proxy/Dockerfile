FROM golang:1.25 AS builder

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . ./
RUN rm ssh_host_key* || true

# Build static binary for Linux
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/ssh-proxy ./cmd/proxy

#FROM debian:11-slim
FROM golang:1.24-bullseye AS runtime
#RUN apt-get update && apt-get install -y --no-install-recommends ncurses-term && rm -rf /var/lib/apt/lists/*
COPY --from=builder /out/ssh-proxy /usr/local/bin/ssh-proxy

EXPOSE 2222 8080
USER root

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/ssh-proxy"]