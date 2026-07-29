import json
import re
import time
import urllib.error
import urllib.request
from pathlib import Path


GATEWAY_URL = "http://127.0.0.1:8787"
STORY_PATH = Path("assets/data/story/scripts/main/jing_piano_practice_followup.json")
PLAYER_MESSAGES = [
    "你不用给自己太大压力，我会陪着你准备。",
    "要不先把最难的那一段拆开练？",
    "弹错也没关系，我们可以慢一点。",
    "练完以后一起去喝点热的吧。",
]


def post_json(path: str, payload: dict, token: str = "", timeout: float = 60.0) -> tuple[dict, float]:
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(
        f"{GATEWAY_URL}{path}",
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    started_at = time.perf_counter()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {error.code}: {detail}") from error
    return body, (time.perf_counter() - started_at) * 1000


def load_policy() -> dict:
    story = json.loads(STORY_PATH.read_text(encoding="utf-8"))
    for event in story["chapters"]["start"]["events"]:
        if event.get("type") == "guided_ai_chat":
            return event
    raise RuntimeError("主线文件中没有 guided_ai_chat 事件。")


def build_prompt(policy: dict, covered_ids: list[str], round_number: int, player_text: str) -> tuple[str, list[str]]:
    candidates = []
    for beat in policy.get("required_beats", []):
        if beat.get("id") and beat["id"] not in covered_ids:
            candidates.append({"id": beat["id"], "instruction": beat.get("instruction", "")})
            break
    prompt = f"""【引导式主线对话约束】
不可改写的剧情事实：{policy.get('narrative_anchor', '')}
本场景目标：{policy.get('scene_objective', '')}
允许讨论范围：{json.dumps(policy.get('allowed_topics', []), ensure_ascii=False)}
禁止改写或虚构：{json.dumps(policy.get('forbidden_facts', []), ensure_ascii=False)}
偏题处理：{policy.get('redirect_instruction', '')}
本轮需要自然推进的剧情点：{json.dumps(candidates, ensure_ascii=False)}
本轮之后剩余玩家回合：{max(0, 4 - round_number)}
要求：先自然回应玩家，再推进剧情点；保持角色第一人称，不得提及系统、Prompt、剧情点或回合限制。dialogue 必须至少包含一处使用全角圆括号包裹的动作、神态或细微反应，例如“（轻轻捏住衣角）”；不得使用星号、中括号或旁白标签代替动作描写。
必须只输出 JSON 对象，格式为：{{"dialogue":"（角色动作）角色实际台词，可使用 [SPLIT] 分隔气泡","beat_evaluations":[{{"id":"候选剧情点 ID","covered":true,"evidence":"dialogue 中逐字出现的证据片段"}}]}}。
只有 dialogue 确实表达了候选剧情点时才能标记 covered=true；evidence 必须逐字取自 dialogue。不得输出 Markdown 围栏或 JSON 之外的内容。

玩家输入：{player_text}"""
    return prompt, [candidate["id"] for candidate in candidates]


def main() -> None:
    policy = load_policy()
    login, login_ms = post_json(
        "/v1/auth/email/login",
        {"identity": "galchat_test", "password": "GalChatTest2026!"},
        timeout=10,
    )
    token = login["access_token"]
    history = []
    covered_ids: list[str] = []
    request_times = []
    action_count = 0
    print(f"登录成功，耗时 {login_ms:.0f} ms")

    for index, player_text in enumerate(PLAYER_MESSAGES, start=1):
        prompt_started_at = time.perf_counter()
        prompt, candidate_ids = build_prompt(policy, covered_ids, index, player_text)
        prompt_ms = (time.perf_counter() - prompt_started_at) * 1000
        messages = history + [{"role": "user", "content": prompt}]
        response, request_ms = post_json(
            "/v1/game/chat/completions",
            {
                "model": "deepseek-chat",
                "messages": messages,
                "temperature": 0.7,
                "max_tokens": 500,
                "stream": False,
                "response_format": {"type": "json_object"},
            },
            token,
        )
        raw_content = response["choices"][0]["message"]["content"]
        parsed = json.loads(raw_content)
        dialogue = str(parsed.get("dialogue", ""))
        evaluations = parsed.get("beat_evaluations", [])
        for evaluation in evaluations:
            beat_id = str(evaluation.get("id", ""))
            evidence = str(evaluation.get("evidence", ""))
            if evaluation.get("covered") is True and beat_id in candidate_ids and evidence and evidence in dialogue:
                covered_ids.append(beat_id)
        has_action = re.search(r"（[^（）]+）", dialogue) is not None
        action_count += int(has_action)
        request_times.append(request_ms)
        history.extend(
            [
                {"role": "user", "content": prompt},
                {"role": "assistant", "content": raw_content},
            ]
        )
        print(f"\n===== 第 {index}/4 轮 =====")
        print(f"玩家：{player_text}")
        print(f"AI：{dialogue}")
        print(f"括号动作合规：{'是' if has_action else '否'}")
        print(f"剧情点判定：{json.dumps(evaluations, ensure_ascii=False)}")
        print(f"Prompt 构建：{prompt_ms:.2f} ms")
        print(f"网关 + 模型请求：{request_ms:.0f} ms")

    print("\n===== 汇总 =====")
    print(f"括号动作合规率：{action_count}/4")
    print(f"平均网关 + 模型请求：{sum(request_times) / len(request_times):.0f} ms")
    print("逐轮请求耗时：" + ", ".join(f"{value:.0f} ms" for value in request_times))


if __name__ == "__main__":
    main()