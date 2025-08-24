/**
 * SCTE-35 Streaming Control Center - SRT Streamer
 * 
 * © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.
 * 
 * This software is the property of Morus Broadcasting Pvt Ltd and is protected by
 * copyright law and international treaties. Unauthorized use, reproduction, or
 * distribution is strictly prohibited.
 */

import { EventEmitter } from 'events';
import { spawn, ChildProcess } from 'child_process';
import * as net from 'net';
import * as dgram from 'dgram';
import { SCTE35Event } from './MediaServer';

export interface SRTStreamConfig {
  id: string;
  name: string;
  mode: 'listener' | 'caller' | 'rendezvous';
  localPort: number;
  remoteHost?: string;
  remotePort?: number;
  latency: number;
  overheadBandwidth: number;
  passphrase?: string;
  streamId: string;
  videoSettings: {
    codec: string;
    bitrate: number;
    resolution: string;
    framerate: string;
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
    autoInsert: boolean;
  };
}

export interface SRTStream {
  id: string;
  name: string;
  config: SRTStreamConfig;
  status: 'starting' | 'active' | 'stopping' | 'stopped' | 'error';
  process?: ChildProcess;
  socket?: net.Socket | dgram.Socket;
  startTime?: Date;
  viewers: number;
  metrics: {
    bitrate: number;
    packetLoss: number;
    latency: number;
    jitter: number;
    uptime: number;
    connectionStatus: 'connected' | 'disconnected' | 'connecting';
  };
  health: 'good' | 'warning' | 'error';
  scte35Events: SCTE35Event[];
}

export class SRTStreamer extends EventEmitter {
  private streams: Map<string, SRTStream> = new Map();
  private isRunning: boolean = false;
  private server?: net.Server;
  private udpServer?: dgram.Socket;
  private eventIdCounter: number = 100023;

  constructor() {
    super();
  }

  async start(): Promise<void> {
    if (this.isRunning) {
      throw new Error('SRT streamer is already running');
    }

    try {
      // Create TCP server for SRT (simulated)
      this.server = net.createServer((socket) => {
        this.handleSRTConnection(socket);
      });

      // Create UDP server for SRT (simulated)
      this.udpServer = dgram.createSocket('udp4');
      this.udpServer.on('message', (msg, rinfo) => {
        this.handleUDPPacket(msg, rinfo);
      });

      this.isRunning = true;
      this.emit('started');
      console.log('SRT streamer started successfully');
    } catch (error) {
      console.error('Failed to start SRT streamer:', error);
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

      // Close servers
      if (this.server) {
        this.server.close();
      }
      if (this.udpServer) {
        this.udpServer.close();
      }

      this.isRunning = false;
      this.emit('stopped');
      console.log('SRT streamer stopped');
    } catch (error) {
      console.error('Error stopping SRT streamer:', error);
      throw error;
    }
  }

  async startStream(config: SRTStreamConfig): Promise<SRTStream> {
    if (!this.isRunning) {
      throw new Error('SRT streamer is not running');
    }

    if (this.streams.has(config.name)) {
      throw new Error(`SRT stream '${config.name}' already exists`);
    }

    try {
      // Create stream object
      const stream: SRTStream = {
        id: `srt_${Date.now()}`,
        name: config.name,
        config,
        status: 'starting',
        viewers: 0,
        metrics: {
          bitrate: 0,
          packetLoss: 0,
          latency: 0,
          jitter: 0,
          uptime: 0,
          connectionStatus: 'connecting'
        },
        health: 'good',
        scte35Events: []
      };

      // Add to streams map
      this.streams.set(config.name, stream);

      // Start SRT process based on mode
      switch (config.mode) {
        case 'listener':
          await this.startListenerMode(stream);
          break;
        case 'caller':
          await this.startCallerMode(stream);
          break;
        case 'rendezvous':
          await this.startRendezvousMode(stream);
          break;
      }

      // Update stream status
      stream.status = 'active';
      stream.startTime = new Date();

      this.emit('streamStarted', stream);
      console.log(`SRT stream '${config.name}' started in ${config.mode} mode`);
      
      return stream;
    } catch (error) {
      // Clean up on failure
      this.streams.delete(config.name);
      console.error(`Failed to start SRT stream '${config.name}':`, error);
      throw error;
    }
  }

  private async startListenerMode(stream: SRTStream): Promise<void> {
    return new Promise((resolve, reject) => {
      const args = this.buildSRTArgs(stream.config, 'listener');
      
      const process = spawn('ffmpeg', args, {
        stdio: ['pipe', 'pipe', 'pipe']
      });

      process.stdout?.on('data', (data) => {
        console.log(`FFmpeg stdout (${stream.name}):`, data.toString());
      });

      process.stderr?.on('data', (data) => {
        const output = data.toString();
        console.log(`FFmpeg stderr (${stream.name}):`, output);
        this.parseFFmpegOutput(stream.name, output);
      });

      process.on('close', (code) => {
        console.log(`FFmpeg process for SRT stream '${stream.name}' exited with code ${code}`);
        this.handleStreamExit(stream.name, code);
      });

      process.on('error', (error) => {
        console.error(`FFmpeg process error for SRT stream '${stream.name}':`, error);
        reject(error);
      });

      stream.process = process;
      
      // Wait for FFmpeg to initialize
      setTimeout(() => {
        stream.metrics.connectionStatus = 'connected';
        resolve();
      }, 2000);
    });
  }

  private async startCallerMode(stream: SRTStream): Promise<void> {
    return new Promise((resolve, reject) => {
      const args = this.buildSRTArgs(stream.config, 'caller');
      
      const process = spawn('ffmpeg', args, {
        stdio: ['pipe', 'pipe', 'pipe']
      });

      process.stdout?.on('data', (data) => {
        console.log(`FFmpeg stdout (${stream.name}):`, data.toString());
      });

      process.stderr?.on('data', (data) => {
        const output = data.toString();
        console.log(`FFmpeg stderr (${stream.name}):`, output);
        this.parseFFmpegOutput(stream.name, output);
      });

      process.on('close', (code) => {
        console.log(`FFmpeg process for SRT stream '${stream.name}' exited with code ${code}`);
        this.handleStreamExit(stream.name, code);
      });

      process.on('error', (error) => {
        console.error(`FFmpeg process error for SRT stream '${stream.name}':`, error);
        reject(error);
      });

      stream.process = process;
      
      // Wait for FFmpeg to initialize
      setTimeout(() => {
        stream.metrics.connectionStatus = 'connected';
        resolve();
      }, 2000);
    });
  }

  private async startRendezvousMode(stream: SRTStream): Promise<void> {
    // Rendezvous mode requires both sides to connect
    // For simplicity, we'll simulate this with FFmpeg
    return new Promise((resolve, reject) => {
      const args = this.buildSRTArgs(stream.config, 'rendezvous');
      
      const process = spawn('ffmpeg', args, {
        stdio: ['pipe', 'pipe', 'pipe']
      });

      process.stdout?.on('data', (data) => {
        console.log(`FFmpeg stdout (${stream.name}):`, data.toString());
      });

      process.stderr?.on('data', (data) => {
        const output = data.toString();
        console.log(`FFmpeg stderr (${stream.name}):`, output);
        this.parseFFmpegOutput(stream.name, output);
      });

      process.on('close', (code) => {
        console.log(`FFmpeg process for SRT stream '${stream.name}' exited with code ${code}`);
        this.handleStreamExit(stream.name, code);
      });

      process.on('error', (error) => {
        console.error(`FFmpeg process error for SRT stream '${stream.name}':`, error);
        reject(error);
      });

      stream.process = process;
      
      // Wait for FFmpeg to initialize
      setTimeout(() => {
        stream.metrics.connectionStatus = 'connected';
        resolve();
      }, 5000); // Rendezvous mode takes longer
    });
  }

  private buildSRTArgs(config: SRTStreamConfig, mode: string): string[] {
    const args: string[] = [];

    // Input (for listener mode, this would be the source)
    if (mode === 'listener') {
      args.push('-i', config.streamId); // Use stream ID as input for listener
    } else {
      // For caller and rendezvous, we need a source
      args.push('-re', '-i', '/dev/video0'); // Default to video device, should be configurable
    }

    // Video settings
    args.push('-c:v', config.videoSettings.codec);
    args.push('-b:v', `${config.videoSettings.bitrate}M`);
    args.push('-s', config.videoSettings.resolution);
    args.push('-r', config.videoSettings.framerate);

    // Audio settings
    args.push('-c:a', config.audioSettings.codec);
    args.push('-b:a', `${config.audioSettings.bitrate}k`);
    args.push('-ar', config.audioSettings.sampleRate.toString());
    args.push('-ac', config.audioSettings.channels.toString());

    // SCTE-35 settings
    if (config.scte35Settings.enabled) {
      args.push('-mpegts_pmt_start_pid', '16');
      args.push('-scte35_pid', config.scte35Settings.pid.toString());
    }

    // SRT output settings
    args.push('-f', 'mpegts');
    args.push('-mpegts_flags', 'resend_headers+pat_pmt_at_start');
    args.push('-flush_packets', '1');
    args.push('-payload_type', '33');

    // Build SRT URL based on mode
    let srtUrl = '';
    switch (mode) {
      case 'listener':
        srtUrl = `srt://:${config.localPort}?mode=listener&latency=${config.latency}&overhead_bandwidth=${config.overheadBandwidth}`;
        break;
      case 'caller':
        srtUrl = `srt://${config.remoteHost}:${config.remotePort}?mode=caller&latency=${config.latency}&overhead_bandwidth=${config.overheadBandwidth}`;
        break;
      case 'rendezvous':
        srtUrl = `srt://${config.remoteHost}:${config.remotePort}?mode=rendezvous&localport=${config.localPort}&latency=${config.latency}&overhead_bandwidth=${config.overheadBandwidth}`;
        break;
    }

    // Add passphrase if provided
    if (config.passphrase) {
      srtUrl += `&passphrase=${encodeURIComponent(config.passphrase)}`;
    }

    // Add stream ID
    srtUrl += `&streamid=${encodeURIComponent(config.streamId)}`;

    args.push(srtUrl);

    return args;
  }

  private handleSRTConnection(socket: net.Socket): void {
    console.log(`SRT connection established from ${socket.remoteAddress}:${socket.remotePort}`);
    
    socket.on('data', (data) => {
      this.handleSRTData(data, socket);
    });

    socket.on('close', () => {
      console.log(`SRT connection closed from ${socket.remoteAddress}:${socket.remotePort}`);
    });

    socket.on('error', (error) => {
      console.error(`SRT connection error:`, error);
    });
  }

  private handleUDPPacket(msg: Buffer, rinfo: any): void {
    // Handle UDP packets for SRT
    console.log(`Received UDP packet from ${rinfo.address}:${rinfo.port}`);
    this.handleSRTData(msg, null);
  }

  private handleSRTData(data: Buffer, socket?: net.Socket): void {
    // Parse SRT data and extract SCTE-35 information
    try {
      // In a real implementation, this would parse SRT packets
      // For now, we'll simulate SCTE-35 extraction
      
      const scte35Data = this.extractSCTE35FromSRT(data);
      if (scte35Data) {
        this.emit('scte35Data', scte35Data);
      }
    } catch (error) {
      console.error('Error handling SRT data:', error);
    }
  }

  private extractSCTE35FromSRT(data: Buffer): SCTE35Event | null {
    // Simulate SCTE-35 extraction from SRT data
    // In a real implementation, this would parse MPEG-TS packets
    
    // Look for SCTE-35 markers in the data
    const scte35Marker = data.toString().includes('SCTE35');
    
    if (scte35Marker) {
      return {
        id: `scte_${Date.now()}`,
        eventId: this.eventIdCounter++,
        type: 'CUE-OUT', // Default type
        duration: 30, // Default duration
        preRoll: 2, // Default pre-roll
        timestamp: new Date(),
        streamName: 'srt_stream',
        status: 'active'
      };
    }
    
    return null;
  }

  private parseFFmpegOutput(streamName: string, output: string) {
    const stream = this.streams.get(streamName);
    if (!stream) return;

    // Parse bitrate information
    const bitrateMatch = output.match(/bitrate=\s*([\d.]+)kbits\/s/);
    if (bitrateMatch) {
      stream.metrics.bitrate = parseFloat(bitrateMatch[1]);
    }

    // Parse latency information
    const latencyMatch = output.match(/latency=\s*([\d.]+)ms/);
    if (latencyMatch) {
      stream.metrics.latency = parseFloat(latencyMatch[1]);
    }

    // Parse packet loss (if available)
    const packetLossMatch = output.match(/packet_loss=\s*([\d.]+)%/);
    if (packetLossMatch) {
      stream.metrics.packetLoss = parseFloat(packetLossMatch[1]);
    }

    // Update uptime
    if (stream.startTime) {
      stream.metrics.uptime = Date.now() - stream.startTime.getTime();
    }

    // Update connection status
    if (output.includes('connected')) {
      stream.metrics.connectionStatus = 'connected';
    } else if (output.includes('disconnected')) {
      stream.metrics.connectionStatus = 'disconnected';
    }

    // Update health based on metrics
    if (stream.metrics.packetLoss > 5 || stream.metrics.latency > 1000) {
      stream.health = 'warning';
    } else if (stream.metrics.packetLoss > 10 || stream.metrics.latency > 2000) {
      stream.health = 'error';
    } else {
      stream.health = 'good';
    }
  }

  private handleStreamExit(streamName: string, exitCode: number) {
    const stream = this.streams.get(streamName);
    if (!stream) return;

    stream.status = exitCode === 0 ? 'stopped' : 'error';
    stream.process = undefined;
    stream.metrics.connectionStatus = 'disconnected';
    
    this.emit('streamStopped', { streamName, exitCode });
  }

  async stopStream(streamName: string): Promise<void> {
    const stream = this.streams.get(streamName);
    if (!stream) {
      throw new Error(`SRT stream '${streamName}' not found`);
    }

    if (stream.status !== 'active') {
      throw new Error(`SRT stream '${streamName}' is not active`);
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

      // Close socket if exists
      if (stream.socket) {
        stream.socket.destroy();
      }

      // Update stream status
      stream.status = 'stopped';
      stream.process = undefined;
      stream.socket = undefined;
      stream.metrics.connectionStatus = 'disconnected';
      
      this.emit('streamStopped', { streamName, exitCode: 0 });
      console.log(`SRT stream '${streamName}' stopped successfully`);
    } catch (error) {
      stream.status = 'error';
      console.error(`Error stopping SRT stream '${streamName}':`, error);
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
      throw new Error(`SRT stream '${streamName}' not found`);
    }

    if (stream.status !== 'active') {
      throw new Error(`SRT stream '${streamName}' is not active`);
    }

    if (!stream.config.scte35Settings.enabled) {
      throw new Error(`SCTE-35 is not enabled for SRT stream '${streamName}'`);
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
      // Add to stream's SCTE-35 events
      stream.scte35Events.push(scte35Event);

      // Inject SCTE-35 into the stream
      await this.injectSCTE35ToStream(stream, scte35Event);
      
      // Update event status
      scte35Event.status = 'active';
      
      this.emit('scte35Event', scte35Event);
      console.log(`SCTE-35 ${eventData.type} event injected into SRT stream '${streamName}'`);
      
      return scte35Event;
    } catch (error) {
      scte35Event.status = 'failed';
      console.error(`Failed to inject SCTE-35 event into SRT stream '${streamName}':`, error);
      throw error;
    }
  }

  private async injectSCTE35ToStream(stream: SRTStream, event: SCTE35Event): Promise<void> {
    // Simulate SCTE-35 injection into SRT stream
    // In a real implementation, this would inject SCTE-35 packets into the SRT stream
    
    return new Promise((resolve) => {
      // Create SCTE-35 packet
      const scte35Packet = this.createSCTE35Packet(event);
      
      // Send SCTE-35 packet through the stream
      if (stream.socket) {
        stream.socket.write(scte35Packet);
      }
      
      // Also send through FFmpeg process if available
      if (stream.process && stream.process.stdin) {
        const scte35Command = `#SCTE35:${event.type}:${event.eventId}:${event.duration}:${event.preRoll}\n`;
        stream.process.stdin.write(scte35Command);
      }
      
      setTimeout(() => {
        console.log(`SCTE-35 injected into SRT stream '${stream.name}'`);
        resolve();
      }, 100);
    });
  }

  private createSCTE35Packet(event: SCTE35Event): Buffer {
    // Create a simplified SCTE-35 packet
    // In a real implementation, this would create proper SCTE-35 binary data
    
    const packetData = {
      protocol_version: 0,
      packet_type: event.type === 'CUE-OUT' ? 0 : 1,
      timestamp: Math.floor(event.timestamp.getTime() / 1000),
      event_id: event.eventId,
      duration: event.duration,
      pre_roll: event.preRoll,
      segmentation_type_id: event.type === 'CUE-OUT' ? 0x34 : 0x36,
      segmentation_message: event.type === 'CUE-OUT' ? 'Program Start' : 'Program End'
    };

    // Convert to JSON string (in real implementation, this would be binary)
    const jsonString = JSON.stringify(packetData);
    return Buffer.from(jsonString);
  }

  getStream(streamName: string): SRTStream | undefined {
    return this.streams.get(streamName);
  }

  getAllStreams(): SRTStream[] {
    return Array.from(this.streams.values());
  }

  getServerStatus(): {
    isRunning: boolean;
    uptime: number;
    streamCount: number;
    totalViewers: number;
    tcpPort?: number;
    udpPort?: number;
  } {
    const totalViewers = Array.from(this.streams.values())
      .reduce((sum, stream) => sum + stream.viewers, 0);

    return {
      isRunning: this.isRunning,
      uptime: process.uptime(),
      streamCount: this.streams.size,
      totalViewers,
      tcpPort: this.server?.address()?.port,
      udpPort: this.udpServer?.address()?.port
    };
  }

  getStreamMetrics(streamName: string): any {
    const stream = this.streams.get(streamName);
    if (!stream) {
      throw new Error(`SRT stream '${streamName}' not found`);
    }

    return {
      ...stream.metrics,
      scte35Events: stream.scte35Events.length,
      mode: stream.config.mode,
      localPort: stream.config.localPort,
      remoteHost: stream.config.remoteHost,
      remotePort: stream.config.remotePort
    };
  }

  // Utility methods for SRT configuration
  createListenerConfig(name: string, port: number, streamId: string): SRTStreamConfig {
    return {
      id: `srt_${Date.now()}`,
      name,
      mode: 'listener',
      localPort: port,
      latency: 120,
      overheadBandwidth: 25,
      streamId,
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
    };
  }

  createCallerConfig(name: string, remoteHost: string, remotePort: number, streamId: string): SRTStreamConfig {
    return {
      id: `srt_${Date.now()}`,
      name,
      mode: 'caller',
      localPort: 0, // Let system choose
      remoteHost,
      remotePort,
      latency: 120,
      overheadBandwidth: 25,
      streamId,
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
    };
  }

  validateConfig(config: SRTStreamConfig): { isValid: boolean; errors: string[] } {
    const errors: string[] = [];

    // Validate basic fields
    if (!config.name || config.name.trim() === '') {
      errors.push('Stream name is required');
    }

    if (!config.streamId || config.streamId.trim() === '') {
      errors.push('Stream ID is required');
    }

    // Validate port
    if (config.localPort < 0 || config.localPort > 65535) {
      errors.push('Local port must be between 0 and 65535');
    }

    // Validate mode-specific settings
    if (config.mode === 'caller' || config.mode === 'rendezvous') {
      if (!config.remoteHost || config.remoteHost.trim() === '') {
        errors.push('Remote host is required for caller and rendezvous modes');
      }
      
      if (!config.remotePort || config.remotePort < 1 || config.remotePort > 65535) {
        errors.push('Remote port must be between 1 and 65535');
      }
    }

    // Validate latency
    if (config.latency < 0 || config.latency > 5000) {
      errors.push('Latency must be between 0 and 5000ms');
    }

    // Validate overhead bandwidth
    if (config.overheadBandwidth < 0 || config.overheadBandwidth > 100) {
      errors.push('Overhead bandwidth must be between 0 and 100%');
    }

    // Validate SCTE-35 settings
    if (config.scte35Settings.enabled) {
      if (config.scte35.pid <= 0) {
        errors.push('SCTE-35 PID must be positive');
      }
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }

  // Test SRT connection
  async testConnection(host: string, port: number, timeout: number = 5000): Promise<boolean> {
    return new Promise((resolve) => {
      const socket = new net.Socket();
      
      const timeoutId = setTimeout(() => {
        socket.destroy();
        resolve(false);
      }, timeout);

      socket.connect(port, host, () => {
        clearTimeout(timeoutId);
        socket.destroy();
        resolve(true);
      });

      socket.on('error', () => {
        clearTimeout(timeoutId);
        resolve(false);
      });
    });
  }
}