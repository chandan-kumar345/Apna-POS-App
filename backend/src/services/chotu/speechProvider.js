/**
 * Speech Provider Abstraction Interface and Implementations
 * Supports English, Hindi, Hinglish transcription.
 */

class SpeechProvider {
  /**
   * Transcribe speech audio or process raw transcription string
   * @param {Object} params
   * @param {Buffer|string} params.audio - Base64 audio or buffer, or raw simulated text
   * @param {string} params.format - wav, m4a, mp3, raw_text
   * @param {string} [params.language] - en, hi, hinglish, auto
   * @returns {Promise<{ text: string, confidence: number, language: string, durationMs?: number }>}
   */
  async transcribe({ audio, format = 'raw_text', language = 'hinglish' }) {
    throw new Error('transcribe() must be implemented by SpeechProvider');
  }
}

/**
 * Normalizes Hindi, Hinglish, and English spoken numerals and common words
 */
function normalizeSpokenText(text) {
  if (!text || typeof text !== 'string') return '';
  let clean = text.trim();

  // Protect Hindi imperative verbs ending in 'do' (e.g. laga do, kar do, bana do, bhej do, hata do)
  const verbDoMap = [];
  clean = clean.replace(/\b(laga|kar|bana|hata|de|bhej|daal|rakh|nikal|le)\s+do\b/gi, (match, p1) => {
    const placeholder = `__VERB_${verbDoMap.length}__`;
    verbDoMap.push({ placeholder, original: `${p1} do` });
    return placeholder;
  });

  // Normalize Hindi / Hinglish / English numerals to digits
  const numberMap = [
    { regex: /\b(ek|ik|one)\b/gi, replacement: '1' },
    { regex: /\b(do|too|two)\b/gi, replacement: '2' },
    { regex: /\b(teen|tin|three)\b/gi, replacement: '3' },
    { regex: /\b(chaar|char|four)\b/gi, replacement: '4' },
    { regex: /\b(paanch|panch|five)\b/gi, replacement: '5' },
    { regex: /\b(chhah|che|chhe|six)\b/gi, replacement: '6' },
    { regex: /\b(saat|sat|seven)\b/gi, replacement: '7' },
    { regex: /\b(aath|ath|eight)\b/gi, replacement: '8' },
    { regex: /\b(nau|no|nine)\b/gi, replacement: '9' },
    { regex: /\b(das|dus|ten)\b/gi, replacement: '10' },
  ];

  for (const item of numberMap) {
    clean = clean.replace(item.regex, item.replacement);
  }

  // Restore verbal 'do' phrases
  for (const v of verbDoMap) {
    clean = clean.replace(v.placeholder, v.original);
  }

  // Normalize common restaurant filler words & spacing
  clean = clean.replace(/\s+/g, ' ').trim();
  return clean;
}

/**
 * Standard Built-in Speech Provider
 * Handles direct text transcription streams (e.g. from mobile/web speech recognizer),
 * speech simulation for testing, and pluggable cloud STT API calls.
 */
class DefaultSpeechProvider extends SpeechProvider {
  constructor(options = {}) {
    super();
    this.apiKey = options.apiKey || process.env.OPENAI_API_KEY || '';
    this.providerName = options.providerName || (this.apiKey ? 'openai_whisper' : 'built_in_stream');
  }

  async transcribe({ audio, format = 'raw_text', language = 'hinglish' }) {
    const startTime = Date.now();

    // 1. If payload is raw_text (transcribed by client browser/device speech engine)
    if (format === 'raw_text' || typeof audio === 'string') {
      const normalized = normalizeSpokenText(audio);
      const durationMs = Date.now() - startTime;
      return {
        text: normalized,
        originalText: audio,
        confidence: 0.98,
        language: language || 'hinglish',
        durationMs,
        provider: this.providerName,
      };
    }

    // 2. If audio buffer is provided and OpenAI API key exists, call Whisper API
    if (this.apiKey && Buffer.isBuffer(audio)) {
      try {
        // Dynamic import / fetch to OpenAI Audio Transcriptions API
        const formData = new FormData();
        const blob = new Blob([audio], { type: format === 'wav' ? 'audio/wav' : 'audio/m4a' });
        formData.append('file', blob, `audio.${format}`);
        formData.append('model', 'whisper-1');
        if (language && language !== 'auto') {
          formData.append('language', language === 'hinglish' ? 'hi' : language);
        }

        const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${this.apiKey}`,
          },
          body: formData,
        });

        if (!response.ok) {
          const errBody = await response.text();
          throw new Error(`OpenAI Whisper error (${response.status}): ${errBody}`);
        }

        const data = await response.json();
        const normalized = normalizeSpokenText(data.text);
        const durationMs = Date.now() - startTime;

        return {
          text: normalized,
          originalText: data.text,
          confidence: 0.95,
          language: language || 'hinglish',
          durationMs,
          provider: 'openai_whisper',
        };
      } catch (err) {
        console.warn('[SpeechProvider] Fallback due to STT error:', err.message);
      }
    }

    // 3. Fallback / Test Provider
    const durationMs = Date.now() - startTime;
    return {
      text: typeof audio === 'string' ? normalizeSpokenText(audio) : '',
      confidence: 0.90,
      language: language || 'hinglish',
      durationMs,
      provider: 'fallback_stt',
    };
  }
}

module.exports = {
  SpeechProvider,
  DefaultSpeechProvider,
  normalizeSpokenText,
};
