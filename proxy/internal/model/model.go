package model

import (
	"context"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/zepoze/ssh-portfolio/proxy/internal/proxy"
)

type model struct {
	client             *proxy.RemoteClient
	target             proxy.TargetHost
	redirectionContext context.Context
	cancelRedirection  context.CancelCauseFunc
	quitting           bool
}

var _ proxy.Model = (*model)(nil)

func New(target proxy.TargetHost) proxy.Model {

	m := &model{
		client:   nil,
		target:   target,
		quitting: false,
	}
	return m
}

type redirectMsg struct{}
type quittingMsg struct {
	err error
}

func (m *model) SetClient(client *proxy.RemoteClient) {
	m.client = client
}

func (m *model) Init() tea.Cmd {
	return tea.Tick(time.Second*3, func(t time.Time) tea.Msg {
		return redirectMsg{}
	})
}

func (m *model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {

	switch ms := msg.(type) {
	case redirectMsg:
		cmd := m.RedirectToTarget()
		return m, cmd

	case quittingMsg:
		m.quitting = true
		if m.redirectionContext.Err() == nil {
			m.cancelRedirection(ms.err)
		}
		return m, tea.Tick(time.Second*4, func(t time.Time) tea.Msg {
			return tea.Quit()
		})
	}

	return m, nil
}

var viewStyle = lipgloss.NewStyle().PaddingLeft(1).PaddingTop(1)

func (m *model) View() string {

	str := ""

	if m.quitting {
		if m.redirectionContext != nil {
			if context.Cause(m.redirectionContext) == context.DeadlineExceeded {
				str = "⏳ La session a expiré ⏳ "
			}
		}
		str += "Merci de votre visite ! À bientôt."
	} else {
		str = "Redirection en cours..."
	}
	return viewStyle.Render(str)
}

func (m *model) RedirectToTarget() tea.Cmd {

	m.redirectionContext, m.cancelRedirection = context.WithCancelCause(context.Background())

	execCommand := m.client.For(m.redirectionContext, m.target)
	cmd := tea.Exec(execCommand, func(err error) tea.Msg {
		return quittingMsg{err: err}
	})
	return tea.Batch(
		cmd,
		func() tea.Msg {
			select {
			case <-m.redirectionContext.Done():
				return nil
			case <-time.After(m.target.MaxSessionDuration):
				m.cancelRedirection(context.DeadlineExceeded)
				return nil
			}

		},
	)
}
