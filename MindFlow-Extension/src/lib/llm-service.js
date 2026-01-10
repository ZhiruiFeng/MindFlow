/**
 * @fileoverview LLM service for text optimization
 * @module llm-service
 *
 * Uses OpenAI GPT models to optimize transcribed text by:
 * - Removing filler words
 * - Fixing grammar
 * - Improving sentence structure
 * - Adjusting tone based on settings
 *
 * @example
 * const llm = new LLMService();
 * const optimized = await llm.optimizeText('Um, so like, I think...');
 */

import {
  API_ENDPOINTS,
  LLM_MODELS,
  OPTIMIZATION_LEVELS,
  OUTPUT_STYLES,
  SYSTEM_PROMPTS,
  ERROR_MESSAGES
} from '../common/constants.js';
import { APIError, ConfigurationError, ValidationError } from '../common/errors.js';
import { log, logError, truncateText } from '../common/utils.js';
import storageManager from './storage-manager.js';

export class LLMService {
  constructor() {
    this.apiKey = null;
    this.model = LLM_MODELS.GPT_4O_MINI;
    this.optimizationLevel = OPTIMIZATION_LEVELS.MEDIUM;
    this.outputStyle = OUTPUT_STYLES.CASUAL;
  }

  /**
   * Initialize service with settings
   * @returns {Promise<void>}
   */
  async initialize() {
    const settings = await storageManager.getSettings();

    this.model = settings.llmModel || LLM_MODELS.GPT_4O_MINI;
    this.optimizationLevel = settings.optimizationLevel || OPTIMIZATION_LEVELS.MEDIUM;
    this.outputStyle = settings.outputStyle || OUTPUT_STYLES.CASUAL;
    this.showTeacherNotes = settings.showTeacherNotes || false;

    // Get OpenAI API key (LLM always uses OpenAI)
    this.apiKey = await storageManager.getAPIKey('openai');

    if (!this.apiKey) {
      throw new ConfigurationError(ERROR_MESSAGES.NO_API_KEY);
    }

    log('LLMService initialized:', {
      model: this.model,
      level: this.optimizationLevel,
      style: this.outputStyle,
      teacherNotes: this.showTeacherNotes
    });
  }

  /**
   * Optimize text using LLM
   * @param {string} text - Text to optimize
   * @param {Object} options - Optimization options
   * @param {string} options.level - Optimization level override
   * @param {string} options.style - Output style override
   * @param {boolean} options.includeTeacherNotes - Whether to include teacher notes
   * @returns {Promise<string|Object>} Optimized text or {refinedText, teacherNotes}
   * @throws {APIError} If optimization fails
   */
  async optimizeText(text, options = {}) {
    if (!text || typeof text !== 'string') {
      throw new ValidationError('Invalid text input');
    }

    if (text.trim().length === 0) {
      return text;
    }

    // Ensure initialized
    if (!this.apiKey) {
      await this.initialize();
    }

    // Use provided options or defaults
    const level = options.level || this.optimizationLevel;
    const style = options.style || this.outputStyle;
    const includeTeacherNotes = options.includeTeacherNotes !== undefined
      ? options.includeTeacherNotes
      : this.showTeacherNotes;

    log(`Optimizing text (${level}, ${style}, teacherNotes: ${includeTeacherNotes})...`);

    try {
      const systemPrompt = this.buildSystemPrompt(level, style, includeTeacherNotes);
      const result = await this.callChatAPI(text, systemPrompt);

      log('Optimization completed');

      // Parse result if teacher notes are included
      if (includeTeacherNotes) {
        return this.parseOptimizationResult(result);
      }

      return result;
    } catch (error) {
      logError('Optimization failed:', error);

      if (error instanceof APIError) {
        throw error;
      }

      throw new APIError(
        ERROR_MESSAGES.OPTIMIZATION_FAILED,
        error.status || 500,
        'openai'
      );
    }
  }

  /**
   * Build system prompt based on level, style, and teacher notes option
   * @private
   */
  buildSystemPrompt(level, style, includeTeacherNotes = false) {
    let basePrompt = SYSTEM_PROMPTS[level] || SYSTEM_PROMPTS.medium;

    // Add style modifier
    if (style === OUTPUT_STYLES.FORMAL) {
      basePrompt += '\n\nUse a formal, professional tone suitable for business communication.';
    } else {
      basePrompt += '\n\nMaintain a casual, conversational tone that sounds natural.';
    }

    // Add teacher notes and vocabulary suggestions instructions if needed
    if (includeTeacherNotes) {
      basePrompt += `

Your task:
1. First, optimize the user's text following the guidelines above
2. Then, provide specific teaching guidance like a teacher giving improvement feedback
3. Finally, suggest vocabulary words worth learning from this transcription

Output format (use exactly this structure):
REFINED_TEXT:
[Your optimized version here]

TEACHER_NOTE:
Score: [X/10]

Key improvements (max 3 points):
• [Specific point with before/after example or vocabulary suggestion]
• [Specific point with before/after example or vocabulary suggestion]
• [Specific point with before/after example or vocabulary suggestion]

VOCABULARY_SUGGESTIONS:
[JSON array of 0-3 vocabulary suggestions]

Teaching guidelines for TEACHER_NOTE:
- Give specific, actionable feedback with examples (e.g., "Instead of 'very good', use 'excellent' or 'outstanding' for stronger impact")
- Show which vocabulary or sentence structure would better express the intended meaning
- Limit to maximum 3 most important improvement points
- Provide a score out of 10 for the original text
- DO NOT give generic comments like "removed filler words" or "improved expression"
- Focus on WHY a specific word or structure is better for the meaning

Vocabulary suggestion guidelines:
- Select 0-3 words from the REFINED text that would benefit English language learners
- Prioritize: uncommon but useful words, nuanced vocabulary, commonly confused words, eloquent alternatives
- Exclude: top 1000 most common English words, proper nouns (names/places), slang
- For each word, provide a JSON object with these fields:
  - word: the vocabulary word
  - partOfSpeech: noun/verb/adjective/adverb/phrase
  - definition: brief definition (1-2 sentences)
  - reason: why this word is worth learning (max 50 words)
  - sourceSentence: the exact sentence from the refined text where this word appears
- Output as a valid JSON array, or empty array [] if no good vocabulary candidates
- Example: [{"word": "eloquent", "partOfSpeech": "adjective", "definition": "fluent or persuasive in speaking or writing", "reason": "More expressive than 'well-spoken'", "sourceSentence": "She gave an eloquent presentation."}]`;
    }

    return basePrompt;
  }

  /**
   * Parse optimization result with teacher notes and vocabulary suggestions
   * @private
   */
  parseOptimizationResult(response) {
    const trimmed = response.trim();

    // Look for the markers
    const refinedMatch = trimmed.indexOf('REFINED_TEXT:');
    const teacherMatch = trimmed.indexOf('TEACHER_NOTE:');
    const vocabMatch = trimmed.indexOf('VOCABULARY_SUGGESTIONS:');

    if (refinedMatch === -1 || teacherMatch === -1) {
      // If markers not found, return whole response as refined text
      log('Could not find markers in response, using fallback parsing');
      return {
        refinedText: trimmed,
        teacherNotes: 'No explanation provided',
        vocabularySuggestions: []
      };
    }

    // Extract refined text (between REFINED_TEXT: and TEACHER_NOTE:)
    const refinedStart = refinedMatch + 'REFINED_TEXT:'.length;
    const refinedText = trimmed.substring(refinedStart, teacherMatch).trim();

    // Extract teacher note (between TEACHER_NOTE: and VOCABULARY_SUGGESTIONS: if present)
    const teacherStart = teacherMatch + 'TEACHER_NOTE:'.length;
    const teacherEnd = vocabMatch !== -1 ? vocabMatch : trimmed.length;
    const teacherNotes = trimmed.substring(teacherStart, teacherEnd).trim();

    // Parse vocabulary suggestions
    const vocabularySuggestions = this.parseVocabularySuggestions(trimmed, vocabMatch);

    return {
      refinedText,
      teacherNotes,
      vocabularySuggestions
    };
  }

  /**
   * Parse vocabulary suggestions JSON from the LLM response
   * @private
   * @param {string} response - The full LLM response
   * @param {number} vocabMatch - Index of VOCABULARY_SUGGESTIONS marker, or -1 if not found
   * @returns {Array} Array of vocabulary suggestions (empty if parsing fails)
   */
  parseVocabularySuggestions(response, vocabMatch) {
    if (vocabMatch === -1) {
      log('No VOCABULARY_SUGGESTIONS marker found in response');
      return [];
    }

    try {
      // Extract everything after VOCABULARY_SUGGESTIONS:
      const vocabStart = vocabMatch + 'VOCABULARY_SUGGESTIONS:'.length;
      let vocabJSON = response.substring(vocabStart).trim();

      // Clean up the response - remove markdown code blocks if present
      if (vocabJSON.startsWith('```json')) {
        vocabJSON = vocabJSON.substring(7);
      } else if (vocabJSON.startsWith('```')) {
        vocabJSON = vocabJSON.substring(3);
      }
      if (vocabJSON.endsWith('```')) {
        vocabJSON = vocabJSON.substring(0, vocabJSON.length - 3);
      }
      vocabJSON = vocabJSON.trim();

      // Find the JSON array boundaries
      const arrayStart = vocabJSON.indexOf('[');
      const arrayEnd = vocabJSON.lastIndexOf(']');

      if (arrayStart === -1 || arrayEnd === -1) {
        log('Could not find JSON array in vocabulary suggestions');
        return [];
      }

      const jsonString = vocabJSON.substring(arrayStart, arrayEnd + 1);
      const suggestions = JSON.parse(jsonString);

      // Validate and filter suggestions
      const validSuggestions = suggestions.filter(s =>
        s.word && s.partOfSpeech && s.definition && s.reason && s.sourceSentence
      ).map(s => ({
        ...s,
        isAlreadySaved: false,
        isAdding: false,
        wasJustAdded: false
      }));

      log(`Parsed ${validSuggestions.length} vocabulary suggestions`);
      return validSuggestions;
    } catch (error) {
      log('Failed to parse vocabulary suggestions:', error.message);
      return [];
    }
  }

  /**
   * Call OpenAI Chat Completions API
   * @private
   */
  async callChatAPI(userMessage, systemPrompt) {
    const requestBody = {
      model: this.model,
      messages: [
        {
          role: 'system',
          content: systemPrompt
        },
        {
          role: 'user',
          content: userMessage
        }
      ],
      temperature: 0.3,
      max_tokens: 2000  // Increased for vocabulary suggestions
    };

    const response = await fetch(API_ENDPOINTS.OPENAI_CHAT, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(requestBody)
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      const errorMessage = errorData.error?.message || response.statusText;

      logError('OpenAI Chat API error:', response.status, errorMessage);

      if (response.status === 401) {
        throw new APIError(ERROR_MESSAGES.INVALID_API_KEY, 401, 'openai');
      } else if (response.status === 429) {
        throw new APIError(ERROR_MESSAGES.RATE_LIMIT, 429, 'openai');
      } else if (response.status === 400) {
        throw new APIError('Invalid request. Text may be too long.', 400, 'openai');
      }

      throw new APIError(errorMessage, response.status, 'openai');
    }

    const data = await response.json();

    if (!data.choices || data.choices.length === 0) {
      throw new Error('No response from API');
    }

    const optimizedText = data.choices[0].message.content.trim();

    return optimizedText;
  }

  /**
   * Validate API key by making a test request
   * @param {string} apiKey - API key to validate
   * @returns {Promise<boolean>} True if valid
   */
  async validateAPIKey(apiKey) {
    const originalKey = this.apiKey;

    try {
      this.apiKey = apiKey;

      // Make a minimal test request
      const testPrompt = 'Say "OK" if you can read this.';
      const result = await this.callChatAPI(testPrompt, 'You are a test assistant.');

      return result.length > 0;
    } catch (error) {
      if (error instanceof APIError && error.status === 401) {
        return false;
      }
      // Other errors might indicate the key is valid but there's another issue
      return true;
    } finally {
      this.apiKey = originalKey;
    }
  }

  /**
   * Get optimization preview (first 100 chars)
   * Useful for showing progress
   * @param {string} text - Text to optimize
   * @returns {Promise<string>} Preview of optimized text
   */
  async getOptimizationPreview(text) {
    const preview = truncateText(text, 100);
    return await this.optimizeText(preview);
  }

  /**
   * Batch optimize multiple texts
   * @param {string[]} texts - Array of texts to optimize
   * @param {Object} options - Optimization options
   * @returns {Promise<string[]>} Array of optimized texts
   */
  async batchOptimize(texts, options = {}) {
    if (!Array.isArray(texts)) {
      throw new ValidationError('Input must be an array of texts');
    }

    // Ensure initialized
    if (!this.apiKey) {
      await this.initialize();
    }

    const results = await Promise.all(
      texts.map(text => this.optimizeText(text, options))
    );

    return results;
  }

  /**
   * Set optimization level
   * @param {string} level - Optimization level
   */
  setOptimizationLevel(level) {
    if (!Object.values(OPTIMIZATION_LEVELS).includes(level)) {
      throw new ValidationError(`Invalid optimization level: ${level}`);
    }
    this.optimizationLevel = level;
    log('Optimization level set to:', level);
  }

  /**
   * Set output style
   * @param {string} style - Output style
   */
  setOutputStyle(style) {
    if (!Object.values(OUTPUT_STYLES).includes(style)) {
      throw new ValidationError(`Invalid output style: ${style}`);
    }
    this.outputStyle = style;
    log('Output style set to:', style);
  }

  /**
   * Set model
   * @param {string} model - Model name
   */
  setModel(model) {
    if (!Object.values(LLM_MODELS).includes(model)) {
      throw new ValidationError(`Invalid model: ${model}`);
    }
    this.model = model;
    log('Model set to:', model);
  }

  /**
   * Get current settings
   * @returns {Object} Current LLM settings
   */
  getSettings() {
    return {
      model: this.model,
      optimizationLevel: this.optimizationLevel,
      outputStyle: this.outputStyle
    };
  }

  /**
   * Estimate token count (rough approximation)
   * @param {string} text - Text to estimate
   * @returns {number} Estimated token count
   */
  estimateTokens(text) {
    // Rough estimate: 1 token ≈ 4 characters
    return Math.ceil(text.length / 4);
  }

  /**
   * Estimate API cost for optimization
   * @param {string} text - Text to optimize
   * @returns {number} Estimated cost in USD
   */
  estimateCost(text) {
    const inputTokens = this.estimateTokens(text);
    const systemPromptTokens = 100; // Approximate
    const outputTokens = inputTokens * 1.2; // Assume output is slightly longer

    // GPT-4o-mini pricing (as of 2024)
    const inputCostPerToken = 0.00000015; // $0.150 / 1M tokens
    const outputCostPerToken = 0.0000006; // $0.600 / 1M tokens

    const inputCost = (inputTokens + systemPromptTokens) * inputCostPerToken;
    const outputCost = outputTokens * outputCostPerToken;

    return inputCost + outputCost;
  }
}

// Export singleton instance
export default new LLMService();
