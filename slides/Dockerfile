FROM golang:1.24-bullseye AS builder

ARG SLIDES_VERSION=v0.9.0

RUN go install github.com/maaslalani/slides@${SLIDES_VERSION}

WORKDIR /app
COPY slides.md /app/slides.md
EXPOSE 23234
ENTRYPOINT ["slides"]
CMD ["serve", "--port", "23234","--host","0.0.0.0" ,"/app/slides.md"]
