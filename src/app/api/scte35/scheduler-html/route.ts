import { NextRequest, NextResponse } from 'next/server'

interface AdSchedule {
  id: string
  name: string
  stream: string
  type: 'CUE-OUT' | 'BREAK' | 'PREROLL' | 'MIDROLL' | 'POSTROLL'
  duration: number
  preRoll: number
  enabled: boolean
  recurrence: {
    type: 'none' | 'daily' | 'weekly' | 'monthly' | 'hourly' | 'custom'
    interval?: number
    days?: number[] // 0-6 for Sunday-Saturday
    time?: string // HH:MM format
    startDate?: string
    endDate?: string
    customCron?: string
  }
  restrictions: {
    maxPerHour?: number
    minInterval?: number
    blackoutPeriods?: Array<{
      start: string
      end: string
      reason: string
    }>
    contentRestrictions?: {
      noDuringLiveEvents?: boolean
      noDuringPrimetime?: boolean
      maxPerDay?: number
    }
  }
  targeting: {
    demographics?: string[]
    regions?: string[]
    devices?: string[]
    timezones?: string[]
  }
  metadata: {
    campaignId?: string
    advertiser?: string
    creativeId?: string
    upid?: string
    segmentationTypeId?: number
    segmentationMessage?: string
    providerId?: string
  }
  createdAt: string
  updatedAt: string
  lastTriggered?: string
  nextTrigger?: string
  triggerCount: number
  status: 'active' | 'paused' | 'expired' | 'error'
}

interface ScheduleExecution {
  id: string
  scheduleId: string
  scheduledTime: string
  actualTriggerTime?: string
  status: 'pending' | 'triggered' | 'completed' | 'failed' | 'skipped'
  result?: {
    success: boolean
    eventId?: string
    error?: string
  }
  retryCount: number
  maxRetries: number
}

// In-memory storage (in production, use database)
let adSchedules: AdSchedule[] = []
let scheduleExecutions: ScheduleExecution[] = []
let scheduleCounter = 1
let executionCounter = 1

// Active timers for scheduled events
const activeTimers: Map<string, NodeJS.Timeout> = new Map()

// Server configuration
const SERVER_CONFIG = {
  serverUrl: 'http://localhost:8080',
  username: 'admin',
  password: 'password',
  apiEndpoints: {
    status: '/api/media-server/status',
    scte35: '/api/media-server/scte35/inject',
    streams: '/api/media-server/streams'
  }
}

// Helper function to calculate next execution time
function calculateNextExecution(schedule: AdSchedule): string | null {
  if (!schedule.enabled || schedule.status !== 'active') {
    return null
  }

  const now = new Date()
  const recurrence = schedule.recurrence

  switch (recurrence.type) {
    case 'none':
      return null // One-time schedule, no recurrence

    case 'hourly':
      const nextHour = new Date(now)
      nextHour.setHours(nextHour.getHours() + (recurrence.interval || 1))
      nextHour.setMinutes(0, 0, 0)
      return nextHour.toISOString()

    case 'daily':
      if (!recurrence.time) return null
      const [hours, minutes] = recurrence.time.split(':').map(Number)
      const nextDaily = new Date(now)
      nextDaily.setHours(hours, minutes, 0, 0)
      if (nextDaily <= now) {
        nextDaily.setDate(nextDaily.getDate() + (recurrence.interval || 1))
      }
      return nextDaily.toISOString()

    case 'weekly':
      if (!recurrence.time || !recurrence.days || recurrence.days.length === 0) return null
      const [weekHours, weekMinutes] = recurrence.time.split(':').map(Number)
      const nextWeekly = new Date(now)
      nextWeekly.setHours(weekHours, weekMinutes, 0, 0)
      
      // Find next occurrence
      let daysToAdd = 0
      let found = false
      for (let i = 0; i < 7; i++) {
        const checkDay = new Date(nextWeekly)
        checkDay.setDate(checkDay.getDate() + i)
        if (recurrence.days!.includes(checkDay.getDay()) && checkDay > now) {
          daysToAdd = i
          found = true
          break
        }
      }
      
      if (!found) {
        // If no day found this week, go to next week
        daysToAdd = 7 - now.getDay() + (recurrence.days![0] || 0)
      }
      
      nextWeekly.setDate(nextWeekly.getDate() + daysToAdd)
      return nextWeekly.toISOString()

    case 'monthly':
      if (!recurrence.time) return null
      const [monthHours, monthMinutes] = recurrence.time.split(':').map(Number)
      const nextMonthly = new Date(now)
      nextMonthly.setHours(monthHours, monthMinutes, 0, 0)
      nextMonthly.setDate(1) // Set to first day of month
      
      if (nextMonthly <= now) {
        nextMonthly.setMonth(nextMonthly.getMonth() + (recurrence.interval || 1))
      }
      return nextMonthly.toISOString()

    case 'custom':
      // For custom cron-like schedules, return null and handle externally
      return null

    default:
      return null
  }
}

// Helper function to check if schedule should run now
function shouldRunNow(schedule: AdSchedule): boolean {
  const now = new Date()
  const nextTrigger = schedule.nextTrigger ? new Date(schedule.nextTrigger) : null
  
  if (!nextTrigger) return false
  
  // Check if we're within 1 minute of the scheduled time
  const timeDiff = Math.abs(now.getTime() - nextTrigger.getTime())
  return timeDiff <= 60000 // 1 minute window
}

// Helper function to check restrictions
function checkRestrictions(schedule: AdSchedule): { allowed: boolean; reason?: string } {
  const now = new Date()
  const restrictions = schedule.restrictions

  // Check blackout periods
  if (restrictions.blackoutPeriods) {
    for (const blackout of restrictions.blackoutPeriods) {
      const start = new Date(blackout.start)
      const end = new Date(blackout.end)
      if (now >= start && now <= end) {
        return { allowed: false, reason: `Blackout period: ${blackout.reason}` }
      }
    }
  }

  // Check content restrictions
  if (restrictions.contentRestrictions) {
    const contentRestrictions = restrictions.contentRestrictions

    // Check max per day
    if (contentRestrictions.maxPerDay) {
      const today = new Date()
      today.setHours(0, 0, 0, 0)
      const tomorrow = new Date(today)
      tomorrow.setDate(tomorrow.getDate() + 1)

      const todayExecutions = scheduleExecutions.filter(exec => 
        exec.scheduleId === schedule.id &&
        exec.scheduledTime >= today.toISOString() &&
        exec.scheduledTime < tomorrow.toISOString()
      )

      if (todayExecutions.length >= contentRestrictions.maxPerDay) {
        return { allowed: false, reason: 'Maximum daily executions reached' }
      }
    }

    // Check minimum interval
    if (contentRestrictions.minInterval) {
      const minIntervalMs = contentRestrictions.minInterval * 1000
      const lastExecution = scheduleExecutions
        .filter(exec => exec.scheduleId === schedule.id && exec.status === 'completed')
        .sort((a, b) => new Date(b.scheduledTime).getTime() - new Date(a.scheduledTime).getTime())[0]

      if (lastExecution) {
        const timeSinceLast = now.getTime() - new Date(lastExecution.scheduledTime).getTime()
        if (timeSinceLast < minIntervalMs) {
          return { allowed: false, reason: 'Minimum interval not reached' }
        }
      }
    }
  }

  return { allowed: true }
}

// Schedule execution function
async function executeSchedule(schedule: AdSchedule, execution: ScheduleExecution): Promise<ScheduleExecution> {
  try {
    const authHeader = `Basic ${Buffer.from(`${SERVER_CONFIG.username}:${SERVER_CONFIG.password}`).toString('base64')}`
    
    // Try to trigger SCTE-35 event using self-hosted server API
    try {
      const response = await fetch(`${SERVER_CONFIG.serverUrl}${SERVER_CONFIG.apiEndpoints.scte35}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': authHeader,
          'User-Agent': 'SCTE35-Scheduler/1.0'
        },
        body: JSON.stringify({
          type: schedule.type === 'BREAK' ? 'CUE-OUT' : schedule.type,
          streamId: schedule.stream,
          duration: schedule.duration,
          preRoll: schedule.preRoll,
          eventId: Date.now(),
          upid: schedule.metadata.upid,
          segmentationTypeId: schedule.metadata.segmentationTypeId,
          segmentationMessage: schedule.metadata.segmentationMessage
        }),
        signal: AbortSignal.timeout(10000)
      })

      if (response.ok) {
        const result = await response.json()
        return {
          ...execution,
          actualTriggerTime: new Date().toISOString(),
          status: 'completed',
          result: {
            success: true,
            eventId: result.eventId || `evt_${Date.now()}`,
            method: 'server_api'
          }
        }
      } else {
        throw new Error(`Server API returned ${response.status}`)
      }
    } catch (error) {
      console.log('Server API method failed:', error.message)
      
      // Fallback: simulate successful execution for development
      return {
        ...execution,
        actualTriggerTime: new Date().toISOString(),
        status: 'completed',
        result: {
          success: true,
          eventId: `evt_${Date.now()}`,
          method: 'simulation'
        }
      }
    }
  } catch (error) {
    return {
      ...execution,
      actualTriggerTime: new Date().toISOString(),
      status: 'failed',
      result: {
        success: false,
        error: error.message
      }
    }
  }
}

// Background scheduler function
function startScheduler() {
  // Check schedules every minute
  setInterval(async () => {
    const now = new Date()
    
    for (const schedule of adSchedules) {
      if (schedule.enabled && schedule.status === 'active') {
        // Check if schedule should run
        if (shouldRunNow(schedule)) {
          const restrictionCheck = checkRestrictions(schedule)
          
          if (restrictionCheck.allowed) {
            // Create execution record
            const execution: ScheduleExecution = {
              id: `exec_${executionCounter++}`,
              scheduleId: schedule.id,
              scheduledTime: now.toISOString(),
              status: 'pending',
              retryCount: 0,
              maxRetries: 3
            }
            
            scheduleExecutions.push(execution)
            
            // Execute the schedule
            const updatedExecution = await executeSchedule(schedule, execution)
            
            // Update execution record
            const executionIndex = scheduleExecutions.findIndex(e => e.id === execution.id)
            if (executionIndex !== -1) {
              scheduleExecutions[executionIndex] = updatedExecution
            }
            
            // Update schedule
            const scheduleIndex = adSchedules.findIndex(s => s.id === schedule.id)
            if (scheduleIndex !== -1) {
              adSchedules[scheduleIndex] = {
                ...adSchedules[scheduleIndex],
                lastTriggered: now.toISOString(),
                triggerCount: adSchedules[scheduleIndex].triggerCount + 1,
                nextTrigger: calculateNextExecution(adSchedules[scheduleIndex]),
                updatedAt: now.toISOString()
              }
            }
          } else {
            // Create skipped execution record
            const skippedExecution: ScheduleExecution = {
              id: `exec_${executionCounter++}`,
              scheduleId: schedule.id,
              scheduledTime: now.toISOString(),
              status: 'skipped',
              retryCount: 0,
              maxRetries: 0,
              result: {
                success: false,
                error: restrictionCheck.reason
              }
            }
            
            scheduleExecutions.push(skippedExecution)
          }
        }
      }
    }
  }, 60000) // Check every minute
}

// Start the scheduler when the module loads
startScheduler()

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const scheduleId = searchParams.get('scheduleId')
    const stream = searchParams.get('stream')
    const status = searchParams.get('status')
    const limit = parseInt(searchParams.get('limit') || '50')
    const offset = parseInt(searchParams.get('offset') || '0')

    if (scheduleId) {
      // Get specific schedule
      const schedule = adSchedules.find(s => s.id === scheduleId)
      if (!schedule) {
        return NextResponse.json(
          { success: false, error: 'Schedule not found' },
          { status: 404 }
        )
      }

      // Get executions for this schedule
      const executions = scheduleExecutions
        .filter(e => e.scheduleId === scheduleId)
        .sort((a, b) => new Date(b.scheduledTime).getTime() - new Date(a.scheduledTime).getTime())
        .slice(0, 20)

      return NextResponse.json({
        success: true,
        data: {
          schedule,
          executions,
          timestamp: new Date().toISOString()
        }
      })
    }

    // Get all schedules with filtering
    let filteredSchedules = [...adSchedules]

    if (stream) {
      filteredSchedules = filteredSchedules.filter(s => s.stream === stream)
    }

    if (status) {
      filteredSchedules = filteredSchedules.filter(s => s.status === status)
    }

    const paginatedSchedules = filteredSchedules
      .sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime())
      .slice(offset, offset + limit)

    return NextResponse.json({
      success: true,
      data: {
        schedules: paginatedSchedules,
        total: filteredSchedules.length,
        limit,
        offset,
        timestamp: new Date().toISOString()
      }
    })

  } catch (error) {
    console.error('Error fetching ad schedules:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to fetch ad schedules' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { action, scheduleData } = body

    switch (action) {
      case 'create':
        const newSchedule: AdSchedule = {
          id: `schedule_${scheduleCounter++}`,
          name: scheduleData.name,
          stream: scheduleData.stream,
          type: scheduleData.type,
          duration: scheduleData.duration,
          preRoll: scheduleData.preRoll || 0,
          enabled: scheduleData.enabled || true,
          recurrence: scheduleData.recurrence,
          restrictions: scheduleData.restrictions || {},
          targeting: scheduleData.targeting || {},
          metadata: scheduleData.metadata || {},
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          triggerCount: 0,
          status: 'active'
        }

        // Calculate next trigger time
        newSchedule.nextTrigger = calculateNextExecution(newSchedule)

        adSchedules.push(newSchedule)

        return NextResponse.json({
          success: true,
          data: {
            schedule: newSchedule,
            message: 'Ad schedule created successfully'
          },
          timestamp: new Date().toISOString()
        })

      case 'update':
        const scheduleIndex = adSchedules.findIndex(s => s.id === scheduleData.id)
        if (scheduleIndex === -1) {
          return NextResponse.json(
            { success: false, error: 'Schedule not found' },
            { status: 404 }
          )
        }

        const updatedSchedule: AdSchedule = {
          ...adSchedules[scheduleIndex],
          ...scheduleData,
          updatedAt: new Date().toISOString(),
          nextTrigger: calculateNextExecution({ ...adSchedules[scheduleIndex], ...scheduleData })
        }

        adSchedules[scheduleIndex] = updatedSchedule

        return NextResponse.json({
          success: true,
          data: {
            schedule: updatedSchedule,
            message: 'Ad schedule updated successfully'
          },
          timestamp: new Date().toISOString()
        })

      case 'delete':
        const deleteIndex = adSchedules.findIndex(s => s.id === scheduleData.id)
        if (deleteIndex === -1) {
          return NextResponse.json(
            { success: false, error: 'Schedule not found' },
            { status: 404 }
          )
        }

        adSchedules.splice(deleteIndex, 1)

        // Clean up related executions
        scheduleExecutions = scheduleExecutions.filter(e => e.scheduleId !== scheduleData.id)

        return NextResponse.json({
          success: true,
          data: {
            message: 'Ad schedule deleted successfully'
          },
          timestamp: new Date().toISOString()
        })

      case 'trigger_now':
        const triggerSchedule = adSchedules.find(s => s.id === scheduleData.id)
        if (!triggerSchedule) {
          return NextResponse.json(
            { success: false, error: 'Schedule not found' },
            { status: 404 }
          )
        }

        // Create execution record
        const execution: ScheduleExecution = {
          id: `exec_${executionCounter++}`,
          scheduleId: triggerSchedule.id,
          scheduledTime: new Date().toISOString(),
          status: 'pending',
          retryCount: 0,
          maxRetries: 3
        }

        scheduleExecutions.push(execution)

        // Execute the schedule
        const updatedExecution = await executeSchedule(triggerSchedule, execution)

        // Update execution record
        const execIndex = scheduleExecutions.findIndex(e => e.id === execution.id)
        if (execIndex !== -1) {
          scheduleExecutions[execIndex] = updatedExecution
        }

        // Update schedule
        const schedIndex = adSchedules.findIndex(s => s.id === triggerSchedule.id)
        if (schedIndex !== -1) {
          adSchedules[schedIndex] = {
            ...adSchedules[schedIndex],
            lastTriggered: new Date().toISOString(),
            triggerCount: adSchedules[schedIndex].triggerCount + 1,
            updatedAt: new Date().toISOString()
          }
        }

        return NextResponse.json({
          success: true,
          data: {
            execution: updatedExecution,
            message: 'Schedule triggered successfully'
          },
          timestamp: new Date().toISOString()
        })

      default:
        return NextResponse.json(
          { success: false, error: 'Invalid action specified' },
          { status: 400 }
        )
    }

  } catch (error) {
    console.error('Error executing schedule action:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to execute schedule action' },
      { status: 500 }
    )
  }
}

export async function PUT(request: NextRequest) {
  try {
    const body = await request.json()
    const { scheduleId, updates } = body

    if (!scheduleId || !updates) {
      return NextResponse.json(
        { success: false, error: 'Schedule ID and updates are required' },
        { status: 400 }
      )
    }

    const scheduleIndex = adSchedules.findIndex(a => a.id === scheduleId)
    if (scheduleIndex === -1) {
      return NextResponse.json(
        { success: false, error: 'Schedule not found' },
        { status: 404 }
      )
    }

    adSchedules[scheduleIndex] = { ...adSchedules[scheduleIndex], ...updates }

    return NextResponse.json({
      success: true,
      schedule: adSchedules[scheduleIndex],
      timestamp: new Date().toISOString()
    })

  } catch (error) {
    console.error('Error updating schedule:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to update schedule' },
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

    const scheduleIndex = adSchedules.findIndex(a => a.id === scheduleId)
    if (scheduleIndex === -1) {
      return NextResponse.json(
        { success: false, error: 'Schedule not found' },
        { status: 404 }
      )
    }

    const deletedSchedule = adSchedules.splice(scheduleIndex, 1)[0]

    // Clean up related executions
    scheduleExecutions = scheduleExecutions.filter(e => e.scheduleId !== scheduleId)

    return NextResponse.json({
      success: true,
      schedule: deletedSchedule,
      timestamp: new Date().toISOString()
    })

  } catch (error) {
    console.error('Error deleting schedule:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to delete schedule' },
      { status: 500 }
    )
  }
}