package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"

	"github.com/charmbracelet/log"
	"github.com/zepoze/ssh-portfolio/proxy/internal/server"
)

const (
	host = "0.0.0.0"
	port = "2222"
)

func main() {

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	err := server.Run(ctx, host, port)
	if err != nil {
		os.Exit(1)
	}

	log.Info("Server stop gracefully")
}
