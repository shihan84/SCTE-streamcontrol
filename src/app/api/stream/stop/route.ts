import { NextRequest, NextResponse } from 'next/server'

// In-memory stream state (in production, use a database or state management)
let streamState = {
  isLive: false,
  startTime: null,
  viewers: 0,
  health: 'good',
  lastUpdated: null
}

export async function POST(request: NextRequest) {
  try {
    // Update stream state
    streamState = {
      isLive: false,
      startTime: null,
      viewers: 0,
      health: 'good',
      lastUpdated: new Date().toISOString()
    }

    // Here you would integrate with your actual streaming system
    // For example, sending commands to OBS Studio or Flussonic Media Server
    console.log('Stream stopped:', {
      stopTime: new Date().toISOString()
    })

    // Simulate OBS Studio integration
    // In a real implementation, you would use OBS Studio's WebSocket API
    // to stop the streaming

    // Simulate Flussonic Media Server integration
    // In a real implementation, you would make API calls to Flussonic
    // to stop the stream and clean up resources

    return NextResponse.json({
      success: true,
      streamState,
      message: 'Stream stopped successfully'
    })
  } catch (error) {
    console.error('Error stopping stream:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to stop stream' },
      { status: 500 }
    )
  }
}

export async function GET() {
  return NextResponse.json({
    success: true,
    streamState
  })
}