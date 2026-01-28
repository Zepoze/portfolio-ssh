package server

import (
	"net"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/ssh"
	"github.com/charmbracelet/wish"
	"github.com/charmbracelet/wish/bubbletea"
	"github.com/charmbracelet/wishlist/blocking"
	"github.com/charmbracelet/wishlist/multiplex"
	"github.com/muesli/termenv"
	"github.com/zepoze/ssh-portfolio/proxy/internal/model"
	"github.com/zepoze/ssh-portfolio/proxy/internal/proxy"
)

func ProxyMiddlewareProgram(abort <-chan struct{}) wish.Middleware {
	newProg := func(m tea.Model, opts ...tea.ProgramOption) *tea.Program {
		p := tea.NewProgram(m, opts...)
		return p
	}

	teaHandler := func(s ssh.Session) *tea.Program {

		multiplexDoneCh := make(chan bool, 1)
		listStdin, handoffStdin := multiplex.Reader(s, multiplexDoneCh)

		client := &proxy.RemoteClient{
			Session: s,
			Stdin:   handoffStdin,
			Cleanup: func() {
				listStdin.Reset()
				handoffStdin.Reset()
			},
		}

		_, _, active := s.Pty()
		if !active {
			wish.Fatalln(s, "no active terminal, skipping")
			return nil
		}

		target := net.JoinHostPort(
			getEnvWithDefault("TARGET_HOST", "localhost"),
			getEnvWithDefault("TARGET_PORT", "23234"),
		)

		m := model.NewModel(client, target)

		prog := newProg(m, tea.WithInput(blocking.New(listStdin)), tea.WithOutput(s))
		go func() {
			<-abort
			s.Close()
			multiplexDoneCh <- true
		}()

		return prog
	}
	return bubbletea.MiddlewareWithProgramHandler(teaHandler, termenv.ANSI256)
}
