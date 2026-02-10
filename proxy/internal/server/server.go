package server

import (
	"context"
	"errors"

	"net"
	"os"
	"time"

	"github.com/charmbracelet/log"
	"github.com/charmbracelet/ssh"
	"github.com/charmbracelet/wish"
	"github.com/charmbracelet/wish/logging"
)

const (
	defaultHostKeyPath = "ssh_host_key"
)

func Run(ctx context.Context, host, port string, hostKeyPath string) error {

	if hostKeyPath == "" {
		hostKeyPath = defaultHostKeyPath
	}

	err := ensureHostKeyExistence(hostKeyPath, os.Getenv("STRICT") != "")
	if err != nil {
		return err
	}

	globalCtx, cancel := context.WithCancelCause(ctx)

	options := []ssh.Option{
		wish.WithAddress(net.JoinHostPort(host, port)),
		wish.WithMiddleware(
			ProxyMiddlewareProgram(globalCtx.Done()),
			logging.Middleware(),
		),
		wish.WithHostKeyPath(hostKeyPath),
	}

	srv, err := wish.NewServer(
		options...,
	)
	if err != nil {
		cancel(err)
		return err
	}

	var CantStart = errors.New("can't start server")

	go func() {
		log.Info("Starting SSH server", "host", host, "port", port)
		if err = srv.ListenAndServe(); err != nil && !errors.Is(err, ssh.ErrServerClosed) {
			log.Error("Could not start server", "error", err)
			cancel(CantStart)
		}
	}()

	<-globalCtx.Done()
	if context.Cause(globalCtx) == CantStart {
		return CantStart
	}

	ctxTimeout, cancelTimeout := context.WithTimeout(context.Background(), 30*time.Second)
	defer func() { cancelTimeout() }()

	log.Info("Stopping SSH server")
	if err := srv.Shutdown(ctxTimeout); err != nil && !errors.Is(err, ssh.ErrServerClosed) {
		log.Error("Could not stop server", "error", err)
		return err
	}

	return nil
}

func ensureHostKeyExistence(hostKeyPath string, strict bool) error {
	_, err := os.Stat(hostKeyPath)
	if strict {
		if err != nil {
			err := errors.New("no host key found, refusing to start in STRICT mode")
			log.Error("Could not start server", "error", err)
			return err
		}
	} else if err != nil {
		log.Warn("no host key configured, using a new one (this is insecure!)")
	}
	return nil
}

func getEnvWithDefault(key, def string) string {
	val, exists := os.LookupEnv(key)
	if !exists {
		return def
	}
	return val
}
