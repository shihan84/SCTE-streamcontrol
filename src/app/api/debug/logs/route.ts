import { NextRequest, NextResponse } from 'next/server'
import { logger, LogLevel } from '@/lib/logger'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const level = searchParams.get('level')
    const category = searchParams.get('category')
    const limit = parseInt(searchParams.get('limit') || '100')
    const offset = parseInt(searchParams.get('offset') || '0')
    const action = searchParams.get('action')

    // Handle different actions
    if (action === 'stats') {
      const stats = logger.getLogStats()
      return NextResponse.json({
        success: true,
        stats,
        timestamp: new Date().toISOString()
      })
    }

    if (action === 'export') {
      const logs = logger.exportLogs()
      return NextResponse.json({
        success: true,
        logs,
        count: logger.getLogs().length,
        timestamp: new Date().toISOString()
      })
    }

    if (action === 'clear') {
      logger.clearLogs()
      return NextResponse.json({
        success: true,
        message: 'Logs cleared successfully',
        timestamp: new Date().toISOString()
      })
    }

    // Get logs with optional filtering
    const logLevel = level !== null ? parseInt(level) as LogLevel : undefined
    const logs = logger.getLogs(logLevel, category || undefined, limit, offset)

    return NextResponse.json({
      success: true,
      logs,
      total: logger.getLogs(logLevel, category || undefined).length,
      limit,
      offset,
      filters: {
        level: logLevel !== undefined ? LogLevel[logLevel] : 'ALL',
        category: category || 'ALL'
      },
      timestamp: new Date().toISOString()
    })

  } catch (error) {
    logger.error('Failed to fetch logs', 'DEBUG_API', { error: error.message })
    return NextResponse.json({
      success: false,
      error: 'Failed to fetch logs',
      timestamp: new Date().toISOString()
    }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { action, level, message, category, details, logs } = body

    if (action === 'log') {
      // Add a custom log entry
      if (!message || !category) {
        return NextResponse.json({
          success: false,
          error: 'Message and category are required for log action',
          timestamp: new Date().toISOString()
        }, { status: 400 })
      }

      const logLevel = level !== undefined ? parseInt(level) as LogLevel : LogLevel.INFO
      logger[LogLevel[logLevel].toLowerCase() as keyof typeof logger](
        message, 
        category, 
        details
      )

      return NextResponse.json({
        success: true,
        message: 'Log entry added successfully',
        timestamp: new Date().toISOString()
      })
    }

    if (action === 'setLevel') {
      // Set log level
      if (level === undefined) {
        return NextResponse.json({
          success: false,
          error: 'Level is required for setLevel action',
          timestamp: new Date().toISOString()
        }, { status: 400 })
      }

      logger.setLogLevel(level as LogLevel)
      return NextResponse.json({
        success: true,
        message: `Log level set to ${LogLevel[level]}`,
        timestamp: new Date().toISOString()
      })
    }

    if (action === 'import') {
      // Import logs
      if (!logs) {
        return NextResponse.json({
          success: false,
          error: 'Logs data is required for import action',
          timestamp: new Date().toISOString()
        }, { status: 400 })
      }

      const success = logger.importLogs(logs)
      if (success) {
        return NextResponse.json({
          success: true,
          message: 'Logs imported successfully',
          timestamp: new Date().toISOString()
        })
      } else {
        return NextResponse.json({
          success: false,
          error: 'Failed to import logs - invalid format',
          timestamp: new Date().toISOString()
        }, { status: 400 })
      }
    }

    return NextResponse.json({
      success: false,
      error: 'Invalid action',
      timestamp: new Date().toISOString()
    }, { status: 400 })

  } catch (error) {
    logger.error('Failed to process debug request', 'DEBUG_API', { error: error.message })
    return NextResponse.json({
      success: false,
      error: 'Failed to process debug request',
      timestamp: new Date().toISOString()
    }, { status: 500 })
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const category = searchParams.get('category')

    if (category) {
      // Clear logs for specific category
      const allLogs = logger.getLogs()
      const otherLogs = allLogs.filter(log => log.category !== category)
      
      // This is a workaround since we don't have direct category clearing
      logger.clearLogs()
      otherLogs.forEach(log => {
        logger[LogLevel[log.level].toLowerCase() as keyof typeof logger](
          log.message, 
          log.category, 
          log.details
        )
      })

      return NextResponse.json({
        success: true,
        message: `Logs for category '${category}' cleared successfully`,
        timestamp: new Date().toISOString()
      })
    } else {
      // Clear all logs
      logger.clearLogs()
      return NextResponse.json({
        success: true,
        message: 'All logs cleared successfully',
        timestamp: new Date().toISOString()
      })
    }

  } catch (error) {
    logger.error('Failed to clear logs', 'DEBUG_API', { error: error.message })
    return NextResponse.json({
      success: false,
      error: 'Failed to clear logs',
      timestamp: new Date().toISOString()
    }, { status: 500 })
  }
}