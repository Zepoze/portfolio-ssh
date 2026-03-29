package proxy

import (
	"context"
	"net"
	"time"

	"github.com/charmbracelet/log"
	"github.com/charmbracelet/ssh"
	"github.com/patrickmn/go-cache"
	"golang.org/x/time/rate"
)

const (
	tarpitDuration = time.Second
)

type Visitor struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

type AbuseManager struct {
	visitors cache.Cache
	bs       BanStore
}

func NewAbuseManager(defaultVisitorExpiration, defaultVisitorCleanupInterval time.Duration, banStore BanStore) *AbuseManager {
	return &AbuseManager{
		visitors: *cache.New(defaultVisitorExpiration, defaultVisitorCleanupInterval),
		bs:       banStore,
	}
}

func (cv AbuseManager) GetVisitor(uid string) *Visitor {
	var v interface{}
	v, found := cv.visitors.Get(uid)
	if !found {
		limiter := rate.NewLimiter(2, 5) // 2 requests per second with a burst of 5
		v := &Visitor{limiter: limiter, lastSeen: time.Now()}
		cv.visitors.Set(uid, v, cache.DefaultExpiration)
		return v
	}

	visitor := v.(*Visitor)
	visitor.lastSeen = time.Now()
	return visitor
}

func (cv AbuseManager) IsBanned(ctx context.Context, uid string) bool {
	vb, err := cv.bs.GetVisitorBan(ctx, uid)

	if err != nil {
		log.Error("failed to get visitor ban: %s", err)
		return false
	}

	if vb != nil {
		return true
	}

	return false
}

func (cv AbuseManager) Ban(ctx context.Context, uid string, duration time.Duration) error {
	return cv.bs.Ban(ctx, NewVisitorBan(uid, duration))
}

func (cv AbuseManager) Allow(uid string) bool {
	visitor := cv.GetVisitor(uid)
	return visitor.limiter.Allow()
}

func WrapConnWithRateLimit(abuseManager *AbuseManager) ssh.ConnCallback {
	return func(ctx ssh.Context, conn net.Conn) net.Conn {
		uid, _, _ := net.SplitHostPort(conn.RemoteAddr().String())
		if abuseManager.IsBanned(ctx, uid) {
			tarpit(ctx, conn)
			return nil
		}

		if !abuseManager.Allow(uid) {
			if err := abuseManager.Ban(ctx, uid, 10*time.Minute); err != nil {
				log.Error("failed to ban visitor", "uid", uid, "error", err)
			} else {
				log.Warn("visitor banned due to rate limit", "uid", uid)
			}
			tarpit(ctx, conn)
			return nil
		}
		return conn
	}
}

func tarpit(ctx ssh.Context, conn net.Conn) {
	select {
	case <-ctx.Done():
	case <-time.After(tarpitDuration):
		conn.Close()
	}
}
