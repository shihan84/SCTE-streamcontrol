/**
 * SCTE-35 Streaming Control Center - Stream Configuration API
 * 
 * © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.
 * 
 * This software is the property of Morus Broadcasting Pvt Ltd and is protected by
 * copyright law and international treaties. Unauthorized use, reproduction, or
 * distribution is strictly prohibited.
 */

import { NextRequest, NextResponse } from 'next/server';
import { MultiFormatStreamer } from '@/lib/media-server/MultiFormatStreamer';
import { SRTStreamer } from '@/lib/media-server/SRTStreamer';

// Global instances
let multiFormatStreamer: MultiFormatStreamer | null = null;
let srtStreamer: SRTStreamer | null = null;

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    
    // Initialize streamers if not already initialized
    if (!multiFormatStreamer) {
      multiFormatStreamer = new MultiFormatStreamer(new MediaServer());
      await multiFormatStreamer.start();
    }
    
    if (!srtStreamer) {
      srtStreamer = new SRTStreamer();
      await srtStreamer.start();
    }

    const { action, config } = body;

    switch (action) {
      case 'validate':
        // Validate stream configuration
        const validation = multiFormatStreamer.validateConfig(config);
        return NextResponse.json({
          success: true,
          isValid: validation.isValid,
          errors: validation.errors
        });

      case 'create_default':
        // Create default configuration
        const defaultConfig = multiFormatStreamer.createDefaultConfig(
          config.name || 'default_stream',
          config.sourceUrl || 'rtmp://localhost:1935/live/test'
        );
        return NextResponse.json({
          success: true,
          config: defaultConfig
        });

      case 'create_srt_config':
        // Create SRT configuration
        let srtConfig;
        if (config.mode === 'listener') {
          srtConfig = srtStreamer.createListenerConfig(
            config.name || 'srt_listener',
            config.port || 9000,
            config.streamId || 'stream1'
          );
        } else if (config.mode === 'caller') {
          srtConfig = srtStreamer.createCallerConfig(
            config.name || 'srt_caller',
            config.remoteHost || 'localhost',
            config.remotePort || 9000,
            config.streamId || 'stream1'
          );
        } else {
          return NextResponse.json({
            success: false,
            error: 'Invalid SRT mode. Must be listener or caller'
          }, { status: 400 });
        }

        // Validate SRT configuration
        const srtValidation = srtStreamer.validateConfig(srtConfig);
        return NextResponse.json({
          success: true,
          config: srtConfig,
          validation: srtValidation
        });

      case 'test_connection':
        // Test SRT connection
        if (!config.host || !config.port) {
          return NextResponse.json({
            success: false,
            error: 'Host and port are required for connection test'
          }, { status: 400 });
        }

        const connectionResult = await srtStreamer.testConnection(
          config.host,
          config.port,
          config.timeout || 5000
        );

        return NextResponse.json({
          success: true,
          connectionResult: {
            connected: connectionResult,
            host: config.host,
            port: config.port,
            message: connectionResult ? 'Connection successful' : 'Connection failed'
          }
        });

      default:
        return NextResponse.json({
          success: false,
          error: 'Invalid action'
        }, { status: 400 });
    }

  } catch (error) {
    console.error('Error in stream configuration:', error);
    return NextResponse.json(
      { error: 'Failed to process stream configuration', details: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 }
    );
  }
}

export async function GET() {
  try {
    // Initialize streamers if not already initialized
    if (!multiFormatStreamer) {
      multiFormatStreamer = new MultiFormatStreamer(new MediaServer());
    }
    
    if (!srtStreamer) {
      srtStreamer = new SRTStreamer();
    }

    // Get available formats and configurations
    const availableFormats = multiFormatStreamer.getAvailableFormats();
    const serverStatus = multiFormatStreamer.getServerStatus();
    const srtStatus = srtStreamer.getServerStatus();

    return NextResponse.json({
      success: true,
      availableFormats,
      serverStatus,
      srtStatus,
      templates: {
        push_stream: {
          name: 'example_push_stream',
          sourceUrl: 'rtmp://localhost:1935/live/test',
          outputFormats: [
            { format: 'HLS', enabled: true },
            { format: 'DASH', enabled: true },
            { format: 'SRT', enabled: false },
            { format: 'RTMP', enabled: false }
          ],
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
        },
        srt_listener: {
          name: 'srt_listener_example',
          mode: 'listener',
          localPort: 9000,
          latency: 120,
          overheadBandwidth: 25,
          streamId: 'listener_stream',
          videoSettings: {
            codec: 'libx264',
            bitrate: 5,
            resolution: '1920x1080',
            framerate: '30'
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
            autoInsert: false
          }
        },
        srt_caller: {
          name: 'srt_caller_example',
          mode: 'caller',
          localPort: 0,
          remoteHost: 'remote-server.com',
          remotePort: 9000,
          latency: 120,
          overheadBandwidth: 25,
          streamId: 'caller_stream',
          videoSettings: {
            codec: 'libx264',
            bitrate: 5,
            resolution: '1920x1080',
            framerate: '30'
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
            autoInsert: false
          }
        }
      },
      examples: {
        sourceUrls: [
          'rtmp://localhost:1935/live/stream',
          'srt://localhost:9000?streamid=test',
          'udp://@:5000',
          'file:/path/to/video.mp4',
          'http://example.com/stream.m3u8'
        ],
        outputFormats: [
          {
            format: 'HLS',
            description: 'HTTP Live Streaming',
            urlPattern: 'http://localhost:3000/hls/{streamName}/{streamName}.m3u8'
          },
          {
            format: 'DASH',
            description: 'MPEG-DASH',
            urlPattern: 'http://localhost:3000/dash/{streamName}/{streamName}.mpd'
          },
          {
            format: 'SRT',
            description: 'Secure Reliable Transport',
            urlPattern: 'srt://localhost:{port}?streamid={streamName}'
          },
          {
            format: 'RTMP',
            description: 'Real-Time Messaging Protocol',
            urlPattern: 'rtmp://localhost:{port}/live/{streamName}'
          }
        ]
      }
    });

  } catch (error) {
    console.error('Error getting stream configuration:', error);
    return NextResponse.json(
      { error: 'Failed to get stream configuration', details: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 }
    );
  }
}