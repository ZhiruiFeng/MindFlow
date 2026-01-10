/**
 * Vocabulary Sync Service for Chrome Extension
 * Handles synchronization with Supabase backend
 */

import { VocabularyStorage } from './vocabulary-storage.js';

export class VocabularySyncService {
    constructor() {
        this.storage = new VocabularyStorage();
        this.isSyncing = false;
        this.lastSyncDate = null;
        this.supabaseUrl = null;
        this.supabaseKey = null;
    }

    /**
     * Configure Supabase connection
     * @param {string} url - Supabase project URL
     * @param {string} key - Supabase anon key or access token
     */
    configure(url, key) {
        this.supabaseUrl = url;
        this.supabaseKey = key;
        console.log('[VocabularySyncService] Configured');
    }

    /**
     * Load configuration from storage
     */
    async loadConfig() {
        try {
            const result = await chrome.storage.sync.get(['supabase_config']);
            const config = result.supabase_config;
            if (config && config.url && config.anonKey) {
                this.configure(config.url, config.anonKey);
                return true;
            }
            return false;
        } catch (error) {
            console.error('[VocabularySyncService] Failed to load config:', error);
            return false;
        }
    }

    /**
     * Check if sync is enabled
     */
    get isEnabled() {
        return this.supabaseUrl && this.supabaseKey;
    }

    /**
     * Sync vocabulary to backend
     */
    async syncToBackend() {
        if (!this.isEnabled) {
            throw new Error('Sync not configured');
        }

        if (this.isSyncing) {
            throw new Error('Sync already in progress');
        }

        this.isSyncing = true;

        try {
            console.log('[VocabularySyncService] Starting sync to backend...');

            // Get all words with pending sync status
            const allWords = await this.storage.getAllWords();
            const pendingWords = allWords.filter(w => w.syncStatus === 'pending');

            console.log(`[VocabularySyncService] Found ${pendingWords.length} entries to sync`);

            if (pendingWords.length === 0) {
                this.lastSyncDate = new Date();
                return { synced: 0 };
            }

            let syncedCount = 0;

            for (const word of pendingWords) {
                try {
                    await this.syncEntry(word);
                    syncedCount++;
                } catch (error) {
                    console.error(`[VocabularySyncService] Failed to sync ${word.word}:`, error);
                }
            }

            this.lastSyncDate = new Date();
            console.log(`[VocabularySyncService] Synced ${syncedCount} entries`);

            return { synced: syncedCount };
        } finally {
            this.isSyncing = false;
        }
    }

    /**
     * Sync from backend - fetch new/updated entries
     */
    async syncFromBackend() {
        if (!this.isEnabled) {
            throw new Error('Sync not configured');
        }

        if (this.isSyncing) {
            throw new Error('Sync already in progress');
        }

        this.isSyncing = true;

        try {
            console.log('[VocabularySyncService] Starting sync from backend...');

            // Fetch remote entries
            const remoteEntries = await this.fetchRemoteEntries();
            console.log(`[VocabularySyncService] Fetched ${remoteEntries.length} remote entries`);

            let processedCount = 0;

            for (const remoteEntry of remoteEntries) {
                try {
                    await this.processRemoteEntry(remoteEntry);
                    processedCount++;
                } catch (error) {
                    console.error('[VocabularySyncService] Failed to process remote entry:', error);
                }
            }

            this.lastSyncDate = new Date();
            console.log(`[VocabularySyncService] Processed ${processedCount} remote entries`);

            return { processed: processedCount };
        } finally {
            this.isSyncing = false;
        }
    }

    /**
     * Full bidirectional sync
     */
    async fullSync() {
        const toBackendResult = await this.syncToBackend();
        const fromBackendResult = await this.syncFromBackend();

        return {
            pushed: toBackendResult.synced,
            pulled: fromBackendResult.processed
        };
    }

    /**
     * Sync a single entry to backend
     */
    async syncEntry(entry) {
        const endpoint = `${this.supabaseUrl}/rest/v1/vocabulary`;

        const payload = this.createSyncPayload(entry);

        const method = entry.backendId ? 'PATCH' : 'POST';
        const url = entry.backendId
            ? `${endpoint}?id=eq.${entry.backendId}`
            : endpoint;

        const response = await fetch(url, {
            method: method,
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.supabaseKey}`,
                'apikey': this.supabaseKey,
                'Prefer': 'return=representation'
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            throw new Error(`Server error: ${response.status}`);
        }

        const data = await response.json();

        if (Array.isArray(data) && data.length > 0) {
            const backendId = data[0].id;

            // Update local entry
            entry.backendId = backendId;
            entry.syncStatus = 'synced';
            await this.storage.updateWord(entry);

            console.log(`[VocabularySyncService] Synced: ${entry.word} -> ${backendId}`);
        }
    }

    /**
     * Create payload for sync request
     */
    createSyncPayload(entry) {
        const payload = {
            word: entry.word,
            mastery_level: entry.masteryLevel || 0,
            ease_factor: entry.easeFactor || 2.5,
            interval: entry.interval || 0,
            review_count: entry.reviewCount || 0,
            correct_count: entry.correctCount || 0,
            is_favorite: entry.isFavorite || false,
            is_archived: entry.isArchived || false,
            created_at: entry.createdAt,
            updated_at: entry.updatedAt || new Date().toISOString(),
            local_id: entry.id
        };

        // Add optional fields
        if (entry.phonetic) payload.phonetic = entry.phonetic;
        if (entry.partOfSpeech) payload.part_of_speech = entry.partOfSpeech;
        if (entry.definitionEN) payload.definition_en = entry.definitionEN;
        if (entry.definitionCN) payload.definition_cn = entry.definitionCN;
        if (entry.examples) payload.example_sentences = JSON.stringify(entry.examples);
        if (entry.synonyms) payload.synonyms = Array.isArray(entry.synonyms) ? entry.synonyms.join(',') : entry.synonyms;
        if (entry.antonyms) payload.antonyms = Array.isArray(entry.antonyms) ? entry.antonyms.join(',') : entry.antonyms;
        if (entry.userContext) payload.user_context = entry.userContext;
        if (entry.category) payload.category = entry.category;
        if (entry.tags) payload.tags = Array.isArray(entry.tags) ? entry.tags.join(',') : entry.tags;
        if (entry.notes) payload.notes = entry.notes;
        if (entry.lastReviewedAt) payload.last_reviewed_at = entry.lastReviewedAt;
        if (entry.nextReviewAt) payload.next_review_at = entry.nextReviewAt;

        return payload;
    }

    /**
     * Fetch entries from backend
     */
    async fetchRemoteEntries() {
        let endpoint = `${this.supabaseUrl}/rest/v1/vocabulary?select=*`;

        // Fetch entries updated after last sync
        if (this.lastSyncDate) {
            const isoDate = this.lastSyncDate.toISOString();
            endpoint += `&updated_at=gt.${isoDate}`;
        }

        const response = await fetch(endpoint, {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.supabaseKey}`,
                'apikey': this.supabaseKey
            }
        });

        if (!response.ok) {
            throw new Error(`Server error: ${response.status}`);
        }

        return await response.json();
    }

    /**
     * Process a remote entry - merge with local or create new
     */
    async processRemoteEntry(remoteEntry) {
        const word = remoteEntry.word;
        if (!word) return;

        // Check if entry exists locally
        const allWords = await this.storage.getAllWords();
        const existingEntry = allWords.find(w => w.word.toLowerCase() === word.toLowerCase());

        if (existingEntry) {
            // Conflict resolution: compare updated_at timestamps
            const remoteUpdated = new Date(remoteEntry.updated_at);
            const localUpdated = new Date(existingEntry.updatedAt);

            if (remoteUpdated > localUpdated) {
                // Remote is newer - update local
                this.updateLocalEntry(existingEntry, remoteEntry);
                await this.storage.updateWord(existingEntry);
                console.log(`[VocabularySyncService] Updated local: ${word}`);
            }
            // Otherwise keep local version
        } else {
            // New entry from remote - create locally
            const newEntry = this.createLocalEntry(remoteEntry);
            await this.storage.addWord(newEntry);
            console.log(`[VocabularySyncService] Created local from remote: ${word}`);
        }
    }

    /**
     * Update local entry from remote data
     */
    updateLocalEntry(localEntry, remoteEntry) {
        if (remoteEntry.phonetic) localEntry.phonetic = remoteEntry.phonetic;
        if (remoteEntry.part_of_speech) localEntry.partOfSpeech = remoteEntry.part_of_speech;
        if (remoteEntry.definition_en) localEntry.definitionEN = remoteEntry.definition_en;
        if (remoteEntry.definition_cn) localEntry.definitionCN = remoteEntry.definition_cn;
        if (remoteEntry.example_sentences) {
            try {
                localEntry.examples = JSON.parse(remoteEntry.example_sentences);
            } catch (e) {
                localEntry.examples = [];
            }
        }
        if (remoteEntry.synonyms) localEntry.synonyms = remoteEntry.synonyms.split(',');
        if (remoteEntry.antonyms) localEntry.antonyms = remoteEntry.antonyms.split(',');
        if (remoteEntry.user_context) localEntry.userContext = remoteEntry.user_context;
        if (remoteEntry.category) localEntry.category = remoteEntry.category;
        if (remoteEntry.tags) localEntry.tags = remoteEntry.tags.split(',');
        if (remoteEntry.notes) localEntry.notes = remoteEntry.notes;

        // Learning progress
        if (remoteEntry.mastery_level !== undefined) localEntry.masteryLevel = remoteEntry.mastery_level;
        if (remoteEntry.ease_factor !== undefined) localEntry.easeFactor = remoteEntry.ease_factor;
        if (remoteEntry.interval !== undefined) localEntry.interval = remoteEntry.interval;
        if (remoteEntry.review_count !== undefined) localEntry.reviewCount = remoteEntry.review_count;
        if (remoteEntry.correct_count !== undefined) localEntry.correctCount = remoteEntry.correct_count;

        if (remoteEntry.is_favorite !== undefined) localEntry.isFavorite = remoteEntry.is_favorite;
        if (remoteEntry.is_archived !== undefined) localEntry.isArchived = remoteEntry.is_archived;

        if (remoteEntry.last_reviewed_at) localEntry.lastReviewedAt = remoteEntry.last_reviewed_at;
        if (remoteEntry.next_review_at) localEntry.nextReviewAt = remoteEntry.next_review_at;
        if (remoteEntry.updated_at) localEntry.updatedAt = remoteEntry.updated_at;

        localEntry.backendId = remoteEntry.id;
        localEntry.syncStatus = 'synced';
    }

    /**
     * Create local entry from remote data
     */
    createLocalEntry(remoteEntry) {
        const entry = {
            id: `vocab_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            word: remoteEntry.word,
            phonetic: remoteEntry.phonetic,
            partOfSpeech: remoteEntry.part_of_speech,
            definitionEN: remoteEntry.definition_en,
            definitionCN: remoteEntry.definition_cn,
            examples: [],
            synonyms: [],
            antonyms: [],
            userContext: remoteEntry.user_context,
            category: remoteEntry.category || 'General',
            tags: [],
            notes: remoteEntry.notes,
            isFavorite: remoteEntry.is_favorite || false,
            isArchived: remoteEntry.is_archived || false,
            masteryLevel: remoteEntry.mastery_level || 0,
            easeFactor: remoteEntry.ease_factor || 2.5,
            interval: remoteEntry.interval || 0,
            reviewCount: remoteEntry.review_count || 0,
            correctCount: remoteEntry.correct_count || 0,
            lastReviewedAt: remoteEntry.last_reviewed_at,
            nextReviewAt: remoteEntry.next_review_at || new Date().toISOString(),
            createdAt: remoteEntry.created_at || new Date().toISOString(),
            updatedAt: remoteEntry.updated_at || new Date().toISOString(),
            backendId: remoteEntry.id,
            syncStatus: 'synced'
        };

        // Parse examples
        if (remoteEntry.example_sentences) {
            try {
                entry.examples = JSON.parse(remoteEntry.example_sentences);
            } catch (e) {
                entry.examples = [];
            }
        }

        // Parse arrays
        if (remoteEntry.synonyms) {
            entry.synonyms = remoteEntry.synonyms.split(',').filter(s => s.trim());
        }
        if (remoteEntry.antonyms) {
            entry.antonyms = remoteEntry.antonyms.split(',').filter(s => s.trim());
        }
        if (remoteEntry.tags) {
            entry.tags = remoteEntry.tags.split(',').filter(t => t.trim());
        }

        return entry;
    }
}

export default new VocabularySyncService();
