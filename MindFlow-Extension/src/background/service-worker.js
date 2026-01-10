/**
 * @fileoverview Background service worker for MindFlow extension
 * @module service-worker
 *
 * Handles:
 * - Extension lifecycle events
 * - Keyboard shortcut commands
 * - Message passing between components
 * - Background task coordination
 *
 * Service workers are stateless and event-driven.
 * They terminate when idle and must handle state restoration.
 */

import { MESSAGE_TYPES, RECORDING_STATES } from '../common/constants.js';
import { log, logError } from '../common/utils.js';
import storageManager from '../lib/storage-manager.js';
import { VocabularyLookupService } from '../lib/vocabulary-lookup.js';

// Initialize vocabulary lookup service
const vocabularyLookup = new VocabularyLookupService();

// Extension installation
chrome.runtime.onInstalled.addListener(async (details) => {
  log('Extension installed:', details.reason);

  if (details.reason === 'install') {
    // First time installation
    log('First install - initializing default settings');

    // Initialize default settings
    const settings = await storageManager.getSettings();
    await storageManager.saveSettings(settings);

    // Open welcome/setup page (optional)
    // chrome.tabs.create({ url: 'src/settings/settings.html' });
  } else if (details.reason === 'update') {
    // Extension updated
    const previousVersion = details.previousVersion;
    const currentVersion = chrome.runtime.getManifest().version;
    log(`Updated from ${previousVersion} to ${currentVersion}`);

    // Handle migration if needed
    // await migrateData(previousVersion, currentVersion);
  }

  // Create context menu for vocabulary lookup
  chrome.contextMenus.create({
    id: 'mindflow-lookup-word',
    title: 'Look up "%s" in MindFlow',
    contexts: ['selection']
  });

  log('Context menu created');
});

// Context menu click handler
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId === 'mindflow-lookup-word') {
    const selectedText = info.selectionText?.trim();

    if (!selectedText) {
      log('No text selected');
      return;
    }

    log('Looking up word from context menu:', selectedText);

    // Inject content script if needed
    try {
      await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        files: ['src/content/content-script.js']
      });
      await new Promise(resolve => setTimeout(resolve, 50));
    } catch (error) {
      log('Content script injection skipped:', error.message);
    }

    // Send message to content script to show popup
    chrome.tabs.sendMessage(tab.id, {
      type: 'SHOW_VOCABULARY_POPUP'
    });
  }
});

// Extension startup (browser start)
chrome.runtime.onStartup.addListener(async () => {
  log('Extension started');

  // Restore any interrupted state
  const recordingState = await storageManager.getRecordingState();
  if (recordingState) {
    log('Found interrupted recording state:', recordingState.state);
    // Clean up interrupted recordings
    await storageManager.clearRecordingState();
  }
});

// Command shortcuts (e.g., Ctrl+Shift+V)
chrome.commands.onCommand.addListener(async (command) => {
  log('Command received:', command);

  if (command === 'start-recording') {
    // Get current tab
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

    if (!tab) {
      logError('No active tab found');
      return;
    }

    // Open popup or toggle recording
    try {
      // Check if popup is already open by trying to send a message
      await chrome.runtime.sendMessage({ type: 'TOGGLE_RECORDING' });
    } catch (error) {
      // Popup not open, open it
      chrome.action.openPopup();
    }
  }
});

// Message handling from popup, content scripts, etc.
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  log('Message received:', request.type, 'from:', sender.url);

  // Audio recording messages should be routed to offscreen document
  const audioMessages = ['START_RECORDING', 'STOP_RECORDING', 'PAUSE_RECORDING',
                         'RESUME_RECORDING', 'GET_AUDIO_LEVEL', 'CANCEL_RECORDING'];

  if (audioMessages.includes(request.type)) {
    routeToOffscreen(request, sendResponse);
    return true; // Keep channel open for async response
  }

  // Handle different message types
  switch (request.type) {
    case MESSAGE_TYPES.GET_SETTINGS:
      handleGetSettings(sendResponse);
      return true;

    case MESSAGE_TYPES.SAVE_SETTINGS:
      handleSaveSettings(request, sendResponse);
      return true;

    case MESSAGE_TYPES.INSERT_TEXT:
      handleInsertText(request, sender, sendResponse);
      return true;

    case MESSAGE_TYPES.VOCABULARY_LOOKUP:
    case 'VOCABULARY_LOOKUP':
      handleVocabularyLookup(request, sender, sendResponse);
      return true;

    case MESSAGE_TYPES.VOCABULARY_ADD:
    case 'VOCABULARY_ADD':
      handleVocabularyAdd(request, sendResponse);
      return true;

    case MESSAGE_TYPES.VOCABULARY_GET_DUE:
    case 'VOCABULARY_GET_DUE':
      handleVocabularyGetDue(sendResponse);
      return true;

    default:
      logError('Unknown message type:', request.type);
      sendResponse({ success: false, error: 'Unknown message type' });
      return false;
  }
});

/**
 * Route message to offscreen document
 */
async function routeToOffscreen(request, sendResponse) {
  try {
    // Ensure offscreen document exists
    await ensureOffscreenDocument();

    // Add a small delay to ensure offscreen is fully loaded
    await new Promise(resolve => setTimeout(resolve, 100));

    // The offscreen document listens on chrome.runtime.onMessage
    // Mark this message as intended for offscreen
    request.target = 'offscreen';

    // Forward the message - the offscreen document will handle it
    chrome.runtime.sendMessage(request, (response) => {
      if (chrome.runtime.lastError) {
        logError('Offscreen message error:', chrome.runtime.lastError);
        sendResponse({
          success: false,
          error: chrome.runtime.lastError.message
        });
      } else {
        sendResponse(response);
      }
    });
  } catch (error) {
    logError('Failed to route to offscreen:', error);
    sendResponse({
      success: false,
      error: error.message,
      errorName: error.name
    });
  }
}

/**
 * Ensure offscreen document exists
 */
async function ensureOffscreenDocument() {
  const existingContexts = await chrome.runtime.getContexts({
    contextTypes: ['OFFSCREEN_DOCUMENT']
  });

  if (existingContexts.length > 0) {
    return;
  }

  await chrome.offscreen.createDocument({
    url: 'src/offscreen/offscreen.html',
    reasons: ['USER_MEDIA'],
    justification: 'Recording audio from user microphone'
  });

  log('Offscreen document created');
}

/**
 * Handle start recording
 */
async function handleStartRecording(request, sendResponse) {
  try {
    log('Starting recording...');

    // Save recording state
    await storageManager.saveRecordingState({
      state: RECORDING_STATES.RECORDING,
      startedAt: Date.now()
    });

    sendResponse({ success: true });
  } catch (error) {
    logError('Start recording failed:', error);
    sendResponse({ success: false, error: error.message });
  }
}

/**
 * Handle stop recording
 */
async function handleStopRecording(request, sendResponse) {
  try {
    log('Stopping recording...');

    // Clear recording state
    await storageManager.clearRecordingState();

    sendResponse({ success: true });
  } catch (error) {
    logError('Stop recording failed:', error);
    sendResponse({ success: false, error: error.message });
  }
}

/**
 * Handle get settings
 */
async function handleGetSettings(sendResponse) {
  try {
    const settings = await storageManager.getSettings();
    sendResponse({ success: true, settings });
  } catch (error) {
    logError('Get settings failed:', error);
    sendResponse({ success: false, error: error.message });
  }
}

/**
 * Handle save settings
 */
async function handleSaveSettings(request, sendResponse) {
  try {
    const { settings } = request;
    await storageManager.saveSettings(settings);
    log('Settings saved');
    sendResponse({ success: true });
  } catch (error) {
    logError('Save settings failed:', error);
    sendResponse({ success: false, error: error.message });
  }
}

/**
 * Handle insert text into active field
 */
async function handleInsertText(request, sender, sendResponse) {
  try {
    const { text } = request;

    if (!text) {
      throw new Error('No text provided');
    }

    // Get active tab
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

    if (!tab) {
      throw new Error('No active tab found');
    }

    // Check if tab URL is restricted
    if (tab.url && (tab.url.startsWith('chrome://') ||
                     tab.url.startsWith('chrome-extension://') ||
                     tab.url.startsWith('edge://') ||
                     tab.url.startsWith('about:'))) {
      throw new Error('Cannot insert text on this page. Please use a regular webpage.');
    }

    // Inject content script if not already injected
    try {
      await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        files: ['src/content/content-script.js']
      });
      // Add a small delay to ensure script is loaded
      await new Promise(resolve => setTimeout(resolve, 50));
    } catch (error) {
      // Content script might already be injected, that's okay
      log('Content script injection skipped:', error.message);
    }

    // Send message to content script to insert text
    try {
      const response = await chrome.tabs.sendMessage(tab.id, {
        type: 'INSERT_TEXT',
        text: text
      });

      if (response && response.success) {
        log('Text inserted successfully');
        sendResponse({ success: true });
      } else {
        throw new Error(response?.error || 'Please click in a text field first');
      }
    } catch (error) {
      // Connection error usually means content script couldn't be injected
      if (error.message.includes('Receiving end does not exist')) {
        throw new Error('Cannot insert text on this page. Try using Copy instead.');
      }
      throw error;
    }
  } catch (error) {
    logError('Insert text failed:', error);
    sendResponse({ success: false, error: error.message });
  }
}

// Handle extension icon click (optional - popup handles this by default)
chrome.action.onClicked.addListener((tab) => {
  log('Extension icon clicked', tab.id);
  // Popup will open automatically due to default_popup in manifest
});

// Service worker lifecycle logging (for debugging)
self.addEventListener('activate', (event) => {
  log('Service worker activated');
});

self.addEventListener('install', (event) => {
  log('Service worker installed');
});

// Keep service worker alive during critical operations (if needed)
let keepAliveInterval;

function startKeepAlive() {
  if (!keepAliveInterval) {
    keepAliveInterval = setInterval(() => {
      chrome.runtime.getPlatformInfo(() => {
        // Just a ping to keep service worker alive
      });
    }, 20000); // Every 20 seconds
  }
}

function stopKeepAlive() {
  if (keepAliveInterval) {
    clearInterval(keepAliveInterval);
    keepAliveInterval = null;
  }
}

// ============================================
// Vocabulary Handlers
// ============================================

/**
 * Handle vocabulary word lookup
 */
async function handleVocabularyLookup(request, sender, sendResponse) {
  try {
    const { word, context } = request;

    if (!word) {
      throw new Error('No word provided');
    }

    log('Looking up vocabulary word:', word);

    // Look up the word
    const result = await vocabularyLookup.lookup(word, context);

    log('Lookup result:', result.word);

    // Send result back to content script
    if (sender.tab) {
      chrome.tabs.sendMessage(sender.tab.id, {
        type: 'VOCABULARY_LOOKUP_RESULT',
        result: result,
        error: null
      });
    }

    sendResponse({ success: true, result });
  } catch (error) {
    logError('Vocabulary lookup failed:', error);

    // Send error back to content script
    if (sender.tab) {
      chrome.tabs.sendMessage(sender.tab.id, {
        type: 'VOCABULARY_LOOKUP_RESULT',
        result: null,
        error: error.message
      });
    }

    sendResponse({ success: false, error: error.message });
  }
}

/**
 * Handle adding word to vocabulary
 */
async function handleVocabularyAdd(request, sendResponse) {
  try {
    const { word, context } = request;

    if (!word) {
      throw new Error('No word data provided');
    }

    log('Adding word to vocabulary:', word.word);

    // Check for duplicate
    const vocabulary = await storageManager.getVocabulary();
    const existing = vocabulary.find(w =>
      w.word.toLowerCase() === word.word.toLowerCase()
    );

    if (existing) {
      throw new Error('This word already exists in your vocabulary');
    }

    // Create vocabulary entry
    const entry = {
      id: `vocab_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      word: word.word,
      phonetic: word.phonetic,
      partOfSpeech: word.partOfSpeech,
      definitionEN: word.definitionEN,
      definitionCN: word.definitionCN,
      examples: word.examples || [],
      synonyms: word.synonyms || [],
      antonyms: word.antonyms || [],
      userContext: context || '',
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

    await storageManager.addVocabularyWord(entry);

    log('Word added successfully:', entry.word);
    sendResponse({ success: true, entry });
  } catch (error) {
    logError('Add vocabulary word failed:', error);
    sendResponse({ success: false, error: error.message });
  }
}

/**
 * Handle getting words due for review
 */
async function handleVocabularyGetDue(sendResponse) {
  try {
    const dueWords = await storageManager.getWordsDueForReview();
    sendResponse({ success: true, words: dueWords, count: dueWords.length });
  } catch (error) {
    logError('Get due words failed:', error);
    sendResponse({ success: false, error: error.message });
  }
}

// Log startup
log('Service worker loaded successfully');
