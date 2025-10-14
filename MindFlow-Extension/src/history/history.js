/**
 * @fileoverview History page controller
 * @module history
 */

import { log, logError, copyToClipboard } from '../common/utils.js';
import storageManager from '../lib/storage-manager.js';

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
      // Has history but nothing matches filter/search
      this.elements.historyList.innerHTML = `
        <div class="empty-state" style="min-height: 200px;">
          <div class="empty-icon">🔍</div>
          <h3>No Results Found</h3>
          <p>Try adjusting your search or filter.</p>
        </div>
      `;
      return;
    }

    this.elements.historyList.innerHTML = '';

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

    const levelBadge = this.getLevelBadge(entry.level);

    item.innerHTML = `
      <div class="history-item-header">
        <span class="history-item-date">${dateStr}</span>
        <div class="history-item-actions">
          <button class="icon-btn copy-btn" title="Copy" data-id="${entry.id}">📋</button>
          <button class="icon-btn delete-btn" title="Delete" data-id="${entry.id}">🗑️</button>
        </div>
      </div>
      <div class="history-item-text">${this.escapeHtml(entry.optimized || entry.original)}</div>
      <div class="history-item-footer">
        ${levelBadge}
      </div>
    `;

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

    return item;
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
   * Get level badge HTML
   */
  getLevelBadge(level) {
    const levelMap = {
      light: 'Light',
      medium: 'Medium',
      heavy: 'Heavy'
    };
    const text = levelMap[level] || 'Medium';
    return `<span class="badge ${level || 'medium'}">${text}</span>`;
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
