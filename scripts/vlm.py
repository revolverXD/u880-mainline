"""Ask the local Qwen VLM (LAN server in the user memory file local-llm-servers) about a photo. usage: python3 -I vlm.py <image> <question>. Downscale first (~640 px); it misreads fine detail, always look at key photos yourself."""
import base64, json, os, sys, urllib.request
img = base64.b64encode(open(sys.argv[1], 'rb').read()).decode()
body = {"model": "qwen3.6-35b-a3b", "max_tokens": 400, "chat_template_kwargs": {"enable_thinking": False},
        "messages": [{"role": "user", "content": [{"type": "text", "text": sys.argv[2]},
                     {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64," + img}}]}]}
req = urllib.request.Request(os.environ.get("VLM_URL", "http://localhost:8085/v1/chat/completions"), json.dumps(body).encode(),
                             {"Content-Type": "application/json"})
print(json.load(urllib.request.urlopen(req, timeout=300))["choices"][0]["message"]["content"])
