/**
 * @fileoverview Content script for inserting text into web pages
 * @module content-script
 *
 * Injected into web pages to:
 * - Detect active input fields
 * - Insert text at cursor position
 * - Handle different input types (textarea, input, contenteditable)
 * - Work with popular frameworks (React, Vue, Angular)
 */

// Avoid re-injecting
if (!window.__MINDFLOW_CONTENT_SCRIPT_LOADED__) {
  window.__MINDFLOW_CONTENT_SCRIPT_LOADED__ = true;

  // Vocabulary popup state
  let vocabularyPopup = null;
  let currentSelectedText = '';

  /**
   * Insert text into active element
   * @param {string} text - Text to insert
   * @returns {Object} Result with success status
   */
  function insertText(text) {
    const activeElement = document.activeElement;

    if (!activeElement) {
      return {
        success: false,
        error: 'No active element found'
      };
    }

    try {
      // Handle different element types
      if (activeElement.tagName === 'TEXTAREA' ||
          (activeElement.tagName === 'INPUT' && activeElement.type === 'text')) {
        return insertIntoTextInput(activeElement, text);
      } else if (activeElement.isContentEditable || activeElement.contentEditable === 'true') {
        return insertIntoContentEditable(activeElement, text);
      } else {
        return {
          success: false,
          error: 'Active element is not editable. Please click in a text field first.'
        };
      }
    } catch (error) {
      console.error('[MindFlow] Insert error:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Insert text into textarea or input element
   * @param {HTMLElement} element - Input element
   * @param {string} text - Text to insert
   * @returns {Object} Result
   */
  function insertIntoTextInput(element, text) {
    const start = element.selectionStart;
    const end = element.selectionEnd;
    const value = element.value;

    // Insert text at cursor position
    const newValue = value.substring(0, start) + text + value.substring(end);
    element.value = newValue;

    // Set cursor position after inserted text
    const newCursorPos = start + text.length;
    element.selectionStart = newCursorPos;
    element.selectionEnd = newCursorPos;

    // Trigger input event for frameworks (React, Vue, etc.)
    element.dispatchEvent(new Event('input', { bubbles: true }));
    element.dispatchEvent(new Event('change', { bubbles: true }));

    // Focus element
    element.focus();

    return {
      success: true,
      insertedAt: start,
      length: text.length
    };
  }

  /**
   * Insert text into contenteditable element
   * @param {HTMLElement} element - Contenteditable element
   * @param {string} text - Text to insert
   * @returns {Object} Result
   */
  function insertIntoContentEditable(element, text) {
    // Try using document.execCommand first (works in most cases)
    if (document.execCommand) {
      element.focus();

      const success = document.execCommand('insertText', false, text);

      if (success) {
        // Trigger input event
        element.dispatchEvent(new Event('input', { bubbles: true }));

        return {
          success: true
        };
      }
    }

    // Fallback: Use Selection API
    const selection = window.getSelection();

    if (selection.rangeCount === 0) {
      // No selection, append to end
      element.focus();

      const range = document.createRange();
      range.selectNodeContents(element);
      range.collapse(false);
      selection.removeAllRanges();
      selection.addRange(range);
    }

    const range = selection.getRangeAt(0);
    range.deleteContents();

    const textNode = document.createTextNode(text);
    range.insertNode(textNode);

    // Move cursor to end of inserted text
    range.setStartAfter(textNode);
    range.setEndAfter(textNode);
    selection.removeAllRanges();
    selection.addRange(range);

    // Trigger input event
    element.dispatchEvent(new Event('input', { bubbles: true }));

    return {
      success: true
    };
  }

  /**
   * Find and focus nearest editable element
   * Useful if no element is currently focused
   * @returns {HTMLElement|null} Found element or null
   */
  function findEditableElement() {
    // Look for visible text inputs
    const inputs = document.querySelectorAll('textarea, input[type="text"], [contenteditable="true"]');

    for (const input of inputs) {
      // Check if visible
      const rect = input.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) {
        return input;
      }
    }

    return null;
  }

  /**
   * Get active element info
   * @returns {Object} Info about active element
   */
  function getActiveElementInfo() {
    const activeElement = document.activeElement;

    if (!activeElement) {
      return {
        hasActive: false
      };
    }

    const isEditable = activeElement.tagName === 'TEXTAREA' ||
                       (activeElement.tagName === 'INPUT' && activeElement.type === 'text') ||
                       activeElement.isContentEditable;

    return {
      hasActive: true,
      isEditable: isEditable,
      tagName: activeElement.tagName,
      type: activeElement.type,
      id: activeElement.id,
      className: activeElement.className
    };
  }

  // Listen for messages from popup/background
  chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.type === 'INSERT_TEXT') {
      const result = insertText(request.text);
      sendResponse(result);
      return true;
    }

    if (request.type === 'GET_ACTIVE_ELEMENT_INFO') {
      const info = getActiveElementInfo();
      sendResponse(info);
      return true;
    }

    if (request.type === 'FIND_EDITABLE') {
      const element = findEditableElement();
      if (element) {
        element.focus();
        sendResponse({ success: true });
      } else {
        sendResponse({
          success: false,
          error: 'No editable element found'
        });
      }
      return true;
    }

    // Vocabulary lookup response
    if (request.type === 'VOCABULARY_LOOKUP_RESULT') {
      showVocabularyResult(request.result, request.error);
      sendResponse({ success: true });
      return true;
    }

    // Show vocabulary popup for selected text
    if (request.type === 'SHOW_VOCABULARY_POPUP') {
      const selectedText = window.getSelection().toString().trim();
      if (selectedText) {
        showVocabularyPopup(selectedText);
      }
      sendResponse({ success: true });
      return true;
    }
  });

  // ============================================
  // Vocabulary Popup Functions
  // ============================================

  /**
   * Create and show vocabulary popup near selection
   * @param {string} word - Selected word
   */
  function showVocabularyPopup(word) {
    // Remove existing popup
    removeVocabularyPopup();

    currentSelectedText = word;

    // Get selection position
    const selection = window.getSelection();
    if (!selection.rangeCount) return;

    const range = selection.getRangeAt(0);
    const rect = range.getBoundingClientRect();

    // Create popup
    vocabularyPopup = document.createElement('div');
    vocabularyPopup.id = 'mindflow-vocabulary-popup';
    vocabularyPopup.innerHTML = `
      <div class="mindflow-popup-header">
        <span class="mindflow-popup-word">${escapeHtml(word)}</span>
        <button class="mindflow-popup-close">&times;</button>
      </div>
      <div class="mindflow-popup-content">
        <div class="mindflow-popup-loading">
          <div class="mindflow-spinner"></div>
          <span>Looking up...</span>
        </div>
      </div>
      <div class="mindflow-popup-actions" style="display: none;">
        <button class="mindflow-btn mindflow-btn-primary mindflow-add-btn">
          Add to Vocabulary
        </button>
      </div>
    `;

    // Position popup
    const popupTop = rect.bottom + window.scrollY + 10;
    const popupLeft = Math.max(10, rect.left + window.scrollX);

    vocabularyPopup.style.cssText = `
      position: absolute;
      top: ${popupTop}px;
      left: ${popupLeft}px;
      z-index: 2147483647;
      background: white;
      border-radius: 12px;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
      width: 320px;
      max-width: calc(100vw - 20px);
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      font-size: 14px;
      color: #333;
    `;

    // Add styles
    injectVocabularyStyles();

    document.body.appendChild(vocabularyPopup);

    // Attach event listeners
    vocabularyPopup.querySelector('.mindflow-popup-close').addEventListener('click', removeVocabularyPopup);
    vocabularyPopup.querySelector('.mindflow-add-btn').addEventListener('click', addWordToVocabulary);

    // Request lookup from background
    chrome.runtime.sendMessage({
      type: 'VOCABULARY_LOOKUP',
      word: word,
      context: getSelectionContext()
    });
  }

  /**
   * Show vocabulary lookup result
   * @param {Object} result - Lookup result
   * @param {string} error - Error message if any
   */
  function showVocabularyResult(result, error) {
    if (!vocabularyPopup) return;

    const content = vocabularyPopup.querySelector('.mindflow-popup-content');
    const actions = vocabularyPopup.querySelector('.mindflow-popup-actions');

    if (error) {
      content.innerHTML = `
        <div class="mindflow-popup-error">
          <span>Failed to lookup word</span>
          <p>${escapeHtml(error)}</p>
        </div>
      `;
      return;
    }

    // Store result for adding
    vocabularyPopup.dataset.result = JSON.stringify(result);

    content.innerHTML = `
      ${result.phonetic ? `<p class="mindflow-phonetic">${escapeHtml(result.phonetic)}</p>` : ''}
      ${result.partOfSpeech ? `<span class="mindflow-pos">${escapeHtml(result.partOfSpeech)}</span>` : ''}
      <div class="mindflow-definition">
        ${result.definitionEN ? `<p>${escapeHtml(result.definitionEN)}</p>` : ''}
        ${result.definitionCN ? `<p class="mindflow-cn">${escapeHtml(result.definitionCN)}</p>` : ''}
      </div>
      ${result.examples && result.examples.length > 0 ? `
        <div class="mindflow-example">
          <p class="mindflow-example-sentence">"${escapeHtml(result.examples[0].sentence)}"</p>
          ${result.examples[0].translation ? `<p class="mindflow-example-translation">${escapeHtml(result.examples[0].translation)}</p>` : ''}
        </div>
      ` : ''}
    `;

    actions.style.display = 'block';
  }

  /**
   * Add word to vocabulary
   */
  function addWordToVocabulary() {
    if (!vocabularyPopup) return;

    const resultData = vocabularyPopup.dataset.result;
    if (!resultData) return;

    const result = JSON.parse(resultData);
    const context = getSelectionContext();

    chrome.runtime.sendMessage({
      type: 'VOCABULARY_ADD',
      word: result,
      context: context
    }, (response) => {
      if (response && response.success) {
        showAddSuccess();
      } else {
        showAddError(response?.error || 'Failed to add word');
      }
    });
  }

  /**
   * Show success message after adding
   */
  function showAddSuccess() {
    if (!vocabularyPopup) return;

    const actions = vocabularyPopup.querySelector('.mindflow-popup-actions');
    actions.innerHTML = `
      <div class="mindflow-success">
        <span>✓ Added to vocabulary!</span>
      </div>
    `;

    setTimeout(removeVocabularyPopup, 1500);
  }

  /**
   * Show error message after adding
   * @param {string} error - Error message
   */
  function showAddError(error) {
    if (!vocabularyPopup) return;

    const actions = vocabularyPopup.querySelector('.mindflow-popup-actions');
    actions.innerHTML = `
      <div class="mindflow-error">
        <span>${escapeHtml(error)}</span>
      </div>
    `;
  }

  /**
   * Remove vocabulary popup
   */
  function removeVocabularyPopup() {
    if (vocabularyPopup) {
      vocabularyPopup.remove();
      vocabularyPopup = null;
    }
  }

  /**
   * Get context around selection
   * @returns {string} Context sentence
   */
  function getSelectionContext() {
    const selection = window.getSelection();
    if (!selection.rangeCount) return '';

    const range = selection.getRangeAt(0);
    const container = range.commonAncestorContainer;

    // Get parent element text
    const element = container.nodeType === Node.TEXT_NODE
      ? container.parentElement
      : container;

    const text = element.textContent || '';

    // Try to get the sentence containing the selection
    const selectedText = selection.toString().trim();
    const index = text.indexOf(selectedText);

    if (index === -1) return text.slice(0, 200);

    // Find sentence boundaries
    const beforeText = text.slice(0, index);
    const afterText = text.slice(index + selectedText.length);

    const sentenceStart = Math.max(
      beforeText.lastIndexOf('.'),
      beforeText.lastIndexOf('!'),
      beforeText.lastIndexOf('?'),
      0
    );

    const afterPeriod = afterText.search(/[.!?]/);
    const sentenceEnd = afterPeriod === -1
      ? text.length
      : index + selectedText.length + afterPeriod + 1;

    return text.slice(sentenceStart, sentenceEnd).trim();
  }

  /**
   * Escape HTML special characters
   * @param {string} text - Text to escape
   * @returns {string} Escaped text
   */
  function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  /**
   * Inject vocabulary popup styles
   */
  function injectVocabularyStyles() {
    if (document.getElementById('mindflow-vocabulary-styles')) return;

    const styles = document.createElement('style');
    styles.id = 'mindflow-vocabulary-styles';
    styles.textContent = `
      #mindflow-vocabulary-popup {
        animation: mindflow-fadeIn 0.2s ease;
      }

      @keyframes mindflow-fadeIn {
        from { opacity: 0; transform: translateY(-5px); }
        to { opacity: 1; transform: translateY(0); }
      }

      .mindflow-popup-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 12px 16px;
        border-bottom: 1px solid #e5e7eb;
      }

      .mindflow-popup-word {
        font-size: 18px;
        font-weight: 600;
        color: #1f2937;
      }

      .mindflow-popup-close {
        background: none;
        border: none;
        font-size: 20px;
        cursor: pointer;
        color: #9ca3af;
        padding: 0;
        line-height: 1;
      }

      .mindflow-popup-close:hover {
        color: #4b5563;
      }

      .mindflow-popup-content {
        padding: 16px;
      }

      .mindflow-popup-loading {
        display: flex;
        align-items: center;
        gap: 12px;
        color: #6b7280;
      }

      .mindflow-spinner {
        width: 20px;
        height: 20px;
        border: 2px solid #e5e7eb;
        border-top-color: #4f46e5;
        border-radius: 50%;
        animation: mindflow-spin 0.8s linear infinite;
      }

      @keyframes mindflow-spin {
        to { transform: rotate(360deg); }
      }

      .mindflow-phonetic {
        color: #6b7280;
        margin-bottom: 8px;
      }

      .mindflow-pos {
        display: inline-block;
        background: #dbeafe;
        color: #2563eb;
        padding: 2px 8px;
        border-radius: 4px;
        font-size: 12px;
        margin-bottom: 12px;
      }

      .mindflow-definition p {
        margin: 0 0 8px 0;
        line-height: 1.5;
      }

      .mindflow-cn {
        color: #6b7280;
      }

      .mindflow-example {
        background: #f9fafb;
        padding: 12px;
        border-radius: 8px;
        margin-top: 12px;
      }

      .mindflow-example-sentence {
        font-style: italic;
        margin: 0 0 4px 0;
      }

      .mindflow-example-translation {
        color: #6b7280;
        font-size: 13px;
        margin: 0;
      }

      .mindflow-popup-actions {
        padding: 12px 16px;
        border-top: 1px solid #e5e7eb;
      }

      .mindflow-btn {
        width: 100%;
        padding: 10px 16px;
        border-radius: 8px;
        border: none;
        cursor: pointer;
        font-size: 14px;
        font-weight: 500;
      }

      .mindflow-btn-primary {
        background: #4f46e5;
        color: white;
      }

      .mindflow-btn-primary:hover {
        background: #4338ca;
      }

      .mindflow-success {
        color: #059669;
        text-align: center;
        font-weight: 500;
      }

      .mindflow-error, .mindflow-popup-error {
        color: #dc2626;
        text-align: center;
      }

      .mindflow-popup-error p {
        margin: 8px 0 0 0;
        font-size: 13px;
      }
    `;

    document.head.appendChild(styles);
  }

  // Close popup when clicking outside
  document.addEventListener('click', (e) => {
    if (vocabularyPopup && !vocabularyPopup.contains(e.target)) {
      removeVocabularyPopup();
    }
  });

  // Close popup on scroll
  document.addEventListener('scroll', removeVocabularyPopup, { passive: true });

  console.log('[MindFlow] Content script loaded');
}
