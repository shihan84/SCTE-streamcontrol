import { EventEmitter } from 'events';
import { createServer, Socket } from 'net';
import * as fs from 'fs';
import * as path from 'path';

export interface RTMPConfig {
  port: number;
  host: string;
  chunkSize: number;
  acknowledgeWindowSize: number;
  maxConnections: number;
}

export interface RTMPConnection {
  id: string;
  socket: Socket;
  remoteAddress: string;
  connectedAt: Date;
  streamName?: string;
  isPublishing: boolean;
  isPlaying: boolean;
  app: string;
  tcUrl?: string;
  pageUrl?: string;
  flashVer?: string;
}

export interface RTMPStream {
  name: string;
  publishers: RTMPConnection[];
  players: RTMPConnection[];
  createdAt: Date;
  lastActivity: Date;
  metadata?: any;
}

export class RTMPServer extends EventEmitter {
  private server: any; // Using any to avoid Node.js type issues
  private connections: Map<string, RTMPConnection> = new Map();
  private streams: Map<string, RTMPStream> = new Map();
  private config: RTMPConfig;
  private isRunning: boolean = false;

  constructor(config: Partial<RTMPConfig> = {}) {
    super();
    
    this.config = {
      port: config.port || 1935,
      host: config.host || '0.0.0.0',
      chunkSize: config.chunkSize || 128,
      acknowledgeWindowSize: config.acknowledgeWindowSize || 2500000,
      maxConnections: config.maxConnections || 1000,
      ...config
    };
  }

  async start(): Promise<void> {
    if (this.isRunning) {
      throw new Error('RTMP server is already running');
    }

    return new Promise((resolve, reject) => {
      try {
        this.server = createServer((socket: Socket) => {
          this.handleConnection(socket);
        });

        this.server.listen(this.config.port, this.config.host, () => {
          this.isRunning = true;
          console.log(`RTMP server listening on ${this.config.host}:${this.config.port}`);
          this.emit('started');
          resolve();
        });

        this.server.on('error', (error: Error) => {
          console.error('RTMP server error:', error);
          this.emit('error', error);
          reject(error);
        });

      } catch (error) {
        console.error('Failed to start RTMP server:', error);
        reject(error);
      }
    });
  }

  async stop(): Promise<void> {
    if (!this.isRunning) {
      return;
    }

    return new Promise((resolve) => {
      // Close all connections
      for (const [id, connection] of this.connections) {
        connection.socket.destroy();
      }
      this.connections.clear();

      // Close server
      this.server.close(() => {
        this.isRunning = false;
        console.log('RTMP server stopped');
        this.emit('stopped');
        resolve();
      });
    });
  }

  private handleConnection(socket: Socket): void {
    const connectionId = `conn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const remoteAddress = socket.remoteAddress || 'unknown';
    
    const connection: RTMPConnection = {
      id: connectionId,
      socket,
      remoteAddress,
      connectedAt: new Date(),
      isPublishing: false,
      isPlaying: false,
      app: ''
    };

    this.connections.set(connectionId, connection);
    
    console.log(`New RTMP connection from ${remoteAddress}`);

    // Handle connection events
    socket.on('data', (data: Buffer) => {
      this.handleData(connection, data);
    });

    socket.on('close', () => {
      this.handleDisconnection(connectionId);
    });

    socket.on('error', (error: Error) => {
      console.error(`RTMP connection error (${connectionId}):`, error);
      this.handleDisconnection(connectionId);
    });

    this.emit('connection', connection);
  }

  private handleData(connection: RTMPConnection, data: Buffer): void {
    try {
      // Simplified RTMP protocol handling
      // In a real implementation, this would parse RTMP packets, handshakes, etc.
      
      // For now, we'll simulate RTMP message handling
      const message = this.parseRTMPMessage(data);
      
      if (message) {
        switch (message.type) {
          case 'connect':
            this.handleConnect(connection, message);
            break;
          case 'publish':
            this.handlePublish(connection, message);
            break;
          case 'play':
            this.handlePlay(connection, message);
            break;
          case 'deleteStream':
            this.handleDeleteStream(connection, message);
            break;
          default:
            console.log(`Unhandled RTMP message type: ${message.type}`);
        }
      }
    } catch (error) {
      console.error('Error handling RTMP data:', error);
    }
  }

  private parseRTMPMessage(data: Buffer): any {
    // Simplified RTMP message parsing
    // In a real implementation, this would properly parse RTMP protocol
    
    // For demo purposes, we'll simulate message parsing
    if (data.length < 1) return null;
    
    const messageType = data[0];
    
    // Simulate different message types based on data content
    if (data.toString().includes('connect')) {
      return { type: 'connect', data: data.toString() };
    } else if (data.toString().includes('publish')) {
      return { type: 'publish', data: data.toString() };
    } else if (data.toString().includes('play')) {
      return { type: 'play', data: data.toString() };
    } else if (data.toString().includes('deleteStream')) {
      return { type: 'deleteStream', data: data.toString() };
    }
    
    return null;
  }

  private handleConnect(connection: RTMPConnection, message: any): void {
    console.log(`RTMP connect from ${connection.remoteAddress}`);
    
    // Parse connection parameters
    const params = this.parseURLParameters(message.data);
    
    connection.app = params.app || 'live';
    connection.tcUrl = params.tcUrl;
    connection.pageUrl = params.pageUrl;
    connection.flashVer = params.flashVer;
    
    // Send connect success response
    this.sendRTMPResponse(connection, {
      command: '_result',
      transactionId: params.transactionId,
      properties: {
        fmsVer: 'FMS/3,0,1,123',
        capabilities: 255,
        mode: 1
      },
      information: {
        level: 'status',
        code: 'NetConnection.Connect.Success',
        description: 'Connection succeeded.',
        objectEncoding: 0
      }
    });
    
    this.emit('connect', connection);
  }

  private handlePublish(connection: RTMPConnection, message: any): void {
    console.log(`RTMP publish request from ${connection.remoteAddress}`);
    
    const params = this.parseURLParameters(message.data);
    const streamName = params.streamName || 'live';
    
    // Check if stream already exists
    let stream = this.streams.get(streamName);
    if (!stream) {
      stream = {
        name: streamName,
        publishers: [],
        players: [],
        createdAt: new Date(),
        lastActivity: new Date()
      };
      this.streams.set(streamName, stream);
    }
    
    // Check if already publishing
    if (stream.publishers.length > 0) {
      this.sendRTMPResponse(connection, {
        command: '_error',
        transactionId: params.transactionId,
        properties: {
          level: 'error',
          code: 'NetStream.Publish.BadName',
          description: 'Stream already publishing'
        }
      });
      return;
    }
    
    // Add publisher to stream
    connection.streamName = streamName;
    connection.isPublishing = true;
    stream.publishers.push(connection);
    stream.lastActivity = new Date();
    
    // Send publish success response
    this.sendRTMPResponse(connection, {
      command: 'onStatus',
      transactionId: params.transactionId,
      properties: {
        level: 'status',
        code: 'NetStream.Publish.Start',
        description: `Stream is now published: ${streamName}`
      }
    });
    
    this.emit('publish', { connection, stream });
    console.log(`Stream '${streamName}' published by ${connection.remoteAddress}`);
  }

  private handlePlay(connection: RTMPConnection, message: any): void {
    console.log(`RTMP play request from ${connection.remoteAddress}`);
    
    const params = this.parseURLParameters(message.data);
    const streamName = params.streamName || 'live';
    
    // Check if stream exists
    const stream = this.streams.get(streamName);
    if (!stream || stream.publishers.length === 0) {
      this.sendRTMPResponse(connection, {
        command: 'onStatus',
        transactionId: params.transactionId,
        properties: {
          level: 'error',
          code: 'NetStream.Play.StreamNotFound',
          description: `Stream '${streamName}' not found`
        }
      });
      return;
    }
    
    // Add player to stream
    connection.streamName = streamName;
    connection.isPlaying = true;
    stream.players.push(connection);
    stream.lastActivity = new Date();
    
    // Send play success response
    this.sendRTMPResponse(connection, {
      command: 'onStatus',
      transactionId: params.transactionId,
      properties: {
        level: 'status',
        code: 'NetStream.Play.Start',
        description: `Started playing stream: ${streamName}`
      }
    });
    
    this.emit('play', { connection, stream });
    console.log(`Stream '${streamName}' played by ${connection.remoteAddress}`);
  }

  private handleDeleteStream(connection: RTMPConnection, message: any): void {
    console.log(`RTMP delete stream request from ${connection.remoteAddress}`);
    
    const params = this.parseURLParameters(message.data);
    const streamName = params.streamName;
    
    if (!streamName || !connection.streamName) {
      return;
    }
    
    const stream = this.streams.get(streamName);
    if (stream) {
      // Remove from publishers or players
      if (connection.isPublishing) {
        stream.publishers = stream.publishers.filter(p => p.id !== connection.id);
        connection.isPublishing = false;
      }
      
      if (connection.isPlaying) {
        stream.players = stream.players.filter(p => p.id !== connection.id);
        connection.isPlaying = false;
      }
      
      // Remove stream if no publishers or players
      if (stream.publishers.length === 0 && stream.players.length === 0) {
        this.streams.delete(streamName);
        console.log(`Stream '${streamName}' removed`);
      }
    }
    
    connection.streamName = undefined;
    
    this.emit('deleteStream', { connection, streamName });
    console.log(`Stream '${streamName}' deleted by ${connection.remoteAddress}`);
  }

  private handleDisconnection(connectionId: string): void {
    const connection = this.connections.get(connectionId);
    if (!connection) {
      return;
    }
    
    console.log(`RTMP disconnection from ${connection.remoteAddress}`);
    
    // Clean up stream associations
    if (connection.streamName) {
      const stream = this.streams.get(connection.streamName);
      if (stream) {
        if (connection.isPublishing) {
          stream.publishers = stream.publishers.filter(p => p.id !== connection.id);
        }
        
        if (connection.isPlaying) {
          stream.players = stream.players.filter(p => p.id !== connection.id);
        }
        
        // Remove stream if empty
        if (stream.publishers.length === 0 && stream.players.length === 0) {
          this.streams.delete(connection.streamName);
        }
      }
    }
    
    this.connections.delete(connectionId);
    this.emit('disconnect', connection);
  }

  private sendRTMPResponse(connection: RTMPConnection, response: any): void {
    // Simplified RTMP response sending
    // In a real implementation, this would properly format RTMP messages
    
    try {
      const responseData = JSON.stringify(response);
      connection.socket.write(Buffer.from(responseData));
    } catch (error) {
      console.error('Error sending RTMP response:', error);
    }
  }

  private parseURLParameters(data: string): any {
    const params: any = {};
    
    // Simple parameter parsing
    // In a real implementation, this would properly parse RTMP AMF messages
    
    if (data.includes('app=')) {
      const appMatch = data.match(/app=([^&\s]+)/);
      if (appMatch) params.app = appMatch[1];
    }
    
    if (data.includes('streamName=')) {
      const streamMatch = data.match(/streamName=([^&\s]+)/);
      if (streamMatch) params.streamName = streamMatch[1];
    }
    
    if (data.includes('tcUrl=')) {
      const tcUrlMatch = data.match(/tcUrl=([^&\s]+)/);
      if (tcUrlMatch) params.tcUrl = tcUrlMatch[1];
    }
    
    if (data.includes('pageUrl=')) {
      const pageUrlMatch = data.match(/pageUrl=([^&\s]+)/);
      if (pageUrlMatch) params.pageUrl = pageUrlMatch[1];
    }
    
    if (data.includes('flashVer=')) {
      const flashVerMatch = data.match(/flashVer=([^&\s]+)/);
      if (flashVerMatch) params.flashVer = flashVerMatch[1];
    }
    
    return params;
  }

  // Public API methods
  getConnections(): RTMPConnection[] {
    return Array.from(this.connections.values());
  }

  getStreams(): RTMPStream[] {
    return Array.from(this.streams.values());
  }

  getStream(streamName: string): RTMPStream | undefined {
    return this.streams.get(streamName);
  }

  getServerStatus(): {
    isRunning: boolean;
    port: number;
    host: string;
    connectionCount: number;
    streamCount: number;
    uptime: number;
  } {
    return {
      isRunning: this.isRunning,
      port: this.config.port,
      host: this.config.host,
      connectionCount: this.connections.size,
      streamCount: this.streams.size,
      uptime: process.uptime()
    };
  }

  forceDisconnect(connectionId: string): boolean {
    const connection = this.connections.get(connectionId);
    if (connection) {
      connection.socket.destroy();
      return true;
    }
    return false;
  }

  kickPublisher(streamName: string): boolean {
    const stream = this.streams.get(streamName);
    if (stream && stream.publishers.length > 0) {
      const publisher = stream.publishers[0];
      publisher.socket.destroy();
      return true;
    }
    return false;
  }

  getStreamStatistics(streamName: string): {
    publisherCount: number;
    playerCount: number;
    totalBandwidth: number;
    uptime: number;
  } | undefined {
    const stream = this.streams.get(streamName);
    if (!stream) {
      return undefined;
    }

    return {
      publisherCount: stream.publishers.length,
      playerCount: stream.players.length,
      totalBandwidth: 0, // Would calculate from actual data
      uptime: Date.now() - stream.createdAt.getTime()
    };
  }

  updateConfig(newConfig: Partial<RTMPConfig>): void {
    this.config = { ...this.config, ...newConfig };
    console.log('RTMP server configuration updated');
  }

  exportConnectionData(): string {
    const data = {
      timestamp: new Date(),
      config: this.config,
      connections: Array.from(this.connections.values()).map(conn => ({
        id: conn.id,
        remoteAddress: conn.remoteAddress,
        connectedAt: conn.connectedAt.toISOString(),
        streamName: conn.streamName,
        isPublishing: conn.isPublishing,
        isPlaying: conn.isPlaying,
        app: conn.app
      })),
      streams: Array.from(this.streams.values()).map(stream => ({
        name: stream.name,
        publisherCount: stream.publishers.length,
        playerCount: stream.players.length,
        createdAt: stream.createdAt.toISOString(),
        lastActivity: stream.lastActivity.toISOString()
      }))
    };

    return JSON.stringify(data, null, 2);
  }
}