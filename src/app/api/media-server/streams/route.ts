import { NextRequest, NextResponse } from 'next/server';
import { MediaServer } from '@/lib/media-server/MediaServer';

// Global media server instance
let mediaServer: MediaServer | null = null;

export async function GET(request: NextRequest) {
  try {
    // Get media server instance
    if (!mediaServer) {
      return NextResponse.json({
        success: true,
        streams: [],
        message: 'Media server is not running'
      });
    }

    // Get all streams
    const streams = mediaServer.getAllStreams();

    return NextResponse.json({
      success: true,
      streams: streams.map(stream => ({
        id: stream.id,
        name: stream.name,
        status: stream.status,
        viewers: stream.viewers,
        metrics: stream.metrics,
        health: stream.health,
        config: {
          videoSettings: stream.config.videoSettings,
          audioSettings: stream.config.audioSettings,
          scte35Settings: stream.config.scte35Settings
        },
        startTime: stream.startTime,
        uptime: stream.metrics.uptime
      })),
      message: 'Streams retrieved successfully'
    });

  } catch (error) {
    console.error('Error getting streams:', error);
    return NextResponse.json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 });
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const streamName = searchParams.get('streamName');

    if (!streamName) {
      return NextResponse.json({
        success: false,
        error: 'Stream name is required'
      }, { status: 400 });
    }

    // Get media server instance
    if (!mediaServer) {
      return NextResponse.json({
        success: false,
        error: 'Media server is not running'
      }, { status: 400 });
    }

    // Stop and remove the stream
    await mediaServer.stopStream(streamName);

    return NextResponse.json({
      success: true,
      message: `Stream '${streamName}' deleted successfully`
    });

  } catch (error) {
    console.error('Error deleting stream:', error);
    return NextResponse.json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 });
  }
}