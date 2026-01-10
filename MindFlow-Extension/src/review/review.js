/**
 * MindFlow Vocabulary Review
 * Implements spaced repetition review functionality for Chrome extension
 */

import { VocabularyStorage } from '../lib/vocabulary-storage.js';
import { SpacedRepetitionService } from '../lib/spaced-repetition.js';
import ttsService from '../lib/tts-service.js';

class ReviewController {
    constructor() {
        this.storage = new VocabularyStorage();
        this.spacedRepetition = new SpacedRepetitionService();

        // State
        this.reviewQueue = [];
        this.currentIndex = 0;
        this.currentWord = null;
        this.isFlipped = false;
        this.sessionStats = {
            reviewed: 0,
            correct: 0,
            ratings: []
        };

        // DOM Elements
        this.elements = {};
    }

    async init() {
        this.cacheElements();
        this.attachEventListeners();
        await this.loadDueWords();
    }

    cacheElements() {
        this.elements = {
            // Screens
            startScreen: document.getElementById('start-screen'),
            reviewScreen: document.getElementById('review-screen'),
            completeScreen: document.getElementById('complete-screen'),
            emptyScreen: document.getElementById('empty-screen'),

            // Start screen
            dueCount: document.getElementById('due-count'),
            reviewLimit: document.getElementById('review-limit'),
            startBtn: document.getElementById('start-btn'),

            // Progress
            progressText: document.getElementById('progress-text'),
            progressFill: document.getElementById('progress-fill'),

            // Flashcard
            flashcard: document.getElementById('flashcard'),
            wordText: document.getElementById('word-text'),
            wordPhonetic: document.getElementById('word-phonetic'),
            wordTextBack: document.getElementById('word-text-back'),
            wordPhoneticBack: document.getElementById('word-phonetic-back'),
            wordPos: document.getElementById('word-pos'),
            wordDefinition: document.getElementById('word-definition'),
            wordDefinitionCn: document.getElementById('word-definition-cn'),
            wordExample: document.getElementById('word-example'),

            // Rating
            ratingButtons: document.getElementById('rating-buttons'),

            // Pronunciation buttons
            pronounceBtnFront: document.getElementById('pronounce-btn-front'),
            pronounceBtnBack: document.getElementById('pronounce-btn-back'),

            // Complete screen
            statReviewed: document.getElementById('stat-reviewed'),
            statCorrect: document.getElementById('stat-correct'),
            statAccuracy: document.getElementById('stat-accuracy'),
            reviewMoreBtn: document.getElementById('review-more-btn')
        };
    }

    attachEventListeners() {
        // Start button
        this.elements.startBtn.addEventListener('click', () => this.startReview());

        // Flashcard click
        this.elements.flashcard.addEventListener('click', () => this.flipCard());

        // Rating buttons
        document.querySelectorAll('.rating-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const quality = parseInt(e.currentTarget.dataset.quality);
                this.rateWord(quality);
            });
        });

        // Review more button
        this.elements.reviewMoreBtn.addEventListener('click', () => this.resetAndStart());

        // Pronunciation buttons
        this.elements.pronounceBtnFront.addEventListener('click', (e) => {
            e.stopPropagation();
            this.playPronunciation();
        });
        this.elements.pronounceBtnBack.addEventListener('click', (e) => {
            e.stopPropagation();
            this.playPronunciation();
        });

        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => this.handleKeyboard(e));
    }

    async playPronunciation() {
        if (!this.currentWord || ttsService.isLoading) return;

        const buttons = [this.elements.pronounceBtnFront, this.elements.pronounceBtnBack];

        try {
            // Show loading state on both buttons
            buttons.forEach(btn => {
                btn.classList.add('loading');
                btn.disabled = true;
            });

            await ttsService.pronounce(this.currentWord.word);

            // Restore buttons
            buttons.forEach(btn => {
                btn.classList.remove('loading');
                btn.disabled = false;
            });
        } catch (error) {
            console.error('[Review] TTS error:', error);

            // Show error state
            buttons.forEach(btn => {
                btn.classList.remove('loading');
                btn.classList.add('error');
                btn.disabled = false;
            });

            setTimeout(() => {
                buttons.forEach(btn => btn.classList.remove('error'));
            }, 2000);
        }
    }

    handleKeyboard(e) {
        // Only handle when on review screen
        if (this.elements.reviewScreen.style.display === 'none') return;

        if (e.code === 'Space') {
            e.preventDefault();
            this.flipCard();
        } else if (this.isFlipped) {
            switch (e.key) {
                case '1':
                    this.rateWord(0); // Again
                    break;
                case '2':
                    this.rateWord(2); // Hard
                    break;
                case '3':
                    this.rateWord(3); // Good
                    break;
                case '4':
                    this.rateWord(5); // Easy
                    break;
            }
        }
    }

    async loadDueWords() {
        try {
            const dueWords = await this.storage.getWordsDueForReview();
            this.elements.dueCount.textContent = dueWords.length;

            if (dueWords.length === 0) {
                this.showScreen('empty');
            }
        } catch (error) {
            console.error('[Review] Failed to load due words:', error);
        }
    }

    async startReview() {
        try {
            // Get review limit
            const limit = parseInt(this.elements.reviewLimit.value) || 20;

            // Get words due for review
            let dueWords = await this.storage.getWordsDueForReview();

            if (dueWords.length === 0) {
                this.showScreen('empty');
                return;
            }

            // Apply limit (0 = all)
            if (limit > 0 && dueWords.length > limit) {
                dueWords = dueWords.slice(0, limit);
            }

            // Shuffle the queue
            this.reviewQueue = this.shuffleArray([...dueWords]);
            this.currentIndex = 0;
            this.sessionStats = { reviewed: 0, correct: 0, ratings: [] };

            // Show review screen and first word
            this.showScreen('review');
            this.showCurrentWord();

        } catch (error) {
            console.error('[Review] Failed to start review:', error);
        }
    }

    showCurrentWord() {
        if (this.currentIndex >= this.reviewQueue.length) {
            this.completeReview();
            return;
        }

        this.currentWord = this.reviewQueue[this.currentIndex];
        this.isFlipped = false;

        // Reset card
        this.elements.flashcard.classList.remove('flipped');
        this.elements.ratingButtons.style.display = 'none';

        // Update progress
        this.updateProgress();

        // Fill in word data
        this.elements.wordText.textContent = this.currentWord.word;
        this.elements.wordTextBack.textContent = this.currentWord.word;

        const phonetic = this.currentWord.phonetic || '';
        this.elements.wordPhonetic.textContent = phonetic;
        this.elements.wordPhoneticBack.textContent = phonetic;

        this.elements.wordPos.textContent = this.currentWord.partOfSpeech || '';
        this.elements.wordDefinition.textContent = this.currentWord.definitionEN || 'No definition available';
        this.elements.wordDefinitionCn.textContent = this.currentWord.definitionCN || '';

        // Show example if available
        if (this.currentWord.examples && this.currentWord.examples.length > 0) {
            const example = this.currentWord.examples[0];
            this.elements.wordExample.textContent = typeof example === 'string' ? example : example.sentence || '';
            this.elements.wordExample.style.display = 'block';
        } else {
            this.elements.wordExample.style.display = 'none';
        }
    }

    flipCard() {
        if (this.isFlipped) return;

        this.isFlipped = true;
        this.elements.flashcard.classList.add('flipped');
        this.elements.ratingButtons.style.display = 'block';
    }

    async rateWord(quality) {
        if (!this.currentWord) return;

        try {
            // Calculate new review data using SM-2
            const reviewData = this.spacedRepetition.calculateReview(this.currentWord, quality);

            // Update the word in storage
            await this.storage.updateWord(this.currentWord.id, {
                masteryLevel: reviewData.masteryLevel,
                easeFactor: reviewData.easeFactor,
                interval: reviewData.interval,
                reviewCount: (this.currentWord.reviewCount || 0) + 1,
                correctCount: quality >= 3 ? (this.currentWord.correctCount || 0) + 1 : this.currentWord.correctCount,
                lastReviewedAt: new Date().toISOString(),
                nextReviewAt: reviewData.nextReviewAt
            });

            // Update session stats
            this.sessionStats.reviewed++;
            if (quality >= 3) {
                this.sessionStats.correct++;
            }
            this.sessionStats.ratings.push(quality);

            // Move to next word
            this.currentIndex++;
            this.showCurrentWord();

        } catch (error) {
            console.error('[Review] Failed to rate word:', error);
        }
    }

    updateProgress() {
        const total = this.reviewQueue.length;
        const current = this.currentIndex + 1;
        const percent = (this.currentIndex / total) * 100;

        this.elements.progressText.textContent = `${current} / ${total}`;
        this.elements.progressFill.style.width = `${percent}%`;
    }

    completeReview() {
        // Calculate accuracy
        const accuracy = this.sessionStats.reviewed > 0
            ? Math.round((this.sessionStats.correct / this.sessionStats.reviewed) * 100)
            : 0;

        // Update complete screen
        this.elements.statReviewed.textContent = this.sessionStats.reviewed;
        this.elements.statCorrect.textContent = this.sessionStats.correct;
        this.elements.statAccuracy.textContent = `${accuracy}%`;

        // Show complete screen
        this.showScreen('complete');

        console.log('[Review] Session complete:', this.sessionStats);
    }

    resetAndStart() {
        this.reviewQueue = [];
        this.currentIndex = 0;
        this.currentWord = null;
        this.isFlipped = false;
        this.sessionStats = { reviewed: 0, correct: 0, ratings: [] };

        this.loadDueWords();
        this.showScreen('start');
    }

    showScreen(screenName) {
        // Hide all screens
        this.elements.startScreen.style.display = 'none';
        this.elements.reviewScreen.style.display = 'none';
        this.elements.completeScreen.style.display = 'none';
        this.elements.emptyScreen.style.display = 'none';

        // Show requested screen
        switch (screenName) {
            case 'start':
                this.elements.startScreen.style.display = 'block';
                break;
            case 'review':
                this.elements.reviewScreen.style.display = 'block';
                break;
            case 'complete':
                this.elements.completeScreen.style.display = 'block';
                break;
            case 'empty':
                this.elements.emptyScreen.style.display = 'block';
                break;
        }
    }

    shuffleArray(array) {
        for (let i = array.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [array[i], array[j]] = [array[j], array[i]];
        }
        return array;
    }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    const controller = new ReviewController();
    controller.init();
});
