/**
 * SCTE-35 Streaming Control Center - Multi-Format Streamer
 * 
 * © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.
 * 
 * This software is the property of Morus Broadcasting Pvt Ltd and is protected by
 * copyright law and international treaties. Unauthorized use, reproduction, or
 * distribution is strictly prohibited.
 */

import { EventEmitter } from 'events';
import { spawn, ChildProcess } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import { MediaServer, StreamConfig, Stream, SCTE35Event } from './MediaServer';
import { HLSGenerator } from './HLSGenerator';
import { SCTE35Injector } from './SCTE35Injector';

export interface StreamFormat {
  id: string;
  name: string;
  protocol: 'RTMP' | 'SRT' | 'HLS' | 'DASH' | 'RTSP' | 'WebRTC';
  description: string;
  supportedCodecs: string[];
  defaultSettings: any;
}

export interface StreamPushConfig {
  id: string;
  name: string;
  sourceUrl: string;
  outputFormats: StreamOutputFormat[];
  videoSettings: {
    codec: string;
    bitrate: number;
    resolution: string;
    framerate: string;
    gop: number;
    bFrames: number;
    profile: string;
    pixelFormat: string;
  };
  audioSettings: {
    codec: string;
    bitrate: number;
    sampleRate: number;
    channels: number;
  };
  scte35Settings: {
    enabled: boolean;
    pid: number;
    nullPid: number;
    autoInsert: boolean;
  };
  outputSettings: {
    hls: {
      enabled: boolean;
      segmentDuration: number;
      playlistLength: number;
      outputDir: string;
    };
    dash: {
      enabled: boolean;
      segmentDuration: number;
      playlistLength: number;
      outputDir: string;
    };
    srt: {
      enabled: boolean;
      port: number;
      latency: number;
      overheadBandwidth: number;
    };
    rtmp: {
      enabled: boolean;
      port: number;
      chunkSize: number;
    };
  };
  transcoding: {
    enabled: boolean;
    profiles: TranscodeProfile[];
  };
}

export interface StreamOutputFormat {
  format: 'HLS' | 'DASH' | 'SRT' | 'RTMP' | 'RTSP';
  enabled: boolean;
  settings: any;
  url: string;
}

export interface TranscodeProfile {
  name: string;
  video: {
    codec: string;
    bitrate: number;
    resolution: string;
    framerate: string;
  };
  audio: {
    codec: string;
    bitrate: number;
    sampleRate: number;
  };
}

export interface PushStream {
  id: string;
  name: string;
  config: StreamPushConfig;
  status: 'starting' | 'active' | 'stopping' | 'stopped' | 'error';
  processes: Map<string, ChildProcess>;
  startTime?: Date;
  viewers: number;
  metrics: {
    inputBitrate: number;
    outputBitrate: number;
    fps: number;
    audioLevel: number;
    latency: number;
    uptime: number;
    cpuUsage: number;
    memoryUsage: number;
  };
  health: 'good' | 'warning' | 'error';
  outputUrls: Map<string, string>;
}

export class MultiFormatStreamer extends EventEmitter {
  private streams: Map<string, PushStream> = new Map();
  private mediaServer: MediaServer;
  private hlsGenerator: HLSGenerator;
  private scte35Injector: SCTE35Injector;
  private eventIdCounter: number = 100023;
  private isRunning: boolean = false;
  private availableFormats: StreamFormat[];

  constructor(mediaServer: MediaServer) {
    super();
    this.mediaServer = mediaServer;
    this.hlsGenerator = new HLSGenerator();
    this.scte35Injector = new SCTE35Injector();
    
    this.initializeFormats();
    this.setupEventListeners();
  }

  private initializeFormats(): void {
    this.availableFormats = [
      {
        id: 'hls',
        name: 'HTTP Live Streaming',
        protocol: 'HLS',
        description: 'Adaptive bitrate streaming over HTTP',
        supportedCodecs: ['h264', 'h265', 'aac'],
        defaultSettings: {
          segmentDuration: 2,
          playlistLength: 6,
          outputDir: './tmp/hls'
        }
      },
      {
        id: 'dash',
        name: 'MPEG-DASH',
        protocol: 'DASH',
        description: 'Dynamic Adaptive Streaming over HTTP',
        supportedCodecs: ['h264', 'h265', 'vp9', 'aac'],
        defaultSettings: {
          segmentDuration: 2,
          playlistLength: 6,
          outputDir: './tmp/dash'
        }
      },
      {
        id: 'srt',
        name: 'Secure Reliable Transport',
        protocol: 'SRT',
        description: 'Secure, reliable transport over UDP',
        supportedCodecs: ['h264', 'h265', 'mpeg2', 'aac'],
        defaultSettings: {
          port: 9000,
          latency: 120,
          overheadBandwidth: 25
        }
      },
      {
        id: 'rtmp',
        name: 'Real-Time Messaging Protocol',
        protocol: 'RTMP',
        description: 'Real-time streaming protocol',
        supportedCodecs: ['h264', 'h265', 'aac'],
        defaultSettings: {
          port: 1935,
          chunkSize: 4096
        }
      },
      {
        id: 'rtsp',
        name: 'Real-Time Streaming Protocol',
        protocol: 'RTSP',
        description: 'Real-time streaming protocol for IP cameras',
        supportedCodecs: ['h264', 'h265', 'mpeg4', 'aac'],
        defaultSettings: {
          port: 8554
        }
      }
    ];
  }

  private setupEventListeners(): void {
    this.scte35Injector.on('eventInjected', (event: SCTE35Event) => {
      this.emit('scte35Event', event);
    });

    this.mediaServer.on('streamHealth', (data: any) => {
      this.emit('streamHealth', data);
    });
  }

  async start(): Promise<void> {
    if (this.isRunning) {
      throw new Error('Multi-format streamer is already running');
    }

    try {
      // Create necessary directories
      this.createDirectories();
      
      // Initialize components
      await this.hlsGenerator.initialize();
      await this.mediaServer.start();
      
      this.isRunning = true;
      this.emit('started');
      console.log('Multi-format streamer started successfully');
    } catch (error) {
      console.error('Failed to start multi-format streamer:', error);
      throw error;
    }
  }

  async stop(): Promise<void> {
    if (!this.isRunning) {
      return;
    }

    try {
      // Stop all streams
      for (const [streamName, stream] of this.streams) {
        await this.stopStream(streamName);
      }

      // Stop components
      await this.mediaServer.stop();
      await this.hlsGenerator.stop();
      
      this.isRunning = false;
      this.emit('stopped');
      console.log('Multi-format streamer stopped');
    } catch (error) {
      console.error('Error stopping multi-format streamer:', error);
      throw error;
    }
  }

  async startPushStream(config: StreamPushConfig): Promise<PushStream> {
    if (!this.isRunning) {
      throw new Error('Multi-format streamer is not running');
    }

    if (this.streams.has(config.name)) {
      throw new Error(`Stream '${config.name}' already exists`);
    }

    try {
      // Create stream object
      const stream: PushStream = {
        id: `push_${Date.now()}`,
        name: config.name,
        config,
        status: 'starting',
        processes: new Map(),
        viewers: 0,
        metrics: {
          inputBitrate: 0,
          outputBitrate: 0,
          fps: 0,
          audioLevel: -20,
          latency: 0,
          uptime: 0,
          cpuUsage: 0,
          memoryUsage: 0
        },
        health: 'good',
        outputUrls: new Map()
      };

      // Add to streams map
      this.streams.set(config.name, stream);

      // Start FFmpeg processes for each output format
      for (const outputFormat of config.outputFormats) {
        if (outputFormat.enabled) {
          const process = await this.startFFmpegProcess(config, outputFormat);
          stream.processes.set(outputFormat.format, process);
        }
      }

      // Update stream status
      stream.status = 'active';
      stream.startTime = new Date();

      // Generate output URLs
      this.generateOutputUrls(stream);

      this.emit('streamStarted', stream);
      console.log(`Push stream '${config.name}' started successfully`);
      
      return stream;
    } catch (error) {
      // Clean up on failure
      this.streams.delete(config.name);
      console.error(`Failed to start push stream '${config.name}':`, error);
      throw error;
    }
  }

  private async startFFmpegProcess(config: StreamPushConfig, outputFormat: StreamOutputFormat): Promise<ChildProcess> {
    return new Promise((resolve, reject) => {
      const args = this.buildFFmpegArgs(config, outputFormat);
      
      const ffmpegProcess = spawn('ffmpeg', args, {
        stdio: ['pipe', 'pipe', 'pipe']
      });

      ffmpegProcess.stdout?.on('data', (data) => {
        console.log(`FFmpeg stdout (${config.name}-${outputFormat.format}):`, data.toString());
      });

      ffmpegProcess.stderr?.on('data', (data) => {
        const output = data.toString();
        console.log(`FFmpeg stderr (${config.name}-${outputFormat.format}):`, output);
        
        // Parse FFmpeg output for metrics
        this.parseFFmpegOutput(config.name, output);
      });

      ffmpegProcess.on('close', (code) => {
        console.log(`FFmpeg process for stream '${config.name}-${outputFormat.format}' exited with code ${code}`);
        this.handleStreamProcessExit(config.name, outputFormat.format, code);
      });

      ffmpegProcess.on('error', (error) => {
        console.error(`FFmpeg process error for stream '${config.name}-${outputFormat.format}':`, error);
        reject(error);
      });

      // Wait for FFmpeg to initialize
      setTimeout(() => {
        resolve(ffmpegProcess);
      }, 2000);
    });
  }

  private buildFFmpegArgs(config: StreamPushConfig, outputFormat: StreamOutputFormat): string[] {
    const args: string[] = [];

    // Input
    args.push('-i', config.sourceUrl);

    // Input format specific options
    if (config.sourceUrl.startsWith('srt://')) {
      args.push('-protocol_whitelist', 'file,udp,rtp,srt');
    }

    // SuperKabuki SCTE-35 enhancements
    if (config.scte35Settings.enabled) {
      // Preserve timestamps (critical for SCTE-35)
      args.push('-copyts');
      
      // MPEG-TS configuration for SCTE-35
      args.push('-mpegts_pmt_start_pid', '16');
      args.push('-mpegts_service_id', '1');
      args.push('-mpegts_pmt_pid', '16');
      args.push('-mpegts_start_pid', '32');
      args.push('-scte35_pid', config.scte35Settings.pid.toString());
      
      // SuperKabuki specific enhancements
      args.push('-muxpreload', '0');
      args.push('-muxdelay', '0');
    }

    // Video settings
    args.push('-c:v', config.videoSettings.codec);
    args.push('-b:v', `${config.videoSettings.bitrate}M`);
    args.push('-s', config.videoSettings.resolution);
    args.push('-r', config.videoSettings.framerate);
    args.push('-g', config.videoSettings.gop.toString());
    args.push('-bf', config.videoSettings.bFrames.toString());
    args.push('-profile:v', config.videoSettings.profile);
    args.push('-pix_fmt', config.videoSettings.pixelFormat);

    // Audio settings
    args.push('-c:a', config.audioSettings.codec);
    args.push('-b:a', `${config.audioSettings.bitrate}k`);
    args.push('-ar', config.audioSettings.sampleRate.toString());
    args.push('-ac', config.audioSettings.channels.toString());

    // Format-specific output options
    switch (outputFormat.format) {
      case 'HLS':
        args.push('-f', 'hls');
        args.push('-hls_time', config.outputSettings.hls.segmentDuration.toString());
        args.push('-hls_list_size', config.outputSettings.hls.playlistLength.toString());
        args.push('-hls_flags', 'delete_segments+independent_segments');
        args.push('-hls_segment_type', 'mpegts');
        args.push('-hls_segment_filename', 
          path.join(config.outputSettings.hls.outputDir, `${config.name}_%03d.ts`));
        args.push('-master_pl_name', `${config.name}.m3u8`);
        args.push('-method', 'PUT');
        break;

      case 'DASH':
        args.push('-f', 'dash');
        args.push('-seg_duration', config.outputSettings.dash.segmentDuration.toString());
        args.push('-window_size', config.outputSettings.dash.playlistLength.toString());
        args.push('-use_template', '1');
        args.push('-use_timeline', '1');
        args.push('-init_seg_name', `${config.name}_init\$RepresentationID\$.m4s`);
        args.push('-media_seg_name', `${config.name}_chunk_\$RepresentationID\$_\$Number\$.m4s`);
        args.push('-adaptation_sets', 'id=0,streams=v id=1,streams=a');
        break;

      case 'SRT':
        args.push('-f', 'mpegts');
        args.push('-mpegts_flags', 'resend_headers+pat_pmt_at_start');
        args.push('-flush_packets', '1');
        args.push('-payload_type', '33');
        break;

      case 'RTMP':
        args.push('-f', 'flv');
        args.push('-flvflags', 'no_duration_filesize');
        break;

      case 'RTSP':
        args.push('-f', 'rtsp');
        args.push('-rtsp_transport', 'tcp');
        break;
    }

    // SCTE-35 metadata with SuperKabuki enhancements
    if (config.scte35Settings.enabled) {
      args.push('-metadata', 'scte35=true');
      args.push('-metadata', 'scte35_passthrough=true');
      args.push('-metadata', 'scte35_descriptor=true');
      
      // Copy SCTE-35 data streams if present
      args.push('-c:d', 'copy');
    }

    // Output URL
    args.push(outputFormat.url);

    return args;
  }

  private generateOutputUrls(stream: PushStream): void {
    const config = stream.config;
    const baseUrl = `http://localhost:3000`;

    for (const outputFormat of config.outputFormats) {
      if (outputFormat.enabled) {
        let url = '';
        
        switch (outputFormat.format) {
          case 'HLS':
            url = `${baseUrl}/hls/${config.name}/${config.name}.m3u8`;
            break;
          case 'DASH':
            url = `${baseUrl}/dash/${config.name}/${config.name}.mpd`;
            break;
          case 'SRT':
            url = `srt://localhost:${config.outputSettings.srt.port}?streamid=${config.name}`;
            break;
          case 'RTMP':
            url = `rtmp://localhost:${config.outputSettings.rtmp.port}/live/${config.name}`;
            break;
          case 'RTSP':
            url = `rtsp://localhost:${config.outputSettings.rtmp.port}/${config.name}`;
            break;
        }
        
        stream.outputUrls.set(outputFormat.format, url);
      }
    }
  }

  private parseFFmpegOutput(streamName: string, output: string) {
    const stream = this.streams.get(streamName);
    if (!stream) return;

    // Parse bitrate information
    const bitrateMatch = output.match(/bitrate=\s*([\d.]+)kbits\/s/);
    if (bitrateMatch) {
      stream.metrics.inputBitrate = parseFloat(bitrateMatch[1]) / 1000;
    }

    // Parse FPS information
    const fpsMatch = output.match(/([\d.]+) fps/);
    if (fpsMatch) {
      stream.metrics.fps = parseFloat(fpsMatch[1]);
    }

    // Parse audio level (if available)
    const audioMatch = output.match(/audio:\s*([\d.-]+)\s*dB/);
    if (audioMatch) {
      stream.metrics.audioLevel = parseFloat(audioMatch[1]);
    }

    // Update uptime
    if (stream.startTime) {
      stream.metrics.uptime = Date.now() - stream.startTime.getTime();
    }
  }

  private handleStreamProcessExit(streamName: string, format: string, exitCode: number) {
    const stream = this.streams.get(streamName);
    if (!stream) return;

    // Remove the process
    stream.processes.delete(format);

    // Check if all processes have stopped
    if (stream.processes.size === 0) {
      stream.status = exitCode === 0 ? 'stopped' : 'error';
      this.emit('streamStopped', { streamName, exitCode });
    }
  }

  async stopStream(streamName: string): Promise<void> {
    const stream = this.streams.get(streamName);
    if (!stream) {
      throw new Error(`Stream '${streamName}' not found`);
    }

    if (stream.status !== 'active') {
      throw new Error(`Stream '${streamName}' is not active`);
    }

    try {
      stream.status = 'stopping';
      
      // Stop all FFmpeg processes
      for (const [format, process] of stream.processes) {
        process.kill('SIGTERM');
        
        // Wait for graceful shutdown
        await new Promise((resolve) => {
          setTimeout(resolve, 5000);
        });
        
        // Force kill if still running
        if (!process.killed) {
          process.kill('SIGKILL');
        }
      }

      // Clear processes
      stream.processes.clear();

      // Update stream status
      stream.status = 'stopped';
      
      this.emit('streamStopped', { streamName, exitCode: 0 });
      console.log(`Push stream '${streamName}' stopped successfully`);
    } catch (error) {
      stream.status = 'error';
      console.error(`Error stopping push stream '${streamName}':`, error);
      throw error;
    }
  }

  async injectSCTE35(streamName: string, eventData: {
    type: 'CUE-OUT' | 'CUE-IN';
    duration: number;
    preRoll: number;
  }): Promise<SCTE35Event> {
    const stream = this.streams.get(streamName);
    if (!stream) {
      throw new Error(`Stream '${streamName}' not found`);
    }

    if (stream.status !== 'active') {
      throw new Error(`Stream '${streamName}' is not active`);
    }

    if (!stream.config.scte35Settings.enabled) {
      throw new Error(`SCTE-35 is not enabled for stream '${streamName}'`);
    }

    const scte35Event: SCTE35Event = {
      id: `scte_${Date.now()}`,
      eventId: this.eventIdCounter++,
      type: eventData.type,
      duration: eventData.duration,
      preRoll: eventData.preRoll,
      timestamp: new Date(),
      streamName,
      status: 'pending'
    };

    try {
      // Inject SCTE-35 event using the injector
      await this.scte35Injector.inject(streamName, scte35Event);
      
      // Inject into all active processes
      for (const [format, process] of stream.processes) {
        await this.injectSCTE35ToProcess(process, scte35Event, format);
      }
      
      // Update event status
      scte35Event.status = 'active';
      
      this.emit('scte35Event', scte35Event);
      console.log(`SCTE-35 ${eventData.type} event injected into push stream '${streamName}'`);
      
      return scte35Event;
    } catch (error) {
      scte35Event.status = 'failed';
      console.error(`Failed to inject SCTE-35 event into push stream '${streamName}':`, error);
      throw error;
    }
  }

  private async injectSCTE35ToProcess(process: ChildProcess, event: SCTE35Event, format: string): Promise<void> {
    // Simulate SCTE-35 injection into FFmpeg process
    // In a real implementation, this would use FFmpeg's SCTE-35 injection capabilities
    
    return new Promise((resolve) => {
      // Create SCTE-35 command
      const scte35Command = this.createSCTE35Command(event);
      
      // Send command to FFmpeg process stdin
      if (process.stdin) {
        process.stdin.write(scte35Command);
      }
      
      setTimeout(() => {
        console.log(`SCTE-35 injected into ${format} process`);
        resolve();
      }, 100);
    });
  }

  private createSCTE35Command(event: SCTE35Event): string {
    // Create a simplified SCTE-35 command for FFmpeg
    const command = `#SCTE35:${event.type}:${event.eventId}:${event.duration}:${event.preRoll}\n`;
    return command;
  }

  getStream(streamName: string): PushStream | undefined {
    return this.streams.get(streamName);
  }

  getAllStreams(): PushStream[] {
    return Array.from(this.streams.values());
  }

  getAvailableFormats(): StreamFormat[] {
    return [...this.availableFormats];
  }

  getServerStatus(): {
    isRunning: boolean;
    uptime: number;
    streamCount: number;
    totalViewers: number;
    availableFormats: string[];
  } {
    const totalViewers = Array.from(this.streams.values())
      .reduce((sum, stream) => sum + stream.viewers, 0);

    return {
      isRunning: this.isRunning,
      uptime: process.uptime(),
      streamCount: this.streams.size,
      totalViewers,
      availableFormats: this.availableFormats.map(f => f.id)
    };
  }

  getStreamMetrics(streamName: string): any {
    const stream = this.streams.get(streamName);
    if (!stream) {
      throw new Error(`Stream '${streamName}' not found`);
    }

    return {
      ...stream.metrics,
      outputUrls: Object.fromEntries(stream.outputUrls),
      processCount: stream.processes.size,
      activeFormats: Array.from(stream.processes.keys())
    };
  }

  private createDirectories(): void {
    const dirs = [
      './tmp/hls',
      './tmp/dash',
      './tmp/logs',
      './tmp/streams'
    ];

    dirs.forEach(dir => {
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
    });
  }

  // Utility methods for stream configuration
  createDefaultConfig(name: string, sourceUrl: string): StreamPushConfig {
    return {
      id: `config_${Date.now()}`,
      name,
      sourceUrl,
      outputFormats: [
        { format: 'HLS', enabled: true, settings: {}, url: '' },
        { format: 'DASH', enabled: true, settings: {}, url: '' },
        { format: 'SRT', enabled: false, settings: {}, url: '' },
        { format: 'RTMP', enabled: false, settings: {}, url: '' },
        { format: 'RTSP', enabled: false, settings: {}, url: '' }
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
      },
      outputSettings: {
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
      transcoding: {
        enabled: false,
        profiles: []
      }
    };
  }

  validateConfig(config: StreamPushConfig): { isValid: boolean; errors: string[] } {
    const errors: string[] = [];

    // Validate basic fields
    if (!config.name || config.name.trim() === '') {
      errors.push('Stream name is required');
    }

    if (!config.sourceUrl || config.sourceUrl.trim() === '') {
      errors.push('Source URL is required');
    }

    // Validate source URL format
    try {
      new URL(config.sourceUrl);
    } catch {
      errors.push('Invalid source URL format');
    }

    // Validate output formats
    if (!config.outputFormats || config.outputFormats.length === 0) {
      errors.push('At least one output format must be enabled');
    }

    const enabledFormats = config.outputFormats.filter(f => f.enabled);
    if (enabledFormats.length === 0) {
      errors.push('At least one output format must be enabled');
    }

    // Validate video settings
    if (config.videoSettings.bitrate <= 0) {
      errors.push('Video bitrate must be positive');
    }

    if (config.audioSettings.bitrate <= 0) {
      errors.push('Audio bitrate must be positive');
    }

    // Validate SCTE-35 settings
    if (config.scte35Settings.enabled) {
      if (config.scte35Settings.pid <= 0) {
        errors.push('SCTE-35 PID must be positive');
      }
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }
}