import { NextRequest, NextResponse } from 'next/server';
import { MediaServer } from '@/lib/media-server/MediaServer';

// Global media server instance
let mediaServer: MediaServer | null = null;

export async function POST(request: NextRequest) {
  try {
    const eventData = await request.json();
    
    // Validate required fields
    const requiredFields = ['streamName', 'type'];
    for (const field of requiredFields) {
      if (!eventData[field]) {
        return NextResponse.json({
          success: false,
          error: `Missing required field: ${field}`
        }, { status: 400 });
      }
    }

    // Validate event type
    if (!['CUE-OUT', 'CUE-IN'].includes(eventData.type)) {
      return NextResponse.json({
        success: false,
        error: 'Invalid event type. Must be CUE-OUT or CUE-IN'
      }, { status: 400 });
    }

    // Validate duration for CUE-OUT events
    if (eventData.type === 'CUE-OUT' && (!eventData.duration || eventData.duration <= 0)) {
      return NextResponse.json({
        success: false,
        error: 'Duration is required and must be positive for CUE-OUT events'
      }, { status: 400 });
    }

    // Get media server instance
    if (!mediaServer) {
      mediaServer = new MediaServer();
      await mediaServer.start();
    }

    // Inject SCTE-35 event
    const scte35Event = await mediaServer.injectSCTE35(eventData.streamName, {
      type: eventData.type,
      duration: eventData.duration || 0,
      preRoll: eventData.preRoll || 0
    });

    return NextResponse.json({
      success: true,
      event: {
        id: scte35Event.id,
        eventId: scte35Event.eventId,
        type: scte35Event.type,
        duration: scte35Event.duration,
        preRoll: scte35Event.preRoll,
        timestamp: scte35Event.timestamp,
        streamName: scte35Event.streamName,
        status: scte35Event.status
      },
      message: `SCTE-35 ${eventData.type} event injected successfully`
    });

  } catch (error) {
    console.error('Error injecting SCTE-35 event:', error);
    return NextResponse.json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 });
  }
}