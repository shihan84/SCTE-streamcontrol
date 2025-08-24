import { NextRequest, NextResponse } from 'next/server';
import { MediaServer } from '@/lib/media-server/MediaServer';

// Global media server instance
let mediaServer: MediaServer | null = null;

export async function POST(request: NextRequest) {
  try {
    // Initialize media server if not already running
    if (!mediaServer) {
      mediaServer = new MediaServer();
      await mediaServer.start();
    }

    const config = await request.json();
    
    // Validate required fields
    const requiredFields = ['name', 'inputUrl', 'outputUrl'];
    for (const field of requiredFields) {
      if (!config[field]) {
        return NextResponse.json({
          success: false,
          error: `Missing required field: ${field}`
        }, { status: 400 });
      }
    }

    // Set default values for optional fields
    const streamConfig = {
      name: config.name,
      inputUrl: config.inputUrl,
      outputUrl: config.outputUrl,
      videoSettings: {
        codec: config.videoSettings?.codec || 'libx264',
        bitrate: config.videoSettings?.bitrate || 5,
        resolution: config.videoSettings?.resolution || '1920x1080',
        framerate: config.videoSettings?.framerate || '30',
        gop: config.videoSettings?.gop || 12,
        bFrames: config.videoSettings?.bFrames || 5,
        profile: config.videoSettings?.profile || 'high'
      },
      audioSettings: {
        codec: config.audioSettings?.codec || 'aac',
        bitrate: config.audioSettings?.bitrate || 128,
        sampleRate: config.audioSettings?.sampleRate || 48000,
        channels: config.audioSettings?.channels || 2
      },
      scte35Settings: {
        enabled: config.scte35Settings?.enabled ?? true,
        pid: config.scte35Settings?.pid || 500,
        nullPid: config.scte35Settings?.nullPid || 8191
      },
      hlsSettings: {
        segmentDuration: config.hlsSettings?.segmentDuration || 2,
        playlistLength: config.hlsSettings?.playlistLength || 6,
        outputDir: config.hlsSettings?.outputDir || './tmp/hls'
      }
    };

    // Start the stream
    const stream = await mediaServer.startStream(streamConfig);

    return NextResponse.json({
      success: true,
      stream: {
        id: stream.id,
        name: stream.name,
        status: stream.status,
        config: stream.config,
        startTime: stream.startTime,
        url: `${stream.config.outputUrl}/${stream.config.name}.m3u8`
      },
      message: `Stream '${stream.name}' started successfully`
    });

  } catch (error) {
    console.error('Error starting media server stream:', error);
    return NextResponse.json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 });
  }
}