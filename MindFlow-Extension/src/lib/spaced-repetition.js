/**
 * @fileoverview Spaced repetition service using SM-2 algorithm
 * @module spaced-repetition
 *
 * Implements the SM-2 algorithm for optimal review scheduling.
 */

/**
 * Response quality levels for review
 */
export const ResponseQuality = {
  FORGOT: 0,    // Complete blackout
  HARD: 1,      // Struggled but recalled
  GOOD: 2       // Recalled correctly
};

/**
 * Mastery levels based on interval
 */
export const MasteryLevel = {
  NEW: 0,
  LEARNING: 1,
  REVIEWING: 2,
  FAMILIAR: 3,
  MASTERED: 4
};

/**
 * Spaced Repetition Service
 */
export class SpacedRepetitionService {
  /**
   * Calculate next review based on response quality
   * @param {number} currentInterval - Current interval in days
   * @param {number} easeFactor - Current ease factor (default 2.5)
   * @param {number} quality - Response quality (0-2)
   * @returns {Object} Review result
   */
  calculateNextReview(currentInterval, easeFactor, quality) {
    let interval = currentInterval;
    let ef = Math.max(1.3, easeFactor);

    const wasCorrect = quality >= ResponseQuality.GOOD;

    if (wasCorrect) {
      // Correct response: increase interval
      if (interval === 0) {
        interval = 1;
      } else if (interval === 1) {
        interval = 3;
      } else {
        interval = Math.round(interval * ef);
      }

      // Update ease factor
      ef = ef + (0.1 - (2.0 - quality) * 0.08);
    } else {
      // Incorrect: reset interval
      interval = 1;
      ef = ef - 0.2;
    }

    // Ensure ease factor bounds
    ef = Math.max(1.3, ef);

    // Calculate mastery level
    const masteryLevel = this.calculateMasteryLevel(interval);

    // Calculate next review date
    const nextReviewDate = Date.now() + (interval * 24 * 60 * 60 * 1000);

    return {
      nextInterval: interval,
      newEaseFactor: ef,
      newMasteryLevel: masteryLevel,
      nextReviewDate: nextReviewDate,
      wasCorrect: wasCorrect
    };
  }

  /**
   * Calculate mastery level from interval
   * @param {number} interval - Interval in days
   * @returns {number} Mastery level (0-4)
   */
  calculateMasteryLevel(interval) {
    if (interval === 0) return MasteryLevel.NEW;
    if (interval < 7) return MasteryLevel.LEARNING;
    if (interval < 21) return MasteryLevel.REVIEWING;
    if (interval < 60) return MasteryLevel.FAMILIAR;
    return MasteryLevel.MASTERED;
  }

  /**
   * Get mastery level display name
   * @param {number} level - Mastery level
   * @returns {string} Display name
   */
  getMasteryLevelName(level) {
    const names = {
      [MasteryLevel.NEW]: 'New',
      [MasteryLevel.LEARNING]: 'Learning',
      [MasteryLevel.REVIEWING]: 'Reviewing',
      [MasteryLevel.FAMILIAR]: 'Familiar',
      [MasteryLevel.MASTERED]: 'Mastered'
    };
    return names[level] || 'Unknown';
  }

  /**
   * Get mastery level color
   * @param {number} level - Mastery level
   * @returns {string} Color name
   */
  getMasteryLevelColor(level) {
    const colors = {
      [MasteryLevel.NEW]: '#9CA3AF',      // gray
      [MasteryLevel.LEARNING]: '#EF4444',  // red
      [MasteryLevel.REVIEWING]: '#F59E0B', // orange
      [MasteryLevel.FAMILIAR]: '#3B82F6',  // blue
      [MasteryLevel.MASTERED]: '#10B981'   // green
    };
    return colors[level] || '#9CA3AF';
  }

  /**
   * Estimate review time
   * @param {number} wordCount - Number of words
   * @returns {number} Estimated minutes
   */
  estimateReviewTime(wordCount) {
    const secondsPerWord = 18;
    return Math.max(1, Math.round((wordCount * secondsPerWord) / 60));
  }

  /**
   * Get words due for review from array
   * @param {Array} words - Array of word entries
   * @param {number} limit - Optional limit
   * @returns {Array} Words due for review
   */
  getWordsDueForReview(words, limit = null) {
    const now = Date.now();

    let dueWords = words.filter(entry =>
      !entry.isArchived &&
      (entry.nextReviewAt === null || entry.nextReviewAt <= now)
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
   * Calculate overall progress
   * @param {Array} words - Array of word entries
   * @returns {Object} Progress statistics
   */
  calculateProgress(words) {
    const activeWords = words.filter(w => !w.isArchived);
    const totalWords = activeWords.length;

    if (totalWords === 0) {
      return {
        totalWords: 0,
        masteredWords: 0,
        learningWords: 0,
        newWords: 0,
        masteryPercentage: 0,
        totalReviews: 0,
        accuracy: 0,
        averageEaseFactor: 2.5
      };
    }

    const masteredWords = activeWords.filter(w => w.masteryLevel === MasteryLevel.MASTERED).length;
    const learningWords = activeWords.filter(w => w.masteryLevel >= 1 && w.masteryLevel < 4).length;
    const newWords = activeWords.filter(w => w.masteryLevel === 0).length;

    const totalReviews = activeWords.reduce((sum, w) => sum + w.reviewCount, 0);
    const totalCorrect = activeWords.reduce((sum, w) => sum + w.correctCount, 0);
    const accuracy = totalReviews > 0 ? (totalCorrect / totalReviews) * 100 : 0;

    const avgEaseFactor = activeWords.reduce((sum, w) => sum + w.easeFactor, 0) / totalWords;

    return {
      totalWords,
      masteredWords,
      learningWords,
      newWords,
      masteryPercentage: (masteredWords / totalWords) * 100,
      totalReviews,
      accuracy,
      averageEaseFactor: avgEaseFactor
    };
  }
}

// Export singleton
export default new SpacedRepetitionService();
