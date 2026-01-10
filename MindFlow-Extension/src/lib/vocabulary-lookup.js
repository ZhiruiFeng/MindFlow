/**
 * @fileoverview Vocabulary lookup service using OpenAI API
 * @module vocabulary-lookup
 *
 * Provides AI-powered word explanations for vocabulary learning.
 */

import storageManager from './storage-manager.js';
import { log, logError } from '../common/utils.js';
import { API_ENDPOINTS, ERROR_MESSAGES } from '../common/constants.js';

/**
 * Vocabulary Lookup Service
 */
export class VocabularyLookupService {
  constructor() {
    this.endpoint = API_ENDPOINTS.OPENAI_CHAT;
  }

  /**
   * Look up a word and get AI explanation
   * @param {string} word - Word to look up
   * @param {string} context - Optional context
   * @returns {Promise<Object>} Word explanation
   */
  async lookupWord(word, context = null) {
    const apiKey = await storageManager.getAPIKey('openai');

    if (!apiKey) {
      throw new Error(ERROR_MESSAGES.NO_API_KEY);
    }

    const trimmedWord = word.trim().toLowerCase();
    if (!trimmedWord) {
      throw new Error('Word cannot be empty');
    }

    log('Looking up word:', trimmedWord);

    const systemPrompt = this.buildSystemPrompt();
    const userPrompt = this.buildUserPrompt(trimmedWord, context);

    const response = await this.callOpenAI(apiKey, systemPrompt, userPrompt);
    const explanation = this.parseResponse(response, trimmedWord);

    log('Word lookup complete:', trimmedWord);
    return explanation;
  }

  /**
   * Build system prompt
   */
  buildSystemPrompt() {
    return `You are a vocabulary assistant helping a Chinese speaker learn English.
Provide comprehensive word explanations optimized for second-language learners.
Focus on practical usage, memorable examples, and Chinese-specific learning tips.
Return ONLY valid JSON without markdown code blocks or any other text.`;
  }

  /**
   * Build user prompt
   */
  buildUserPrompt(word, context) {
    let prompt = `Explain the English word: "${word}"`;

    if (context) {
      prompt += `\nContext where it was used: "${context}"`;
    }

    prompt += `

Return JSON with this exact structure:
{
  "word": "${word}",
  "phonetic": "IPA pronunciation",
  "partOfSpeech": "noun/verb/adjective/etc",
  "definitionEN": "clear English definition",
  "definitionCN": "中文释义",
  "exampleSentences": [
    {"en": "Example in English.", "cn": "中文翻译。"}
  ],
  "synonyms": ["word1", "word2"],
  "antonyms": ["word1", "word2"],
  "wordFamily": "related word forms",
  "usageNotes": "context and common collocations",
  "etymology": "brief word origin",
  "memoryTips": "mnemonic for Chinese speakers"
}`;

    return prompt;
  }

  /**
   * Call OpenAI API
   */
  async callOpenAI(apiKey, systemPrompt, userPrompt) {
    const settings = await storageManager.getSettings();
    const model = settings.llmModel || 'gpt-4o-mini';

    const response = await fetch(this.endpoint, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: model,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        temperature: 0.3,
        max_tokens: 1200
      })
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`API error ${response.status}: ${error}`);
    }

    const data = await response.json();

    if (!data.choices?.[0]?.message?.content) {
      throw new Error('Empty response from API');
    }

    return data.choices[0].message.content.trim();
  }

  /**
   * Parse API response into word explanation
   */
  parseResponse(response, word) {
    // Clean up response (remove markdown code blocks if present)
    let cleaned = response;
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.slice(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.slice(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.slice(0, -3);
    }
    cleaned = cleaned.trim();

    try {
      const explanation = JSON.parse(cleaned);
      return {
        word: explanation.word || word,
        phonetic: explanation.phonetic || null,
        partOfSpeech: explanation.partOfSpeech || null,
        definitionEN: explanation.definitionEN || null,
        definitionCN: explanation.definitionCN || null,
        exampleSentences: explanation.exampleSentences || [],
        synonyms: explanation.synonyms || [],
        antonyms: explanation.antonyms || [],
        wordFamily: explanation.wordFamily || null,
        usageNotes: explanation.usageNotes || null,
        etymology: explanation.etymology || null,
        memoryTips: explanation.memoryTips || null
      };
    } catch (error) {
      logError('Failed to parse word explanation:', error);
      // Return minimal explanation
      return {
        word: word,
        phonetic: null,
        partOfSpeech: null,
        definitionEN: cleaned,
        definitionCN: null,
        exampleSentences: [],
        synonyms: [],
        antonyms: [],
        wordFamily: null,
        usageNotes: null,
        etymology: null,
        memoryTips: null
      };
    }
  }
}

// Export singleton
export default new VocabularyLookupService();
