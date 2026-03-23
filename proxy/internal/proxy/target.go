package proxy

import (
	"net"
	"strconv"
	"time"
)

type TargetHost struct {
	Host               string
	Port               int
	UseAltScreen       bool
	MaxSessionDuration time.Duration
}

func (t TargetHost) String() string {
	return net.JoinHostPort(t.Host, strconv.Itoa(t.Port))
}
