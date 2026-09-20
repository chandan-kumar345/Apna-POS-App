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
 * Phonetically transliterates Devanagari script to Latin alphabet
 */
function transliterateDevanagari(text) {
  if (!text || typeof text !== 'string') return '';
  if (!/[\u0900-\u097F]/.test(text)) return text;

  const charMap = {
    // Independent Vowels
    'अ': 'a', 'आ': 'aa', 'इ': 'i', 'ई': 'ee', 'उ': 'u', 'ऊ': 'oo',
    'ऋ': 'ri', 'ए': 'e', 'ऐ': 'ai', 'ओ': 'o', 'औ': 'au',
    'अं': 'an', 'अः': 'ah', 'ऑ': 'o', 'ऍ': 'e',
    // Dependent Vowels (Matras)
    'ा': 'a', 'ि': 'i', 'ी': 'i', 'ु': 'u', 'ू': 'u',
    'ृ': 'ri', 'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au',
    'ॉ': 'o', 'ॅ': 'e',
    // Modifiers
    'ं': 'n', 'ँ': 'n', 'ः': 'h', '़': '',
    // Consonants
    'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'ng',
    'च': 'ch', 'छ': 'chh', 'ज': 'j', 'झ': 'jh', 'ञ': 'ny',
    'ट': 't', 'ठ': 'th', 'ड': 'd', 'ढ': 'dh', 'ण': 'n',
    'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh', 'न': 'n',
    'प': 'p', 'फ': 'f', 'ब': 'b', 'भ': 'bh', 'म': 'm',
    'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v',
    'श': 'sh', 'ष': 'sh', 'स': 's', 'ह': 'h',
    'क्ष': 'ksh', 'त्र': 'tr', 'ज्ञ': 'gy',
    'क़': 'q', 'ख़': 'kh', 'ग़': 'gh', 'ज़': 'z', 'ड़': 'r', 'ढ़': 'rh', 'फ़': 'f',
  };

  // Convert known food/POS compound words cleanly first
  const commonHindiWords = [
    { hi: /टेबल/g, en: 'table' },
    { hi: /मेज/g, en: 'table' },
    { hi: /कोट|केओटी|के\.ओ\.टी|के\s+ओ\s+टी/g, en: 'kot' },
    { hi: /किचन|रसोई/g, en: 'kitchen' },
    { hi: /बिल|पर्ची/g, en: 'bill' },
    { hi: /प्रिंट/g, en: 'print' },
    { hi: /सेटल/g, en: 'settle' },
    { hi: /पेमेंट|हिसाब/g, en: 'payment' },
    { hi: /डिस्काउंट|छूट/g, en: 'discount' },
    { hi: /प्रतिशत|परसेंट/g, en: 'percent' },
    { hi: /रुपये|रुपए|रु\./g, en: 'rs' },
    { hi: /कार्ट/g, en: 'cart' },
    { hi: /ऑर्डर|आर्डर/g, en: 'order' },
    { hi: /खाली/g, en: 'clear' },
    { hi: /कैंसिल|कैंसल|रद्द/g, en: 'cancel' },
    { hi: /हटा\s*दो|हटाओ|हटा/g, en: 'hata do' },
    { hi: /लगा\s*दो|लगाओ|लगा/g, en: 'laga do' },
    { hi: /डाल\s*दो|डालो|डाल/g, en: 'daal do' },
    { hi: /कर\s*दो|करो/g, en: 'kar do' },
    { hi: /बना\s*दो|बनाओ/g, en: 'bana do' },
    { hi: /भेज\s*दो|भेजो/g, en: 'bhej do' },
    { hi: /ऐड\s*करो|ऐड\s*कर\s*दो|ऐड/g, en: 'add karo' },
    { hi: /ग्राहक|कस्टमर/g, en: 'customer' },
    { hi: /नाम/g, en: 'naam' },
    { hi: /नंबर|फोन|मोबाइल/g, en: 'number' },
    { hi: /और|तथा|एवं/g, en: 'aur' },
    { hi: /समझ\s*गए|समझे|समझा|अंडरस्टैंड/g, en: 'understand' },
    { hi: /कोल्ड\s*कॉफी/g, en: 'cold coffee' },
    { hi: /मसाला\s*डोसा/g, en: 'masala dosa' },
    { hi: /पनीर\s*बटर\s*मसाला/g, en: 'paneer butter masala' },
    { hi: /कढ़ाई\s*पनीर|कढाई\s*पनीर/g, en: 'kadhai paneer' },
    { hi: /बटर\s*नान/g, en: 'butter naan' },
    { hi: /तंदूरी\s*रोटी/g, en: 'tandoori roti' },
    { hi: /दाल\s*मखनी/g, en: 'dal makhani' },
    { hi: /दाल\s*तड़का|दाल\s*तड़का/g, en: 'dal tadka' },
    { hi: /चिकन\s*बिरयानी/g, en: 'chicken biryani' },
    { hi: /वेज\s*बिरयानी/g, en: 'veg biryani' },
    { hi: /गुलाब\s*जामुन/g, en: 'gulab jamun' },
    { hi: /चाय/g, en: 'chai' },
    { hi: /कॉफी/g, en: 'coffee' },
    { hi: /समोसा/g, en: 'samosa' },
    { hi: /पिज़्ज़ा|पिज्जा/g, en: 'pizza' },
    { hi: /बर्गर/g, en: 'burger' },
    { hi: /सैंडविच/g, en: 'sandwich' },
    { hi: /चाउमीन|चाऊमीन/g, en: 'chowmein' },
    { hi: /मोमोज|मोमोज़/g, en: 'momos' },
    { hi: /पाव\s*भाजी/g, en: 'pav bhaji' },
    { hi: /छोले\s*भटूरे/g, en: 'chhole bhature' },
    { hi: /लस्सी/g, en: 'lassi' },
    { hi: /फ्रेंच\s*फ्राइज|फ्राइज/g, en: 'french fries' },
  ];

  let res = text;
  for (const item of commonHindiWords) {
    res = res.replace(item.hi, item.en);
  }

  // General character transliteration for any other Devanagari words
  let out = '';
  const len = res.length;
  for (let i = 0; i < len; i++) {
    const ch = res[i];
    const nextCh = i + 1 < len ? res[i + 1] : '';

    if (charMap[ch] !== undefined) {
      out += charMap[ch];
      // Inherent 'a' vowel after consonants if no matra or halant follows
      const isConsonant = /[\u0915-\u0939\u0958-\u095F]/.test(ch);
      const isMatraOrHalant = /[\u093E-\u094D\u0962-\u0963]/.test(nextCh);
      if (isConsonant && !isMatraOrHalant && nextCh && !/\s/.test(nextCh) && /[\u0915-\u0939]/.test(nextCh)) {
        out += 'a';
      }
    } else if (ch === '्') {
      // Halant - suppress inherent vowel
    } else {
      out += ch;
    }
  }

  return out;
}

/**
 * Normalizes Hindi, Hinglish, and English spoken numerals, keywords, and common speech artifacts
 */
function normalizeSpokenText(text) {
  if (!text || typeof text !== 'string') return '';
  let clean = text.trim();

  // 1. Devanagari numerals (०-९)
  const devanagariDigits = { '०': '0', '१': '1', '२': '2', '३': '3', '४': '4', '५': '5', '६': '6', '७': '7', '८': '8', '९': '9' };
  clean = clean.replace(/[०-९]/g, (d) => devanagariDigits[d] || d);

  // 2. Hindi number words in Devanagari
  const devanagariNumberWords = [
    { regex: /\b(सौ|एक\s+सौ)\b/g, replacement: '100' },
    { regex: /\b(पचास|पचाास)\b/g, replacement: '50' },
    { regex: /\b(पैंतीस|पैंतेंस)\b/g, replacement: '35' },
    { regex: /\b(चालीस|चालिस)\b/g, replacement: '40' },
    { regex: /\b(तीस)\b/g, replacement: '30' },
    { regex: /\b(पच्चीस|पचीस)\b/g, replacement: '25' },
    { regex: /\b(बीस|बिस)\b/g, replacement: '20' },
    { regex: /\b(उन्नीस|उनीस)\b/g, replacement: '19' },
    { regex: /\b(अठारह|अठारा)\b/g, replacement: '18' },
    { regex: /\b(सत्रह|सत्रा)\b/g, replacement: '17' },
    { regex: /\b(सोलह|सोला)\b/g, replacement: '16' },
    { regex: /\b(पंद्रह|पंदरा)\b/g, replacement: '15' },
    { regex: /\b(चौदह|चौदा)\b/g, replacement: '14' },
    { regex: /\b(तेरह|तेरा)\b/g, replacement: '13' },
    { regex: /\b(बारह|बारा)\b/g, replacement: '12' },
    { regex: /\b(ग्यारह|ग्यारा)\b/g, replacement: '11' },
    { regex: /\b(दस|दश)\b/g, replacement: '10' },
    { regex: /\b(नौ)\b/g, replacement: '9' },
    { regex: /\b(आठ)\b/g, replacement: '8' },
    { regex: /\b(सात)\b/g, replacement: '7' },
    { regex: /\b(छह|छः|छे)\b/g, replacement: '6' },
    { regex: /\b(पांच|पाँच)\b/g, replacement: '5' },
    { regex: /\b(चार)\b/g, replacement: '4' },
    { regex: /\b(तीन)\b/g, replacement: '3' },
    { regex: /\b(दो)\b/g, replacement: '2' },
    { regex: /\b(एक)\b/g, replacement: '1' },
  ];

  for (const item of devanagariNumberWords) {
    clean = clean.replace(item.regex, item.replacement);
  }

  // 3. Transliterate remaining Devanagari Hindi text to Romanized Hindi/English
  clean = transliterateDevanagari(clean);

  // 4. Protect Hindi imperative verbs ending in 'do' (e.g. laga do, kar do, bana do, bhej do, hata do)
  const verbDoMap = [];
  clean = clean.replace(/\b(laga|kar|bana|hata|de|bhej|daal|rakh|nikal|le)\s+do\b/gi, (match, p1) => {
    const placeholder = `__VERB_${verbDoMap.length}__`;
    verbDoMap.push({ placeholder, original: `${p1} do` });
    return placeholder;
  });

  // 5. Normalize Hindi / Hinglish / English number words (higher numbers first)
  const numberMap = [
    { regex: /\b(sau|ek\s+sau|one\s+hundred|hundred)\b/gi, replacement: '100' },
    { regex: /\b(pachaas|pachas|fifty)\b/gi, replacement: '50' },
    { regex: /\b(paintees|pentees|thirty\s*five)\b/gi, replacement: '35' },
    { regex: /\b(chalis|chaalis|forty)\b/gi, replacement: '40' },
    { regex: /\b(tees|thirty)\b/gi, replacement: '30' },
    { regex: /\b(pachees|pachis|twenty\s*five)\b/gi, replacement: '25' },
    { regex: /\b(bees|bis|twenty)\b/gi, replacement: '20' },
    { regex: /\b(unnis|unees|nineteen)\b/gi, replacement: '19' },
    { regex: /\b(atharah|athara|eighteen)\b/gi, replacement: '18' },
    { regex: /\b(satrah|satra|seventeen)\b/gi, replacement: '17' },
    { regex: /\b(solah|sola|sixteen)\b/gi, replacement: '16' },
    { regex: /\b(pandrah|pandra|fifteen)\b/gi, replacement: '15' },
    { regex: /\b(chaudah|chauda|fourteen)\b/gi, replacement: '14' },
    { regex: /\b(terah|tera|thirteen)\b/gi, replacement: '13' },
    { regex: /\b(barah|baarah|twelve)\b/gi, replacement: '12' },
    { regex: /\b(gyarah|gyara|eleven)\b/gi, replacement: '11' },
    { regex: /\b(das|dus|ten)\b/gi, replacement: '10' },
    { regex: /\b(nau|no|nine)\b/gi, replacement: '9' },
    { regex: /\b(aath|ath|eight)\b/gi, replacement: '8' },
    { regex: /\b(saat|sat|seven)\b/gi, replacement: '7' },
    { regex: /\b(chhah|che|chhe|six)\b/gi, replacement: '6' },
    { regex: /\b(paanch|panch|five)\b/gi, replacement: '5' },
    { regex: /\b(chaar|char|four)\b/gi, replacement: '4' },
    { regex: /\b(teen|tin|three)\b/gi, replacement: '3' },
    { regex: /\b(do|too|two)\b/gi, replacement: '2' },
    { regex: /\b(ek|ik|one)\b/gi, replacement: '1' },
  ];

  for (const item of numberMap) {
    clean = clean.replace(item.regex, item.replacement);
  }

  // 6. Restore verbal 'do' phrases
  for (const v of verbDoMap) {
    clean = clean.replace(v.placeholder, v.original);
  }

  // 7. Filter background chatter, filler artifacts, and conversation triggers
  clean = clean
    .replace(/\b(umm+|ahh+|uhh+|hmmm+|hmm|arre\s+yaar|arre|suno|sun|chotu\s+sun|chotu|kripya|please)\b/gi, '')
    .replace(/\b(understand|understood|samjhe|samajh\s*gaye|samjh\s*gaye|samjha|samjh)\b/gi, '')
    .replace(/\[(?:noise|music|laughter|applause|cough|throat-clearing)\]/gi, '');

  // 8. Normalize spacing
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
