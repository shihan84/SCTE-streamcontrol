/**
 * SCTE-35 Streaming Control Center - DASH Generator
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

export interface DASHManifest {
  streamName: string;
  version: number;
  profiles: string[];
  mediaPresentationDuration: number;
  minBufferTime: number;
  type: 'static' | 'dynamic';
  publishTime: Date;
  availabilityStartTime?: Date;
  availabilityEndTime?: Date;
  periods: DASHPeriod[];
  scte35Events: SCTE35Event[];
  manifestPath: string;
  directory: string;
}

export interface DASHPeriod {
  id: string;
  start: number;
  duration: number;
  adaptations: DASHAdaptation[];
}

export interface DASHAdaptation {
  id: string;
  contentType: 'video' | 'audio';
  mimeType: string;
  codecs: string;
  bandwidth: number;
  width?: number;
  height?: number;
  frameRate?: string;
  sampleRate?: number;
  channels?: number;
  representations: DASHRepresentation[];
}

export interface DASHRepresentation {
  id: string;
  bandwidth: number;
  codecs: string;
  width?: number;
  height?: number;
  frameRate?: string;
  sampleRate?: number;
  channels?: number;
  mimeType: string;
  segments: DASHSegment[];
}

export interface DASHSegment {
  id: string;
  duration: number;
  media: string;
  mediaRange?: string;
  indexRange?: string;
  initialization: string;
  timeline: number;
  scte35Events?: SCTE35Event[];
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

export interface DASHConfig {
  segmentDuration: number;
  playlistLength: number;
  outputDir: string;
  version: number;
  profiles: string[];
  minBufferTime: number;
  type: 'static' | 'dynamic';
  availabilityTimeOffset?: number;
  timeShiftBufferDepth?: number;
}

export class DASHGenerator extends EventEmitter {
  private manifests: Map<string, DASHManifest> = new Map();
  private isInitialized: boolean = false;
  private config: DASHConfig = {
    segmentDuration: 2,
    playlistLength: 6,
    outputDir: './tmp/dash',
    version: 1,
    profiles: [
      'urn:mpeg:dash:profile:isoff-live:2011',
      'urn:mpeg:dash:profile:isoff-live:2013',
      'urn:mpeg:dash:profile:isoff-on-demand:2011'
    ],
    minBufferTime: 2,
    type: 'dynamic',
    availabilityTimeOffset: 0,
    timeShiftBufferDepth: 300
  };

  constructor() {
    super();
  }

  async initialize(config?: Partial<DASHConfig>): Promise<void> {
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
      console.log('DASH Generator initialized');
    } catch (error) {
      console.error('Failed to initialize DASH Generator:', error);
      throw error;
    }
  }

  async startStream(streamConfig: any): Promise<DASHManifest> {
    if (!this.isInitialized) {
      throw new Error('DASH Generator is not initialized');
    }

    const streamName = streamConfig.name;
    const streamDir = path.join(this.config.outputDir, streamName);

    try {
      // Create stream directory
      if (!fs.existsSync(streamDir)) {
        fs.mkdirSync(streamDir, { recursive: true });
      }

      // Create manifest
      const manifest: DASHManifest = {
        streamName,
        version: this.config.version,
        profiles: this.config.profiles,
        mediaPresentationDuration: 0, // Will be updated as segments are added
        minBufferTime: this.config.minBufferTime,
        type: this.config.type,
        publishTime: new Date(),
        availabilityStartTime: new Date(),
        periods: [],
        scte35Events: [],
        manifestPath: path.join(streamDir, `${streamName}.mpd`),
        directory: streamDir
      };

      // Create initial period
      const period: DASHPeriod = {
        id: 'period_1',
        start: 0,
        duration: 0,
        adaptations: []
      };

      // Create video adaptation
      const videoAdaptation: DASHAdaptation = {
        id: 'video',
        contentType: 'video',
        mimeType: 'video/mp4',
        codecs: 'avc1.640028',
        bandwidth: streamConfig.videoSettings.bitrate * 1000000, // Convert to bps
        width: parseInt(streamConfig.videoSettings.resolution.split('x')[0]),
        height: parseInt(streamConfig.videoSettings.resolution.split('x')[1]),
        frameRate: streamConfig.videoSettings.framerate,
        representations: []
      };

      // Create video representation
      const videoRepresentation: DASHRepresentation = {
        id: 'video_1',
        bandwidth: streamConfig.videoSettings.bitrate * 1000000,
        codecs: 'avc1.640028',
        width: parseInt(streamConfig.videoSettings.resolution.split('x')[0]),
        height: parseInt(streamConfig.videoSettings.resolution.split('x')[1]),
        frameRate: streamConfig.videoSettings.framerate,
        mimeType: 'video/mp4',
        segments: []
      };

      videoAdaptation.representations.push(videoRepresentation);
      period.adaptations.push(videoAdaptation);

      // Create audio adaptation
      const audioAdaptation: DASHAdaptation = {
        id: 'audio',
        contentType: 'audio',
        mimeType: 'audio/mp4',
        codecs: 'mp4a.40.2',
        bandwidth: streamConfig.audioSettings.bitrate * 1000, // Convert to bps
        sampleRate: streamConfig.audioSettings.sampleRate,
        channels: streamConfig.audioSettings.channels,
        representations: []
      };

      // Create audio representation
      const audioRepresentation: DASHRepresentation = {
        id: 'audio_1',
        bandwidth: streamConfig.audioSettings.bitrate * 1000,
        codecs: 'mp4a.40.2',
        sampleRate: streamConfig.audioSettings.sampleRate,
        channels: streamConfig.audioSettings.channels,
        mimeType: 'audio/mp4',
        segments: []
      };

      audioAdaptation.representations.push(audioRepresentation);
      period.adaptations.push(audioAdaptation);

      manifest.periods.push(period);

      // Create DASH manifest
      await this.createDASHManifest(manifest);

      this.manifests.set(streamName, manifest);
      
      this.emit('streamStarted', manifest);
      console.log(`DASH generation started for stream '${streamName}'`);

      return manifest;
    } catch (error) {
      console.error(`Failed to start DASH generation for stream '${streamName}':`, error);
      throw error;
    }
  }

  private async createDASHManifest(manifest: DASHManifest): Promise<void> {
    const manifestContent = this.generateManifestXML(manifest);
    fs.writeFileSync(manifest.manifestPath, manifestContent);
  }

  private generateManifestXML(manifest: DASHManifest): string {
    let xml = `<?xml version="1.0" encoding="UTF-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="urn:mpeg:dash:schema:mpd:2011 http://standards.iso.org/ittf/PubliclyAvailableStandards/MPEG-DASH_schema_files/DASH-MPD.xsd"
    profiles="${manifest.profiles.join(' ')}"
    type="${manifest.type}"
    minimumUpdatePeriod="PT${this.config.segmentDuration}S"
    minBufferTime="PT${manifest.minBufferTime}S"
    timeShiftBufferDepth="PT${this.config.timeShiftBufferDepth}S"
    availabilityStartTime="${manifest.availabilityStartTime?.toISOString()}"
    publishTime="${manifest.publishTime.toISOString()}"
    mediaPresentationDuration="PT${manifest.mediaPresentationDuration}S">`;

    // Add periods
    for (const period of manifest.periods) {
      xml += `
    <Period id="${period.id}" start="PT${period.start}S" duration="PT${period.duration}S">`;

      // Add adaptations
      for (const adaptation of period.adaptations) {
        xml += `
        <AdaptationSet id="${adaptation.id}" contentType="${adaptation.contentType}" 
            mimeType="${adaptation.mimeType}" codecs="${adaptation.codecs}" 
            bandwidth="${adaptation.bandwidth}"`;

        if (adaptation.width && adaptation.height) {
          xml += ` width="${adaptation.width}" height="${adaptation.height}"`;
        }
        if (adaptation.frameRate) {
          xml += ` frameRate="${adaptation.frameRate}"`;
        }
        if (adaptation.sampleRate) {
          xml += ` sampleRate="${adaptation.sampleRate}"`;
        }
        if (adaptation.channels) {
          xml += ` audioSamplingRate="${adaptation.sampleRate}" numChannels="${adaptation.channels}"`;
        }

        xml += `>`;

        // Add representations
        for (const representation of adaptation.representations) {
          xml += `
            <Representation id="${representation.id}" bandwidth="${representation.bandwidth}" 
                codecs="${representation.codecs}" mimeType="${representation.mimeType}"`;

          if (representation.width && representation.height) {
            xml += ` width="${representation.width}" height="${representation.height}"`;
          }
          if (representation.frameRate) {
            xml += ` frameRate="${representation.frameRate}"`;
          }
          if (representation.sampleRate) {
            xml += ` audioSamplingRate="${representation.sampleRate}"`;
          }
          if (representation.channels) {
            xml += ` numChannels="${representation.channels}"`;
          }

          xml += `>
                <SegmentTemplate timescale="1000" duration="${this.config.segmentDuration * 1000}" 
                    media="$RepresentationID$_$Number$.m4s" startNumber="1" 
                    initialization="$RepresentationID$_init.m4s"/>`;

          // Add SCTE-35 events if any
          if (manifest.scte35Events.length > 0) {
            xml += `
                <SupplementalProperty schemeIdUri="urn:scte:dash:2014:xml" 
                    value="${this.generateSCTE35XML(manifest.scte35Events)}"/>`;
          }

          xml += `
            </Representation>`;
        }

        xml += `
        </AdaptationSet>`;
      }

      xml += `
    </Period>`;
    }

    xml += `
</MPD>`;

    return xml;
  }

  private generateSCTE35XML(events: SCTE35Event[]): string {
    let scte35XML = '<scte35:Signal xmlns:scte35="urn:scte:scte35:2014:xml+bin">';
    
    for (const event of events) {
      scte35XML += `
        <scte35:SignalEvent>
            <scte35:BinaryData>${this.createSCTE35Binary(event)}</scte35:BinaryData>
            <scte35:XMLData>
                <scte35:Signal xmlns="urn:scte:scte35:2013:xml">
                    <scte35:BinaryData>${this.createSCTE35Binary(event)}</scte35:BinaryData>
                    <scte35:Time>${event.timestamp.getTime()}</scte35:Time>
                    <scte35:Duration>${event.duration * 1000}</scte35:Duration>
                    <scte35:EventType>${event.type}</scte35:EventType>
                    <scte35:EventID>${event.eventId}</scte35:EventID>
                </scte35:Signal>
            </scte35:XMLData>
        </scte35:SignalEvent>`;
    }
    
    scte35XML += '</scte35:Signal>';
    return scte35XML;
  }

  private createSCTE35Binary(event: SCTE35Event): string {
    // Create a simplified SCTE-35 binary representation
    // In a real implementation, this would create proper SCTE-35 binary data
    const binaryData = {
      protocol_version: 0,
      packet_type: event.type === 'CUE-OUT' ? 0 : 1,
      timestamp: Math.floor(event.timestamp.getTime() / 1000),
      event_id: event.eventId,
      duration: event.duration,
      pre_roll: event.preRoll,
      segmentation_type_id: event.type === 'CUE-OUT' ? 0x34 : 0x36
    };
    
    return Buffer.from(JSON.stringify(binaryData)).toString('base64');
  }

  async addSegment(streamName: string, segmentData: {
    representationId: string;
    sequence: number;
    duration: number;
    filename: string;
    size: number;
    isInitialization?: boolean;
  }): Promise<void> {
    const manifest = this.manifests.get(streamName);
    if (!manifest) {
      throw new Error(`Manifest for stream '${streamName}' not found`);
    }

    try {
      let segmentAdded = false;

      // Find the representation and add the segment
      for (const period of manifest.periods) {
        for (const adaptation of period.adaptations) {
          for (const representation of adaptation.representations) {
            if (representation.id === segmentData.representationId) {
              const segment: DASHSegment = {
                id: `${segmentData.representationId}_${segmentData.sequence}`,
                duration: segmentData.duration,
                media: segmentData.filename,
                initialization: `${segmentData.representationId}_init.m4s`,
                timeline: segmentData.sequence
              };

              representation.segments.push(segment);
              segmentAdded = true;

              // Update period duration
              period.duration = Math.max(period.duration, 
                representation.segments.reduce((sum, seg) => sum + seg.duration, 0));
              break;
            }
          }
          if (segmentAdded) break;
        }
        if (segmentAdded) break;
      }

      if (segmentAdded) {
        // Update manifest duration
        manifest.mediaPresentationDuration = Math.max(...manifest.periods.map(p => p.duration));
        
        // Update manifest
        await this.createDASHManifest(manifest);

        this.emit('segmentAdded', { streamName, segment: segmentData });
      }
    } catch (error) {
      console.error(`Failed to add segment to DASH stream '${streamName}':`, error);
      throw error;
    }
  }

  async injectSCTE35(streamName: string, event: SCTE35Event): Promise<void> {
    const manifest = this.manifests.get(streamName);
    if (!manifest) {
      throw new Error(`Manifest for stream '${streamName}' not found`);
    }

    try {
      // Add event to manifest
      manifest.scte35Events.push(event);

      // Update manifest to include SCTE-35
      await this.createDASHManifest(manifest);

      this.emit('scte35Injected', { streamName, event });
      console.log(`SCTE-35 ${event.type} event injected into DASH manifest for stream '${streamName}'`);
    } catch (error) {
      console.error(`Failed to inject SCTE-35 into DASH manifest for stream '${streamName}':`, error);
      throw error;
    }
  }

  async stopStream(streamName: string): Promise<void> {
    const manifest = this.manifests.get(streamName);
    if (!manifest) {
      return;
    }

    try {
      // Update manifest type to static for VOD
      manifest.type = 'static';
      manifest.availabilityEndTime = new Date();
      
      // Update manifest
      await this.createDASHManifest(manifest);

      this.manifests.delete(streamName);
      
      this.emit('streamStopped', { streamName });
      console.log(`DASH generation stopped for stream '${streamName}'`);
    } catch (error) {
      console.error(`Failed to stop DASH generation for stream '${streamName}':`, error);
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
      console.log('DASH Generator stopped');
    } catch (error) {
      console.error('Error stopping DASH Generator:', error);
      throw error;
    }
  }

  getManifest(streamName: string): DASHManifest | undefined {
    return this.manifests.get(streamName);
  }

  getAllManifests(): DASHManifest[] {
    return Array.from(this.manifests.values());
  }

  getManifestContent(streamName: string): string | undefined {
    const manifest = this.manifests.get(streamName);
    if (!manifest) {
      return undefined;
    }

    try {
      return fs.readFileSync(manifest.manifestPath, 'utf8');
    } catch (error) {
      console.error(`Failed to read DASH manifest for stream '${streamName}':`, error);
      return undefined;
    }
  }

  getSCTE35Events(streamName: string): SCTE35Event[] {
    const manifest = this.manifests.get(streamName);
    return manifest ? manifest.scte35Events : [];
  }

  async createMultiPeriodManifest(streamName: string, periods: Array<{
    id: string;
    start: number;
    duration: number;
    adaptations: any[];
  }>): Promise<string> {
    const manifest = this.manifests.get(streamName);
    if (!manifest) {
      throw new Error(`Manifest for stream '${streamName}' not found`);
    }

    try {
      // Update periods
      manifest.periods = periods;
      
      // Update manifest duration
      manifest.mediaPresentationDuration = Math.max(...periods.map(p => p.duration));
      
      // Update manifest
      await this.createDASHManifest(manifest);

      return manifest.manifestPath;
    } catch (error) {
      console.error(`Failed to create multi-period manifest for stream '${streamName}':`, error);
      throw error;
    }
  }

  async createAdaptiveBitrateManifest(streamName: string, profiles: Array<{
    id: string;
    bandwidth: number;
    resolution: string;
    codecs: string;
  }>): Promise<string> {
    const manifest = this.manifests.get(streamName);
    if (!manifest) {
      throw new Error(`Manifest for stream '${streamName}' not found`);
    }

    try {
      // Add multiple representations for adaptive bitrate
      for (const period of manifest.periods) {
        for (const adaptation of period.adaptations) {
          if (adaptation.contentType === 'video') {
            // Clear existing representations
            adaptation.representations = [];
            
            // Add new representations for each profile
            for (const profile of profiles) {
              const representation: DASHRepresentation = {
                id: profile.id,
                bandwidth: profile.bandwidth,
                codecs: profile.codecs,
                width: parseInt(profile.resolution.split('x')[0]),
                height: parseInt(profile.resolution.split('x')[1]),
                mimeType: 'video/mp4',
                segments: []
              };
              
              adaptation.representations.push(representation);
            }
          }
        }
      }

      // Update manifest
      await this.createDASHManifest(manifest);

      return manifest.manifestPath;
    } catch (error) {
      console.error(`Failed to create adaptive bitrate manifest for stream '${streamName}':`, error);
      throw error;
    }
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
        if (file.endsWith('.m4s') || file.endsWith('.mpd') || file.endsWith('.m4v')) {
          const filePath = path.join(manifest.directory, file);
          const stats = fs.statSync(filePath);
          
          if (now - stats.mtime.getTime() > maxAge) {
            fs.unlinkSync(filePath);
            console.log(`Cleaned up old DASH file: ${file}`);
          }
        }
      }
    } catch (error) {
      console.error(`Failed to cleanup old DASH segments for stream '${streamName}':`, error);
    }
  }

  getStatistics(): {
    totalStreams: number;
    totalSegments: number;
    totalSCTE35Events: number;
    averageSegmentDuration: number;
    adaptiveStreams: number;
  } {
    const manifests = Array.from(this.manifests.values());
    const totalStreams = manifests.length;
    let totalSegments = 0;
    let totalSCTE35Events = 0;
    let adaptiveStreams = 0;

    const allDurations: number[] = [];

    for (const manifest of manifests) {
      totalSCTE35Events += manifest.scte35Events.length;
      
      // Count segments and adaptive streams
      for (const period of manifest.periods) {
        for (const adaptation of period.adaptations) {
          totalSegments += adaptation.representations.reduce((sum, rep) => sum + rep.segments.length, 0);
          
          if (adaptation.representations.length > 1) {
            adaptiveStreams++;
          }
          
          // Collect segment durations
          for (const representation of adaptation.representations) {
            allDurations.push(...representation.segments.map(seg => seg.duration));
          }
        }
      }
    }

    const averageSegmentDuration = allDurations.length > 0 
      ? allDurations.reduce((sum, duration) => sum + duration, 0) / allDurations.length
      : 0;

    return {
      totalStreams,
      totalSegments,
      totalSCTE35Events,
      averageSegmentDuration,
      adaptiveStreams
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

    // Check if manifest file exists
    if (!fs.existsSync(manifest.manifestPath)) {
      errors.push('DASH manifest file does not exist');
    }

    // Check manifest content
    const content = this.getManifestContent(streamName);
    if (!content) {
      errors.push('Cannot read manifest content');
    } else {
      if (!content.includes('<MPD')) {
        errors.push('Invalid manifest format: missing MPD element');
      }
      if (!content.includes('profiles=')) {
        errors.push('Invalid manifest format: missing profiles attribute');
      }
      if (!content.includes('<Period')) {
        errors.push('Invalid manifest format: missing Period element');
      }
      if (!content.includes('<AdaptationSet')) {
        errors.push('Invalid manifest format: missing AdaptationSet element');
      }
      if (!content.includes('<Representation')) {
        errors.push('Invalid manifest format: missing Representation element');
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
      publishTime: manifest.publishTime.toISOString(),
      availabilityStartTime: manifest.availabilityStartTime?.toISOString(),
      availabilityEndTime: manifest.availabilityEndTime?.toISOString(),
      scte35Events: manifest.scte35Events.map(event => ({
        ...event,
        timestamp: event.timestamp.toISOString()
      }))
    }, null, 2);
  }

  importManifest(jsonData: string): Promise<void> {
    try {
      const manifestData = JSON.parse(jsonData);
      
      // Convert date strings back to Date objects
      manifestData.publishTime = new Date(manifestData.publishTime);
      if (manifestData.availabilityStartTime) {
        manifestData.availabilityStartTime = new Date(manifestData.availabilityStartTime);
      }
      if (manifestData.availabilityEndTime) {
        manifestData.availabilityEndTime = new Date(manifestData.availabilityEndTime);
      }
      if (manifestData.scte35Events) {
        manifestData.scte35Events = manifestData.scte35Events.map((event: any) => ({
          ...event,
          timestamp: new Date(event.timestamp)
        }));
      }

      // Add to manifests
      this.manifests.set(manifestData.streamName, manifestData);
      
      // Write manifest file
      await this.createDASHManifest(manifestData);
      
      console.log(`DASH manifest imported for stream '${manifestData.streamName}'`);
    } catch (error) {
      console.error('Failed to import DASH manifest:', error);
      throw new Error('Invalid manifest data format');
    }
  }
}