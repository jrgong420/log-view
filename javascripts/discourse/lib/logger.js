/**
 * Centralized logging utility for Owner Comments theme component.
 *
 * Provides consistent logging API with:
 * - Automatic prefix injection
 * - Settings-based gating (debug_logging_enabled)
 * - Rate-limiting for high-frequency logs
 * - Structured context objects
 * - Performance timing helpers
 * - Grouped logging for multi-step flows
 *
 * Usage:
 *   import { createLogger } from "../lib/logger";
 *
 *   const log = createLogger("[Owner View] [Feature Name]");
 *
 *   log.debug("Low-level detail", { context: "value" });
 *   log.info("Lifecycle milestone", { topicId: 123 });
 *   log.warn("Unexpected condition", { reason: "data missing" });
 *   log.error("Critical failure", error);
 *
 *   log.group("Multi-step Flow");
 *   log.info("Step 1");
 *   log.info("Step 2");
 *   log.groupEnd();
 *
 *   log.time("Operation");
 *   // ... do work ...
 *   log.timeEnd("Operation");
 */

// Throttle tracking: Map<messageKey, lastLogTime>
const throttleMap = new Map();
const DEFAULT_THROTTLE_MS = 2000;

/**
 * Check if logging is enabled via theme settings.
 * @returns {boolean} true if debug logging is enabled
 */
function isLoggingEnabled() {
  // Access global settings object provided by Discourse
  return typeof settings !== "undefined" && settings.debug_logging_enabled === true;
}

/**
 * Generate a throttle key from prefix and message.
 * @param {string} prefix - Logger prefix
 * @param {string} message - Log message
 * @returns {string} Throttle key
 */
function getThrottleKey(prefix, message) {
  return `${prefix}::${message}`;
}

/**
 * Check if a message should be throttled.
 * @param {string} key - Throttle key
 * @param {number} throttleMs - Throttle duration in milliseconds
 * @returns {boolean} true if message should be suppressed
 */
function shouldThrottle(key, throttleMs) {
  const now = Date.now();
  const lastTime = throttleMap.get(key);

  if (lastTime && now - lastTime < throttleMs) {
    return true; // Suppress
  }

  throttleMap.set(key, now);
  return false; // Allow
}

/**
 * Create a logger instance with the given prefix.
 * @param {string} prefix - Prefix to prepend to all log messages
 * @returns {Object} Logger instance with debug, info, warn, error, group, time methods
 */
export function createLogger(prefix) {
  return {
    /**
     * Log debug-level message (only when debug_logging_enabled = true).
     * @param {string} message - Log message
     * @param {...any} args - Additional arguments (objects, primitives)
     */
    debug(message, ...args) {
      if (!isLoggingEnabled()) return;
      // eslint-disable-next-line no-console
      console.log(prefix, message, ...args);
    },

    /**
     * Log debug-level message with throttling (max 1 per throttleMs).
     * @param {string} message - Log message
     * @param {Object} options - Options object
     * @param {number} options.throttleMs - Throttle duration (default: 2000ms)
     * @param {...any} args - Additional arguments
     */
    debugThrottled(message, { throttleMs = DEFAULT_THROTTLE_MS } = {}, ...args) {
      if (!isLoggingEnabled()) return;

      const key = getThrottleKey(prefix, message);
      if (shouldThrottle(key, throttleMs)) return;

      // eslint-disable-next-line no-console
      console.log(prefix, message, ...args);
    },

    /**
     * Log info-level message (only when debug_logging_enabled = true).
     * @param {string} message - Log message
     * @param {...any} args - Additional arguments
     */
    info(message, ...args) {
      if (!isLoggingEnabled()) return;
      // eslint-disable-next-line no-console
      console.log(prefix, message, ...args);
    },

    /**
     * Log warning message (only when debug_logging_enabled = true).
     * @param {string} message - Log message
     * @param {...any} args - Additional arguments
     */
    warn(message, ...args) {
      if (!isLoggingEnabled()) return;
      // eslint-disable-next-line no-console
      console.warn(prefix, message, ...args);
    },

    /**
     * Log error message (ALWAYS logged, even when debug disabled).
     * @param {string} message - Log message
     * @param {...any} args - Additional arguments
     */
    error(message, ...args) {
      // Errors are always logged for user visibility
      // eslint-disable-next-line no-console
      console.error(prefix, message, ...args);
    },

    /**
     * Start a console group (only when debug_logging_enabled = true).
     * @param {string} label - Group label
     */
    group(label) {
      if (!isLoggingEnabled()) return;
      // eslint-disable-next-line no-console
      console.group(prefix, label);
    },

    /**
     * Start a collapsed console group (only when debug_logging_enabled = true).
     * @param {string} label - Group label
     */
    groupCollapsed(label) {
      if (!isLoggingEnabled()) return;
      // eslint-disable-next-line no-console
      console.groupCollapsed(prefix, label);
    },

    /**
     * End the current console group (only when debug_logging_enabled = true).
     */
    groupEnd() {
      if (!isLoggingEnabled()) return;
      // eslint-disable-next-line no-console
      console.groupEnd();
    },

    /**
     * Start a performance timer (only when debug_logging_enabled = true).
     * @param {string} label - Timer label
     */
    time(label) {
      if (!isLoggingEnabled()) return;
      // eslint-disable-next-line no-console
      console.time(`${prefix} ${label}`);
    },

    /**
     * Log intermediate time for a running timer (only when debug_logging_enabled = true).
     * @param {string} label - Timer label
     * @param {...any} args - Additional context
     */
    timeLog(label, ...args) {
      if (!isLoggingEnabled()) return;
      // eslint-disable-next-line no-console
      console.timeLog(`${prefix} ${label}`, ...args);
    },

    /**
     * End a performance timer and log elapsed time (only when debug_logging_enabled = true).
     * @param {string} label - Timer label
     */
    timeEnd(label) {
      if (!isLoggingEnabled()) return;
      // eslint-disable-next-line no-console
      console.timeEnd(`${prefix} ${label}`);
    },

    /**
     * Log a table (only when debug_logging_enabled = true).
     * @param {Object|Array} data - Data to display as table
     */
    table(data) {
      if (!isLoggingEnabled()) return;
      // eslint-disable-next-line no-console
      console.log(prefix);
      // eslint-disable-next-line no-console
      console.table(data);
    },
  };
}

/**
 * Clear throttle map (useful for testing or manual reset).
 */
export function clearThrottleMap() {
  throttleMap.clear();
}

