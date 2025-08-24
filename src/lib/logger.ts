// Logger utility for the SCTE-35 Streaming Control Center

export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3
}

export interface LogEntry {
  timestamp: string
  level: LogLevel
  message: string
  category: string
  details?: any
  requestId?: string
}

class Logger {
  private logs: LogEntry[] = []
  private maxLogs: number = 1000
  private logLevel: LogLevel = LogLevel.INFO

  setLogLevel(level: LogLevel) {
    this.logLevel = level
  }

  private createLogEntry(
    level: LogLevel, 
    message: string, 
    category: string, 
    details?: any,
    requestId?: string
  ): LogEntry {
    return {
      timestamp: new Date().toISOString(),
      level,
      message,
      category,
      details,
      requestId
    }
  }

  private addLog(entry: LogEntry) {
    this.logs.unshift(entry)
    
    // Keep only the most recent logs
    if (this.logs.length > this.maxLogs) {
      this.logs = this.logs.slice(0, this.maxLogs)
    }

    // Also log to console for development
    const levelName = LogLevel[entry.level]
    const prefix = `[${entry.timestamp}] [${levelName}] [${entry.category}]`
    
    switch (entry.level) {
      case LogLevel.DEBUG:
        console.debug(prefix, entry.message, entry.details || '')
        break
      case LogLevel.INFO:
        console.info(prefix, entry.message, entry.details || '')
        break
      case LogLevel.WARN:
        console.warn(prefix, entry.message, entry.details || '')
        break
      case LogLevel.ERROR:
        console.error(prefix, entry.message, entry.details || '')
        break
    }
  }

  debug(message: string, category: string = 'GENERAL', details?: any, requestId?: string) {
    if (this.logLevel <= LogLevel.DEBUG) {
      const entry = this.createLogEntry(LogLevel.DEBUG, message, category, details, requestId)
      this.addLog(entry)
    }
  }

  info(message: string, category: string = 'GENERAL', details?: any, requestId?: string) {
    if (this.logLevel <= LogLevel.INFO) {
      const entry = this.createLogEntry(LogLevel.INFO, message, category, details, requestId)
      this.addLog(entry)
    }
  }

  warn(message: string, category: string = 'GENERAL', details?: any, requestId?: string) {
    if (this.logLevel <= LogLevel.WARN) {
      const entry = this.createLogEntry(LogLevel.WARN, message, category, details, requestId)
      this.addLog(entry)
    }
  }

  error(message: string, category: string = 'GENERAL', details?: any, requestId?: string) {
    if (this.logLevel <= LogLevel.ERROR) {
      const entry = this.createLogEntry(LogLevel.ERROR, message, category, details, requestId)
      this.addLog(entry)
    }
  }

  getLogs(
    level?: LogLevel, 
    category?: string, 
    limit: number = 100, 
    offset: number = 0
  ): LogEntry[] {
    let filteredLogs = this.logs

    if (level !== undefined) {
      filteredLogs = filteredLogs.filter(log => log.level >= level)
    }

    if (category) {
      filteredLogs = filteredLogs.filter(log => log.category === category)
    }

    return filteredLogs.slice(offset, offset + limit)
  }

  getLogsByCategory(category: string, limit: number = 100): LogEntry[] {
    return this.getLogs(undefined, category, limit)
  }

  getErrorLogs(limit: number = 100): LogEntry[] {
    return this.getLogs(LogLevel.ERROR, undefined, limit)
  }

  clearLogs() {
    this.logs = []
  }

  getLogStats() {
    const stats = {
      total: this.logs.length,
      debug: 0,
      info: 0,
      warn: 0,
      error: 0,
      categories: {} as Record<string, number>
    }

    this.logs.forEach(log => {
      switch (log.level) {
        case LogLevel.DEBUG:
          stats.debug++
          break
        case LogLevel.INFO:
          stats.info++
          break
        case LogLevel.WARN:
          stats.warn++
          break
        case LogLevel.ERROR:
          stats.error++
          break
      }

      stats.categories[log.category] = (stats.categories[log.category] || 0) + 1
    })

    return stats
  }

  exportLogs(): string {
    return JSON.stringify(this.logs, null, 2)
  }

  importLogs(logsJson: string) {
    try {
      const importedLogs = JSON.parse(logsJson)
      if (Array.isArray(importedLogs)) {
        this.logs = importedLogs
          .filter(log => 
            log.timestamp && 
            log.level !== undefined && 
            log.message && 
            log.category
          )
          .map(log => ({
            ...log,
            level: parseInt(log.level) as LogLevel
          }))
        return true
      }
      return false
    } catch (error) {
      this.error('Failed to import logs', 'LOGGER', { error: error.message })
      return false
    }
  }
}

// Create a singleton instance
export const logger = new Logger()

// Export convenience functions
export const debug = (message: string, category?: string, details?: any) => 
  logger.debug(message, category, details)

export const info = (message: string, category?: string, details?: any) => 
  logger.info(message, category, details)

export const warn = (message: string, category?: string, details?: any) => 
  logger.warn(message, category, details)

export const error = (message: string, category?: string, details?: any) => 
  logger.error(message, category, details)