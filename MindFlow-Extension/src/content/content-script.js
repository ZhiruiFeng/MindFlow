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
  });

  console.log('[MindFlow] Content script loaded');
}
