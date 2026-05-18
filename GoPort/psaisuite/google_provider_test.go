package psaisuite

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGoogleProviderReturnsText(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"candidates":[{"content":{"parts":[{"text":"hello from gemini"}]}}]}`)
	}))
	defer ts.Close()

	p := NewGoogleProvider(ts.Client())
	p.APIKey = "test-key"
	p.BaseURL = ts.URL

	text, err := p.Complete(context.Background(), ProviderRequest{
		ModelName: "gemini-2.0-flash",
		Messages:  []Message{{Role: "user", Content: "hi"}},
	})
	if err != nil {
		t.Fatalf("Complete() error = %v", err)
	}
	if text != "hello from gemini" {
		t.Fatalf("expected 'hello from gemini', got %q", text)
	}
}

func TestGoogleProviderRequiresAPIKey(t *testing.T) {
	p := NewGoogleProvider(nil)
	_, err := p.Complete(context.Background(), ProviderRequest{ModelName: "gemini-2.0-flash"})
	if err == nil {
		t.Fatal("expected missing key error")
	}
}

func TestGoogleProviderNoCandidatesError(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"candidates":[]}`)
	}))
	defer ts.Close()

	p := NewGoogleProvider(ts.Client())
	p.APIKey = "test-key"
	p.BaseURL = ts.URL

	_, err := p.Complete(context.Background(), ProviderRequest{
		ModelName: "gemini-2.0-flash",
		Messages:  []Message{{Role: "user", Content: "hi"}},
	})
	if err == nil {
		t.Fatal("expected error for empty candidates")
	}
}
