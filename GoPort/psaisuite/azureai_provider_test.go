package psaisuite

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestAzureAIProviderReturnsContent(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("api-key") == "" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		fmt.Fprint(w, `{"choices":[{"message":{"content":"hello from azure"}}]}`)
	}))
	defer ts.Close()

	p := NewAzureAIProvider(ts.Client())
	p.APIKey = "test-key"
	p.Endpoint = ts.URL

	text, err := p.Complete(context.Background(), ProviderRequest{
		ModelName: "gpt-4",
		Messages:  []Message{{Role: "user", Content: "hi"}},
	})
	if err != nil {
		t.Fatalf("Complete() error = %v", err)
	}
	if text != "hello from azure" {
		t.Fatalf("expected 'hello from azure', got %q", text)
	}
}

func TestAzureAIProviderRequiresAPIKey(t *testing.T) {
	p := NewAzureAIProvider(nil)
	p.Endpoint = "https://example.openai.azure.com"
	_, err := p.Complete(context.Background(), ProviderRequest{ModelName: "gpt-4"})
	if err == nil {
		t.Fatal("expected missing key error")
	}
}

func TestAzureAIProviderRequiresEndpoint(t *testing.T) {
	p := NewAzureAIProvider(nil)
	p.APIKey = "test-key"
	_, err := p.Complete(context.Background(), ProviderRequest{ModelName: "gpt-4"})
	if err == nil {
		t.Fatal("expected missing endpoint error")
	}
}
