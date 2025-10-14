/**
 * @fileoverview Offscreen document for audio recording
 * @module offscreen
 *
 * Handles microphone access and audio recording in an offscreen document
 * because Chrome extension popups cannot request microphone permissions.
 */

let mediaRecorder = null;
let audioChunks = [];
let stream = null;
let audioContext = null;
let analyser = null;

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  // Only handle messages targeted to offscreen
  if (message.target === 'offscreen') {
    console.log('Offscreen received message:', message.type);
    handleMessage(message, sendResponse);
    return true; // Keep channel open for async response
  }
  // Ignore messages not for us
  return false;
});

async function handleMessage(message, sendResponse) {
  try {
    switch (message.type) {
      case 'START_RECORDING':
        await startRecording();
        sendResponse({ success: true });
        break;

      case 'STOP_RECORDING':
        const audioBlob = await stopRecording();
        // Convert blob to base64 for message passing
        const reader = new FileReader();
        reader.onloadend = () => {
          sendResponse({
            success: true,
            audioData: reader.result,
            mimeType: audioBlob.type
          });
        };
        reader.readAsDataURL(audioBlob);
        break;

      case 'PAUSE_RECORDING':
        pauseRecording();
        sendResponse({ success: true });
        break;

      case 'RESUME_RECORDING':
        resumeRecording();
        sendResponse({ success: true });
        break;

      case 'GET_AUDIO_LEVEL':
        const level = getAudioLevel();
        sendResponse({ success: true, level });
        break;

      case 'CANCEL_RECORDING':
        cancelRecording();
        sendResponse({ success: true });
        break;

      default:
        sendResponse({ success: false, error: 'Unknown message type' });
    }
  } catch (error) {
    console.error('Offscreen error:', error);
    sendResponse({
      success: false,
      error: error.message,
      errorName: error.name
    });
  }
}

async function startRecording() {
  if (stream) {
    cleanup();
  }

  // Request microphone access
  stream = await navigator.mediaDevices.getUserMedia({
    audio: {
      channelCount: 1,
      sampleRate: 44100,
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true
    }
  });

  // Set up audio context for level monitoring
  audioContext = new (window.AudioContext || window.webkitAudioContext)();
  const source = audioContext.createMediaStreamSource(stream);
  analyser = audioContext.createAnalyser();
  analyser.fftSize = 256;
  source.connect(analyser);

  // Determine MIME type
  const mimeType = getSupportedMimeType();

  // Create MediaRecorder
  mediaRecorder = new MediaRecorder(stream, {
    mimeType: mimeType,
    audioBitsPerSecond: 128000
  });

  // Set up event handlers
  mediaRecorder.ondataavailable = (event) => {
    if (event.data.size > 0) {
      audioChunks.push(event.data);
    }
  };

  mediaRecorder.onerror = (event) => {
    console.error('MediaRecorder error:', event.error);
  };

  // Start recording
  audioChunks = [];
  mediaRecorder.start();

  console.log('Recording started in offscreen document');
}

function pauseRecording() {
  if (!mediaRecorder || mediaRecorder.state !== 'recording') {
    throw new Error('Cannot pause - not recording');
  }
  mediaRecorder.pause();
}

function resumeRecording() {
  if (!mediaRecorder || mediaRecorder.state !== 'paused') {
    throw new Error('Cannot resume - not paused');
  }
  mediaRecorder.resume();
}

function stopRecording() {
  return new Promise((resolve, reject) => {
    if (!mediaRecorder || mediaRecorder.state === 'inactive') {
      reject(new Error('Cannot stop - not recording'));
      return;
    }

    mediaRecorder.onstop = () => {
      try {
        const mimeType = mediaRecorder.mimeType || 'audio/webm;codecs=opus';
        const audioBlob = new Blob(audioChunks, { type: mimeType });
        cleanup();
        resolve(audioBlob);
      } catch (error) {
        cleanup();
        reject(error);
      }
    };

    mediaRecorder.stop();
  });
}

function cancelRecording() {
  if (mediaRecorder && mediaRecorder.state !== 'inactive') {
    mediaRecorder.stop();
  }
  cleanup();
}

function getAudioLevel() {
  if (!analyser) {
    return 0;
  }

  const bufferLength = analyser.frequencyBinCount;
  const dataArray = new Uint8Array(bufferLength);
  analyser.getByteFrequencyData(dataArray);

  // Calculate average volume
  let sum = 0;
  for (let i = 0; i < bufferLength; i++) {
    sum += dataArray[i];
  }
  const average = sum / bufferLength;

  // Normalize to 0-1 range
  return Math.min(average / 128, 1.0);
}

function getSupportedMimeType() {
  const types = [
    'audio/webm;codecs=opus',
    'audio/webm',
    'audio/ogg;codecs=opus',
    'audio/mp4'
  ];

  for (const type of types) {
    if (MediaRecorder.isTypeSupported(type)) {
      return type;
    }
  }

  return '';
}

function cleanup() {
  // Stop all tracks
  if (stream) {
    stream.getTracks().forEach(track => track.stop());
    stream = null;
  }

  // Close audio context
  if (audioContext) {
    audioContext.close().catch(() => {});
    audioContext = null;
  }

  // Clear state
  mediaRecorder = null;
  analyser = null;
  audioChunks = [];

  console.log('Offscreen recorder cleaned up');
}

console.log('Offscreen document loaded');
