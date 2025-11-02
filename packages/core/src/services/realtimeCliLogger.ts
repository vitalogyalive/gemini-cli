/**
 * @license
 * Copyright 2025 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

import { EventEmitter } from 'node:events';

/**
 * Event types for real-time CLI logging
 */
export interface RealtimeLogEvent {
  timestamp: string;
  type: 'api_call_start' | 'api_call_end' | 'api_call_error' | 'info';
  message: string;
  metadata?: {
    model?: string;
    duration?: number;
    error?: string;
    promptId?: string;
  };
}

/**
 * Singleton service for real-time CLI logging
 * This service emits events that can be displayed to the user in real-time
 */
export class RealtimeCliLogger {
  private static instance: RealtimeCliLogger | null = null;
  private eventEmitter: EventEmitter;
  private enabled = false;

  private constructor() {
    this.eventEmitter = new EventEmitter();
  }

  static getInstance(): RealtimeCliLogger {
    if (!RealtimeCliLogger.instance) {
      RealtimeCliLogger.instance = new RealtimeCliLogger();
    }
    return RealtimeCliLogger.instance;
  }

  /**
   * Enable or disable verbose logging
   */
  setEnabled(enabled: boolean): void {
    this.enabled = enabled;
  }

  /**
   * Check if verbose logging is enabled
   */
  isEnabled(): boolean {
    return this.enabled;
  }

  /**
   * Subscribe to log events
   */
  onLogEvent(callback: (event: RealtimeLogEvent) => void): () => void {
    this.eventEmitter.on('log', callback);
    // Return unsubscribe function
    return () => {
      this.eventEmitter.off('log', callback);
    };
  }

  /**
   * Log an API call start event
   */
  logApiCallStart(model: string, promptId: string): void {
    if (!this.enabled) return;

    const event: RealtimeLogEvent = {
      timestamp: new Date().toISOString(),
      type: 'api_call_start',
      message: `🚀 Starting API call to ${model}`,
      metadata: {
        model,
        promptId,
      },
    };

    this.eventEmitter.emit('log', event);
    this.logToConsole(event);
  }

  /**
   * Log an API call end event
   */
  logApiCallEnd(model: string, duration: number, promptId: string): void {
    if (!this.enabled) return;

    const durationInSeconds = (duration / 1000).toFixed(2);
    const event: RealtimeLogEvent = {
      timestamp: new Date().toISOString(),
      type: 'api_call_end',
      message: `✅ API call to ${model} completed in ${durationInSeconds}s`,
      metadata: {
        model,
        duration,
        promptId,
      },
    };

    this.eventEmitter.emit('log', event);
    this.logToConsole(event);
  }

  /**
   * Log an API call error event
   */
  logApiCallError(
    model: string,
    error: string,
    duration: number,
    promptId: string,
  ): void {
    if (!this.enabled) return;

    const durationInSeconds = (duration / 1000).toFixed(2);
    const event: RealtimeLogEvent = {
      timestamp: new Date().toISOString(),
      type: 'api_call_error',
      message: `❌ API call to ${model} failed after ${durationInSeconds}s: ${error}`,
      metadata: {
        model,
        duration,
        error,
        promptId,
      },
    };

    this.eventEmitter.emit('log', event);
    this.logToConsole(event);
  }

  /**
   * Log a general info message
   */
  logInfo(message: string): void {
    if (!this.enabled) return;

    const event: RealtimeLogEvent = {
      timestamp: new Date().toISOString(),
      type: 'info',
      message,
    };

    this.eventEmitter.emit('log', event);
    this.logToConsole(event);
  }

  /**
   * Output log event to console (stderr to not interfere with stdout)
   */
  private logToConsole(event: RealtimeLogEvent): void {
    const timestamp = new Date(event.timestamp).toLocaleTimeString();
    console.error(`[${timestamp}] ${event.message}`);
  }
}
