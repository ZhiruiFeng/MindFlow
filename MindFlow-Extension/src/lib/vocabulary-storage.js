/**
 * @fileoverview Vocabulary storage manager for Chrome Extension
 * @module vocabulary-storage
 *
 * Manages vocabulary entries using Chrome Storage API.
 * Supports CRUD operations, search, and sync status tracking.
 */

import { log, logError } from '../common/utils.js';

// Storage keys for vocabulary data
const VOCABULARY_KEYS = {
  ENTRIES: 'vocabulary_entries',
  REVIEW_SESSIONS: 'vocabulary_review_sessions',
  LEARNING_STATS: 'vocabulary_learning_stats',
  SETTINGS: 'vocabulary_settings'
};

// Default vocabulary settings
const DEFAULT_VOCABULARY_SETTINGS = {
  dailyNewWordsGoal: 5,
  dailyReviewGoal: 15,
  enableReminders: true,
  reminderHour: 9,
  defaultCategory: '',
  syncEnabled: false
};

/**
 * Vocabulary Storage Manager
 */
export class VocabularyStorage {
  constructor() {
    this.storage = chrome.storage.local;
  }

  // MARK: - Vocabulary Entry CRUD

  /**
   * Add a new vocabulary entry
   * @param {Object} entry - Vocabulary entry data
   * @returns {Promise<Object>} Created entry with ID
   */
  async addWord(entry) {
    const entries = await this.getAllWords();

    // Check for duplicates
    const normalizedWord = entry.word.toLowerCase().trim();
    if (entries.some(e => e.word.toLowerCase() === normalizedWord)) {
      throw new Error(`Word "${entry.word}" already exists in vocabulary`);
    }

    const newEntry = {
      id: this.generateId(),
      createdAt: Date.now(),
      updatedAt: Date.now(),
      syncStatus: 'pending',
      backendId: null,

      // Word information
      word: normalizedWord,
      phonetic: entry.phonetic || null,
      partOfSpeech: entry.partOfSpeech || null,
      definitionEN: entry.definitionEN || null,
      definitionCN: entry.definitionCN || null,
      exampleSentences: entry.exampleSentences || [],
      synonyms: entry.synonyms || [],
      antonyms: entry.antonyms || [],
      wordFamily: entry.wordFamily || null,
      usageNotes: entry.usageNotes || null,
      etymology: entry.etymology || null,
      memoryTips: entry.memoryTips || null,

      // Context & organization
      userContext: entry.userContext || null,
      sourceUrl: entry.sourceUrl || null,
      tags: entry.tags || [],
      category: entry.category || '',
      isFavorite: false,
      isArchived: false,

      // Spaced repetition
      masteryLevel: 0,
      reviewCount: 0,
      correctCount: 0,
      lastReviewedAt: null,
      nextReviewAt: Date.now(), // Due immediately
      easeFactor: 2.5,
      interval: 0
    };

    entries.push(newEntry);
    await this.saveEntries(entries);

    // Update daily stats
    await this.incrementWordsAdded();

    log('Word added:', newEntry.word);
    return newEntry;
  }

  /**
   * Get all vocabulary entries
   * @param {boolean} includeArchived - Include archived entries
   * @returns {Promise<Array>} Array of entries
   */
  async getAllWords(includeArchived = false) {
    try {
      const result = await this.storage.get(VOCABULARY_KEYS.ENTRIES);
      let entries = result[VOCABULARY_KEYS.ENTRIES] || [];

      if (!includeArchived) {
        entries = entries.filter(e => !e.isArchived);
      }

      return entries;
    } catch (error) {
      logError('Failed to get vocabulary entries:', error);
      return [];
    }
  }

  /**
   * Get entry by ID
   * @param {string} id - Entry ID
   * @returns {Promise<Object|null>} Entry or null
   */
  async getWordById(id) {
    const entries = await this.getAllWords(true);
    return entries.find(e => e.id === id) || null;
  }

  /**
   * Get entry by word text
   * @param {string} word - Word to find
   * @returns {Promise<Object|null>} Entry or null
   */
  async getWordByText(word) {
    const entries = await this.getAllWords(true);
    const normalizedWord = word.toLowerCase().trim();
    return entries.find(e => e.word.toLowerCase() === normalizedWord) || null;
  }

  /**
   * Check if word exists
   * @param {string} word - Word to check
   * @returns {Promise<boolean>}
   */
  async wordExists(word) {
    const entry = await this.getWordByText(word);
    return entry !== null;
  }

  /**
   * Update vocabulary entry
   * @param {string} id - Entry ID
   * @param {Object} updates - Fields to update
   * @returns {Promise<Object>} Updated entry
   */
  async updateWord(id, updates) {
    const entries = await this.getAllWords(true);
    const index = entries.findIndex(e => e.id === id);

    if (index === -1) {
      throw new Error(`Entry not found: ${id}`);
    }

    entries[index] = {
      ...entries[index],
      ...updates,
      updatedAt: Date.now(),
      syncStatus: 'pending'
    };

    await this.saveEntries(entries);
    log('Word updated:', entries[index].word);

    return entries[index];
  }

  /**
   * Delete vocabulary entry
   * @param {string} id - Entry ID
   */
  async deleteWord(id) {
    const entries = await this.getAllWords(true);
    const filtered = entries.filter(e => e.id !== id);
    await this.saveEntries(filtered);
    log('Word deleted:', id);
  }

  /**
   * Archive entry (soft delete)
   * @param {string} id - Entry ID
   */
  async archiveWord(id) {
    await this.updateWord(id, { isArchived: true });
  }

  /**
   * Toggle favorite status
   * @param {string} id - Entry ID
   * @returns {Promise<boolean>} New favorite status
   */
  async toggleFavorite(id) {
    const entry = await this.getWordById(id);
    if (!entry) throw new Error(`Entry not found: ${id}`);

    await this.updateWord(id, { isFavorite: !entry.isFavorite });
    return !entry.isFavorite;
  }

  // MARK: - Search & Filter

  /**
   * Search words
   * @param {string} query - Search query
   * @returns {Promise<Array>} Matching entries
   */
  async searchWords(query) {
    const entries = await this.getAllWords();
    const normalizedQuery = query.toLowerCase().trim();

    if (!normalizedQuery) return entries;

    return entries.filter(e =>
      e.word.toLowerCase().includes(normalizedQuery) ||
      (e.definitionEN && e.definitionEN.toLowerCase().includes(normalizedQuery)) ||
      (e.definitionCN && e.definitionCN.includes(normalizedQuery)) ||
      e.tags.some(t => t.toLowerCase().includes(normalizedQuery))
    );
  }

  /**
   * Get words by category
   * @param {string} category - Category name
   * @returns {Promise<Array>}
   */
  async getWordsByCategory(category) {
    const entries = await this.getAllWords();
    return entries.filter(e => e.category === category);
  }

  /**
   * Get words by mastery level
   * @param {number} level - Mastery level (0-4)
   * @returns {Promise<Array>}
   */
  async getWordsByMasteryLevel(level) {
    const entries = await this.getAllWords();
    return entries.filter(e => e.masteryLevel === level);
  }

  /**
   * Get favorite words
   * @returns {Promise<Array>}
   */
  async getFavorites() {
    const entries = await this.getAllWords();
    return entries.filter(e => e.isFavorite);
  }

  /**
   * Get words due for review
   * @param {number} limit - Optional limit
   * @returns {Promise<Array>}
   */
  async getWordsDueForReview(limit = null) {
    const entries = await this.getAllWords();
    const now = Date.now();

    let dueWords = entries.filter(e =>
      !e.isArchived && (e.nextReviewAt === null || e.nextReviewAt <= now)
    );

    // Sort by next review date and mastery level
    dueWords.sort((a, b) => {
      const dateA = a.nextReviewAt || 0;
      const dateB = b.nextReviewAt || 0;
      if (dateA === dateB) {
        return a.masteryLevel - b.masteryLevel;
      }
      return dateA - dateB;
    });

    if (limit) {
      dueWords = dueWords.slice(0, limit);
    }

    return dueWords;
  }

  /**
   * Get all unique categories
   * @returns {Promise<Array<string>>}
   */
  async getAllCategories() {
    const entries = await this.getAllWords();
    const categories = [...new Set(entries.map(e => e.category).filter(c => c))];
    return categories.sort();
  }

  // MARK: - Statistics

  /**
   * Get word count
   * @returns {Promise<number>}
   */
  async getWordCount() {
    const entries = await this.getAllWords();
    return entries.length;
  }

  /**
   * Get count of words due for review
   * @returns {Promise<number>}
   */
  async getDueForReviewCount() {
    const dueWords = await this.getWordsDueForReview();
    return dueWords.length;
  }

  /**
   * Get mastery level counts
   * @returns {Promise<Object>}
   */
  async getMasteryLevelCounts() {
    const entries = await this.getAllWords();
    const counts = { 0: 0, 1: 0, 2: 0, 3: 0, 4: 0 };

    entries.forEach(e => {
      counts[e.masteryLevel] = (counts[e.masteryLevel] || 0) + 1;
    });

    return counts;
  }

  // MARK: - Learning Stats

  /**
   * Get or create today's stats
   * @returns {Promise<Object>}
   */
  async getOrCreateTodayStats() {
    const stats = await this.getLearningStats();
    const today = this.getDateKey(new Date());

    if (!stats[today]) {
      stats[today] = {
        date: today,
        wordsAdded: 0,
        wordsReviewed: 0,
        correctReviews: 0,
        incorrectReviews: 0,
        studyTimeSeconds: 0
      };
      await this.saveLearningStats(stats);
    }

    return stats[today];
  }

  /**
   * Increment words added today
   */
  async incrementWordsAdded() {
    const stats = await this.getLearningStats();
    const today = this.getDateKey(new Date());

    if (!stats[today]) {
      await this.getOrCreateTodayStats();
    }

    stats[today].wordsAdded++;
    await this.saveLearningStats(stats);
  }

  /**
   * Record a review
   * @param {boolean} correct - Whether the review was correct
   */
  async recordReview(correct) {
    const stats = await this.getLearningStats();
    const today = this.getDateKey(new Date());

    if (!stats[today]) {
      await this.getOrCreateTodayStats();
    }

    stats[today].wordsReviewed++;
    if (correct) {
      stats[today].correctReviews++;
    } else {
      stats[today].incorrectReviews++;
    }

    await this.saveLearningStats(stats);
  }

  /**
   * Add study time
   * @param {number} seconds - Seconds to add
   */
  async addStudyTime(seconds) {
    const stats = await this.getLearningStats();
    const today = this.getDateKey(new Date());

    if (!stats[today]) {
      await this.getOrCreateTodayStats();
    }

    stats[today].studyTimeSeconds += seconds;
    await this.saveLearningStats(stats);
  }

  /**
   * Calculate current streak
   * @returns {Promise<number>}
   */
  async calculateStreak() {
    const stats = await this.getLearningStats();
    const dates = Object.keys(stats).sort().reverse();

    let streak = 0;
    const today = new Date();

    for (let i = 0; i < dates.length && i < 365; i++) {
      const expectedDate = new Date(today);
      expectedDate.setDate(expectedDate.getDate() - i);
      const expectedKey = this.getDateKey(expectedDate);

      const dayStats = stats[expectedKey];
      if (dayStats && (dayStats.wordsAdded > 0 || dayStats.wordsReviewed > 0)) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }

    return streak;
  }

  // MARK: - Review Sessions

  /**
   * Create a review session
   * @param {number} totalWords - Number of words in session
   * @param {string} mode - Review mode
   * @returns {Promise<Object>}
   */
  async createReviewSession(totalWords, mode = 'flashcard') {
    const sessions = await this.getReviewSessions();

    const session = {
      id: this.generateId(),
      startedAt: Date.now(),
      completedAt: null,
      totalWords,
      correctCount: 0,
      incorrectCount: 0,
      skippedCount: 0,
      reviewMode: mode,
      durationSeconds: 0
    };

    sessions.unshift(session);

    // Keep only last 50 sessions
    const trimmedSessions = sessions.slice(0, 50);
    await this.saveReviewSessions(trimmedSessions);

    return session;
  }

  /**
   * Complete a review session
   * @param {string} sessionId - Session ID
   * @param {Object} results - Session results
   */
  async completeReviewSession(sessionId, results) {
    const sessions = await this.getReviewSessions();
    const index = sessions.findIndex(s => s.id === sessionId);

    if (index !== -1) {
      sessions[index] = {
        ...sessions[index],
        ...results,
        completedAt: Date.now(),
        durationSeconds: Math.floor((Date.now() - sessions[index].startedAt) / 1000)
      };
      await this.saveReviewSessions(sessions);
    }
  }

  /**
   * Get recent review sessions
   * @param {number} limit - Number of sessions to return
   * @returns {Promise<Array>}
   */
  async getRecentSessions(limit = 10) {
    const sessions = await this.getReviewSessions();
    return sessions.slice(0, limit);
  }

  // MARK: - Settings

  /**
   * Get vocabulary settings
   * @returns {Promise<Object>}
   */
  async getSettings() {
    try {
      const result = await this.storage.get(VOCABULARY_KEYS.SETTINGS);
      return {
        ...DEFAULT_VOCABULARY_SETTINGS,
        ...(result[VOCABULARY_KEYS.SETTINGS] || {})
      };
    } catch (error) {
      logError('Failed to get vocabulary settings:', error);
      return { ...DEFAULT_VOCABULARY_SETTINGS };
    }
  }

  /**
   * Save vocabulary settings
   * @param {Object} settings
   */
  async saveSettings(settings) {
    await this.storage.set({
      [VOCABULARY_KEYS.SETTINGS]: {
        ...DEFAULT_VOCABULARY_SETTINGS,
        ...settings
      }
    });
  }

  // MARK: - Private Helpers

  async saveEntries(entries) {
    await this.storage.set({ [VOCABULARY_KEYS.ENTRIES]: entries });
  }

  async getLearningStats() {
    try {
      const result = await this.storage.get(VOCABULARY_KEYS.LEARNING_STATS);
      return result[VOCABULARY_KEYS.LEARNING_STATS] || {};
    } catch (error) {
      return {};
    }
  }

  async saveLearningStats(stats) {
    await this.storage.set({ [VOCABULARY_KEYS.LEARNING_STATS]: stats });
  }

  async getReviewSessions() {
    try {
      const result = await this.storage.get(VOCABULARY_KEYS.REVIEW_SESSIONS);
      return result[VOCABULARY_KEYS.REVIEW_SESSIONS] || [];
    } catch (error) {
      return [];
    }
  }

  async saveReviewSessions(sessions) {
    await this.storage.set({ [VOCABULARY_KEYS.REVIEW_SESSIONS]: sessions });
  }

  generateId() {
    return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  getDateKey(date) {
    return date.toISOString().split('T')[0];
  }
}

// Export singleton
export default new VocabularyStorage();
