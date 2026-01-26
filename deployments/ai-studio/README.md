# Tyk AI Studio

To run Tyk AI Studio:

1. Add your license to `.env`:

`TYK_AI_STUDIO_LICENSE=<YOUR_AI_STUDIO_LICENSE>`

2. Run the Tyk Demo `up.sh` script with the `ai-studio` argument:

```shell
./up.sh ai-studio
```

3. Visit AI Studio in your browser at http://localhost:3011

4. Log on using:

```
dev@tyk.io
T0pSecR3t!
```

## Configuration once logged in to actrually get the External; Anthropic demo elements to work:
We do not ship the demo DB with any pre-configured LLM credentials, these need to be set up once when you first run studio. There is only one secret you really have to set: `ANTHROPIC_TYKGATEWAY_SECRET`, but there are also two more for Anthropic and OpenAI for the two default LLMs that Tyk AI Studio ships with, this are Bring-Your-Own keys, so if you want to directly interface with Anthropic or OpenAI without going through the centrally managed Tyk AI Gateway, then set these with your own key. 

The following instructions are solely for setting up managed accss for tyk demo.

### 1. Get app credentials for Anthropic access from the internal Tyk AI Gateway: 

  - Go to https://chat.tyk.technology
  - Login with OneLogin 
  - Go to the app you are using for tyk demo 
    - (if you dont have one, create one and let Martin, Leo, or Laurentiu know and we can approve it) 
  - Make sure it has requested access to our Anthropic Gateway LLM - (tyk demo is mainly configured for Anthropic)
  - Get the token for that app and navigate to 

### 2. Update the secrets oj your local demo instance:
  - Browse to Administration -> Governance -> Secrets  
  - Select `ANTHROPIC_TYKGATEWAY_SECRET` -> Edit secret
  - Paste your API key from `chat.tyk.technology` into the VALUE field
  - Click save

### 3. Make sure your edge gateway updates it's secrets repository:
  - Still on tyk-demo, browse to Administration -> AI Portal -> Edge Gateways
  - Click "Push Configuration", and again "Push Configuration"

### 4. Test your instance (replace or set `$TYK_DEMO_KEY` in your shell):

```
curl http://localhost:9091/llm/call/external-claude-gateway/v1/messages \
          -H "Content-Type: application/json" \
          -H "x-api-key: $TYK_DEMO_KEY" \
          -H "anthropic-version: 2023-06-01" \
          -d '{
    "model": "claude-sonnet-4-5-20250929",
    "max_tokens": 1000,  "system": [
      {
        "type": "text",
        "text": "You are a helpful assistant.",
        "cache_control": {"type": "ephemeral"}
      }
    ],
    "messages": [
      {
        "role": "user",
        "content": "tell me a very shortt story about a unicorn please!!"
      }
    ]
  }'
  ```