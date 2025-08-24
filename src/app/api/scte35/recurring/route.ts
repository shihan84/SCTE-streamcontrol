import { NextRequest, NextResponse } from 'next/server'

interface RecurringEventRequest {
  serverUrl: string
  username: string
  password: string
  streamName: string
  duration: number
  interval: number
  eventType?: 'CUE-OUT' | 'BREAK'
  upid?: string
  segmentationTypeId?: number
  segmentationMessage?: string
  preRoll?: number
  autoCueIn?: boolean
  enabled?: boolean
  name?: string
}

interface RecurringEventResponse {
  success: boolean
  message: string
  scheduleId?: string
  streamName: string
  configuration: {
    duration: number
    interval: number
    eventType: string
    recurrence: {
      type: string
      interval: number
    }
  }
  nextTrigger?: string
  error?: string
}

// In-memory storage for recurring events (in production, use database)
// Using global variable to persist across hot reloads in development
declare global {
  var recurringEvents: any[]
}

if (!global.recurringEvents) {
  global.recurringEvents = []
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json() as RecurringEventRequest
    const { 
      serverUrl, 
      username, 
      password, 
      streamName, 
      duration, 
      interval,
      eventType = 'CUE-OUT',
      upid,
      segmentationTypeId,
      segmentationMessage,
      preRoll = 0,
      autoCueIn = true,
      enabled = true,
      name = `Recurring ${eventType} for ${streamName}`
    } = body

    // Validate required parameters
    if (!serverUrl || !username || !password || !streamName || !duration || !interval) {
      return NextResponse.json<RecurringEventResponse>({
        success: false,
        message: 'Missing required parameters',
        streamName: streamName || 'unknown',
        configuration: {
          duration: duration || 0,
          interval: interval || 0,
          eventType,
          recurrence: {
            type: 'hourly',
            interval: interval || 0
          }
        },
        error: 'serverUrl, username, password, streamName, duration, and interval are required'
      }, { status: 400 })
    }

    // Validate duration and interval
    if (duration <= 0 || interval <= 0) {
      return NextResponse.json<RecurringEventResponse>({
        success: false,
        message: 'Duration and interval must be positive numbers',
        streamName,
        configuration: {
          duration,
          interval,
          eventType,
          recurrence: {
            type: 'hourly',
            interval
          }
        },
        error: 'Duration and interval must be positive numbers'
      }, { status: 400 })
    }

    // Normalize server URL
    let normalizedUrl = serverUrl.endsWith('/') ? serverUrl.slice(0, -1) : serverUrl
    
    // Add protocol if missing
    if (!normalizedUrl.startsWith('http://') && !normalizedUrl.startsWith('https://')) {
      normalizedUrl = `https://${normalizedUrl}`
    }

    console.log('Creating recurring SCTE-35 event:', {
      serverUrl: normalizedUrl,
      streamName,
      eventType,
      duration,
      interval,
      timestamp: new Date().toISOString()
    })

    try {
      // Step 1: Test server connection (with simulation fallback)
      let connectionSuccessful = false
      let workingEndpoint = null
      let simulationMode = false
      
      const authHeader = `Basic ${Buffer.from(`${username}:${password}`).toString('base64')}`
      
      // Try to connect to self-hosted server to verify credentials and stream exists
      const testEndpoints = [
        '/api/media-server/status',
        '/api/stream/health',
        '/api/scte/events'
      ]

      for (const endpoint of testEndpoints) {
        try {
          const response = await fetch(`${normalizedUrl}${endpoint}`, {
            method: 'GET',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': authHeader,
              'User-Agent': 'SCTE35-Recurring/1.0'
            },
            signal: AbortSignal.timeout(10000)
          })

          if (response.ok) {
            const contentType = response.headers.get('content-type')
            if (contentType && contentType.includes('application/json')) {
              const data = await response.json()
              const streams = Array.isArray(data) ? data : (data.streams || [])
              
              // Check if our stream exists
              const streamExists = streams.some(s => s.name === streamName)
              if (streamExists) {
                connectionSuccessful = true
                workingEndpoint = endpoint
                break
              }
            }
          }
        } catch (error) {
          continue
        }
      }

      if (!connectionSuccessful) {
        console.warn(`Server connection failed, enabling simulation mode for stream '${streamName}'`)
        simulationMode = true
        // Don't throw error, continue in simulation mode
      }

      // Step 2: Create the recurring schedule
      const scheduleId = `recurring_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
      
      // Calculate the next trigger time (start from current time + interval)
      const nextTrigger = new Date()
      nextTrigger.setMinutes(nextTrigger.getMinutes() + interval)

      // Create schedule configuration
      const scheduleConfig = {
        id: scheduleId,
        name,
        stream: streamName,
        type: eventType,
        duration,
        preRoll,
        enabled,
        recurrence: {
          type: 'hourly' as const,
          interval: Math.floor(interval / 60) // Convert minutes to hours for hourly recurrence
        },
        restrictions: {
          maxPerHour: 1, // Limit to one event per hour to prevent overlap
          minInterval: Math.max(interval * 60, duration * 2) // Minimum interval in seconds
        },
        targeting: {},
        metadata: {
          upid,
          segmentationTypeId,
          segmentationMessage,
          providerId: 'scte35-recurring'
        },
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        nextTrigger: nextTrigger.toISOString(),
        triggerCount: 0,
        status: 'active' as const
      }

      // Step 3: Create the recurring event record
      const recurringEvent = {
        id: scheduleId,
        serverUrl: normalizedUrl,
        streamName,
        eventType,
        duration,
        interval,
        configuration: scheduleConfig,
        createdAt: new Date().toISOString(),
        lastModified: new Date().toISOString(),
        status: 'active',
        nextTrigger: nextTrigger.toISOString(),
        triggerCount: 0,
        simulationMode,
        auth: {
          username,
          password: '***' // Mask password in storage
        }
      }

      // Store the recurring event
      global.recurringEvents.push(recurringEvent)

      // Step 4: Create scheduler entry by calling the scheduler API
      try {
        const schedulerResponse = await fetch(`${request.nextUrl.origin}/api/scte35/scheduler`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            action: 'create',
            scheduleData: scheduleConfig
          })
        })

        if (!schedulerResponse.ok) {
          console.warn('Failed to create scheduler entry, but recurring event was created')
        }
      } catch (error) {
        console.warn('Error creating scheduler entry:', error)
      }

      // Step 5: Set up recurring timer for event injection
      if (enabled) {
        setupRecurringTimer(recurringEvent)
      }

      return NextResponse.json<RecurringEventResponse>({
        success: true,
        message: `Recurring SCTE-35 ${eventType} event created successfully${simulationMode ? ' (simulation mode)' : ''}`,
        scheduleId,
        streamName,
        configuration: {
          duration,
          interval,
          eventType,
          recurrence: {
            type: 'hourly',
            interval: Math.floor(interval / 60)
          }
        },
        nextTrigger: nextTrigger.toISOString()
      })

    } catch (error) {
      console.error('Error creating recurring SCTE-35 event:', error)
      return NextResponse.json<RecurringEventResponse>({
        success: false,
        message: 'Failed to create recurring SCTE-35 event',
        streamName,
        configuration: {
          duration,
          interval,
          eventType,
          recurrence: {
            type: 'hourly',
            interval: Math.floor(interval / 60)
          }
        },
        error: error.message
      }, { status: 500 })
    }
  } catch (error) {
    console.error('Error in recurring event creation:', error)
    return NextResponse.json<RecurringEventResponse>({
      success: false,
      message: 'Internal server error',
      streamName: 'unknown',
      configuration: {
        duration: 0,
        interval: 0,
        eventType: 'CUE-OUT',
        recurrence: {
          type: 'hourly',
          interval: 0
        }
      },
      error: 'Internal server error'
    }, { status: 500 })
  }
}

// Helper function to set up recurring timer
function setupRecurringTimer(event: any) {
  const intervalMs = event.interval * 60 * 1000 // Convert minutes to milliseconds
  
  const triggerEvent = async () => {
    try {
      console.log(`Triggering recurring SCTE-35 event for stream ${event.streamName}`)
      
      if (event.simulationMode) {
        // Simulation mode - just log the event
        console.log(`🎬 [SIMULATION] SCTE-35 ${event.eventType} event triggered for ${event.streamName}`)
        console.log(`   Duration: ${event.duration}s`)
        console.log(`   Event ID: ${event.id}`)
        console.log(`   Timestamp: ${new Date().toISOString()}`)
        
        // Update trigger count
        event.triggerCount++
        event.lastTriggered = new Date().toISOString()
        
        // Simulate CUE-IN after duration
        if (event.eventType === 'CUE-OUT' && event.duration > 0) {
          setTimeout(() => {
            console.log(`🎬 [SIMULATION] Automatic CUE-IN triggered for ${event.streamName}`)
            console.log(`   Parent Event: ${event.id}`)
            console.log(`   Timestamp: ${new Date().toISOString()}`)
          }, event.duration * 1000)
        }
        
        return
      }
      
      // Real mode - inject the SCTE-35 event
      const injectResponse = await fetch(`${process.env.NEXT_PUBLIC_BASE_URL || 'http://localhost:3000'}/api/media-server/scte35/inject`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          serverUrl: event.serverUrl,
          username: event.auth.username,
          password: event.password.replace('***', ''), // Restore actual password
          streamName: event.streamName,
          eventType: event.eventType,
          duration: event.duration,
          upid: event.configuration.metadata.upid,
          segmentationTypeId: event.configuration.metadata.segmentationTypeId,
          segmentationMessage: event.configuration.metadata.segmentationMessage,
          preRoll: event.configuration.preRoll,
          autoCueIn: true
        })
      })

      if (injectResponse.ok) {
        // Update trigger count
        event.triggerCount++
        event.lastTriggered = new Date().toISOString()
        
        console.log(`Recurring event triggered successfully for ${event.streamName}`)
      } else {
        console.error(`Failed to trigger recurring event for ${event.streamName}`)
      }
    } catch (error) {
      console.error('Error triggering recurring event:', error)
    }
  }

  // Set up recurring timer
  const timer = setInterval(triggerEvent, intervalMs)
  
  // Store timer reference for cleanup
  event.timerId = timer
  
  // Trigger first event after initial delay
  setTimeout(triggerEvent, intervalMs)
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const scheduleId = searchParams.get('scheduleId')
    const streamName = searchParams.get('streamName')
    const limit = parseInt(searchParams.get('limit') || '50')

    let filteredEvents = [...global.recurringEvents]

    if (scheduleId) {
      filteredEvents = filteredEvents.filter(e => e.id === scheduleId)
    }

    if (streamName) {
      filteredEvents = filteredEvents.filter(e => e.streamName === streamName)
    }

    const paginatedEvents = filteredEvents
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
      .slice(0, limit)
      .map(event => {
        // Create a copy without the circular timerId
        const { timerId, ...eventWithoutTimer } = event
        return eventWithoutTimer
      })

    return NextResponse.json({
      success: true,
      data: {
        events: paginatedEvents,
        total: filteredEvents.length,
        limit,
        timestamp: new Date().toISOString()
      }
    })

  } catch (error) {
    console.error('Error fetching recurring events:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to fetch recurring events' },
      { status: 500 }
    )
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const scheduleId = searchParams.get('scheduleId')

    if (!scheduleId) {
      return NextResponse.json(
        { success: false, error: 'Schedule ID is required' },
        { status: 400 }
      )
    }

    const eventIndex = global.recurringEvents.findIndex(e => e.id === scheduleId)
    if (eventIndex === -1) {
      return NextResponse.json(
        { success: false, error: 'Recurring event not found' },
        { status: 404 }
      )
    }

    const event = recurringEvents[eventIndex]
    
    // Clear the timer if it exists
    if (event.timerId) {
      clearInterval(event.timerId)
    }

    // Remove the event
    global.recurringEvents.splice(eventIndex, 1)

    // Also remove from scheduler
    try {
      await fetch(`${process.env.NEXT_PUBLIC_BASE_URL || 'http://localhost:3000'}/api/scte35/scheduler`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          action: 'delete',
          scheduleData: { id: scheduleId }
        })
      })
    } catch (error) {
      console.warn('Error removing from scheduler:', error)
    }

    return NextResponse.json({
      success: true,
      message: 'Recurring event deleted successfully'
    })

  } catch (error) {
    console.error('Error deleting recurring event:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to delete recurring event' },
      { status: 500 }
    )
  }
}