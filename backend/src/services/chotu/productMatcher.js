/**
 * 5-Tier Intelligent Product Matcher for Restaurant POS
 * Priority:
 * 1. Exact Product Name (Case-insensitive)
 * 2. Product Alias System (product.aliases array)
 * 3. Normalized Name (romanized transliteration, punctuation, foodType)
 * 4. Fuzzy Levenshtein Distance & Token Jaccard Similarity
 * 5. Ambiguity Detection (Multiple matches -> Ask clarification, never randomly select)
 */

class ProductMatcher {
  /**
   * Compute normalized similarity string
   */
  static cleanString(str) {
    if (!str || typeof str !== 'string') return '';
    return str
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * Calculate Levenshtein edit distance between two strings
   */
  static levenshteinDistance(a, b) {
    const matrix = [];
    for (let i = 0; i <= b.length; i++) matrix[i] = [i];
    for (let j = 0; j <= a.length; j++) matrix[0][j] = j;

    for (let i = 1; i <= b.length; i++) {
      for (let j = 1; j <= a.length; j++) {
        if (b.charAt(i - 1) === a.charAt(j - 1)) {
          matrix[i][j] = matrix[i - 1][j - 1];
        } else {
          matrix[i][j] = Math.min(
            matrix[i - 1][j - 1] + 1, // substitution
            matrix[i][j - 1] + 1,     // insertion
            matrix[i - 1][j] + 1      // deletion
          );
        }
      }
    }
    return matrix[b.length][a.length];
  }

  /**
   * Compute token-based Jaccard similarity score (0.0 to 1.0)
   */
  static tokenSimilarity(query, target) {
    const qTokens = new Set(this.cleanString(query).split(' ').filter(Boolean));
    const tTokens = new Set(this.cleanString(target).split(' ').filter(Boolean));
    if (qTokens.size === 0 || tTokens.size === 0) return 0;

    let intersection = 0;
    for (const token of qTokens) {
      if (tTokens.has(token)) {
        intersection++;
      } else {
        // Partial substring match on token
        for (const t of tTokens) {
          if (t.includes(token) || token.includes(t)) {
            intersection += 0.8;
            break;
          }
        }
      }
    }
    const union = new Set([...qTokens, ...tTokens]).size;
    return intersection / union;
  }

  /**
   * Match a spoken item name against available products
   * @param {string} spokenName
   * @param {Array<Object>} products - Available product documents
   * @returns {{ match: Object|null, confidence: number, tier: string, ambiguousMatches?: Array<Object>, question?: string }}
   */
  static matchProduct(spokenName, products) {
    if (!spokenName || !Array.isArray(products) || products.length === 0) {
      return { match: null, confidence: 0, tier: 'none' };
    }

    const cleanSpoken = this.cleanString(spokenName);
    if (!cleanSpoken) return { match: null, confidence: 0, tier: 'none' };

    // --- TIER 1: EXACT MATCH ---
    const exactMatches = [];
    for (const p of products) {
      const pName = this.cleanString(p.name);
      if (pName === cleanSpoken) {
        exactMatches.push(p);
      }
    }
    if (exactMatches.length === 1) {
      return {
        match: exactMatches[0],
        confidence: 1.0,
        tier: 'exact',
      };
    } else if (exactMatches.length > 1) {
      const options = exactMatches.map((p) => p.name).join(' ya ');
      return {
        match: null,
        confidence: 0.70,
        tier: 'ambiguous',
        ambiguousMatches: exactMatches,
        question: `${options}? Kaunsa add karna hai?`,
      };
    }

    // --- TIER 2: ALIAS MATCH ---
    const aliasMatches = [];
    for (const p of products) {
      if (Array.isArray(p.aliases)) {
        for (const alias of p.aliases) {
          const cleanAlias = this.cleanString(alias);
          if (cleanAlias === cleanSpoken) {
            const pId = String(p.id || p._id);
            if (!aliasMatches.some((item) => String(item.id || item._id) === pId)) {
              aliasMatches.push(p);
            }
            break;
          }
        }
      }
    }

    if (aliasMatches.length === 1) {
      return {
        match: aliasMatches[0],
        confidence: 0.98,
        tier: 'alias_exact',
      };
    } else if (aliasMatches.length > 1) {
      const options = aliasMatches.map((p) => p.name).join(' ya ');
      return {
        match: null,
        confidence: 0.70,
        tier: 'ambiguous',
        ambiguousMatches: aliasMatches,
        question: `${options}? Kaunsa add karna hai?`,
      };
    }

    // --- TIER 3: CONTAINS / SUBSTRING MATCH & AMBIGUITY CHECK ---
    const substringMatches = [];
    for (const p of products) {
      const pName = this.cleanString(p.name);
      const isMatch = pName.includes(cleanSpoken) || cleanSpoken.includes(pName);
      let aliasMatch = false;

      if (!isMatch && Array.isArray(p.aliases)) {
        aliasMatch = p.aliases.some((a) => {
          const ca = this.cleanString(a);
          return ca.includes(cleanSpoken) || cleanSpoken.includes(ca);
        });
      }

      if (isMatch || aliasMatch) {
        substringMatches.push(p);
      }
    }

    if (substringMatches.length === 1) {
      return {
        match: substringMatches[0],
        confidence: 0.92,
        tier: 'substring',
      };
    } else if (substringMatches.length > 1) {
      // Ambiguity Detected! (e.g., spoken "coke" when "Coke 300ml" and "Coke 750ml" exist)
      const options = substringMatches.map((p) => p.name).join(' ya ');
      return {
        match: null,
        confidence: 0.70,
        tier: 'ambiguous',
        ambiguousMatches: substringMatches,
        question: `${options}? Kaunsa add karna hai?`,
      };
    }

    // --- TIER 4: FUZZY SIMILARITY (Levenshtein & Jaccard) ---
    let bestMatch = null;
    let bestScore = 0;
    const scoredList = [];

    for (const p of products) {
      const pName = this.cleanString(p.name);
      const jaccard = this.tokenSimilarity(cleanSpoken, pName);

      // Levenshtein normalized (0 to 1)
      const maxLen = Math.max(cleanSpoken.length, pName.length);
      const levDist = this.levenshteinDistance(cleanSpoken, pName);
      const levScore = maxLen > 0 ? 1 - levDist / maxLen : 0;

      // Combined score favoring token overlap
      let combined = (jaccard * 0.6) + (levScore * 0.4);

      // Also check fuzzy score on aliases
      if (Array.isArray(p.aliases)) {
        for (const a of p.aliases) {
          const aName = this.cleanString(a);
          const aJaccard = this.tokenSimilarity(cleanSpoken, aName);
          const aLevDist = this.levenshteinDistance(cleanSpoken, aName);
          const aLevScore = Math.max(cleanSpoken.length, aName.length) > 0 ? 1 - aLevDist / Math.max(cleanSpoken.length, aName.length) : 0;
          const aCombined = (aJaccard * 0.6) + (aLevScore * 0.4);
          if (aCombined > combined) combined = aCombined;
        }
      }

      scoredList.push({ product: p, score: combined });

      if (combined > bestScore) {
        bestScore = combined;
        bestMatch = p;
      }
    }

    // Check if multiple fuzzy matches have almost identical high scores (Ambiguity)
    const topCandidates = scoredList.filter((s) => s.score >= 0.70 && s.score >= bestScore - 0.05);
    if (topCandidates.length > 1) {
      const options = topCandidates.map((c) => c.product.name).join(' ya ');
      return {
        match: null,
        confidence: 0.65,
        tier: 'ambiguous',
        ambiguousMatches: topCandidates.map((c) => c.product),
        question: `${options}? Kaunsa add karna hai?`,
      };
    }

    // Threshold check for fuzzy match
    if (bestScore >= 0.65 && bestMatch) {
      return {
        match: bestMatch,
        confidence: parseFloat(bestScore.toFixed(2)),
        tier: 'fuzzy',
      };
    }

    return {
      match: null,
      confidence: 0.2,
      tier: 'not_found',
      message: 'Ye item menu mein nahi mila.',
    };
  }
}

module.exports = ProductMatcher;
