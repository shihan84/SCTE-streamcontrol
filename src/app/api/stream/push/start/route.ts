/**
 * SCTE-35 Streaming Control Center - Push Stream Start API
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
    const requiredFields = ['name', 'sourceUrl', 'outputFormats'];
    for (const field of requiredFields) {
      if (!body[field]) {
        return NextResponse.json(
          { error: `Missing required field: ${field}` },
          { status: 400 }
        );
      }
    }

    // Check if streamers are initialized
    if (!GlobalInstanceManager.isInitialized()) {
        return NextResponse.json(
            { error: 'Streaming components not initialized. Please call /api/stream/push/init first.' },
            { status: 400 }
        );
    }

    const mediaServer = GlobalInstanceManager.getMediaServer();
    const multiFormatStreamer = GlobalInstanceManager.getMultiFormatStreamer();
    const srtStreamer = GlobalInstanceManager.getSRTStreamer();

    if (!mediaServer || !multiFormatStreamer || !srtStreamer) {
        return NextResponse.json(
            { error: 'Streaming components not properly initialized' },
            { status: 500 }
        );
    }

    // Create stream configuration
    const streamConfig = {
      id: `stream_${Date.now()}`,
      name: body.name,
      sourceUrl: body.sourceUrl,
      outputFormats: body.outputFormats.map((format: any) => ({
        format: format.format,
        enabled: format.enabled || true,
        settings: format.settings || {},
        url: format.url || ''
      })),
      videoSettings: body.videoSettings || {
        codec: 'libx264',
        bitrate: 5,
        resolution: '1920x1080',
        framerate: '30',
        gop: 12,
        bFrames: 5,
        profile: 'high',
        pixelFormat: 'yuv420p'
      },
      audioSettings: body.audioSettings || {
        codec: 'aac',
        bitrate: 128,
        sampleRate: 48000,
        channels: 2
      },
      scte35Settings: body.scte35Settings || {
        enabled: true,
        pid: 500,
        nullPid: 8191,
        autoInsert: false
      },
      outputSettings: body.outputSettings || {
        hls: {
          enabled: true,
          segmentDuration: 2,
          playlistLength: 6,
          outputDir: './tmp/hls'
        },
        dash: {
          enabled: true,
          segmentDuration: 2,
          playlistLength: 6,
          outputDir: './tmp/dash'
        },
        srt: {
          enabled: false,
          port: 9000,
          latency: 120,
          overheadBandwidth: 25
        },
        rtmp: {
          enabled: false,
          port: 1935,
          chunkSize: 4096
        }
      },
      transcoding: body.transcoding || {
        enabled: false,
        profiles: []
      }
    };

    // Validate configuration
    const validation = multiFormatStreamer.validateConfig(streamConfig);
    if (!validation.isValid) {
      return NextResponse.json(
        { error: 'Invalid configuration', details: validation.errors },
        { status: 400 }
      );
    }

    // Start the stream
    const stream = await multiFormatStreamer.startPushStream(streamConfig);

    return NextResponse.json({
      success: true,
      message: 'Push stream started successfully',
      stream: {
        id: stream.id,
        name: stream.name,
        status: stream.status,
        outputUrls: Object.fromEntries(stream.outputUrls),
        startTime: stream.startTime,
        metrics: stream.metrics
      }
    });

  } catch (error) {
    console.error('Error starting push stream:', error);
    return NextResponse.json(
      { error: 'Failed to start push stream', details: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 }
    );
  }
}

export async function GET() {
  try {
    // Check if streamers are initialized
    if (!GlobalInstanceManager.isInitialized()) {
        return NextResponse.json(
            { error: 'Streaming components not initialized. Please call /api/stream/push/init first.' },
            { status: 400 }
        );
    }

    const multiFormatStreamer = GlobalInstanceManager.getMultiFormatStreamer();

    if (!multiFormatStreamer) {
        return NextResponse.json(
            { error: 'MultiFormatStreamer not properly initialized' },
            { status: 500 }
        );
    }

    const availableFormats = multiFormatStreamer.getAvailableFormats();

    return NextResponse.json({
      success: true,
      availableFormats,
      defaultConfig: {
        videoSettings: {
          codec: 'libx264',
          bitrate: 5,
          resolution: '1920x1080',
          framerate: '30',
          gop: 12,
          bFrames: 5,
          profile: 'high',
          pixelFormat: 'yuv420p'
        },
        audioSettings: {
          codec: 'aac',
          bitrate: 128,
          sampleRate: 48000,
          channels: 2
        },
        scte35Settings: {
          enabled: true,
          pid: 500,
          nullPid: 8191,
          autoInsert: false
        }
      }
    });

  } catch (error) {
    console.error('Error getting push stream info:', error);
    return NextResponse.json(
      { error: 'Failed to get push stream info', details: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 }
    );
  }
}