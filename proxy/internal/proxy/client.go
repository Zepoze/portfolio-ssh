package proxy

import (
	"errors"
	"fmt"
	"io"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/log"
	"github.com/charmbracelet/ssh"
	"github.com/charmbracelet/wishlist/blocking"
	gossh "golang.org/x/crypto/ssh"
)

type Closers []func()

func (c Closers) Close() {
	for _, close := range c {
		close()
	}
}

type RemoteClient struct {
	// parent Session
	Session ssh.Session

	// Stdin, which is usually multiplexed from the session Stdin
	Stdin io.Reader

	Cleanup func()

	Abort <-chan struct{}
}

func (c *RemoteClient) For(target string) tea.ExecCommand {
	return &RemoteSession{
		Target:        target,
		ParentSession: c.Session,
		Stdin:         c.Stdin,
		Cleanup:       c.Cleanup,
		Abort:         c.Abort,
	}
}

type RemoteSession struct {
	// endpoint we are connecting to
	Target string

	// the parent session (ie the session running the listing)
	ParentSession ssh.Session

	Stdin   io.Reader
	Cleanup func()
	Abort   <-chan struct{}
}

func (s *RemoteSession) SetStdin(_ io.Reader)  {}
func (s *RemoteSession) SetStdout(_ io.Writer) {}
func (s *RemoteSession) SetStderr(_ io.Writer) {}

func (s *RemoteSession) Run() error {
	if s.Cleanup != nil {
		s.Cleanup()
		defer s.Cleanup()
	}

	stdin := blocking.New(s.Stdin)

	conf := &gossh.ClientConfig{
		User:            s.ParentSession.User(),
		HostKeyCallback: gossh.InsecureIgnoreHostKey(),
		Timeout:         time.Second * 5,
	}

	conn, session, cl, err := createSession(conf, s.Target)
	if err != nil {
		return err
	}
	defer cl.Close()

	log.Info(
		"connect",
		"user", s.ParentSession.User(),
		"endpoint", s.Target,
		"remote.addr", s.ParentSession.RemoteAddr().String(),
	)

	session.Stdout = s.ParentSession
	session.Stderr = s.ParentSession.Stderr()
	session.Stdin = stdin

	pty, winch, ok := s.ParentSession.Pty()
	if !ok {
		return fmt.Errorf("requested a tty, but current session doesn't allow one")
	}
	w := pty.Window
	if err := session.RequestPty(pty.Term, w.Height, w.Width, nil); err != nil {
		return fmt.Errorf("failed to request pty: %w", err)
	}

	done := make(chan bool, 1)
	defer func() { done <- true }()
	go s.notifyWindowChanges(session, done, winch)

	shellErr := make(chan error, 1)
	go func() {
		shellErr <- shellAndWait(session)
	}()

	select {
	case err := <-shellErr:
		return err
	case <-s.Abort:
		session.Close()
		conn.Close()
		log.Info("aborting remote session")
		return nil
	}
}

func (s *RemoteSession) notifyWindowChanges(session *gossh.Session, done <-chan bool, winch <-chan ssh.Window) {
	for {
		select {
		case <-done:
			return
		case w := <-winch:
			if w.Height == 0 && w.Width == 0 {
				return
			}
			if err := session.WindowChange(w.Height, w.Width); err != nil {
				log.Warn("failed to notify window change", "err", err)
				return
			}
		}
	}
}

func shellAndWait(session *gossh.Session) error {
	if err := session.Shell(); err != nil {
		return fmt.Errorf("failed to start shell: %w", err)
	}
	if err := session.Wait(); err != nil {
		if errors.Is(err, &gossh.ExitMissingError{}) {
			log.Info("exit was missing, assuming exit 0")
			return nil
		}
		return fmt.Errorf("session failed: %w", err)
	}
	return nil
}

func createSession(conf *gossh.ClientConfig, target string) (*gossh.Client, *gossh.Session, Closers, error) {
	var cl Closers
	var conn *gossh.Client
	var session *gossh.Session
	var err error

	conn, err = gossh.Dial("tcp", target, conf)
	if err != nil {
		return nil, nil, nil, fmt.Errorf("failed to dial: %w", err)
	}
	cl = append(cl, func() { conn.Close() })

	session, err = conn.NewSession()
	if err != nil {
		return nil, nil, nil, fmt.Errorf("failed to open session: %w", err)
	}
	cl = append(cl, func() { session.Close() })

	return conn, session, cl, nil
}
