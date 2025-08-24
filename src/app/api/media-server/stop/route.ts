import { NextRequest, NextResponse } from 'next/server';
import { MediaServer } from '@/lib/media-server/MediaServer';

// Global media server instance
let mediaServer: MediaServer | null = null;

export async function POST(request: NextRequest) {
  try {
    const { streamName } = await request.json();
    
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

    // Stop the stream
    await mediaServer.stopStream(streamName);

    return NextResponse.json({
      success: true,
      message: `Stream '${streamName}' stopped successfully`
    });

  } catch (error) {
    console.error('Error stopping media server stream:', error);
    return NextResponse.json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 });
  }
}