package proxy

import (
	"context"
	"time"

	"github.com/patrickmn/go-cache"
)

type VisitorBan struct {
	uid   string
	until time.Time
}

func NewVisitorBan(uid string, duration time.Duration) VisitorBan {
	return VisitorBan{
		uid:   uid,
		until: time.Now().Add(duration),
	}
}

func (v VisitorBan) IsExpired() bool {
	return time.Now().After(v.until)
}

type BanStore interface {
	Ban(context context.Context, data VisitorBan) error
	GetVisitorBan(context context.Context, uid string) (*VisitorBan, error)
}

var _ BanStore = (*InMemoryBanStore)(nil)

type InMemoryBanStore struct {
	cache *cache.Cache
}

func NewInMemoryBanStore(defaultExpiration, cleanupInterval time.Duration) *InMemoryBanStore {
	return &InMemoryBanStore{
		cache: cache.New(defaultExpiration, cleanupInterval),
	}
}

// Ban implements [BanStore].
func (i *InMemoryBanStore) Ban(context context.Context, data VisitorBan) error {
	i.cache.Set(data.uid, &data, time.Until(data.until))
	return nil
}

func (i *InMemoryBanStore) GetVisitorBan(context context.Context, uid string) (*VisitorBan, error) {
	data, found := i.cache.Get(uid)
	if !found {
		return nil, nil
	}

	ban := data.(*VisitorBan)

	if ban.IsExpired() {
		i.cache.Delete(uid)
		return nil, nil
	}

	return ban, nil
}
