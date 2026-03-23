package proxy

import tea "github.com/charmbracelet/bubbletea"

type Model interface {
	tea.Model
	SetClient(*RemoteClient)
}
