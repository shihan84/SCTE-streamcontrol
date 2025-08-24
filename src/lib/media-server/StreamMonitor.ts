import { EventEmitter } from 'events';

export interface StreamMetrics {
  bitrate: number;
  fps: number;
  audioLevel: number;
  latency: number;
  uptime: number;
  viewers: number;
  cpuUsage: number;
  memoryUsage: number;
  diskUsage: number;
  networkBandwidth: number;
}

export interface StreamHealth {
  streamName: string;
  health: 'good' | 'warning' | 'critical';
  metrics: StreamMetrics;
  issues: HealthIssue[];
  lastCheck: Date;
}

export interface HealthIssue {
  type: 'bitrate' | 'fps' | 'audio' | 'latency' | 'connection' | 'resource';
  severity: 'low' | 'medium' | 'high';
  message: string;
  timestamp: Date;
  resolved: boolean;
}

export interface MonitoringConfig {
  checkInterval: number;
  thresholds: {
    bitrate: { min: number; max: number };
    fps: { min: number; max: number };
    audioLevel: { min: number; max: number };
    latency: { max: number };
    cpuUsage: { max: number };
    memoryUsage: { max: number };
    diskUsage: { max: number };
  };
  alerts: {
    enabled: boolean;
    cooldown: number;
  };
}

export class StreamMonitor extends EventEmitter {
  private monitoredStreams: Map<string, StreamHealth> = new Map();
  private monitoringIntervals: Map<string, NodeJS.Timeout> = new Map();
  private isInitialized: boolean = false;
  private config: MonitoringConfig = {
    checkInterval: 5000, // 5 seconds
    thresholds: {
      bitrate: { min: 1, max: 10 }, // Mbps
      fps: { min: 25, max: 35 },
      audioLevel: { min: -30, max: -10 }, // dB
      latency: { max: 3000 }, // ms
      cpuUsage: { max: 80 }, // %
      memoryUsage: { max: 85 }, // %
      diskUsage: { max: 90 } // %
    },
    alerts: {
      enabled: true,
      cooldown: 30000 // 30 seconds
    }
  };

  constructor() {
    super();
  }

  async initialize(config?: Partial<MonitoringConfig>): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    if (config) {
      this.config = { ...this.config, ...config };
    }

    this.isInitialized = true;
    console.log('Stream Monitor initialized');
  }

  async stop(): Promise<void> {
    // Stop all monitoring intervals
    for (const [streamName, interval] of this.monitoringIntervals) {
      clearInterval(interval);
    }
    this.monitoringIntervals.clear();

    this.isInitialized = false;
    console.log('Stream Monitor stopped');
  }

  watchStream(stream: any): void {
    if (!this.isInitialized) {
      throw new Error('Stream Monitor is not initialized');
    }

    const streamName = stream.name;
    if (this.monitoringIntervals.has(streamName)) {
      console.log(`Stream '${streamName}' is already being monitored`);
      return;
    }

    // Initialize stream health
    const health: StreamHealth = {
      streamName,
      health: 'good',
      metrics: {
        bitrate: 0,
        fps: 0,
        audioLevel: -20,
        latency: 0,
        uptime: 0,
        viewers: 0,
        cpuUsage: 0,
        memoryUsage: 0,
        diskUsage: 0,
        networkBandwidth: 0
      },
      issues: [],
      lastCheck: new Date()
    };

    this.monitoredStreams.set(streamName, health);

    // Start monitoring interval
    const interval = setInterval(() => {
      this.checkStreamHealth(streamName);
    }, this.config.checkInterval);

    this.monitoringIntervals.set(streamName, interval);

    console.log(`Started monitoring stream '${streamName}'`);
    this.emit('monitoringStarted', { streamName });
  }

  unwatchStream(streamName: string): void {
    const interval = this.monitoringIntervals.get(streamName);
    if (interval) {
      clearInterval(interval);
      this.monitoringIntervals.delete(streamName);
      this.monitoredStreams.delete(streamName);
      console.log(`Stopped monitoring stream '${streamName}'`);
      this.emit('monitoringStopped', { streamName });
    }
  }

  private async checkStreamHealth(streamName: string): Promise<void> {
    const health = this.monitoredStreams.get(streamName);
    if (!health) {
      return;
    }

    try {
      // Collect metrics
      const metrics = await this.collectMetrics(streamName);
      
      // Analyze health
      const { healthStatus, issues } = this.analyzeHealth(streamName, metrics);
      
      // Update health status
      health.health = healthStatus;
      health.metrics = metrics;
      health.issues = issues;
      health.lastCheck = new Date();

      // Emit health update
      this.emit('streamHealth', {
        streamName,
        health: healthStatus,
        metrics,
        issues
      });

      // Emit alerts for new issues
      if (this.config.alerts.enabled) {
        this.processAlerts(streamName, issues);
      }

    } catch (error) {
      console.error(`Error checking health for stream '${streamName}':`, error);
      
      // Mark as critical on error
      health.health = 'critical';
      health.issues.push({
        type: 'connection',
        severity: 'high',
        message: `Health check failed: ${error.message}`,
        timestamp: new Date(),
        resolved: false
      });
    }
  }

  private async collectMetrics(streamName: string): Promise<StreamMetrics> {
    // Simulate metrics collection
    // In a real implementation, this would collect actual metrics from the media server
    
    return {
      bitrate: 4.5 + (Math.random() - 0.5) * 1, // 4-5 Mbps
      fps: 29.97 + (Math.random() - 0.5) * 0.1, // ~30 fps
      audioLevel: -20 + (Math.random() - 0.5) * 2, // -22 to -18 dB
      latency: 100 + Math.random() * 200, // 100-300ms
      uptime: Math.random() * 86400000, // Random uptime
      viewers: Math.floor(Math.random() * 1000) + 100, // 100-1100 viewers
      cpuUsage: Math.random() * 100, // 0-100%
      memoryUsage: Math.random() * 100, // 0-100%
      diskUsage: Math.random() * 100, // 0-100%
      networkBandwidth: Math.random() * 1000000 // 0-1 Gbps
    };
  }

  private analyzeHealth(streamName: string, metrics: StreamMetrics): {
    healthStatus: 'good' | 'warning' | 'critical';
    issues: HealthIssue[];
  } {
    const issues: HealthIssue[] = [];
    const { thresholds } = this.config;

    // Check bitrate
    if (metrics.bitrate < thresholds.bitrate.min || metrics.bitrate > thresholds.bitrate.max) {
      issues.push({
        type: 'bitrate',
        severity: 'medium',
        message: `Bitrate ${metrics.bitrate.toFixed(2)} Mbps is outside optimal range (${thresholds.bitrate.min}-${thresholds.bitrate.max} Mbps)`,
        timestamp: new Date(),
        resolved: false
      });
    }

    // Check FPS
    if (metrics.fps < thresholds.fps.min || metrics.fps > thresholds.fps.max) {
      issues.push({
        type: 'fps',
        severity: 'medium',
        message: `FPS ${metrics.fps.toFixed(2)} is outside optimal range (${thresholds.fps.min}-${thresholds.fps.max})`,
        timestamp: new Date(),
        resolved: false
      });
    }

    // Check audio level
    if (metrics.audioLevel < thresholds.audioLevel.min || metrics.audioLevel > thresholds.audioLevel.max) {
      issues.push({
        type: 'audio',
        severity: 'medium',
        message: `Audio level ${metrics.audioLevel.toFixed(2)} dB is outside optimal range (${thresholds.audioLevel.min}-${thresholds.audioLevel.max} dB)`,
        timestamp: new Date(),
        resolved: false
      });
    }

    // Check latency
    if (metrics.latency > thresholds.latency.max) {
      issues.push({
        type: 'latency',
        severity: 'high',
        message: `Latency ${metrics.latency.toFixed(0)} ms exceeds threshold (${thresholds.latency.max} ms)`,
        timestamp: new Date(),
        resolved: false
      });
    }

    // Check resource usage
    if (metrics.cpuUsage > thresholds.cpuUsage.max) {
      issues.push({
        type: 'resource',
        severity: 'high',
        message: `CPU usage ${metrics.cpuUsage.toFixed(1)}% exceeds threshold (${thresholds.cpuUsage.max}%)`,
        timestamp: new Date(),
        resolved: false
      });
    }

    if (metrics.memoryUsage > thresholds.memoryUsage.max) {
      issues.push({
        type: 'resource',
        severity: 'high',
        message: `Memory usage ${metrics.memoryUsage.toFixed(1)}% exceeds threshold (${thresholds.memoryUsage.max}%)`,
        timestamp: new Date(),
        resolved: false
      });
    }

    if (metrics.diskUsage > thresholds.diskUsage.max) {
      issues.push({
        type: 'resource',
        severity: 'medium',
        message: `Disk usage ${metrics.diskUsage.toFixed(1)}% exceeds threshold (${thresholds.diskUsage.max}%)`,
        timestamp: new Date(),
        resolved: false
      });
    }

    // Determine overall health status
    let healthStatus: 'good' | 'warning' | 'critical' = 'good';
    
    const highSeverityIssues = issues.filter(issue => issue.severity === 'high');
    const mediumSeverityIssues = issues.filter(issue => issue.severity === 'medium');

    if (highSeverityIssues.length > 0) {
      healthStatus = 'critical';
    } else if (mediumSeverityIssues.length > 0) {
      healthStatus = 'warning';
    }

    return { healthStatus, issues };
  }

  private processAlerts(streamName: string, newIssues: HealthIssue[]): void {
    const health = this.monitoredStreams.get(streamName);
    if (!health) {
      return;
    }

    // Get previous issues to detect new ones
    const previousIssues = health.issues.filter(issue => !issue.resolved);
    const resolvedIssues = previousIssues.filter(prevIssue => 
      !newIssues.some(newIssue => 
        newIssue.type === prevIssue.type && 
        newIssue.message === prevIssue.message
      )
    );

    // Mark resolved issues
    resolvedIssues.forEach(issue => {
      issue.resolved = true;
    });

    // Emit alerts for new issues
    newIssues.forEach(newIssue => {
      const isExistingIssue = previousIssues.some(prevIssue => 
        prevIssue.type === newIssue.type && 
        prevIssue.message === newIssue.message &&
        !prevIssue.resolved
      );

      if (!isExistingIssue) {
        this.emit('alert', {
          streamName,
          type: 'issue',
          severity: newIssue.severity,
          message: newIssue.message,
          timestamp: new Date()
        });
      }
    });

    // Emit resolution alerts
    resolvedIssues.forEach(resolvedIssue => {
      this.emit('alert', {
        streamName,
        type: 'resolution',
        severity: 'low',
        message: `Issue resolved: ${resolvedIssue.message}`,
        timestamp: new Date()
      });
    });
  }

  getStreamHealth(streamName: string): StreamHealth | undefined {
    return this.monitoredStreams.get(streamName);
  }

  getAllStreamHealth(): StreamHealth[] {
    return Array.from(this.monitoredStreams.values());
  }

  getSystemHealth(): {
    overall: 'good' | 'warning' | 'critical';
    streams: {
      total: number;
      healthy: number;
      warning: number;
      critical: number;
    };
    issues: {
      total: number;
      high: number;
      medium: number;
      low: number;
    };
  } {
    const allHealth = Array.from(this.monitoredStreams.values());
    
    const streams = {
      total: allHealth.length,
      healthy: allHealth.filter(h => h.health === 'good').length,
      warning: allHealth.filter(h => h.health === 'warning').length,
      critical: allHealth.filter(h => h.health === 'critical').length
    };

    const allIssues = allHealth.flatMap(h => h.issues);
    const issues = {
      total: allIssues.length,
      high: allIssues.filter(i => i.severity === 'high').length,
      medium: allIssues.filter(i => i.severity === 'medium').length,
      low: allIssues.filter(i => i.severity === 'low').length
    };

    let overall: 'good' | 'warning' | 'critical' = 'good';
    if (streams.critical > 0) {
      overall = 'critical';
    } else if (streams.warning > 0) {
      overall = 'warning';
    }

    return {
      overall,
      streams,
      issues
    };
  }

  updateMetrics(streamName: string, metrics: Partial<StreamMetrics>): void {
    const health = this.monitoredStreams.get(streamName);
    if (health) {
      health.metrics = { ...health.metrics, ...metrics };
    }
  }

  async runDiagnostics(streamName?: string): Promise<any> {
    const results: any = {
      timestamp: new Date(),
      diagnostics: []
    };

    const streamsToCheck = streamName 
      ? [this.monitoredStreams.get(streamName)].filter(Boolean)
      : Array.from(this.monitoredStreams.values());

    for (const health of streamsToCheck) {
      const diagnostic = {
        streamName: health.streamName,
        health: health.health,
        metrics: health.metrics,
        issues: health.issues,
        connectivity: await this.testConnectivity(health.streamName),
        performance: await this.testPerformance(health.streamName)
      };

      results.diagnostics.push(diagnostic);
    }

    return results;
  }

  private async testConnectivity(streamName: string): Promise<{
    status: 'connected' | 'disconnected' | 'error';
    latency: number;
    packetLoss: number;
  }> {
    // Simulate connectivity test
    return {
      status: Math.random() > 0.1 ? 'connected' : 'disconnected',
      latency: Math.random() * 100,
      packetLoss: Math.random() * 5
    };
  }

  private async testPerformance(streamName: string): Promise<{
    throughput: number;
    jitter: number;
    quality: 'excellent' | 'good' | 'fair' | 'poor';
  }> {
    // Simulate performance test
    const throughput = Math.random() * 1000000; // 0-1 Gbps
    const jitter = Math.random() * 50; // 0-50ms
    
    let quality: 'excellent' | 'good' | 'fair' | 'poor' = 'excellent';
    if (throughput < 100000) quality = 'poor';
    else if (throughput < 500000) quality = 'fair';
    else if (throughput < 800000) quality = 'good';

    return {
      throughput,
      jitter,
      quality
    };
  }

  updateConfig(config: Partial<MonitoringConfig>): void {
    this.config = { ...this.config, ...config };
    console.log('Stream Monitor configuration updated');
  }

  exportHealthData(): string {
    const data = {
      timestamp: new Date(),
      config: this.config,
      streams: Array.from(this.monitoredStreams.values()).map(health => ({
        ...health,
        lastCheck: health.lastCheck.toISOString(),
        issues: health.issues.map(issue => ({
          ...issue,
          timestamp: issue.timestamp.toISOString()
        }))
      }))
    };

    return JSON.stringify(data, null, 2);
  }
}