import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const config = await request.json();
    
    // Generate OBS configuration for self-hosted media server
    const obsConfig = {
      output: {
        type: 'custom_output',
        settings: {
          server: config.serverUrl || 'rtmp://localhost:1935',
          streamKey: config.streamName || 'live',
          bframes: config.videoSettings?.bFrames || 5,
          bitrate: config.videoSettings?.bitrate || 5000,
          keyint_sec: config.videoSettings?.gop || 2,
          profile: config.videoSettings?.profile || 'high',
          preset: 'veryfast',
          rate_control: 'CBR',
          audio_bitrate: config.audioSettings?.bitrate || 128,
          audio_sample_rate: config.audioSettings?.sampleRate || 48000,
          audio_channels: config.audioSettings?.channels || 2
        },
        name: 'Self-Hosted Media Server'
      }
    };

    // Generate FFmpeg command for testing
    const ffmpegCommand = `ffmpeg -re -i input.mp4 \\
  -c:v libx264 -b:v ${config.videoSettings?.bitrate || 5}M \\
  -c:a aac -b:a ${config.audioSettings?.bitrate || 128}k \\
  -f flv rtmp://localhost:1935/${config.streamName || 'live'}`;

    // Generate configuration file content
    const configContent = `# Self-Hosted Media Server Configuration
# Stream: ${config.streamName || 'live'}

[stream]
name = ${config.streamName || 'live'}
input_source = ${config.inputUrl || 'rtmp://localhost:1935/live'}
output_url = ${config.outputUrl || 'http://localhost:8080/hls'}

[video]
codec = ${config.videoSettings?.codec || 'libx264'}
bitrate = ${config.videoSettings?.bitrate || 5}M
resolution = ${config.videoSettings?.resolution || '1920x1080'}
framerate = ${config.videoSettings?.framerate || '30'}
gop = ${config.videoSettings?.gop || 12}
b_frames = ${config.videoSettings?.bFrames || 5}
profile = ${config.videoSettings?.profile || 'high'}

[audio]
codec = ${config.audioSettings?.codec || 'aac'}
bitrate = ${config.audioSettings?.bitrate || 128}k
sample_rate = ${config.audioSettings?.sampleRate || 48000}
channels = ${config.audioSettings?.channels || 2}

[scte35]
enabled = ${config.scte35Settings?.enabled ?? true}
pid = ${config.scte35Settings?.pid || 500}
null_pid = ${config.scte35Settings?.nullPid || 8191}

[hls]
segment_duration = ${config.hlsSettings?.segmentDuration || 2}
playlist_length = ${config.hlsSettings?.playlistLength || 6}
output_dir = ${config.hlsSettings?.outputDir || './tmp/hls'}`;

    return NextResponse.json({
      success: true,
      config: {
        obsConfig,
        ffmpegCommand,
        configContent,
        endpoints: {
          rtmp: `rtmp://localhost:1935/${config.streamName || 'live'}`,
          hls: `http://localhost:8080/hls/${config.streamName || 'live'}.m3u8`,
          api: 'http://localhost:3000/api/media-server'
        },
        streamSettings: {
          name: config.streamName || 'live',
          videoSettings: config.videoSettings || {},
          audioSettings: config.audioSettings || {},
          scte35Settings: config.scte35Settings || {},
          hlsSettings: config.hlsSettings || {}
        }
      },
      message: 'Configuration generated successfully'
    });

  } catch (error) {
    console.error('Error generating configuration:', error);
    return NextResponse.json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 });
  }
}