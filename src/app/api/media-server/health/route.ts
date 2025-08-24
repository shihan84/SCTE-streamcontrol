import { NextRequest, NextResponse } from 'next/server';
import { MediaServer } from '@/lib/media-server/MediaServer';

// Global media server instance
let mediaServer: MediaServer | null = null;

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const streamName = searchParams.get('streamName');

    // Get media server instance
    if (!mediaServer) {
      return NextResponse.json({
        success: false,
        error: 'Media server is not running'
      }, { status: 400 });
    }

    let healthData;

    if (streamName) {
      // Get health for specific stream
      const stream = mediaServer.getStream(streamName);
      if (!stream) {
        return NextResponse.json({
          success: false,
          error: `Stream '${streamName}' not found`
        }, { status: 404 });
      }

      healthData = {
        streamName: stream.name,
        health: stream.health,
        metrics: stream.metrics,
        status: stream.status,
        uptime: stream.metrics.uptime,
        lastUpdate: new Date()
      };
    } else {
      // Get overall system health
      const serverStatus = mediaServer.getServerStatus();
      const streams = mediaServer.getAllStreams();
      
      const healthyStreams = streams.filter(s => s.health === 'good').length;
      const warningStreams = streams.filter(s => s.health === 'warning').length;
      const criticalStreams = streams.filter(s => s.health === 'critical').length;

      let overallHealth: 'good' | 'warning' | 'critical' = 'good';
      if (criticalStreams > 0) {
        overallHealth = 'critical';
      } else if (warningStreams > 0) {
        overallHealth = 'warning';
      }

      healthData = {
        overall: overallHealth,
        server: {
          isRunning: serverStatus.isRunning,
          uptime: serverStatus.uptime,
          streamCount: serverStatus.streamCount,
          totalViewers: serverStatus.totalViewers
        },
        streams: {
          total: streams.length,
          healthy: healthyStreams,
          warning: warningStreams,
          critical: criticalStreams
        },
        lastUpdate: new Date()
      };
    }

    return NextResponse.json({
      success: true,
      health: healthData,
      message: streamName 
        ? `Health data for stream '${streamName}' retrieved successfully`
        : 'System health data retrieved successfully'
    });

  } catch (error) {
    console.error('Error getting health data:', error);
    return NextResponse.json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    }, { status: 500 });
  }
}