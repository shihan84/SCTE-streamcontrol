import { NextRequest, NextResponse } from 'next/server'

interface MonitoringMetrics {
  timestamp: string
  server_metrics: {
    cpu_usage: number
    memory_usage: number
    disk_usage: number
    network_in: number
    network_out: number
    uptime: number
    version: string
  }
  stream_metrics: {
    total_streams: number
    active_streams: number
    total_viewers: number
    total_bandwidth: number
    average_bitrate: number
    average_latency: number
  }
  scte35_metrics: {
    total_events: number
    events_last_hour: number
    events_last_24h: number
    successful_events: number
    failed_events: number
    average_response_time: number
  }
  ssai_metrics: {
    total_ad_insertions: number
    ad_insertions_last_hour: number
    successful_insertions: number
    failed_insertions: number
    fill_rate: number
    average_ad_duration: number
    ad_impressions: number
    ad_clicks: number
  }
  distributor_metrics: {
    total_distributors: number
    active_distributors: number
    compliance_score: number
    delivery_success_rate: number
    average_uptime: number
  }
  alerts: Alert[]
}

interface Alert {
  id: string
  type: 'server' | 'stream' | 'scte35' | 'ssai' | 'distributor' | 'quality'
  severity: 'low' | 'medium' | 'high' | 'critical'
  message: string
  description: string
  timestamp: string
  source: string
  resolved: boolean
  metadata: Record<string, any>
}

interface HealthStatus {
  overall: 'healthy' | 'warning' | 'critical'
  components: {
    server: 'healthy' | 'warning' | 'critical'
    streams: 'healthy' | 'warning' | 'critical'
    scte35: 'healthy' | 'warning' | 'critical'
    ssai: 'healthy' | 'warning' | 'critical'
    distributors: 'healthy' | 'warning' | 'critical'
  }
  issues: string[]
  last_check: string
}

interface DashboardData {
  metrics: MonitoringMetrics
  health: HealthStatus
  top_streams: StreamPerformance[]
  recent_alerts: Alert[]
  distributor_status: DistributorStatus[]
}

interface StreamPerformance {
  name: string
  status: 'active' | 'inactive' | 'error'
  viewers: number
  bitrate: number
  latency: number
  uptime: number
  scte35_events: number
  ssai_insertions: number
  health_score: number
}

interface DistributorStatus {
  id: string
  name: string
  status: 'active' | 'inactive' | 'warning' | 'error'
  streams_count: number
  compliance_score: number
  delivery_success_rate: number
  last_activity: string
  issues_count: number
}

// In-memory storage (in production, use database and time-series database)
let metricsHistory: MonitoringMetrics[] = []
let alerts: Alert[] = []
let alertIdCounter = 1

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const action = searchParams.get('action')
    const serverUrl = searchParams.get('serverUrl')
    const username = searchParams.get('username')
    const password = searchParams.get('password')
    const distributorId = searchParams.get('distributorId')
    const timeRange = searchParams.get('timeRange') || '1h'
    const limit = parseInt(searchParams.get('limit') || '100')

    if (action === 'dashboard') {
      const dashboardData = await generateDashboardData(serverUrl, username, password)
      
      return NextResponse.json({
        success: true,
        data: {
          dashboard: dashboardData,
          timestamp: new Date().toISOString()
        }
      })
    }

    if (action === 'metrics') {
      const metrics = await getCurrentMetrics(serverUrl, username, password)
      
      return NextResponse.json({
        success: true,
        data: {
          metrics,
          timestamp: new Date().toISOString()
        }
      })
    }

    if (action === 'health') {
      const health = await getHealthStatus(serverUrl, username, password)
      
      return NextResponse.json({
        success: true,
        data: {
          health,
          timestamp: new Date().toISOString()
        }
      })
    }

    if (action === 'alerts') {
      const recentAlerts = alerts.slice(0, limit)
      
      return NextResponse.json({
        success: true,
        data: {
          alerts: recentAlerts,
          total: alerts.length,
          timestamp: new Date().toISOString()
        }
      })
    }

    if (action === 'history') {
      const history = getMetricsHistory(timeRange, limit)
      
      return NextResponse.json({
        success: true,
        data: {
          history,
          timeRange,
          total: history.length,
          timestamp: new Date().toISOString()
        }
      })
    }

    if (action === 'distributor_metrics' && distributorId) {
      const distributorMetrics = await getDistributorMetrics(distributorId, serverUrl, username, password)
      
      return NextResponse.json({
        success: true,
        data: {
          distributorMetrics,
          distributorId,
          timestamp: new Date().toISOString()
        }
      })
    }

    if (action === 'stream_performance') {
      const streamPerformance = await getStreamPerformance(serverUrl, username, password)
      
      return NextResponse.json({
        success: true,
        data: {
          streams: streamPerformance,
          timestamp: new Date().toISOString()
        }
      })
    }

    return NextResponse.json(
      { success: false, error: 'Invalid action specified' },
      { status: 400 }
    )

  } catch (error) {
    console.error('Error in monitoring API:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to process monitoring request' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { action, serverUrl, username, password, alertConfig, testConfig } = body

    let result = {}

    switch (action) {
      case 'create_alert':
        if (!alertConfig) {
          return NextResponse.json(
            { success: false, error: 'Alert configuration is required' },
            { status: 400 }
          )
        }

        const newAlert: Alert = {
          id: `alert_${alertIdCounter++}`,
          type: alertConfig.type || 'server',
          severity: alertConfig.severity || 'medium',
          message: alertConfig.message,
          description: alertConfig.description || '',
          timestamp: new Date().toISOString(),
          source: alertConfig.source || 'system',
          resolved: false,
          metadata: alertConfig.metadata || {}
        }

        alerts.unshift(newAlert)

        result = {
          action: 'create_alert',
          alert: newAlert,
          success: true
        }
        break

      case 'resolve_alert':
        if (!alertConfig || !alertConfig.id) {
          return NextResponse.json(
            { success: false, error: 'Alert ID is required' },
            { status: 400 }
          )
        }

        const alertIndex = alerts.findIndex(a => a.id === alertConfig.id)
        if (alertIndex === -1) {
          return NextResponse.json(
            { success: false, error: 'Alert not found' },
            { status: 404 }
          )
        }

        alerts[alertIndex].resolved = true

        result = {
          action: 'resolve_alert',
          alert: alerts[alertIndex],
          success: true
        }
        break

      case 'test_connection':
        if (!serverUrl) {
          return NextResponse.json(
            { success: false, error: 'Server URL is required' },
            { status: 400 }
          )
        }

        const testResult = await testServerConnection(serverUrl, username, password)

        result = {
          action: 'test_connection',
          testResult,
          success: testResult.success
        }
        break

      case 'run_diagnostics':
        if (!serverUrl) {
          return NextResponse.json(
            { success: false, error: 'Server URL is required' },
            { status: 400 }
          )
        }

        const diagnostics = await runDiagnostics(serverUrl, username, password)

        result = {
          action: 'run_diagnostics',
          diagnostics,
          success: true
        }
        break

      case 'export_metrics':
        if (!testConfig || !testConfig.format) {
          return NextResponse.json(
            { success: false, error: 'Export format is required' },
            { status: 400 }
          )
        }

        const exportData = await exportMetrics(testConfig.format, testConfig.timeRange || '1h')

        result = {
          action: 'export_metrics',
          exportData,
          format: testConfig.format,
          success: true
        }
        break

      default:
        return NextResponse.json(
          { success: false, error: 'Invalid action specified' },
          { status: 400 }
        )
    }

    return NextResponse.json({
      success: true,
      result,
      timestamp: new Date().toISOString()
    })

  } catch (error) {
    console.error('Error executing monitoring action:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to execute monitoring action' },
      { status: 500 }
    )
  }
}

export async function PUT(request: NextRequest) {
  try {
    const body = await request.json()
    const { alertId, updates } = body

    if (!alertId || !updates) {
      return NextResponse.json(
        { success: false, error: 'Alert ID and updates are required' },
        { status: 400 }
      )
    }

    const alertIndex = alerts.findIndex(a => a.id === alertId)
    if (alertIndex === -1) {
      return NextResponse.json(
        { success: false, error: 'Alert not found' },
        { status: 404 }
      )
    }

    alerts[alertIndex] = { ...alerts[alertIndex], ...updates }

    return NextResponse.json({
      success: true,
      alert: alerts[alertIndex],
      timestamp: new Date().toISOString()
    })

  } catch (error) {
    console.error('Error updating alert:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to update alert' },
      { status: 500 }
    )
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const alertId = searchParams.get('alertId')

    if (!alertId) {
      return NextResponse.json(
        { success: false, error: 'Alert ID is required' },
        { status: 400 }
      )
    }

    const alertIndex = alerts.findIndex(a => a.id === alertId)
    if (alertIndex === -1) {
      return NextResponse.json(
        { success: false, error: 'Alert not found' },
        { status: 404 }
      )
    }

    const deletedAlert = alerts.splice(alertIndex, 1)[0]

    return NextResponse.json({
      success: true,
      alert: deletedAlert,
      timestamp: new Date().toISOString()
    })

  } catch (error) {
    console.error('Error deleting alert:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to delete alert' },
      { status: 500 }
    )
  }
}

async function generateDashboardData(serverUrl?: string, username?: string, password?: string): Promise<DashboardData> {
  const metrics = await getCurrentMetrics(serverUrl || '', username || '', password || '')
  const health = await getHealthStatus(serverUrl || '', username || '', password || '')
  const streamPerformance = await getStreamPerformance(serverUrl || '', username || '', password || '')
  const recentAlerts = alerts.slice(0, 10)
  
  // Mock distributor status (in production, fetch from distributor API)
  const distributorStatus: DistributorStatus[] = [
    {
      id: 'dist_1',
      name: 'Major Cable Network',
      status: 'active',
      streams_count: 5,
      compliance_score: 98.5,
      delivery_success_rate: 99.2,
      last_activity: new Date().toISOString(),
      issues_count: 0
    },
    {
      id: 'dist_2',
      name: 'Regional Broadcaster',
      status: 'warning',
      streams_count: 3,
      compliance_score: 92.1,
      delivery_success_rate: 95.8,
      last_activity: new Date(Date.now() - 300000).toISOString(),
      issues_count: 2
    }
  ]

  return {
    metrics,
    health,
    top_streams: streamPerformance.slice(0, 10),
    recent_alerts: recentAlerts,
    distributor_status: distributorStatus
  }
}

async function getCurrentMetrics(serverUrl?: string, username?: string, password?: string): Promise<MonitoringMetrics> {
  // Simulate fetching current metrics
  // In production, this would fetch from Flussonic API and other sources
  
  const metrics: MonitoringMetrics = {
    timestamp: new Date().toISOString(),
    server_metrics: {
      cpu_usage: 45.2,
      memory_usage: 67.8,
      disk_usage: 82.1,
      network_in: 1250000,
      network_out: 8500000,
      uptime: 86400,
      version: '24.12'
    },
    stream_metrics: {
      total_streams: 15,
      active_streams: 12,
      total_viewers: 45800,
      total_bandwidth: 85000000,
      average_bitrate: 4980,
      average_latency: 1800
    },
    scte35_metrics: {
      total_events: 1250,
      events_last_hour: 45,
      events_last_24h: 1250,
      successful_events: 1235,
      failed_events: 15,
      average_response_time: 120
    },
    ssai_metrics: {
      total_ad_insertions: 680,
      ad_insertions_last_hour: 28,
      successful_insertions: 665,
      failed_insertions: 15,
      fill_rate: 97.8,
      average_ad_duration: 30,
      ad_impressions: 12500,
      ad_clicks: 125
    },
    distributor_metrics: {
      total_distributors: 8,
      active_distributors: 7,
      compliance_score: 96.2,
      delivery_success_rate: 98.5,
      average_uptime: 99.8
    },
    alerts: alerts.slice(0, 5)
  }

  // Add to history
  metricsHistory.push(metrics)
  if (metricsHistory.length > 1000) {
    metricsHistory = metricsHistory.slice(-1000)
  }

  return metrics
}

async function getHealthStatus(serverUrl?: string, username?: string, password?: string): Promise<HealthStatus> {
  // Simulate health check
  const health: HealthStatus = {
    overall: 'healthy',
    components: {
      server: 'healthy',
      streams: 'healthy',
      scte35: 'healthy',
      ssai: 'warning',
      distributors: 'healthy'
    },
    issues: [
      'SSAI fill rate slightly below target (97.8%)',
      'High memory usage on server (67.8%)'
    ],
    last_check: new Date().toISOString()
  }

  return health
}

async function getStreamPerformance(serverUrl?: string, username?: string, password?: string): Promise<StreamPerformance[]> {
  // Simulate stream performance data
  const streams: StreamPerformance[] = [
    {
      name: 'channel_1',
      status: 'active',
      viewers: 12500,
      bitrate: 4980,
      latency: 1800,
      uptime: 86400,
      scte35_events: 125,
      ssai_insertions: 68,
      health_score: 98
    },
    {
      name: 'channel_2',
      status: 'active',
      viewers: 8900,
      bitrate: 4950,
      latency: 1900,
      uptime: 86400,
      scte35_events: 98,
      ssai_insertions: 52,
      health_score: 95
    },
    {
      name: 'channel_3',
      status: 'warning',
      viewers: 3200,
      bitrate: 4800,
      latency: 2500,
      uptime: 72000,
      scte35_events: 45,
      ssai_insertions: 28,
      health_score: 85
    }
  ]

  return streams
}

async function getDistributorMetrics(distributorId: string, serverUrl: string, username: string, password: string): Promise<any> {
  // Simulate distributor-specific metrics
  return {
    distributor_id: distributorId,
    metrics: {
      streams_count: 5,
      total_viewers: 25000,
      total_bandwidth: 45000000,
      scte35_events: 450,
      ssai_insertions: 225,
      compliance_score: 96.5,
      delivery_success_rate: 98.2,
      uptime_percentage: 99.7,
      average_latency: 1850
    },
    performance_trend: 'stable',
    last_updated: new Date().toISOString()
  }
}

function getMetricsHistory(timeRange: string, limit: number): MonitoringMetrics[] {
  // Filter metrics by time range
  const now = Date.now()
  let timeRangeMs: number

  switch (timeRange) {
    case '1h':
      timeRangeMs = 60 * 60 * 1000
      break
    case '24h':
      timeRangeMs = 24 * 60 * 60 * 1000
      break
    case '7d':
      timeRangeMs = 7 * 24 * 60 * 60 * 1000
      break
    default:
      timeRangeMs = 60 * 60 * 1000
  }

  const filtered = metricsHistory.filter(m => {
    const metricTime = new Date(m.timestamp).getTime()
    return (now - metricTime) <= timeRangeMs
  })

  return filtered.slice(-limit)
}

async function testServerConnection(serverUrl: string, username: string, password: string): Promise<any> {
  try {
    const normalizedUrl = serverUrl.endsWith('/') ? serverUrl.slice(0, -1) : serverUrl
    const authHeader = username && password 
      ? `Basic ${Buffer.from(`${username}:${password}`).toString('base64')}`
      : null

    const response = await fetch(`${normalizedUrl}/api/media-server/status`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        ...(authHeader && { 'Authorization': authHeader })
      },
      signal: AbortSignal.timeout(10000)
    })

    if (response.ok) {
      const serverInfo = await response.json()
      return {
        success: true,
        message: 'Connection successful',
        serverInfo,
        response_time: response.headers.get('x-response-time') || 'unknown'
      }
    } else {
      return {
        success: false,
        message: `Connection failed: ${response.status} ${response.statusText}`,
        error: response.statusText
      }
    }
  } catch (error) {
    return {
      success: false,
      message: `Connection error: ${error.message}`,
      error: error.message
    }
  }
}

async function runDiagnostics(serverUrl: string, username: string, password: string): Promise<any> {
  // Simulate comprehensive diagnostics
  return {
    timestamp: new Date().toISOString(),
    tests: [
      {
        name: 'Server Connectivity',
        status: 'pass',
        message: 'Successfully connected to Flussonic server',
        details: {
          response_time: '45ms',
          server_version: '24.12'
        }
      },
      {
        name: 'Stream Health',
        status: 'pass',
        message: 'All streams are healthy',
        details: {
          total_streams: 15,
          active_streams: 12,
          healthy_streams: 12
        }
      },
      {
        name: 'SCTE-35 Functionality',
        status: 'pass',
        message: 'SCTE-35 events are processing correctly',
        details: {
          events_last_hour: 45,
          success_rate: '98.8%'
        }
      },
      {
        name: 'SSAI Performance',
        status: 'warning',
        message: 'SSAI fill rate slightly below target',
        details: {
          fill_rate: '97.8%',
          target_rate: '98.0%',
          recommendations: ['Review ad inventory', 'Check fallback configuration']
        }
      }
    ],
    overall_status: 'warning',
    recommendations: [
      'Monitor SSAI performance closely',
      'Consider increasing ad inventory',
      'Review server resource usage'
    ]
  }
}

async function exportMetrics(format: string, timeRange: string): Promise<any> {
  const history = getMetricsHistory(timeRange, 1000)
  
  switch (format) {
    case 'json':
      return {
        format: 'json',
        data: history,
        filename: `metrics_${timeRange}_${Date.now()}.json`
      }
    
    case 'csv':
      // Convert to CSV format (simplified)
      const csvHeaders = [
        'timestamp',
        'cpu_usage',
        'memory_usage',
        'total_streams',
        'active_streams',
        'total_viewers',
        'scte35_events',
        'ssai_insertions'
      ]
      
      const csvRows = history.map(m => [
        m.timestamp,
        m.server_metrics.cpu_usage,
        m.server_metrics.memory_usage,
        m.stream_metrics.total_streams,
        m.stream_metrics.active_streams,
        m.stream_metrics.total_viewers,
        m.scte35_metrics.total_events,
        m.ssai_metrics.total_ad_insertions
      ])
      
      const csvContent = [csvHeaders.join(','), ...csvRows.map(row => row.join(','))].join('\n')
      
      return {
        format: 'csv',
        data: csvContent,
        filename: `metrics_${timeRange}_${Date.now()}.csv`
      }
    
    default:
      throw new Error('Unsupported export format')
  }
}