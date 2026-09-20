#!/usr/bin/env python3
"""
Chotu Voice Engine (Python Bridge)
Provides background noise cancellation, Voice Activity Detection (VAD),
multi-lingual Hindi/Hinglish speech recognition, and 'understand' end-of-speech trigger detection.
"""

import sys
import json
import time
import re

try:
    import speech_recognition as sr
except ImportError:
    print(json.dumps({"status": "ERROR", "message": "speech_recognition package not installed"}), flush=True)
    sys.exit(1)

TRIGGER_WORDS = [
    "understand", "understood", "samjhe", "samajh gaye", "samjh gaye", "samjha", "samjh", "done", "execute"
]

def contains_trigger(text: str) -> bool:
    lower = text.lower()
    for trigger in TRIGGER_WORDS:
        if re.search(r'\b' + re.escape(trigger) + r'\b', lower):
            return True
    return False

def transcribe_audio(recognizer, audio) -> str:
    """Tries Hindi (hi-IN) first, then Indian English (en-IN), then en-US."""
    # 1. Hindi primary
    try:
        text = recognizer.recognize_google(audio, language="hi-IN")
        if text and len(text.strip()) > 0:
            return text.strip()
    except Exception:
        pass

    # 2. Indian English / Hinglish
    try:
        text = recognizer.recognize_google(audio, language="en-IN")
        if text and len(text.strip()) > 0:
            return text.strip()
    except Exception:
        pass

    # 3. English standard
    try:
        text = recognizer.recognize_google(audio, language="en-US")
        if text and len(text.strip()) > 0:
            return text.strip()
    except Exception:
        pass

    return ""

def run_listener():
    recognizer = sr.Recognizer()
    
    # Configure sensitivity & noise rejection
    recognizer.energy_threshold = 280
    recognizer.dynamic_energy_threshold = True
    recognizer.dynamic_energy_adjustment_damping = 0.15
    recognizer.dynamic_energy_ratio = 1.5
    recognizer.pause_threshold = 0.75          # Pause detection when user pauses
    recognizer.phrase_threshold = 0.2
    recognizer.non_speaking_duration = 0.4

    try:
        with sr.Microphone() as source:
            # 1. Ambient noise calibration
            recognizer.adjust_for_ambient_noise(source, duration=0.4)
            print(json.dumps({"status": "READY", "energy_threshold": recognizer.energy_threshold}), flush=True)
            print(json.dumps({"status": "LISTENING"}), flush=True)

            accumulated_phrases = []
            max_listen_time = time.time() + 18.0  # Max total session 18s

            while time.time() < max_listen_time:
                try:
                    # Listen for phrase chunks
                    audio = recognizer.listen(source, timeout=4.5, phrase_time_limit=10.0)
                except sr.WaitTimeoutError:
                    if accumulated_phrases:
                        # User spoke and stopped speaking
                        break
                    else:
                        # Initial silence
                        print(json.dumps({"status": "SILENCE", "text": ""}), flush=True)
                        return

                chunk_text = transcribe_audio(recognizer, audio)
                if chunk_text:
                    accumulated_phrases.append(chunk_text)
                    combined_text = " ".join(accumulated_phrases).strip()
                    
                    print(json.dumps({"status": "PARTIAL", "text": combined_text}), flush=True)

                    # Check if user said "understand" / "samajh gaye" to end conversation
                    if contains_trigger(combined_text) or contains_trigger(chunk_text):
                        print(json.dumps({
                            "status": "RECOGNIZED",
                            "text": combined_text,
                            "trigger_ended": True,
                            "confidence": 0.98
                        }), flush=True)
                        return
                    else:
                        # Once a complete POS phrase is spoken and paused, finalize
                        time.sleep(0.1)
                        break

            final_text = " ".join(accumulated_phrases).strip()
            if final_text:
                print(json.dumps({
                    "status": "RECOGNIZED",
                    "text": final_text,
                    "confidence": 0.95
                }), flush=True)
            else:
                print(json.dumps({"status": "SILENCE", "text": ""}), flush=True)

    except Exception as ex:
        print(json.dumps({"status": "ERROR", "message": str(ex)}), flush=True)

if __name__ == "__main__":
    run_listener()
