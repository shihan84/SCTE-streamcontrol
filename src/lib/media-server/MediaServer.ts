/**
 * SCTE-35 Streaming Control Center - Media Server Core
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
import { HLSGenerator } from './HLSGenerator';
import { SCTE35Injector } from './SCTE35Injector';
import { StreamMonitor } from './StreamMonitor';

export interface StreamConfig {
  name: string;
  inputUrl: string;
  outputUrl: string;
  videoSettings: {
    codec: string;
    bitrate: number;
    resolution: string;
    framerate: string;
    gop: number;
    bFrames: number;
    profile: string;
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
  };
  hlsSettings: {
    segmentDuration: number;
    playlistLength: number;
    outputDir: string;
  };
}

export interface Stream {
  id: string;
  name: string;
  config: StreamConfig;
  status: 'starting' | 'active' | 'stopping' | 'stopped' | 'error';
  process?: ChildProcess;
  startTime?: Date;
  viewers: number;
  metrics: {
    bitrate: number;
    fps: number;
    audioLevel: number;
    latency: number;
    uptime: number;
  };
  health: 'good' | 'warning' | 'error';
}

export interface SCTE35Event {
  id: string;
  eventId: number;
  type: 'CUE-OUT' | 'CUE-IN';
  duration: number;
  preRoll: number;
  timestamp: Date;
  streamName: string;
  status: 'pending' | 'active' | 'completed' | 'failed';
}

export class MediaServer extends EventEmitter {
  private streams: Map<string, Stream> = new Map();
  private scte35Injector: SCTE35Injector;
  private hlsGenerator: HLSGenerator;
  private streamMonitor: StreamMonitor;
  private eventIdCounter: number = 100023;
  private isRunning: boolean = false;

  constructor() {
    super();
    this.scte35Injector = new SCTE35Injector();
    this.hlsGenerator = new HLSGenerator();
    this.streamMonitor = new StreamMonitor();
    
    // Set up event listeners
    this.setupEventListeners();
  }

  private setupEventListeners() {
    this.scte35Injector.on('eventInjected', (event: SCTE35Event) => {
      this.emit('scte35Event', event);
    });

    this.streamMonitor.on('streamHealth', (data: { streamName: string; health: 'good' | 'warning' | 'error'; metrics: any }) => {
      this.updateStreamMetrics(data.streamName, data.metrics);
      this.emit('streamHealth', data);
    });

    this.streamMonitor.on('alert', (alert: any) => {
      this.emit('alert', alert);
    });
  }

  async start(): Promise<void> {
    if (this.isRunning) {
      throw new Error('Media server is already running');
    }

    try {
      // Create necessary directories
      this.createDirectories();
      
      // Initialize components
      await this.hlsGenerator.initialize();
      await this.streamMonitor.initialize();
      
      this.isRunning = true;
      this.emit('started');
      console.log('Self-hosted media server started successfully');
    } catch (error) {
      console.error('Failed to start media server:', error);
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
      await this.streamMonitor.stop();
      await this.hlsGenerator.stop();
      
      this.isRunning = false;
      this.emit('stopped');
      console.log('Self-hosted media server stopped');
    } catch (error) {
      console.error('Error stopping media server:', error);
      throw error;
    }
  }

  async startStream(config: StreamConfig): Promise<Stream> {
    if (!this.isRunning) {
      throw new Error('Media server is not running');
    }

    if (this.streams.has(config.name)) {
      throw new Error(`Stream '${config.name}' already exists`);
    }

    try {
      // Create stream object
      const stream: Stream = {
        id: `stream_${Date.now()}`,
        name: config.name,
        config,
        status: 'starting',
        viewers: 0,
        metrics: {
          bitrate: 0,
          fps: 0,
          audioLevel: -20,
          latency: 0,
          uptime: 0
        },
        health: 'good'
      };

      // Add to streams map
      this.streams.set(config.name, stream);

      // Initialize HLS generation
      await this.hlsGenerator.startStream(config);

      // Start FFmpeg process
      const ffmpegProcess = await this.startFFmpegProcess(config);
      
      // Update stream status
      stream.process = ffmpegProcess;
      stream.status = 'active';
      stream.startTime = new Date();
      
      // Start monitoring
      this.streamMonitor.watchStream(stream);

      this.emit('streamStarted', stream);
      console.log(`Stream '${config.name}' started successfully`);
      
      return stream;
    } catch (error) {
      // Clean up on failure
      this.streams.delete(config.name);
      console.error(`Failed to start stream '${config.name}':`, error);
      throw error;
    }
  }

  private async startFFmpegProcess(config: StreamConfig): Promise<ChildProcess> {
    return new Promise((resolve, reject) => {
      const args = [
        // Input
        '-i', config.inputUrl,
        
        // Video settings
        '-c:v', config.videoSettings.codec,
        '-b:v', `${config.videoSettings.bitrate}M`,
        '-s', config.videoSettings.resolution,
        '-r', config.videoSettings.framerate,
        '-g', config.videoSettings.gop.toString(),
        '-bf', config.videoSettings.bFrames.toString(),
        '-profile:v', config.videoSettings.profile,
        '-pix_fmt', 'yuv420p',
        
        // Audio settings
        '-c:a', config.audioSettings.codec,
        '-b:a', `${config.audioSettings.bitrate}k`,
        '-ar', config.audioSettings.sampleRate.toString(),
        '-ac', config.audioSettings.channels.toString(),
        
        // SCTE-35 settings
        '-mpegts_pmt_start_pid', '16',
        '-mpegts_service_id', '1',
        '-mpegts_pmt_pid', '16',
        '-mpegts_start_pid', '32',
        
        // Output format
        '-f', 'hls',
        '-hls_time', config.hlsSettings.segmentDuration.toString(),
        '-hls_list_size', config.hlsSettings.playlistLength.toString(),
        '-hls_flags', 'delete_segments+independent_segments',
        '-hls_segment_type', 'mpegts',
        '-hls_segment_filename', path.join(config.hlsSettings.outputDir, `${config.name}_%03d.ts`),
        '-master_pl_name', `${config.name}.m3u8`,
        '-method', 'PUT',
        
        // SCTE-35 injection point
        '-metadata', 'scte35=true',
        
        // Output URL
        config.outputUrl
      ];

      const ffmpegProcess = spawn('ffmpeg', args, {
        stdio: ['pipe', 'pipe', 'pipe']
      });

      ffmpegProcess.stdout?.on('data', (data) => {
        console.log(`FFmpeg stdout (${config.name}):`, data.toString());
      });

      ffmpegProcess.stderr?.on('data', (data) => {
        const output = data.toString();
        console.log(`FFmpeg stderr (${config.name}):`, output);
        
        // Parse FFmpeg output for metrics
        this.parseFFmpegOutput(config.name, output);
      });

      ffmpegProcess.on('close', (code) => {
        console.log(`FFmpeg process for stream '${config.name}' exited with code ${code}`);
        this.handleStreamExit(config.name, code);
      });

      ffmpegProcess.on('error', (error) => {
        console.error(`FFmpeg process error for stream '${config.name}':`, error);
        reject(error);
      });

      // Wait for FFmpeg to initialize
      setTimeout(() => {
        resolve(ffmpegProcess);
      }, 2000);
    });
  }

  private parseFFmpegOutput(streamName: string, output: string) {
    // Parse bitrate information
    const bitrateMatch = output.match(/bitrate=\s*([\d.]+)kbits\/s/);
    if (bitrateMatch) {
      this.updateStreamMetrics(streamName, { bitrate: parseFloat(bitrateMatch[1]) / 1000 });
    }

    // Parse FPS information
    const fpsMatch = output.match(/([\d.]+) fps/);
    if (fpsMatch) {
      this.updateStreamMetrics(streamName, { fps: parseFloat(fpsMatch[1]) });
    }

    // Parse audio level (if available)
    const audioMatch = output.match(/audio:\s*([\d.-]+)\s*dB/);
    if (audioMatch) {
      this.updateStreamMetrics(streamName, { audioLevel: parseFloat(audioMatch[1]) });
    }
  }

  private updateStreamMetrics(streamName: string, metrics: Partial<any>) {
    const stream = this.streams.get(streamName);
    if (stream) {
      stream.metrics = { ...stream.metrics, ...metrics };
      
      // Update uptime
      if (stream.startTime) {
        stream.metrics.uptime = Date.now() - stream.startTime.getTime();
      }
    }
  }

  private handleStreamExit(streamName: string, exitCode: number) {
    const stream = this.streams.get(streamName);
    if (stream) {
      stream.status = exitCode === 0 ? 'stopped' : 'error';
      stream.process = undefined;
      
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
      
      // Stop FFmpeg process
      if (stream.process) {
        stream.process.kill('SIGTERM');
        
        // Wait for graceful shutdown
        await new Promise((resolve) => {
          setTimeout(resolve, 5000);
        });
        
        // Force kill if still running
        if (stream.process && !stream.process.killed) {
          stream.process.kill('SIGKILL');
        }
      }

      // Stop HLS generation
      await this.hlsGenerator.stopStream(streamName);
      
      // Stop monitoring
      this.streamMonitor.unwatchStream(streamName);
      
      // Update stream status
      stream.status = 'stopped';
      stream.process = undefined;
      
      this.emit('streamStopped', { streamName, exitCode: 0 });
      console.log(`Stream '${streamName}' stopped successfully`);
    } catch (error) {
      stream.status = 'error';
      console.error(`Error stopping stream '${streamName}':`, error);
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
      // Inject SCTE-35 event
      await this.scte35Injector.inject(streamName, scte35Event);
      
      // Update HLS manifest
      await this.hlsGenerator.injectSCTE35(streamName, scte35Event);
      
      // Update event status
      scte35Event.status = 'active';
      
      this.emit('scte35Event', scte35Event);
      console.log(`SCTE-35 ${eventData.type} event injected into stream '${streamName}'`);
      
      return scte35Event;
    } catch (error) {
      scte35Event.status = 'failed';
      console.error(`Failed to inject SCTE-35 event into stream '${streamName}':`, error);
      throw error;
    }
  }

  getStream(streamName: string): Stream | undefined {
    return this.streams.get(streamName);
  }

  getAllStreams(): Stream[] {
    return Array.from(this.streams.values());
  }

  getServerStatus(): {
    isRunning: boolean;
    uptime: number;
    streamCount: number;
    totalViewers: number;
  } {
    const totalViewers = Array.from(this.streams.values())
      .reduce((sum, stream) => sum + stream.viewers, 0);

    return {
      isRunning: this.isRunning,
      uptime: process.uptime(),
      streamCount: this.streams.size,
      totalViewers
    };
  }

  private createDirectories(): void {
    const dirs = [
      './tmp/hls',
      './tmp/logs',
      './tmp/streams'
    ];

    dirs.forEach(dir => {
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
    });
  }
}