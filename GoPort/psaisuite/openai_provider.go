package psaisuite

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
)

const openAIResponsesURL = "https://api.openai.com/v1/responses"

type OpenAIProvider struct {
	APIKey     string
	BaseURL    string
	HTTPClient *http.Client
}

func NewOpenAIProvider(client *http.Client) *OpenAIProvider {
	if client == nil {
		client = http.DefaultClient
	}
	return &OpenAIProvider{HTTPClient: client}
}

func (p *OpenAIProvider) Complete(ctx context.Context, req ProviderRequest) (string, error) {
	apiKey := p.APIKey
	if apiKey == "" {
		apiKey = os.Getenv("OpenAIKey")
	}
	if apiKey == "" {
		return "", fmt.Errorf("OpenAIKey environment variable is required")
	}

	baseURL := p.BaseURL
	if baseURL == "" {
		baseURL = openAIResponsesURL
	}

	body := openAIResponsesRequest{
		Model: req.ModelName,
		Input: toAnySlice(req.Messages),
		Tools: convertToOpenAIResponseTools(req.Tools),
	}

	for i := 0; i < 5; i++ {
		response, err := p.call(ctx, baseURL, apiKey, body)
		if err != nil {
			return "", err
		}

		functionCalls := make([]openAIOutputItem, 0)
		for _, out := range response.Output {
			if out.Type == "function_call" {
				functionCalls = append(functionCalls, out)
			}
		}

		if len(functionCalls) == 0 {
			text := extractOutputText(response.Output)
			if text == "" {
				return "", fmt.Errorf("no text content in response")
			}
			return text, nil
		}

		for _, outputItem := range response.Output {
			body.Input = append(body.Input, outputItem)
		}
		for _, call := range functionCalls {
			result := ""
			if tool, ok := req.ToolExecutions[call.Name]; ok {
				args := map[string]any{}
				if call.Arguments != "" {
					_ = json.Unmarshal([]byte(call.Arguments), &args)
				}
				r, err := tool(args)
				if err != nil {
					result = "Error: " + err.Error()
				} else {
					result = r
				}
			} else {
				result = fmt.Sprintf("Error: Function %s not found", call.Name)
			}
			body.Input = append(body.Input, openAIFunctionCallOutput{
				Type:   "function_call_output",
				CallID: call.CallID,
				Output: result,
			})
		}
	}

	return "", fmt.Errorf("maximum iterations reached without completing the response")
}

func (p *OpenAIProvider) call(ctx context.Context, url, apiKey string, payload openAIResponsesRequest) (openAIResponsesResponse, error) {
	data, err := json.Marshal(payload)
	if err != nil {
		return openAIResponsesResponse{}, err
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(data))
	if err != nil {
		return openAIResponsesResponse{}, err
	}
	httpReq.Header.Set("Authorization", "Bearer "+apiKey)
	httpReq.Header.Set("OpenAI-Beta", "responses=v1")
	httpReq.Header.Set("Content-Type", "application/json")

	httpResp, err := p.HTTPClient.Do(httpReq)
	if err != nil {
		return openAIResponsesResponse{}, err
	}
	defer httpResp.Body.Close()

	var out openAIResponsesResponse
	if err := json.NewDecoder(httpResp.Body).Decode(&out); err != nil {
		return openAIResponsesResponse{}, err
	}
	if httpResp.StatusCode >= 400 {
		if out.Error.Message != "" {
			return openAIResponsesResponse{}, fmt.Errorf("openai api error (HTTP %d): %s", httpResp.StatusCode, out.Error.Message)
		}
		return openAIResponsesResponse{}, fmt.Errorf("openai api error (HTTP %d)", httpResp.StatusCode)
	}
	if out.Error.Message != "" {
		return openAIResponsesResponse{}, fmt.Errorf(out.Error.Message)
	}
	return out, nil
}

func convertToOpenAIResponseTools(tools []ToolDefinition) []openAIResponseTool {
	if len(tools) == 0 {
		return nil
	}
	result := make([]openAIResponseTool, 0, len(tools))
	for _, t := range tools {
		if t.Function != nil {
			result = append(result, openAIResponseTool{Type: "function", Name: t.Function.Name, Description: t.Function.Description, Parameters: t.Function.Parameters})
			continue
		}
		result = append(result, openAIResponseTool{Type: "function", Name: t.Name, Description: t.Desc, Parameters: t.Params})
	}
	return result
}

func extractOutputText(items []openAIOutputItem) string {
	text := ""
	for _, item := range items {
		if item.Type != "message" {
			continue
		}
		for _, c := range item.Content {
			if c.Type == "output_text" {
				text += c.Text
			}
		}
	}
	return text
}

func toAnySlice(messages []Message) []any {
	out := make([]any, 0, len(messages))
	for _, m := range messages {
		out = append(out, m)
	}
	return out
}

type openAIResponsesRequest struct {
	Model string               `json:"model"`
	Input []any                `json:"input"`
	Tools []openAIResponseTool `json:"tools,omitempty"`
}

type openAIResponseTool struct {
	Type        string         `json:"type"`
	Name        string         `json:"name"`
	Description string         `json:"description,omitempty"`
	Parameters  map[string]any `json:"parameters,omitempty"`
}

type openAIFunctionCallOutput struct {
	Type   string `json:"type"`
	CallID string `json:"call_id"`
	Output string `json:"output"`
}

type openAIResponsesResponse struct {
	Output []openAIOutputItem `json:"output"`
	Error  struct {
		Message string `json:"message"`
	} `json:"error"`
}

type openAIOutputItem struct {
	Type      string                `json:"type"`
	Name      string                `json:"name,omitempty"`
	Arguments string                `json:"arguments,omitempty"`
	CallID    string                `json:"call_id,omitempty"`
	Content   []openAIOutputContent `json:"content,omitempty"`
}

type openAIOutputContent struct {
	Type string `json:"type"`
	Text string `json:"text"`
}
