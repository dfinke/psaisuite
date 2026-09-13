package psaisuite

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestAnthropicProviderReturnsText(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("x-api-key") == "" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		fmt.Fprint(w, `{"content":[{"type":"text","text":"hello from claude"}]}`)
	}))
	defer ts.Close()

	p := NewAnthropicProvider(ts.Client())
	p.APIKey = "test-key"
	p.BaseURL = ts.URL

	text, err := p.Complete(context.Background(), ProviderRequest{
		ModelName: "claude-3-haiku-20240307",
		Messages:  []Message{{Role: "user", Content: "hi"}},
	})
	if err != nil {
		t.Fatalf("Complete() error = %v", err)
	}
	if text != "hello from claude" {
		t.Fatalf("expected 'hello from claude', got %q", text)
	}
}

func TestAnthropicProviderRequiresAPIKey(t *testing.T) {
	p := NewAnthropicProvider(nil)
	_, err := p.Complete(context.Background(), ProviderRequest{ModelName: "claude-3-haiku-20240307"})
	if err == nil {
		t.Fatal("expected missing key error")
	}
}

func TestAnthropicProviderSystemMessageSeparated(t *testing.T) {
	var capturedBody []byte
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		buf := make([]byte, r.ContentLength)
		r.Body.Read(buf)
		capturedBody = buf
		fmt.Fprint(w, `{"content":[{"type":"text","text":"ok"}]}`)
	}))
	defer ts.Close()

	p := NewAnthropicProvider(ts.Client())
	p.APIKey = "test-key"
	p.BaseURL = ts.URL

	_, err := p.Complete(context.Background(), ProviderRequest{
		ModelName: "claude-3-haiku-20240307",
		Messages: []Message{
			{Role: "system", Content: "you are helpful"},
			{Role: "user", Content: "hello"},
		},
	})
	if err != nil {
		t.Fatalf("Complete() error = %v", err)
	}
	body := string(capturedBody)
	if !strings.Contains(body, `"system":"you are helpful"`) {
		t.Fatalf("expected system field in body, got: %s", body)
	}
}
