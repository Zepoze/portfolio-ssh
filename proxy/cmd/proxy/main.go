package main

import (
	"context"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/charmbracelet/log"
	"github.com/zepoze/ssh-portfolio/proxy/internal/model"
	"github.com/zepoze/ssh-portfolio/proxy/internal/proxy"
	"github.com/zepoze/ssh-portfolio/proxy/internal/server"
)

const (
	host = "0.0.0.0"
	port = "2222"
)

func main() {

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	maxTargetTimeout := os.Getenv("TARGET_MAX_TIMEOUT")

	maxTargetTimeoutInt, err := strconv.Atoi(maxTargetTimeout)
	if err != nil {
		maxTargetTimeoutInt = 360
	}

	var portInt int
	slidesport := os.Getenv("TARGET_PORT")
	if portInt, err = strconv.Atoi(slidesport); err != nil {
		portInt = 23234
	}

	target := proxy.TargetHost{
		Host:               os.Getenv("TARGET_HOST"),
		Port:               portInt,
		UseAltScreen:       true,
		MaxSessionDuration: time.Duration(maxTargetTimeoutInt) * time.Second,
	}

	modelHandler := func() proxy.Model {
		return model.New(target)
	}

	err = server.Run(
		ctx,
		host,
		port,
		os.Getenv("SSH_HOST_KEY"),
		os.Getenv("SSH_TRUSTED_USERS_CA"),
		modelHandler,
	)
	if err != nil {
		log.Error("Error running server", "error", err)
		os.Exit(1)
	}

	log.Info("Server stop gracefully")
}
