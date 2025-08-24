/**
 * SCTE-35 Streaming Control Center - Push Stream SCTE-35 API
 * 
 * © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.
 * 
 * This software is the property of Morus Broadcasting Pvt Ltd and is protected by
 * copyright law and international treaties. Unauthorized use, reproduction, or
 * distribution is strictly prohibited.
 */

import { NextRequest, NextResponse } from 'next/server';
import { GlobalInstanceManager } from '@/lib/global-instances';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    
    // Validate required fields
    const requiredFields = ['streamName', 'type'];
    for (const field of requiredFields) {
      if (!body[field]) {
        return NextResponse.json(
          { error: `Missing required field: ${field}` },
          { status: 400 }
        );
      }
    }

    // Validate event type
    if (!['CUE-OUT', 'CUE-IN'].includes(body.type)) {
      return NextResponse.json(
        { error: 'Invalid event type. Must be CUE-OUT or CUE-IN' },
        { status: 400 }
      );
    }

    // Validate duration for CUE-OUT
    if (body.type === 'CUE-OUT' && (!body.duration || body.duration <= 0)) {
      return NextResponse.json(
        { error: 'Duration must be positive for CUE-OUT events' },
        { status: 400 }
      );
    }

  // Check if streamers are initialized
    if (!GlobalInstanceManager.isInitialized()) {
        return NextResponse.json(
            { error: 'Streaming components not initialized. Please call /api/stream/push/init first.' },
            { status: 400 }
        );
    }

    const multiFormatStreamer = GlobalInstanceManager.getMultiFormatStreamer();

    // Check if streamer is initialized
    if (!multiFormatStreamer) {
        return NextResponse.json(
            { error: 'Multi-format streamer is not initialized' },
            { status: 400 }
        );
    }

    // Inject SCTE-35 event
    const eventData = {
      type: body.type,
      duration: body.duration || 30,
      preRoll: body.preRoll || 2
    };

    const event = await multiFormatStreamer.injectSCTE35(body.streamName, eventData);

    return NextResponse.json({
      success: true,
      message: `SCTE-35 ${body.type} event injected successfully`,
      event: {
        id: event.id,
        eventId: event.eventId,
        type: event.type,
        duration: event.duration,
        preRoll: event.preRoll,
        timestamp: event.timestamp,
        streamName: event.streamName,
        status: event.status
      }
    });

  } catch (error) {
    console.error('Error injecting SCTE-35 event:', error);
    return NextResponse.json(
      { error: 'Failed to inject SCTE-35 event', details: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 }
    );
  }
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const streamName = searchParams.get('streamName');

    // Check if streamers are initialized
    if (!GlobalInstanceManager.isInitialized()) {
        return NextResponse.json({
            success: true,
            events: [],
            message: 'Streaming components not initialized'
        });
    }

    const multiFormatStreamer = GlobalInstanceManager.getMultiFormatStreamer();

    // Get SCTE-35 events
    let events: any[] = [];
    
    if (multiFormatStreamer && streamName) {
      // Get events for specific stream
      const stream = multiFormatStreamer.getStream(streamName);
      if (stream) {
        // Note: This would need to be implemented in MultiFormatStreamer
        events = []; // Placeholder - would get events from stream
      }
    } else if (multiFormatStreamer) {
      // Get all events
      events = []; // Placeholder - would get all events
    }

    return NextResponse.json({
      success: true,
      events: events.map(event => ({
        id: event.id,
        eventId: event.eventId,
        type: event.type,
        duration: event.duration,
        preRoll: event.preRoll,
        timestamp: event.timestamp,
        streamName: event.streamName,
        status: event.status
      }))
    });

  } catch (error) {
    console.error('Error getting SCTE-35 events:', error);
    return NextResponse.json(
      { error: 'Failed to get SCTE-35 events', details: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 }
    );
  }
}