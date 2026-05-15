import json
import httpx
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse, Response

app = FastAPI()

# ─── 配置区 ──────────────────────────────────────────
TARGET = "http://192.168.x.x:33333"   # 模型服务地址
MODEL_NAME = "ds"                       # 模型实际 id
API_KEY = "sk-anything"
# ─────────────────────────────────────────────────────


@app.get("/v1/models")
async def list_models():
    """伪造模型列表，让 Claude Code 本地校验通过"""
    return {
        "object": "list",
        "data": [
            {
                "id": MODEL_NAME,
                "object": "model",
                "created": 1700000000,
                "owned_by": "vllm",
            }
        ],
    }


@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def proxy(path: str, request: Request):
    """透传所有请求，替换模型名"""
    body = await request.body()

    if body:
        try:
            data = json.loads(body)
            if "model" in data:
                data["model"] = MODEL_NAME
            body = json.dumps(data).encode()
        except Exception:
            pass

    headers = {k: v for k, v in request.headers.items() if k.lower() != "host"}
    headers["content-length"] = str(len(body))
    headers["authorization"] = f"Bearer {API_KEY}"

    async with httpx.AsyncClient(timeout=300) as client:
        resp = await client.request(
            method=request.method,
            url=f"{TARGET}/{path}",
            headers=headers,
            content=body,
            params=dict(request.query_params),
        )

    if "text/event-stream" in resp.headers.get("content-type", ""):
        async def stream():
            yield resp.content

        return StreamingResponse(
            stream(),
            status_code=resp.status_code,
            headers=dict(resp.headers),
            media_type="text/event-stream",
        )

    return Response(
        content=resp.content,
        status_code=resp.status_code,
        headers=dict(resp.headers),
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=4000)
