/**
 * SCTE-35 Streaming Control Center - Push Stream Stop API
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
    if (!body.streamName) {
      return NextResponse.json(
        { error: 'Missing required field: streamName' },
        { status: 400 }
      );
    }

    // Check if streamers are initialized
    if (!GlobalInstanceManager.isInitialized()) {
        return NextResponse.json(
            { error: 'Streaming components not initialized' },
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

    // Stop the stream
    await multiFormatStreamer.stopStream(body.streamName);

    return NextResponse.json({
      success: true,
      message: `Push stream '${body.streamName}' stopped successfully`
    });

  } catch (error) {
    console.error('Error stopping push stream:', error);
    return NextResponse.json(
      { error: 'Failed to stop push stream', details: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 }
    );
  }
}

export async function GET() {
  try {
    // Get all active streams
    if (!multiFormatStreamer) {
      return NextResponse.json({
        success: true,
        streams: [],
        message: 'Multi-format streamer is not initialized'
      });
    }

    const streams = multiFormatStreamer.getAllStreams();

    return NextResponse.json({
      success: true,
      streams: streams.map(stream => ({
        id: stream.id,
        name: stream.name,
        status: stream.status,
        startTime: stream.startTime,
        viewers: stream.viewers,
        health: stream.health,
        outputFormats: Array.from(stream.outputUrls.keys()),
        metrics: stream.metrics
      }))
    });

  } catch (error) {
    console.error('Error getting push streams:', error);
    return NextResponse.json(
      { error: 'Failed to get push streams', details: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 }
    );
  }
}