/**
 * MindFlow Vocabulary Page JavaScript
 * Main functionality for vocabulary list, search, and review
 */

import { VocabularyStorage } from '../lib/vocabulary-storage.js';
import { VocabularyLookupService } from '../lib/vocabulary-lookup.js';
import { SpacedRepetitionService } from '../lib/spaced-repetition.js';
import ttsService from '../lib/tts-service.js';

// Initialize services
const storage = new VocabularyStorage();
const lookupService = new VocabularyLookupService();
const spacedRepetition = new SpacedRepetitionService();

// State
let allWords = [];
let filteredWords = [];
let currentFilter = 'all';
let searchQuery = '';
let selectedWord = null;

// Review state
let reviewSession = null;
let reviewWords = [];
let currentReviewIndex = 0;
let isAnswerRevealed = false;
let reviewStats = { correct: 0, incorrect: 0, skipped: 0 };

// DOM Elements
const elements = {
    // Stats
    totalWords: document.getElementById('total-words'),
    dueCount: document.getElementById('due-count'),
    masteredCount: document.getElementById('mastered-count'),

    // Navigation
    navLinks: document.querySelectorAll('.sidebar-nav a'),

    // Search
    searchInput: document.getElementById('search-input'),
    clearSearch: document.getElementById('clear-search'),

    // Word list
    wordList: document.getElementById('word-list'),
    emptyState: document.getElementById('empty-state'),
    addWordEmptyBtn: document.getElementById('add-word-empty'),

    // Buttons
    addWordBtn: document.getElementById('add-word-btn'),
    startReviewBtn: document.getElementById('start-review-btn'),

    // Add Word Modal
    addWordModal: document.getElementById('add-word-modal'),
    closeAddModal: document.getElementById('close-add-modal'),
    wordInput: document.getElementById('word-input'),
    contextInput: document.getElementById('context-input'),
    lookupBtn: document.getElementById('lookup-btn'),
    lookupPreview: document.getElementById('lookup-preview'),
    lookupLoading: document.getElementById('lookup-loading'),
    lookupResult: document.getElementById('lookup-result'),
    lookupError: document.getElementById('lookup-error'),
    cancelAddBtn: document.getElementById('cancel-add'),
    saveWordBtn: document.getElementById('save-word'),

    // Word Detail Modal
    wordDetailModal: document.getElementById('word-detail-modal'),
    closeDetailModal: document.getElementById('close-detail-modal'),
    wordDetailContent: document.getElementById('word-detail-content'),
    editWordBtn: document.getElementById('edit-word'),
    deleteWordBtn: document.getElementById('delete-word'),

    // Review Modal
    reviewModal: document.getElementById('review-modal'),
    closeReviewModal: document.getElementById('close-review-modal'),
    reviewProgress: document.getElementById('review-progress'),
    reviewCorrect: document.getElementById('review-correct'),
    reviewIncorrect: document.getElementById('review-incorrect'),
    flashcard: document.getElementById('flashcard'),
    flashcardWord: document.getElementById('flashcard-word'),
    flashcardPhonetic: document.getElementById('flashcard-phonetic'),
    flashcardDefinition: document.getElementById('flashcard-definition'),
    tapHint: document.getElementById('tap-hint'),
    ratingButtons: document.getElementById('rating-buttons'),
    rateForgot: document.getElementById('rate-forgot'),
    rateHard: document.getElementById('rate-hard'),
    rateGood: document.getElementById('rate-good')
};

// Current lookup result for saving
let currentLookupResult = null;

// ============================================
// Initialization
// ============================================

document.addEventListener('DOMContentLoaded', async () => {
    await loadWords();
    setupEventListeners();
    updateStats();
});

async function loadWords() {
    allWords = await storage.getAllWords();
    applyFilters();
    renderWordList();
}

function setupEventListeners() {
    // Navigation
    elements.navLinks.forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const filter = link.dataset.filter;
            setActiveFilter(filter);
        });
    });

    // Search
    elements.searchInput.addEventListener('input', debounce(handleSearch, 300));
    elements.clearSearch.addEventListener('click', clearSearch);

    // Add word
    elements.addWordBtn.addEventListener('click', openAddWordModal);
    elements.addWordEmptyBtn?.addEventListener('click', openAddWordModal);
    elements.closeAddModal.addEventListener('click', closeAddWordModal);
    elements.lookupBtn.addEventListener('click', lookupWord);
    elements.cancelAddBtn.addEventListener('click', closeAddWordModal);
    elements.saveWordBtn.addEventListener('click', saveWord);
    elements.wordInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') lookupWord();
    });

    // Word detail
    elements.closeDetailModal.addEventListener('click', closeWordDetailModal);
    elements.deleteWordBtn.addEventListener('click', deleteCurrentWord);

    // Review
    elements.startReviewBtn.addEventListener('click', startReview);
    elements.closeReviewModal.addEventListener('click', closeReviewModal);
    elements.flashcard.addEventListener('click', revealAnswer);
    elements.rateForgot.addEventListener('click', () => rateWord(1));
    elements.rateHard.addEventListener('click', () => rateWord(2));
    elements.rateGood.addEventListener('click', () => rateWord(4));

    // Keyboard shortcuts for review
    document.addEventListener('keydown', handleKeydown);

    // Close modals on backdrop click
    [elements.addWordModal, elements.wordDetailModal, elements.reviewModal].forEach(modal => {
        modal?.addEventListener('click', (e) => {
            if (e.target === modal) {
                modal.style.display = 'none';
            }
        });
    });
}

// ============================================
// Word List Management
// ============================================

function applyFilters() {
    filteredWords = allWords.filter(word => {
        // Apply category/status filter
        let matchesFilter = true;
        switch (currentFilter) {
            case 'all':
                matchesFilter = true;
                break;
            case 'due':
                matchesFilter = word.nextReviewAt && new Date(word.nextReviewAt) <= new Date();
                break;
            case 'favorites':
                matchesFilter = word.isFavorite;
                break;
            case 'new':
                matchesFilter = word.masteryLevel === 0;
                break;
            case 'learning':
                matchesFilter = word.masteryLevel === 1;
                break;
            case 'reviewing':
                matchesFilter = word.masteryLevel === 2;
                break;
            case 'familiar':
                matchesFilter = word.masteryLevel === 3;
                break;
            case 'mastered':
                matchesFilter = word.masteryLevel === 4;
                break;
            default:
                matchesFilter = true;
        }

        // Apply search filter
        let matchesSearch = true;
        if (searchQuery) {
            const query = searchQuery.toLowerCase();
            matchesSearch = (
                word.word.toLowerCase().includes(query) ||
                (word.definitionEN && word.definitionEN.toLowerCase().includes(query)) ||
                (word.definitionCN && word.definitionCN.toLowerCase().includes(query))
            );
        }

        return matchesFilter && matchesSearch;
    });

    // Sort by most recently added
    filteredWords.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
}

function renderWordList() {
    if (filteredWords.length === 0) {
        elements.wordList.innerHTML = '';
        elements.emptyState.style.display = 'block';
        return;
    }

    elements.emptyState.style.display = 'none';

    elements.wordList.innerHTML = filteredWords.map(word => `
        <div class="word-item" data-id="${word.id}">
            <div class="word-info">
                <h3>
                    ${escapeHtml(word.word)}
                    ${word.phonetic ? `<span class="phonetic">${escapeHtml(word.phonetic)}</span>` : ''}
                </h3>
                <p class="definition">${escapeHtml(word.definitionEN || word.definitionCN || 'No definition')}</p>
            </div>
            <div class="word-meta">
                <span class="mastery-badge mastery-${word.masteryLevel}">${getMasteryLabel(word.masteryLevel)}</span>
                ${word.isFavorite ? '<span class="favorite-icon">★</span>' : ''}
                ${isDueForReview(word) ? '<span class="due-badge">Due</span>' : ''}
            </div>
        </div>
    `).join('');

    // Add click handlers
    document.querySelectorAll('.word-item').forEach(item => {
        item.addEventListener('click', () => {
            const id = item.dataset.id;
            const word = allWords.find(w => w.id === id);
            if (word) openWordDetail(word);
        });
    });
}

function setActiveFilter(filter) {
    currentFilter = filter;

    // Update nav UI
    elements.navLinks.forEach(link => {
        link.classList.toggle('active', link.dataset.filter === filter);
    });

    applyFilters();
    renderWordList();
}

function handleSearch() {
    searchQuery = elements.searchInput.value.trim();
    applyFilters();
    renderWordList();
}

function clearSearch() {
    elements.searchInput.value = '';
    searchQuery = '';
    applyFilters();
    renderWordList();
}

// ============================================
// Statistics
// ============================================

function updateStats() {
    const total = allWords.length;
    const due = allWords.filter(w => isDueForReview(w)).length;
    const mastered = allWords.filter(w => w.masteryLevel === 4).length;

    elements.totalWords.textContent = total;
    elements.dueCount.textContent = due;
    elements.masteredCount.textContent = mastered;

    // Update review button state
    elements.startReviewBtn.disabled = due === 0;
}

function isDueForReview(word) {
    if (!word.nextReviewAt) return true;
    return new Date(word.nextReviewAt) <= new Date();
}

// ============================================
// Add Word Modal
// ============================================

function openAddWordModal() {
    elements.addWordModal.style.display = 'flex';
    elements.wordInput.value = '';
    elements.contextInput.value = '';
    elements.lookupPreview.style.display = 'none';
    elements.lookupLoading.style.display = 'none';
    elements.lookupResult.style.display = 'none';
    elements.lookupError.style.display = 'none';
    elements.saveWordBtn.disabled = true;
    currentLookupResult = null;
    elements.wordInput.focus();
}

function closeAddWordModal() {
    elements.addWordModal.style.display = 'none';
}

async function lookupWord() {
    const word = elements.wordInput.value.trim();
    if (!word) return;

    const context = elements.contextInput.value.trim();

    // Show loading
    elements.lookupPreview.style.display = 'block';
    elements.lookupLoading.style.display = 'block';
    elements.lookupResult.style.display = 'none';
    elements.lookupError.style.display = 'none';
    elements.saveWordBtn.disabled = true;

    try {
        const result = await lookupService.lookup(word, context);
        currentLookupResult = result;

        // Display result
        elements.lookupLoading.style.display = 'none';
        elements.lookupResult.style.display = 'block';
        elements.lookupResult.innerHTML = `
            <h3>${escapeHtml(result.word)}</h3>
            ${result.phonetic ? `<p class="phonetic">${escapeHtml(result.phonetic)}</p>` : ''}
            ${result.partOfSpeech ? `<span class="pos">${escapeHtml(result.partOfSpeech)}</span>` : ''}
            <p><strong>English:</strong> ${escapeHtml(result.definitionEN || 'N/A')}</p>
            <p><strong>Chinese:</strong> ${escapeHtml(result.definitionCN || 'N/A')}</p>
            ${result.examples && result.examples.length > 0 ? `
                <div style="margin-top: 12px;">
                    <strong>Example:</strong>
                    <p style="margin-top: 4px; font-style: italic;">${escapeHtml(result.examples[0].sentence)}</p>
                    ${result.examples[0].translation ? `<p style="color: #6B7280; font-size: 14px;">${escapeHtml(result.examples[0].translation)}</p>` : ''}
                </div>
            ` : ''}
        `;

        elements.saveWordBtn.disabled = false;

    } catch (error) {
        elements.lookupLoading.style.display = 'none';
        elements.lookupError.style.display = 'block';
        elements.lookupError.textContent = error.message || 'Failed to lookup word. Please try again.';
    }
}

async function saveWord() {
    if (!currentLookupResult) return;

    // Check for duplicate
    const existing = allWords.find(w => w.word.toLowerCase() === currentLookupResult.word.toLowerCase());
    if (existing) {
        alert('This word already exists in your vocabulary.');
        return;
    }

    const context = elements.contextInput.value.trim();

    const wordEntry = {
        id: generateId(),
        word: currentLookupResult.word,
        phonetic: currentLookupResult.phonetic,
        partOfSpeech: currentLookupResult.partOfSpeech,
        definitionEN: currentLookupResult.definitionEN,
        definitionCN: currentLookupResult.definitionCN,
        examples: currentLookupResult.examples || [],
        synonyms: currentLookupResult.synonyms || [],
        antonyms: currentLookupResult.antonyms || [],
        userContext: context,
        category: 'General',
        tags: [],
        notes: '',
        isFavorite: false,
        masteryLevel: 0,
        easeFactor: 2.5,
        interval: 0,
        reviewCount: 0,
        correctCount: 0,
        lastReviewedAt: null,
        nextReviewAt: new Date().toISOString(),
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        syncStatus: 'pending'
    };

    await storage.addWord(wordEntry);
    allWords.unshift(wordEntry);

    closeAddWordModal();
    applyFilters();
    renderWordList();
    updateStats();
}

// ============================================
// Word Detail Modal
// ============================================

function openWordDetail(word) {
    selectedWord = word;
    elements.wordDetailModal.style.display = 'flex';

    elements.wordDetailContent.innerHTML = `
        <div class="detail-section">
            <h2 style="font-size: 28px; margin-bottom: 8px;">${escapeHtml(word.word)}</h2>
            <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 16px;">
                ${word.phonetic ? `<span style="color: #6B7280; font-size: 18px;">${escapeHtml(word.phonetic)}</span>` : ''}
                <button class="pronunciation-btn" data-word="${escapeHtml(word.word)}" title="Play pronunciation">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon>
                        <path d="M15.54 8.46a5 5 0 0 1 0 7.07"></path>
                        <path d="M19.07 4.93a10 10 0 0 1 0 14.14"></path>
                    </svg>
                </button>
            </div>
            ${word.partOfSpeech ? `<span class="tag" style="background: #DBEAFE; color: #2563EB;">${escapeHtml(word.partOfSpeech)}</span>` : ''}
        </div>

        <div class="detail-section">
            <h4>Definition</h4>
            ${word.definitionEN ? `<p style="margin-bottom: 8px;"><strong>EN:</strong> ${escapeHtml(word.definitionEN)}</p>` : ''}
            ${word.definitionCN ? `<p><strong>CN:</strong> ${escapeHtml(word.definitionCN)}</p>` : ''}
        </div>

        ${word.examples && word.examples.length > 0 ? `
            <div class="detail-section">
                <h4>Examples</h4>
                ${word.examples.map(ex => `
                    <div class="example-item">
                        <p class="en">${escapeHtml(ex.sentence)}</p>
                        ${ex.translation ? `<p class="cn">${escapeHtml(ex.translation)}</p>` : ''}
                    </div>
                `).join('')}
            </div>
        ` : ''}

        ${word.synonyms && word.synonyms.length > 0 ? `
            <div class="detail-section">
                <h4>Synonyms</h4>
                <div class="tag-list">
                    ${word.synonyms.map(s => `<span class="tag">${escapeHtml(s)}</span>`).join('')}
                </div>
            </div>
        ` : ''}

        ${word.userContext ? `
            <div class="detail-section">
                <h4>Your Context</h4>
                <p>${escapeHtml(word.userContext)}</p>
            </div>
        ` : ''}

        ${word.notes ? `
            <div class="detail-section">
                <h4>Notes</h4>
                <p>${escapeHtml(word.notes)}</p>
            </div>
        ` : ''}

        <div class="detail-section">
            <h4>Learning Progress</h4>
            <p>Mastery: <span class="mastery-badge mastery-${word.masteryLevel}">${getMasteryLabel(word.masteryLevel)}</span></p>
            <p style="margin-top: 8px; color: #6B7280; font-size: 14px;">
                Reviews: ${word.reviewCount} |
                Accuracy: ${word.reviewCount > 0 ? Math.round((word.correctCount / word.reviewCount) * 100) : 0}%
            </p>
        </div>
    `;

    // Add pronunciation button click handler
    const pronBtn = elements.wordDetailContent.querySelector('.pronunciation-btn');
    if (pronBtn) {
        pronBtn.addEventListener('click', async (e) => {
            e.stopPropagation();
            await playPronunciation(word.word, pronBtn);
        });
    }
}

function closeWordDetailModal() {
    elements.wordDetailModal.style.display = 'none';
    selectedWord = null;
}

async function deleteCurrentWord() {
    if (!selectedWord) return;

    if (confirm(`Delete "${selectedWord.word}" from your vocabulary?`)) {
        await storage.deleteWord(selectedWord.id);
        allWords = allWords.filter(w => w.id !== selectedWord.id);
        closeWordDetailModal();
        applyFilters();
        renderWordList();
        updateStats();
    }
}

// ============================================
// Review Session
// ============================================

async function startReview() {
    reviewWords = allWords.filter(w => isDueForReview(w));

    if (reviewWords.length === 0) {
        alert('No words due for review!');
        return;
    }

    // Shuffle words
    reviewWords = shuffleArray(reviewWords);

    // Limit to 20 words per session
    if (reviewWords.length > 20) {
        reviewWords = reviewWords.slice(0, 20);
    }

    currentReviewIndex = 0;
    isAnswerRevealed = false;
    reviewStats = { correct: 0, incorrect: 0, skipped: 0 };

    elements.reviewModal.style.display = 'flex';
    showCurrentCard();
}

function closeReviewModal() {
    elements.reviewModal.style.display = 'none';

    // Refresh the list and stats
    loadWords();
}

function showCurrentCard() {
    if (currentReviewIndex >= reviewWords.length) {
        showReviewSummary();
        return;
    }

    const word = reviewWords[currentReviewIndex];

    // Update progress
    elements.reviewProgress.textContent = `${currentReviewIndex + 1} / ${reviewWords.length}`;
    elements.reviewCorrect.textContent = reviewStats.correct;
    elements.reviewIncorrect.textContent = reviewStats.incorrect;

    // Reset card state
    isAnswerRevealed = false;
    elements.flashcard.classList.remove('revealed');
    elements.ratingButtons.style.display = 'none';
    elements.tapHint.style.display = 'block';

    // Show word with pronunciation button
    elements.flashcardWord.textContent = word.word;
    elements.flashcardPhonetic.innerHTML = `
        ${word.phonetic || ''}
        <button class="pronunciation-btn flashcard-pronunciation" data-word="${escapeHtml(word.word)}" title="Play pronunciation">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon>
                <path d="M15.54 8.46a5 5 0 0 1 0 7.07"></path>
            </svg>
        </button>
    `;
    elements.flashcardDefinition.innerHTML = '';

    // Add pronunciation button handler
    const pronBtn = elements.flashcardPhonetic.querySelector('.pronunciation-btn');
    if (pronBtn) {
        pronBtn.addEventListener('click', async (e) => {
            e.stopPropagation();
            await playPronunciation(word.word, pronBtn);
        });
    }
}

function revealAnswer() {
    if (isAnswerRevealed) return;

    const word = reviewWords[currentReviewIndex];

    isAnswerRevealed = true;
    elements.flashcard.classList.add('revealed');
    elements.tapHint.style.display = 'none';
    elements.ratingButtons.style.display = 'flex';

    // Show definition
    let definitionHTML = '';
    if (word.definitionEN) {
        definitionHTML += `<p>${escapeHtml(word.definitionEN)}</p>`;
    }
    if (word.definitionCN) {
        definitionHTML += `<p style="color: #6B7280; margin-top: 8px;">${escapeHtml(word.definitionCN)}</p>`;
    }
    if (word.examples && word.examples.length > 0) {
        definitionHTML += `<p style="font-style: italic; margin-top: 16px; color: #4B5563;">"${escapeHtml(word.examples[0].sentence)}"</p>`;
    }

    elements.flashcardDefinition.innerHTML = definitionHTML;
}

async function rateWord(quality) {
    const word = reviewWords[currentReviewIndex];

    // Update stats
    if (quality >= 3) {
        reviewStats.correct++;
    } else {
        reviewStats.incorrect++;
    }

    // Calculate new spaced repetition values
    const result = spacedRepetition.calculateNextReview(
        word.easeFactor,
        word.interval,
        word.reviewCount,
        quality
    );

    // Update word
    word.easeFactor = result.easeFactor;
    word.interval = result.interval;
    word.nextReviewAt = result.nextReviewDate.toISOString();
    word.lastReviewedAt = new Date().toISOString();
    word.reviewCount++;
    if (quality >= 3) {
        word.correctCount++;
    }
    word.masteryLevel = calculateMasteryLevel(word);
    word.updatedAt = new Date().toISOString();

    // Save to storage
    await storage.updateWord(word);

    // Move to next card
    currentReviewIndex++;
    showCurrentCard();
}

function calculateMasteryLevel(word) {
    const accuracy = word.reviewCount > 0 ? word.correctCount / word.reviewCount : 0;

    if (word.interval >= 21 && accuracy >= 0.8) return 4; // Mastered
    if (word.interval >= 7 && accuracy >= 0.7) return 3; // Familiar
    if (word.interval >= 1 && accuracy >= 0.5) return 2; // Reviewing
    if (word.reviewCount > 0) return 1; // Learning
    return 0; // New
}

function showReviewSummary() {
    const total = reviewStats.correct + reviewStats.incorrect + reviewStats.skipped;
    const accuracy = total > 0 ? Math.round((reviewStats.correct / total) * 100) : 0;

    elements.flashcard.classList.remove('revealed');
    elements.ratingButtons.style.display = 'none';
    elements.tapHint.style.display = 'none';

    elements.flashcardWord.textContent = 'Session Complete!';
    elements.flashcardPhonetic.textContent = '';
    elements.flashcardDefinition.innerHTML = `
        <div style="margin-top: 24px;">
            <p style="font-size: 24px; font-weight: bold; margin-bottom: 16px;">
                ${accuracy}% Accuracy
            </p>
            <p style="color: #059669;">✓ ${reviewStats.correct} Correct</p>
            <p style="color: #DC2626;">✗ ${reviewStats.incorrect} Incorrect</p>
            <button id="finish-review" class="btn btn-primary" style="margin-top: 24px;">
                Done
            </button>
        </div>
    `;

    document.getElementById('finish-review')?.addEventListener('click', closeReviewModal);
}

function handleKeydown(e) {
    // Only handle keys when review modal is open
    if (elements.reviewModal.style.display !== 'flex') return;

    if (!isAnswerRevealed) {
        // Space to reveal
        if (e.code === 'Space') {
            e.preventDefault();
            revealAnswer();
        }
    } else {
        // 1, 2, 3 for ratings
        if (e.key === '1') {
            e.preventDefault();
            rateWord(1);
        } else if (e.key === '2') {
            e.preventDefault();
            rateWord(2);
        } else if (e.key === '3') {
            e.preventDefault();
            rateWord(4);
        }
    }

    // Escape to close
    if (e.key === 'Escape') {
        closeReviewModal();
    }
}

// ============================================
// TTS / Pronunciation
// ============================================

/**
 * Play pronunciation for a word
 * @param {string} word - Word to pronounce
 * @param {HTMLElement} button - Button element to update state
 */
async function playPronunciation(word, button) {
    if (!word || ttsService.isLoading) return;

    const originalContent = button.innerHTML;

    try {
        // Show loading state
        button.innerHTML = '<span class="loading-spinner"></span>';
        button.disabled = true;

        await ttsService.pronounce(word);

        // Restore button
        button.innerHTML = originalContent;
        button.disabled = false;
    } catch (error) {
        console.error('TTS error:', error);

        // Show error state briefly
        button.innerHTML = '<span style="color: #DC2626;">!</span>';
        button.title = error.message || 'Failed to play pronunciation';

        setTimeout(() => {
            button.innerHTML = originalContent;
            button.disabled = false;
            button.title = 'Play pronunciation';
        }, 2000);
    }
}

// ============================================
// Utility Functions
// ============================================

function getMasteryLabel(level) {
    const labels = ['New', 'Learning', 'Reviewing', 'Familiar', 'Mastered'];
    return labels[level] || 'New';
}

function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function generateId() {
    return 'vocab_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
}

function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

function shuffleArray(array) {
    const shuffled = [...array];
    for (let i = shuffled.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
}
