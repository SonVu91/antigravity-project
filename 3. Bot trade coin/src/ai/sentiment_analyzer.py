import logging
import json
from typing import List, Dict, Any
import aiohttp
from config.settings import settings

logger = logging.getLogger("SentimentAnalyzer")


class SentimentAnalyzer:
    """
    AI News & Social Sentiment Scorer using Google Gemini API.
    Scores context from -1.0 (Very Bearish) to +1.0 (Very Bullish).
    Includes intelligent rule-based fallback when offline or no API key is set.
    """

    def __init__(self):
        self.api_key = settings.GEMINI_API_KEY
        self.model_name = settings.GEMINI_MODEL or "gemini-2.0-flash"
        self.gemini_url = (
            f"https://generativelanguage.googleapis.com/v1beta/models/{self.model_name}:generateContent?key={self.api_key}"
            if self.api_key
            else None
        )

    async def analyze_headlines(self, headlines: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Analyze news headlines for Cardano (ADA) and Midnight (NIGHT).
        Returns aggregated sentiment score, confidence, and catalyst summary.
        """
        if not headlines:
            return {"sentiment_score": 0.0, "confidence": 0.5, "summary": "Không có tin tức mới."}

        # Format prompt
        titles = "\n".join([f"- {h.get('title', '')} ({h.get('source', '')})" for h in headlines[:8]])

        prompt = f"""
Bạn là chuyên gia phân tích định lượng tâm lý thị trường tiền mã hóa cho hệ sinh thái Cardano và Midnight Network.
Hãy đánh giá các tiêu đề tin tức sau đây:
{titles}

Trả về DUY NHẤT một chuỗi JSON hợp lệ không có markdown bọc ngoài theo đúng định dạng sau:
{{
  "sentiment_score": float từ -1.0 (Rất tiêu cực) đến +1.0 (Rất tích cực),
  "confidence": float từ 0.0 đến 1.0,
  "key_catalyst": "Tóm tắt ngắn gọn động lực chính trong 1 câu"
}}
"""

        if self.gemini_url:
            try:
                payload = {
                    "contents": [{"parts": [{"text": prompt}]}],
                    "generationConfig": {"temperature": 0.2, "maxOutputTokens": 200},
                }
                async with aiohttp.ClientSession() as session:
                    async with session.post(self.gemini_url, json=payload, timeout=12) as resp:
                        if resp.status == 200:
                            data = await resp.json()
                            candidate_text = data["candidates"][0]["content"]["parts"][0]["text"].strip()
                            clean_json = candidate_text.replace("```json", "").replace("```", "").strip()
                            parsed = json.loads(clean_json)
                            return {
                                "sentiment_score": float(parsed.get("sentiment_score", 0.0)),
                                "confidence": float(parsed.get("confidence", 0.8)),
                                "summary": parsed.get("key_catalyst", "Tin tức cập nhật từ Gemini AI."),
                            }
            except Exception as e:
                logger.debug(f"Gemini API sentiment error: {e}. Using rule-based fallback.")

        # Heuristic / Keyword Rule-based Fallback
        return self._heuristic_analysis(headlines)

    def _heuristic_analysis(self, headlines: List[Dict[str, Any]]) -> Dict[str, Any]:
        bullish_words = ["surge", "ath", "high", "adoption", "partnership", "growth", "breakout", "testnet", "launch", "upgrade"]
        bearish_words = ["crash", "drop", "hack", "exploit", "sec", "lawsuit", "delay", "rug", "dump", "ban"]

        score = 0.0
        text = " ".join([h.get("title", "").lower() for h in headlines])
        for w in bullish_words:
            if w in text:
                score += 0.15
        for w in bearish_words:
            if w in text:
                score -= 0.20

        score = max(-1.0, min(1.0, score))
        summary = "Tâm lý tích cực từ hệ sinh thái." if score > 0 else ("Tâm lý tiêu cực cần thận trọng." if score < 0 else "Tâm lý thị trường trung lập.")
        return {
            "sentiment_score": round(score, 2),
            "confidence": 0.65,
            "summary": summary,
        }
