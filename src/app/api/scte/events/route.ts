import { NextRequest, NextResponse } from 'next/server'

// In-memory storage for SCTE-35 events (in production, use a database)
let scteEvents = []
let nextEventId = 100023

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const limit = searchParams.get('limit') ? parseInt(searchParams.get('limit')!) : 50
    
    const events = scteEvents.slice(0, limit)
    
    return NextResponse.json({
      success: true,
      events,
      total: scteEvents.length,
      nextEventId
    })
  } catch (error) {
    console.error('Error fetching SCTE-35 events:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to fetch SCTE-35 events' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { type, adDuration, preRollDuration } = body

    if (!type || !['CUE-OUT', 'CUE-IN'].includes(type)) {
      return NextResponse.json(
        { success: false, error: 'Invalid event type' },
        { status: 400 }
      )
    }

    const event = {
      id: Date.now().toString(),
      eventId: nextEventId,
      type,
      adDuration: type === 'CUE-OUT' ? adDuration || 600 : 0,
      preRollDuration: type === 'CUE-OUT' ? preRollDuration || 0 : 0,
      timestamp: new Date().toISOString(),
      status: type === 'CUE-OUT' ? 'active' : 'completed'
    }

    scteEvents.unshift(event)
    nextEventId++

    // Simulate event completion for CUE-OUT
    if (type === 'CUE-OUT' && adDuration) {
      setTimeout(() => {
        const eventIndex = scteEvents.findIndex(e => e.id === event.id)
        if (eventIndex !== -1) {
          scteEvents[eventIndex].status = 'completed'
        }
      }, adDuration * 1000)
    }

    // Here you would integrate with your actual SCTE-35 injection system
    // For example, sending commands to Flussonic Media Server or OBS
    console.log(`SCTE-35 ${type} event sent:`, {
      eventId: event.eventId,
      adDuration: event.adDuration,
      preRollDuration: event.preRollDuration,
      timestamp: event.timestamp
    })

    return NextResponse.json({
      success: true,
      event,
      message: `SCTE-35 ${type} event sent successfully`
    })
  } catch (error) {
    console.error('Error creating SCTE-35 event:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to create SCTE-35 event' },
      { status: 500 }
    )
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const eventId = searchParams.get('eventId')

    if (!eventId) {
      return NextResponse.json(
        { success: false, error: 'Event ID is required' },
        { status: 400 }
      )
    }

    const eventIndex = scteEvents.findIndex(e => e.id === eventId)
    if (eventIndex === -1) {
      return NextResponse.json(
        { success: false, error: 'Event not found' },
        { status: 404 }
      )
    }

    scteEvents.splice(eventIndex, 1)

    return NextResponse.json({
      success: true,
      message: 'SCTE-35 event deleted successfully'
    })
  } catch (error) {
    console.error('Error deleting SCTE-35 event:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to delete SCTE-35 event' },
      { status: 500 }
    )
  }
}