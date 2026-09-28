package psaisuite

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestChatCompletionProviderReturnsContent(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"choices":[{"message":{"content":"hello from groq"}}]}`)
	}))
	defer ts.Close()

	p := NewChatCompletionProvider(ts.URL, "GROQ_API_KEY", ts.Client())
	p.APIKey = "test-key"

	text, err := p.Complete(context.Background(), ProviderRequest{
		ModelName: "llama3-70b-8192",
		Messages:  []Message{{Role: "user", Content: "hi"}},
	})
	if err != nil {
		t.Fatalf("Complete() error = %v", err)
	}
	if text != "hello from groq" {
		t.Fatalf("expected 'hello from groq', got %q", text)
	}
}

func TestChatCompletionProviderReturnsAPIError(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
		fmt.Fprint(w, `{"error":{"message":"invalid api key"}}`)
	}))
	defer ts.Close()

	p := NewChatCompletionProvider(ts.URL, "", ts.Client())
	_, err := p.Complete(context.Background(), ProviderRequest{ModelName: "m", Messages: nil})
	if err == nil {
		t.Fatal("expected error, got nil")
	}
}

func TestChatCompletionProviderNoChoicesError(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"choices":[]}`)
	}))
	defer ts.Close()

	p := NewChatCompletionProvider(ts.URL, "", ts.Client())
	_, err := p.Complete(context.Background(), ProviderRequest{ModelName: "m", Messages: nil})
	if err == nil {
		t.Fatal("expected error for empty choices")
	}
}
