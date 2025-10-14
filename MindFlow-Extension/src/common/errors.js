/**
 * @fileoverview Custom error classes
 * @module errors
 */

/**
 * Base error class for MindFlow
 */
export class MindFlowError extends Error {
  constructor(message, code = 'UNKNOWN') {
    super(message);
    this.name = 'MindFlowError';
    this.code = code;
  }
}

/**
 * API-related errors
 */
export class APIError extends MindFlowError {
  constructor(message, status, provider = 'unknown') {
    super(message, 'API_ERROR');
    this.name = 'APIError';
    this.status = status;
    this.provider = provider;
  }
}

/**
 * Configuration errors
 */
export class ConfigurationError extends MindFlowError {
  constructor(message) {
    super(message, 'CONFIG_ERROR');
    this.name = 'ConfigurationError';
  }
}

/**
 * Recording errors
 */
export class RecordingError extends MindFlowError {
  constructor(message) {
    super(message, 'RECORDING_ERROR');
    this.name = 'RecordingError';
  }
}

/**
 * Validation errors
 */
export class ValidationError extends MindFlowError {
  constructor(message) {
    super(message, 'VALIDATION_ERROR');
    this.name = 'ValidationError';
  }
}

/**
 * Storage errors
 */
export class StorageError extends MindFlowError {
  constructor(message) {
    super(message, 'STORAGE_ERROR');
    this.name = 'StorageError';
  }
}
