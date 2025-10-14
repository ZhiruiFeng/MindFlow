/**
 * @fileoverview History page controller
 * @module history
 */

import { log, logError, copyToClipboard } from '../common/utils.js';
import storageManager from '../lib/storage-manager.js';
import supabaseAuth from '../lib/supabase-auth.js';
import zmemoryAPI from '../lib/zmemory-api.js';

class HistoryController {
  constructor() {
    this.elements = {};
    this.history = [];
    this.filteredHistory = [];
    this.currentFilter = 'all';
    this.searchQuery = '';
    this.selectedEntry = null;
  }

  /**
   * Initialize history page
   */
  async init() {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.setup());
    } else {
      this.setup();
    }
  }

  /**
   * Setup after DOM ready
   */
  async setup() {
    this.cacheElements();
    this.attachEventListeners();

    // Initialize auth service
    await supabaseAuth.initialize();
    await zmemoryAPI.initialize();

    await this.loadHistory();

    log('History page ready');
  }

  /**
   * Cache DOM elements
   */
  cacheElements() {
    this.elements = {
      // Header
      clearAllBtn: document.getElementById('clear-all-btn'),
      closeBtn: document.getElementById('close-btn'),

      // Toolbar
      searchInput: document.getElementById('search-input'),
      filterButtons: document.querySelectorAll('.filter-btn'),

      // Content
      emptyState: document.getElementById('empty-state'),
      historyList: document.getElementById('history-list'),
      loading: document.getElementById('loading'),
      openSettingsBtn: document.getElementById('open-settings-btn'),

      // Footer
      historyCount: document.getElementById('history-count'),

      // Modal
      modal: document.getElementById('detail-modal'),
      modalCloseBtn: document.getElementById('modal-close-btn'),
      modalOriginal: document.getElementById('modal-original'),
      modalOptimized: document.getElementById('modal-optimized'),
      modalTeacherNotesSection: document.getElementById('modal-teacher-notes-section'),
      modalTeacherNotes: document.getElementById('modal-teacher-notes'),
      modalLevel: document.getElementById('modal-level'),
      modalDate: document.getElementById('modal-date'),
      modalCopyBtn: document.getElementById('modal-copy-btn'),
      modalDeleteBtn: document.getElementById('modal-delete-btn'),

      // Toast
      toast: document.getElementById('toast'),
      toastMessage: document.getElementById('toast-message')
    };
  }

  /**
   * Attach event listeners
   */
  attachEventListeners() {
    // Header actions
    this.elements.clearAllBtn.addEventListener('click', () => this.handleClearAll());
    this.elements.closeBtn.addEventListener('click', () => window.close());

    // Toolbar
    this.elements.searchInput.addEventListener('input', (e) => {
      this.searchQuery = e.target.value.toLowerCase();
      this.applyFilters();
    });

    this.elements.filterButtons.forEach(btn => {
      btn.addEventListener('click', (e) => {
        this.currentFilter = e.target.dataset.filter;
        this.elements.filterButtons.forEach(b => b.classList.remove('active'));
        e.target.classList.add('active');
        this.applyFilters();
      });
    });

    // Empty state
    if (this.elements.openSettingsBtn) {
      this.elements.openSettingsBtn.addEventListener('click', () => {
        chrome.runtime.openOptionsPage();
      });
    }

    // Modal
    this.elements.modalCloseBtn.addEventListener('click', () => this.closeModal());
    this.elements.modal.addEventListener('click', (e) => {
      if (e.target === this.elements.modal) {
        this.closeModal();
      }
    });

    this.elements.modalCopyBtn.addEventListener('click', () => this.handleModalCopy());
    this.elements.modalDeleteBtn.addEventListener('click', () => this.handleModalDelete());

    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        this.closeModal();
      }
    });
  }

  /**
   * Load history from storage
   */
  async loadHistory() {
    this.showLoading(true);

    try {
      this.history = await storageManager.getHistory();
      log('History loaded:', this.history.length, 'entries');

      this.applyFilters();
      this.updateCount();

      if (this.history.length === 0) {
        this.showEmptyState(true);
      } else {
        this.showEmptyState(false);
      }
    } catch (error) {
      logError('Failed to load history:', error);
      this.showToast('⚠️ Failed to load history');
    } finally {
      this.showLoading(false);
    }
  }

  /**
   * Apply filters and search
   */
  applyFilters() {
    let filtered = [...this.history];

    // Apply time filter
    const now = Date.now();
    const oneDayAgo = now - 24 * 60 * 60 * 1000;
    const oneWeekAgo = now - 7 * 24 * 60 * 60 * 1000;

    switch (this.currentFilter) {
      case 'today':
        filtered = filtered.filter(entry => entry.timestamp >= oneDayAgo);
        break;
      case 'week':
        filtered = filtered.filter(entry => entry.timestamp >= oneWeekAgo);
        break;
      case 'all':
      default:
        // No filter
        break;
    }

    // Apply search
    if (this.searchQuery) {
      filtered = filtered.filter(entry => {
        const original = (entry.original || '').toLowerCase();
        const optimized = (entry.optimized || '').toLowerCase();
        return original.includes(this.searchQuery) || optimized.includes(this.searchQuery);
      });
    }

    this.filteredHistory = filtered;
    this.renderHistory();
  }

  /**
   * Render history list
   */
  renderHistory() {
    if (this.filteredHistory.length === 0 && this.history.length > 0) {
      // Has history but nothing matches filter/search - create empty state safely
      this.elements.historyList.textContent = '';

      const emptyState = document.createElement('div');
      emptyState.className = 'empty-state';
      emptyState.style.minHeight = '200px';

      const icon = document.createElement('div');
      icon.className = 'empty-icon';
      icon.textContent = '🔍';

      const heading = document.createElement('h3');
      heading.textContent = 'No Results Found';

      const text = document.createElement('p');
      text.textContent = 'Try adjusting your search or filter.';

      emptyState.appendChild(icon);
      emptyState.appendChild(heading);
      emptyState.appendChild(text);
      this.elements.historyList.appendChild(emptyState);
      return;
    }

    this.elements.historyList.textContent = '';

    this.filteredHistory.forEach(entry => {
      const item = this.createHistoryItem(entry);
      this.elements.historyList.appendChild(item);
    });
  }

  /**
   * Create history item element
   */
  createHistoryItem(entry) {
    const item = document.createElement('div');
    item.className = 'history-item';
    item.dataset.id = entry.id;

    const date = new Date(entry.timestamp);
    const dateStr = this.formatDate(date);

    // Determine sync status
    const isAuthenticated = zmemoryAPI.isAuthenticated();

    log('📊 History item sync status:', {
      entryId: entry.id,
      syncedToBackend: entry.syncedToBackend,
      isAuthenticated: isAuthenticated,
      audioDuration: entry.audioDuration
    });

    // Build structure safely using DOM methods
    const header = document.createElement('div');
    header.className = 'history-item-header';

    const dateSpan = document.createElement('span');
    dateSpan.className = 'history-item-date';
    dateSpan.textContent = dateStr;

    const actions = document.createElement('div');
    actions.className = 'history-item-actions';

    const copyBtn = document.createElement('button');
    copyBtn.className = 'icon-btn copy-btn';
    copyBtn.title = 'Copy';
    copyBtn.dataset.id = entry.id;
    copyBtn.textContent = '📋';

    const deleteBtn = document.createElement('button');
    deleteBtn.className = 'icon-btn delete-btn';
    deleteBtn.title = 'Delete';
    deleteBtn.dataset.id = entry.id;
    deleteBtn.textContent = '🗑️';

    actions.appendChild(copyBtn);
    actions.appendChild(deleteBtn);
    header.appendChild(dateSpan);
    header.appendChild(actions);

    const textDiv = document.createElement('div');
    textDiv.className = 'history-item-text';
    textDiv.textContent = entry.optimized || entry.original;

    const footer = document.createElement('div');
    footer.className = 'history-item-footer';

    // Add level badge
    footer.appendChild(this.getLevelBadge(entry.level));

    // Add duration badge if available
    if (entry.audioDuration) {
      const durationBadge = document.createElement('span');
      durationBadge.className = 'duration-badge';
      durationBadge.textContent = Math.round(entry.audioDuration) + 's';
      footer.appendChild(durationBadge);
    }

    // Add sync status
    if (entry.syncedToBackend) {
      const syncBadge = document.createElement('span');
      syncBadge.className = 'sync-badge synced';
      syncBadge.title = 'Synced to ZephyrOS';
      syncBadge.textContent = '✓ Synced';
      footer.appendChild(syncBadge);
    } else if (isAuthenticated) {
      const syncBtn = document.createElement('button');
      syncBtn.className = 'sync-btn';
      syncBtn.dataset.id = entry.id;
      syncBtn.title = 'Sync to ZephyrOS';
      syncBtn.textContent = '↑ Sync';
      footer.appendChild(syncBtn);
    } else {
      const syncBadge = document.createElement('span');
      syncBadge.className = 'sync-badge not-synced';
      syncBadge.title = 'Sign in to sync';
      syncBadge.textContent = 'Local only';
      footer.appendChild(syncBadge);
    }

    item.appendChild(header);
    item.appendChild(textDiv);
    item.appendChild(footer);

    // Click to view details (except on buttons)
    item.addEventListener('click', (e) => {
      if (!e.target.closest('.icon-btn')) {
        this.showDetail(entry);
      }
    });

    // Copy button
    const copyBtn = item.querySelector('.copy-btn');
    copyBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      this.handleCopy(entry);
    });

    // Delete button
    const deleteBtn = item.querySelector('.delete-btn');
    deleteBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      this.handleDelete(entry.id);
    });

    // Sync button (if present)
    const syncBtn = item.querySelector('.sync-btn');
    if (syncBtn) {
      syncBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        this.handleSync(entry);
      });
    }

    return item;
  }

  /**
   * Handle manual sync to backend
   */
  async handleSync(entry) {
    if (!zmemoryAPI.isAuthenticated()) {
      this.showToast('Please sign in first to sync to ZephyrOS');
      return;
    }

    try {
      log('Manually syncing entry:', entry.id);
      this.showToast('Syncing to ZephyrOS...', 10000);

      // Get current settings for mapping
      const settings = await storageManager.getSettings();

      // Map provider names
      const transcriptionApi = 'OpenAI'; // Default since we don't store this in history

      // Map output style
      const outputStyle = settings.outputStyle === 'casual' ? 'conversational' : 'formal';

      const interaction = {
        transcriptionApi: transcriptionApi,
        transcriptionModel: 'whisper-1',
        optimizationModel: settings.llmModel || 'gpt-4o-mini',
        optimizationLevel: entry.level || settings.optimizationLevel,
        outputStyle: outputStyle,
        originalText: entry.original,
        optimizedText: entry.optimized,
        teacherNotes: entry.teacherNotes || null,
        audioDurationSeconds: entry.audioDuration || null
      };

      const result = await zmemoryAPI.createInteraction(interaction);

      // Update entry in history
      entry.syncedToBackend = true;
      entry.backendId = result.id;
      await storageManager.updateHistoryEntry(entry.id, {
        syncedToBackend: true,
        backendId: result.id
      });

      // Reload history to update UI
      await this.loadHistory();

      this.showToast('✓ Synced to ZephyrOS');
      log('Entry synced successfully:', result.id);
    } catch (error) {
      logError('Manual sync error:', error);
      this.showToast('⚠️ Failed to sync: ' + error.message);
    }
  }

  /**
   * Show detail modal
   */
  showDetail(entry) {
    this.selectedEntry = entry;

    this.elements.modalOriginal.textContent = entry.original;
    this.elements.modalOptimized.textContent = entry.optimized;

    // Show/hide teacher notes
    if (entry.teacherNotes) {
      this.elements.modalTeacherNotes.textContent = entry.teacherNotes;
      this.elements.modalTeacherNotesSection.style.display = 'block';
    } else {
      this.elements.modalTeacherNotesSection.style.display = 'none';
    }

    const levelText = (entry.level || 'medium').charAt(0).toUpperCase() +
                      (entry.level || 'medium').slice(1);
    this.elements.modalLevel.textContent = levelText;
    this.elements.modalLevel.className = `badge ${entry.level || 'medium'}`;

    const date = new Date(entry.timestamp);
    this.elements.modalDate.textContent = this.formatDate(date);

    this.elements.modal.style.display = 'flex';
  }

  /**
   * Close modal
   */
  closeModal() {
    this.elements.modal.style.display = 'none';
    this.selectedEntry = null;
  }

  /**
   * Handle copy from history item
   */
  async handleCopy(entry) {
    const text = entry.optimized || entry.original;
    const success = await copyToClipboard(text);

    if (success) {
      this.showToast('✓ Copied to clipboard');
    } else {
      this.showToast('⚠️ Failed to copy');
    }
  }

  /**
   * Handle modal copy
   */
  async handleModalCopy() {
    if (!this.selectedEntry) return;

    const text = this.selectedEntry.optimized || this.selectedEntry.original;
    const success = await copyToClipboard(text);

    if (success) {
      this.showToast('✓ Copied to clipboard');
    } else {
      this.showToast('⚠️ Failed to copy');
    }
  }

  /**
   * Handle delete
   */
  async handleDelete(id) {
    if (!confirm('Delete this entry?')) {
      return;
    }

    try {
      await storageManager.deleteHistoryEntry(id);
      this.history = this.history.filter(entry => entry.id !== id);
      this.applyFilters();
      this.updateCount();

      if (this.history.length === 0) {
        this.showEmptyState(true);
      }

      this.showToast('✓ Entry deleted');
    } catch (error) {
      logError('Failed to delete entry:', error);
      this.showToast('⚠️ Failed to delete');
    }
  }

  /**
   * Handle modal delete
   */
  async handleModalDelete() {
    if (!this.selectedEntry) return;

    this.closeModal();
    await this.handleDelete(this.selectedEntry.id);
  }

  /**
   * Handle clear all
   */
  async handleClearAll() {
    if (!confirm('Clear all history? This cannot be undone.')) {
      return;
    }

    try {
      await storageManager.clearHistory();
      this.history = [];
      this.filteredHistory = [];
      this.renderHistory();
      this.updateCount();
      this.showEmptyState(true);
      this.showToast('✓ History cleared');
    } catch (error) {
      logError('Failed to clear history:', error);
      this.showToast('⚠️ Failed to clear history');
    }
  }

  /**
   * Update history count
   */
  updateCount() {
    this.elements.historyCount.textContent = this.history.length;
  }

  /**
   * Show/hide empty state
   */
  showEmptyState(show) {
    this.elements.emptyState.style.display = show ? 'flex' : 'none';
    this.elements.historyList.style.display = show ? 'none' : 'block';
  }

  /**
   * Show/hide loading
   */
  showLoading(show) {
    this.elements.loading.style.display = show ? 'flex' : 'none';
    this.elements.historyList.style.display = show ? 'none' : 'block';
  }

  /**
   * Get level badge element (returns DOM element, not HTML string)
   */
  getLevelBadge(level) {
    const levelMap = {
      light: 'Light',
      medium: 'Medium',
      heavy: 'Heavy'
    };
    const text = levelMap[level] || 'Medium';
    const badge = document.createElement('span');
    badge.className = `badge ${level || 'medium'}`;
    badge.textContent = text;
    return badge;
  }

  /**
   * Format date
   */
  formatDate(date) {
    const now = new Date();
    const diff = now - date;
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);

    if (minutes < 1) {
      return 'Just now';
    } else if (minutes < 60) {
      return `${minutes} minute${minutes === 1 ? '' : 's'} ago`;
    } else if (hours < 24) {
      return `${hours} hour${hours === 1 ? '' : 's'} ago`;
    } else if (days < 7) {
      return `${days} day${days === 1 ? '' : 's'} ago`;
    } else {
      return date.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    }
  }

  /**
   * Escape HTML
   */
  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  /**
   * Show toast notification
   */
  showToast(message, duration = 3000) {
    this.elements.toastMessage.textContent = message;
    this.elements.toast.style.display = 'block';

    setTimeout(() => {
      this.elements.toast.style.display = 'none';
    }, duration);
  }
}

// Initialize history page
const history = new HistoryController();
history.init();
