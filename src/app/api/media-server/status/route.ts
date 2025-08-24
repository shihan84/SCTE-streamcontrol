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
        server: {
          isRunning: false,
          uptime: 0,
          streamCount: 0,
          totalViewers: 0,
          streams: []
        },
        message: 'Media server is not running'
      });
    }

    // Get server status
    const serverStatus = mediaServer.getServerStatus();
    const streams = mediaServer.getAllStreams();

    return NextResponse.json({
      success: true,
      server: {
        ...serverStatus,
        streams: streams.map(stream => ({
          id: stream.id,
          name: stream.name,
          status: stream.status,
          viewers: stream.viewers,
          metrics: stream.metrics,
          health: stream.health,
          startTime: stream.startTime,
          uptime: stream.metrics.uptime
        }))
      },
      message: 'Media server status retrieved successfully'
    });

  } catch (error) {
    console.error('Error getting media server status:', error);
    return NextResponse.json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 });
  }
}