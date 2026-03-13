# Portfolio SSH

An interactive developer portfolio accessible directly through SSH.

Instead of visiting a website, users connect to a public SSH endpoint and navigate a slide-based presentation directly inside their terminal.

```bash
ssh portfolio-ssh.zepoze.fr
```

The SSH session launches a terminal presentation powered by Slides, creating a lightweight and unconventional portfolio experience.

## Why this project?

Most developer portfolios are simple websites.

This project explores a different approach: delivering a portfolio as a terminal application over SSH.

It was built to experiment with:

- cloud infrastructure
- containerized applications
- CI/CD pipelines
- SSH protocol and proxying
- observability and security patterns

The result is a small but realistic infrastructure project combining application development and DevOps practices.

## Architecture

The service exposes a public SSH endpoint, similar to how a website exposes HTTP.

When a user connects:

1. The connection reaches a custom SSH reverse proxy written in Go

2. The proxy forwards the session to the presentation container

3. The user navigates slides rendered directly in the terminal

Architecture overview:
```
User
 │
 │ SSH
 ▼
SSH Reverse Proxy (Go)
 │
 │ internal forwarding
 ▼
Slides Service
 │
 ▼
Terminal slides
```
Components:

### SSH Reverse Proxy

Responsibilities:

- public SSH entrypoint
- session forwarding
- connection handling

Planned improvements:

- logging
- Prometheus metrics
- rate limiting

### Slides Service

Container running the terminal presentation powered by
[Slides](https://github.com/maaslalani/slides).

Slides are currently written in Markdown (slides.md).

## Infrastructure

The project is deployed on AWS with infrastructure managed as code.

Main components:

- EC2 instance hosting the containers
- Docker container runtime
- Terraform infrastructure provisioning

Everything is designed to be reproducible and automated.

## CI/CD

Deployment is fully automated using GitHub Actions.

Pipeline steps:

1. Build Docker images
2. Push images to the registry
3. Deploy the application to EC2

This setup ensures updates to the project can be shipped quickly and consistently.

## Tech Stack

### Language

- Go

### Infrastructure

- AWS
- Terraform

### Containers

- Docker

### CI/CD

- GitHub Actions

### Terminal UI

- [slides](https://github.com/maaslalani/slides)

## Roadmap

Planned improvements:

- connection logging
- Prometheus metrics
- rate limiting on SSH connections
- multi-language slides
- analytics on connections

## Project Goal

This project was built to:

- demonstrate interest in infrastructure and DevOps
- experiment with SSH-based services
- build a technical and unconventional portfolio

It also serves as a playground to explore cloud-native patterns and infrastructure tooling.