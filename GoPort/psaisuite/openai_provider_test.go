package psaisuite

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestOpenAIProviderCompleteReturnsOutputText(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"output":[{"type":"message","content":[{"type":"output_text","text":"hello from api"}]}]}`)
	}))
	defer ts.Close()

	provider := NewOpenAIProvider(ts.Client())
	provider.APIKey = "test-key"
	provider.BaseURL = ts.URL

	text, err := provider.Complete(context.Background(), ProviderRequest{
		ModelName: "gpt-4o-mini",
		Messages:  []Message{{Role: "user", Content: "hello"}},
	})
	if err != nil {
		t.Fatalf("Complete() error = %v", err)
	}
	if text != "hello from api" {
		t.Fatalf("expected text output, got %q", text)
	}
}

func TestOpenAIProviderRequiresAPIKey(t *testing.T) {
	provider := NewOpenAIProvider(nil)
	_, err := provider.Complete(context.Background(), ProviderRequest{ModelName: "gpt-4o-mini"})
	if err == nil {
		t.Fatal("expected missing key error")
	}
}
