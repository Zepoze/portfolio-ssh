package proxy

import (
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/ssh"
	"github.com/charmbracelet/wish"
	"github.com/charmbracelet/wish/bubbletea"
	"github.com/charmbracelet/wishlist/blocking"
	"github.com/charmbracelet/wishlist/multiplex"
	"github.com/muesli/termenv"
)

func MiddlewareProgram(modelHandler func() Model) wish.Middleware {
	newProg := func(m tea.Model, opts ...tea.ProgramOption) *tea.Program {
		p := tea.NewProgram(m, opts...)
		return p
	}

	teaHandler := func(s ssh.Session) *tea.Program {

		multiplexDoneCh := make(chan bool, 1)
		listStdin, handoffStdin := multiplex.Reader(s, multiplexDoneCh)

		client := &RemoteClient{
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

		m := modelHandler()

		m.SetClient(client)

		prog := newProg(m, tea.WithInput(blocking.New(listStdin)), tea.WithOutput(s))
		go func() {
			<-s.Context().Done()
			multiplexDoneCh <- true
		}()

		return prog
	}
	return bubbletea.MiddlewareWithProgramHandler(teaHandler, termenv.ANSI256)
}
