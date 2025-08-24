/**
 * SCTE-35 Streaming Control Center - HLS Generator
 * 
 * © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.
 * 
 * This software is the property of Morus Broadcasting Pvt Ltd and is protected by
 * copyright law and international treaties. Unauthorized use, reproduction, or
 * distribution is strictly prohibited.
 */

import { EventEmitter } from 'events';
import * as fs from 'fs';
import * as path from 'path';

export interface HLSManifest {
  streamName: string;
  version: number;
  targetDuration: number;
  mediaSequence: number;
  playlistType: 'EVENT' | 'VOD';
  segments: HLSegment[];
  scte35Events: SCTE35Event[];
  masterPlaylistPath: string;
  directory: string;
}

export interface HLSegment {
  sequence: number;
  duration: number;
  filename: string;
  filePath: string;
  size: number;
  timestamp: Date;
  discontinuity: boolean;
  scte35Event?: SCTE35Event;
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

export interface HLSConfig {
  segmentDuration: number;
  playlistLength: number;
  outputDir: string;
  version: number;
  targetDuration: number;
}

export class HLSGenerator extends EventEmitter {
  private manifests: Map<string, HLSManifest> = new Map();
  private isInitialized: boolean = false;
  private config: HLSConfig = {
    segmentDuration: 2,
    playlistLength: 6,
    outputDir: './tmp/hls',
    version: 3,
    targetDuration: 2
  };

  constructor() {
    super();
  }

  async initialize(config?: Partial<HLSConfig>): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    if (config) {
      this.config = { ...this.config, ...config };
    }

    try {
      // Create output directory
      if (!fs.existsSync(this.config.outputDir)) {
        fs.mkdirSync(this.config.outputDir, { recursive: true });
      }

      this.isInitialized = true;
      console.log('HLS Generator initialized');
    } catch (error) {
      console.error('Failed to initialize HLS Generator:', error);
      throw error;
    }
  }

  async startStream(streamConfig: any): Promise<HLSManifest> {
    if (!this.isInitialized) {
      throw new Error('HLS Generator is not initialized');
    }

    const streamName = streamConfig.name;
    const streamDir = path.join(this.config.outputDir, streamName);

    try {
      // Create stream directory
      if (!fs.existsSync(streamDir)) {
        fs.mkdirSync(streamDir, { recursive: true });
      }

      // Create manifest
      const manifest: HLSManifest = {
        streamName,
        version: this.config.version,
        targetDuration: this.config.targetDuration,
        mediaSequence: 0,
        playlistType: 'EVENT',
        segments: [],
        scte35Events: [],
        masterPlaylistPath: path.join(streamDir, `${streamName}.m3u8`),
        directory: streamDir
      };

      // Create master playlist
      await this.createMasterPlaylist(manifest);

      this.manifests.set(streamName, manifest);
      
      this.emit('streamStarted', manifest);
      console.log(`HLS generation started for stream '${streamName}'`);

      return manifest;
    } catch (error) {
      console.error(`Failed to start HLS generation for stream '${streamName}':`, error);
      throw error;
    }
  }

  private async createMasterPlaylist(manifest: HLSManifest): Promise<void> {
    const playlistContent = `#EXTM3U
#EXT-X-VERSION:${manifest.version}
#EXT-X-TARGETDURATION:${manifest.targetDuration}
#EXT-X-MEDIA-SEQUENCE:${manifest.mediaSequence}
#EXT-X-PLAYLIST-TYPE:${manifest.playlistType}
#EXT-X-ALLOW-CACHE:NO
`;

    fs.writeFileSync(manifest.masterPlaylistPath, playlistContent);
  }

  async addSegment(streamName: string, segmentData: {
    sequence: number;
    duration: number;
    filename: string;
    size: number;
    discontinuity?: boolean;
  }): Promise<void> {
    const manifest = this.manifests.get(streamName);
    if (!manifest) {
      throw new Error(`Manifest for stream '${streamName}' not found`);
    }

    try {
      const segment: HLSSegment = {
        sequence: segmentData.sequence,
        duration: segmentData.duration,
        filename: segmentData.filename,
        filePath: path.join(manifest.directory, segmentData.filename),
        size: segmentData.size,
        timestamp: new Date(),
        discontinuity: segmentData.discontinuity || false
      };

      manifest.segments.push(segment);
      manifest.mediaSequence++;

      // Update playlist
      await this.updatePlaylist(manifest);

      this.emit('segmentAdded', { streamName, segment });
    } catch (error) {
      console.error(`Failed to add segment to stream '${streamName}':`, error);
      throw error;
    }
  }

  private async updatePlaylist(manifest: HLSManifest): Promise<void> {
    let playlistContent = `#EXTM3U
#EXT-X-VERSION:${manifest.version}
#EXT-X-TARGETDURATION:${manifest.targetDuration}
#EXT-X-MEDIA-SEQUENCE:${manifest.mediaSequence}
#EXT-X-PLAYLIST-TYPE:${manifest.playlistType}
#EXT-X-ALLOW-CACHE:NO
`;

    // Add SCTE-35 events (sorted by timestamp)
    const sortedEvents = [...manifest.scte35Events].sort((a, b) => 
      a.timestamp.getTime() - b.timestamp.getTime()
    );

    let eventIndex = 0;
    for (const segment of manifest.segments) {
      // Add SCTE-35 events that should appear before this segment
      while (eventIndex < sortedEvents.length && 
             sortedEvents[eventIndex].timestamp <= segment.timestamp) {
        const event = sortedEvents[eventIndex];
        playlistContent += this.formatSCTE35Tag(event);
        eventIndex++;
      }

      // Add discontinuity tag if needed
      if (segment.discontinuity) {
        playlistContent += '#EXT-X-DISCONTINUITY\n';
      }

      // Add segment
      playlistContent += `#EXTINF:${segment.duration.toFixed(3)},\n`;
      playlistContent += `${segment.filename}\n`;
    }

    // Add remaining SCTE-35 events
    while (eventIndex < sortedEvents.length) {
      const event = sortedEvents[eventIndex];
      playlistContent += this.formatSCTE35Tag(event);
      eventIndex++;
    }

    // Write to file
    fs.writeFileSync(manifest.masterPlaylistPath, playlistContent);
  }

  private formatSCTE35Tag(event: SCTE35Event): string {
    if (event.type === 'CUE-OUT') {
      return `#EXT-X-CUE-OUT:${event.duration}\n`;
    } else if (event.type === 'CUE-IN') {
      return `#EXT-X-CUE-IN\n`;
    }
    return '';
  }

  async injectSCTE35(streamName: string, event: SCTE35Event): Promise<void> {
    const manifest = this.manifests.get(streamName);
    if (!manifest) {
      throw new Error(`Manifest for stream '${streamName}' not found`);
    }

    try {
      // Add event to manifest
      manifest.scte35Events.push(event);

      // Update playlist to include SCTE-35 tag
      await this.updatePlaylist(manifest);

      this.emit('scte35Injected', { streamName, event });
      console.log(`SCTE-35 ${event.type} tag injected into HLS manifest for stream '${streamName}'`);
    } catch (error) {
      console.error(`Failed to inject SCTE-35 into HLS manifest for stream '${streamName}':`, error);
      throw error;
    }
  }

  async stopStream(streamName: string): Promise<void> {
    const manifest = this.manifests.get(streamName);
    if (!manifest) {
      return;
    }

    try {
      // Add end tag to playlist
      const playlistContent = fs.readFileSync(manifest.masterPlaylistPath, 'utf8');
      const endTag = '#EXT-X-ENDLIST\n';
      
      if (!playlistContent.includes(endTag)) {
        fs.appendFileSync(manifest.masterPlaylistPath, endTag);
      }

      this.manifests.delete(streamName);
      
      this.emit('streamStopped', { streamName });
      console.log(`HLS generation stopped for stream '${streamName}'`);
    } catch (error) {
      console.error(`Failed to stop HLS generation for stream '${streamName}':`, error);
      throw error;
    }
  }

  async stop(): Promise<void> {
    try {
      // Stop all streams
      for (const [streamName] of this.manifests) {
        await this.stopStream(streamName);
      }

      this.isInitialized = false;
      console.log('HLS Generator stopped');
    } catch (error) {
      console.error('Error stopping HLS Generator:', error);
      throw error;
    }
  }

  getManifest(streamName: string): HLSManifest | undefined {
    return this.manifests.get(streamName);
  }

  getAllManifests(): HLSManifest[] {
    return Array.from(this.manifests.values());
  }

  getPlaylistContent(streamName: string): string | undefined {
    const manifest = this.manifests.get(streamName);
    if (!manifest) {
      return undefined;
    }

    try {
      return fs.readFileSync(manifest.masterPlaylistPath, 'utf8');
    } catch (error) {
      console.error(`Failed to read playlist for stream '${streamName}':`, error);
      return undefined;
    }
  }

  getSCTE35Events(streamName: string): SCTE35Event[] {
    const manifest = this.manifests.get(streamName);
    return manifest ? manifest.scte35Events : [];
  }

  async createVariantPlaylist(streamName: string, variants: Array<{
    bandwidth: number;
    resolution: string;
    codecs: string;
    uri: string;
  }>): Promise<string> {
    const manifest = this.manifests.get(streamName);
    if (!manifest) {
      throw new Error(`Manifest for stream '${streamName}' not found`);
    }

    let playlistContent = '#EXTM3U\n#EXT-X-VERSION:3\n';

    for (const variant of variants) {
      playlistContent += `#EXT-X-STREAM-INF:BANDWIDTH=${variant.bandwidth},RESOLUTION=${variant.resolution},CODECS="${variant.codecs}"\n`;
      playlistContent += `${variant.uri}\n`;
    }

    const variantPath = path.join(manifest.directory, `${streamName}_variant.m3u8`);
    fs.writeFileSync(variantPath, playlistContent);

    return variantPath;
  }

  async createMediaManifest(streamName: string, mediaType: 'audio' | 'video' | 'subtitle'): Promise<string> {
    const manifest = this.manifests.get(streamName);
    if (!manifest) {
      throw new Error(`Manifest for stream '${streamName}' not found`);
    }

    const mediaManifestPath = path.join(manifest.directory, `${streamName}_${mediaType}.m3u8`);
    const content = `#EXTM3U
#EXT-X-VERSION:3
#EXT-X-MEDIA:TYPE=${mediaType.toUpperCase()},GROUP-ID="${mediaType}",NAME="${streamName} ${mediaType}",AUTOSELECT=YES,DEFAULT=YES
#EXT-X-STREAM-INF:BANDWIDTH=128000,CODECS="mp4a.40.2"
${streamName}_${mediaType}_main.m3u8
`;

    fs.writeFileSync(mediaManifestPath, content);
    return mediaManifestPath;
  }

  async cleanupOldSegments(streamName: string, maxAge: number = 3600000): Promise<void> {
    const manifest = this.manifests.get(streamName);
    if (!manifest) {
      return;
    }

    try {
      const now = Date.now();
      const files = fs.readdirSync(manifest.directory);

      for (const file of files) {
        if (file.endsWith('.ts') || file.endsWith('.m3u8')) {
          const filePath = path.join(manifest.directory, file);
          const stats = fs.statSync(filePath);
          
          if (now - stats.mtime.getTime() > maxAge) {
            fs.unlinkSync(filePath);
            console.log(`Cleaned up old file: ${file}`);
          }
        }
      }
    } catch (error) {
      console.error(`Failed to cleanup old segments for stream '${streamName}':`, error);
    }
  }

  getStatistics(): {
    totalStreams: number;
    totalSegments: number;
    totalSCTE35Events: number;
    averageSegmentDuration: number;
  } {
    const manifests = Array.from(this.manifests.values());
    const totalStreams = manifests.length;
    const totalSegments = manifests.reduce((sum, manifest) => sum + manifest.segments.length, 0);
    const totalSCTE35Events = manifests.reduce((sum, manifest) => sum + manifest.scte35Events.length, 0);

    const allDurations = manifests.flatMap(manifest => 
      manifest.segments.map(segment => segment.duration)
    );
    const averageSegmentDuration = allDurations.length > 0 
      ? allDurations.reduce((sum, duration) => sum + duration, 0) / allDurations.length
      : 0;

    return {
      totalStreams,
      totalSegments,
      totalSCTE35Events,
      averageSegmentDuration
    };
  }

  validateManifest(streamName: string): { isValid: boolean; errors: string[] } {
    const manifest = this.manifests.get(streamName);
    if (!manifest) {
      return {
        isValid: false,
        errors: ['Manifest not found']
      };
    }

    const errors: string[] = [];

    // Check if playlist file exists
    if (!fs.existsSync(manifest.masterPlaylistPath)) {
      errors.push('Master playlist file does not exist');
    }

    // Check if segments exist
    for (const segment of manifest.segments) {
      if (!fs.existsSync(segment.filePath)) {
        errors.push(`Segment file ${segment.filename} does not exist`);
      }
    }

    // Check playlist content
    const content = this.getPlaylistContent(streamName);
    if (!content) {
      errors.push('Cannot read playlist content');
    } else {
      if (!content.includes('#EXTM3U')) {
        errors.push('Invalid playlist format: missing #EXTM3U');
      }
      if (!content.includes('#EXT-X-VERSION')) {
        errors.push('Invalid playlist format: missing #EXT-X-VERSION');
      }
      if (!content.includes('#EXT-X-TARGETDURATION')) {
        errors.push('Invalid playlist format: missing #EXT-X-TARGETDURATION');
      }
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }

  exportManifest(streamName: string): string | undefined {
    const manifest = this.manifests.get(streamName);
    if (!manifest) {
      return undefined;
    }

    return JSON.stringify({
      ...manifest,
      segments: manifest.segments.map(segment => ({
        ...segment,
        timestamp: segment.timestamp.toISOString()
      })),
      scte35Events: manifest.scte35Events.map(event => ({
        ...event,
        timestamp: event.timestamp.toISOString()
      }))
    }, null, 2);
  }
}