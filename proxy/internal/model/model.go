package model

import (
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/zepoze/ssh-portfolio/proxy/internal/proxy"
)

type model struct {
	client   *proxy.RemoteClient
	target   string
	quitting bool
}

var _ tea.Model = (*model)(nil)

func NewModel(client *proxy.RemoteClient, target string) tea.Model {
	return &model{
		client: client,
		target: target,
	}
}

type redirectMsg struct{}
type quittingMsg struct {
	err error
}

func (m *model) Init() tea.Cmd {
	return tea.Tick(time.Second*3, func(t time.Time) tea.Msg {
		return redirectMsg{}
	})
}

func (m *model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {

	switch msg.(type) {
	case redirectMsg:
		execCommand := m.client.For(m.target)
		return m, tea.Exec(execCommand, func(err error) tea.Msg {
			return quittingMsg{err: err}
		})

	case quittingMsg:
		m.quitting = true
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
		str = "Merci de votre visite ! À bientôt."
	} else {
		str = "Redirection en cours..."
	}
	return viewStyle.Render(str)
}
