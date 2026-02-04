"""
Firestore Emulator seed script (Python)
Run with: python firebase/seed.py
"""

import os
import sys
from datetime import datetime, timedelta

import firebase_admin
from firebase_admin import firestore
from google.auth.credentials import AnonymousCredentials

# ----------------------------
# Emulator only (VERY IMPORTANT)
# ----------------------------
os.environ["FIRESTORE_EMULATOR_HOST"] = "localhost:8081"

# Initialize app for emulator (no real credentials needed)
cred = AnonymousCredentials()
firebase_admin.initialize_app(cred, options={"projectId": "memory-harbor"})

db = firestore.client()

def _non_empty_str(value, default):
    if value is None:
        return default
    text = str(value).strip()
    return text if text else default

def _clear_collection(collection_ref):
    docs = collection_ref.stream()
    for doc in docs:
        doc.reference.delete()


def clear_all():
    print("🧹 Clearing Firestore emulator data...")
    #_clear_collection(db.collection("users"))
    _clear_collection(db.collection("groups"))
    _clear_collection(db.collection("receivers"))
    _clear_collection(db.collection("calls"))
    _clear_collection(db.collection("meta"))
    print("✅ Clear completed")


def seed():
    print("🌱 Seeding Firestore (emulator) with Python...")

    # ---------- IDs ----------
    group_id = "group_1"
    receiver_id = "receiver_1"

    user_a = "user_jungwon"
    user_b = "user_alice"

    residences = [
        {
            "id": "res_1950s_andong",
            "era": "1950~1965",
            "location": "경상북도 안동시",
            "detail": "태어난 곳, 어린 시절",
        },
        {
            "id": "res_1960s_jongno",
            "era": "1966~1975",
            "location": "서울 종로구",
            "detail": "학창시절, 결혼 전",
        },
        {
            "id": "res_1975s_gangnam",
            "era": "1976~1989",
            "location": "서울 강남구",
            "detail": "신혼, 자녀 양육기",
        },
        {
            "id": "res_1990s_bundang",
            "era": "1990~2010",
            "location": "경기도 분당",
            "detail": "자녀 독립 후",
        },
        {
            "id": "res_2010s_seocho",
            "era": "2011~현재",
            "location": "서울 서초구",
            "detail": "현재 거주지",
        },
    ]

    calls = [
        {
            "call_id": "call_001",
            "summary": "안동 어린 시절 이야기",
            "residences": ["res_1950s_andong"],
        },
        {
            "call_id": "call_002",
            "summary": "종로 학창시절 회상",
            "residences": ["res_1960s_jongno"],
        },
        {
            "call_id": "call_003",
            "summary": "강남에서 자녀 양육기 이야기",
            "residences": ["res_1975s_gangnam"],
        },
        {
            "call_id": "call_004",
            "summary": "분당 신도시 정착기",
            "residences": ["res_1990s_bundang"],
        },
        {
            "call_id": "call_005",
            "summary": "서초에서의 현재 일상",
            "residences": ["res_2010s_seocho"],
        },
    ]

    now = datetime.utcnow()

    # ---------- Users ----------
    db.collection("users").document(user_a).set({
        "uid": user_a,
        "name": "Jungwon",
        "email": "jungwon@test.com",
        "profileImage": "https://placehold.co/200x200",
        "groupIds": [group_id],
        "createdAt": now,
    })

    db.collection("users").document(user_b).set({
        "uid": user_b,
        "name": "Alice",
        "email": "alice@test.com",
        "profileImage": "https://placehold.co/200x200",
        "groupIds": [group_id],
        "createdAt": now,
    })

    # ---------- Group ----------
    db.collection("groups").document(group_id).set({
        "groupId": group_id,
        "name": "Boston Care Group",
        "careGiverUserIds": [user_a, user_b],
        "receiverId": receiver_id,
        "stats": {
            "totalCalls": len(calls),
            "lastCallId": calls[-1]["call_id"],
            "lastCallAt": now,
        },
    })

    # ---------- CareReceiver ----------
    db.collection("receivers").document(receiver_id).set({
        "receiverId": receiver_id,
        "groupId": group_id,
        "name": "김영옥",
        "profileImage": "https://placehold.co/200x200",
        "majorResidences": [
            {
                "residenceId": r["id"],
                "era": _non_empty_str(r.get("era"), "시기 미상"),
                "location": _non_empty_str(r.get("location"), "장소 미상"),
                "detail": _non_empty_str(r.get("detail"), ""),
            }
            for r in residences
        ],
    })

    # ---------- Residences + Stats ----------
    for r in residences:
        era = _non_empty_str(r.get("era"), "시기 미상")
        location = _non_empty_str(r.get("location"), "장소 미상")
        detail = _non_empty_str(r.get("detail"), "")
        ai_summary = (
            f"{era}({location})의 기억은 일상과 관계 중심으로 정리됩니다."
            + (f" 주요 단서: {detail}." if detail else "")
        )

        db.collection("receivers").document(receiver_id) \
            .collection("residence_stats").document(r["id"]).set({
                "groupId": group_id,
                "receiverId": receiver_id,
                "residenceId": r["id"],
                "era": era,
                "location": location,
                "detail": detail,
                "keywords": ["가족", "추억"],
                "totalCalls": 1,
                "lastCallAt": now,
                "aiSummary": ai_summary,
                "humanComments": ["이 시절 이야기가 자주 등장함"],
            })

    # ---------- Calls + Reviews ----------
    for i, c in enumerate(calls):
        call_ref = db.collection("calls").document(c["call_id"])

        created_at = (now - timedelta(days=3 - i))
        answered_at = created_at + timedelta(seconds=5)
        ended_at = created_at + timedelta(seconds=600)
        channel_name = f"{group_id}_{user_a}_{receiver_id}_{int(created_at.timestamp() * 1000)}"

        call_ref.set({
            "callId": c["call_id"],
            "channelName": channel_name,
            "groupId": group_id,
            "receiverId": receiver_id,
            "caregiverUserId": user_a,
            "groupNameSnapshot": "Boston Care Group",
            "giverNameSnapshot": "Jungwon",
            "receiverNameSnapshot": "김영옥",
            "createdAt": created_at,
            "answeredAt": answered_at,
            "endedAt": ended_at,
            "durationSec": 600,
            "status": "ended",
            "humanSummary": "",
            "humanKeywords": [],
            "humanNotes": "",
            "aiSummary": "",
            "reviewCount": 1,
            "lastReviewAt": now,
        })

        call_ref.collection("reviews").add({
            "callId": c["call_id"],
            "writerUserId": user_a,
            "writerNameSnapshot": "Jungwon",
            "mentionedResidences": c["residences"],
            "humanSummary": "대화가 자연스럽고 감정이 잘 드러났음",
            "humanKeywords": ["따뜻함"],
            "mood": "warm",
            "comment": "다음에도 비슷한 질문을 이어가면 좋겠다",
            "createdAt": now,
        })

    print("✅ Seed completed successfully (Python)")

if __name__ == "__main__":
    if "--reset" in sys.argv:
        clear_all()
    seed()
