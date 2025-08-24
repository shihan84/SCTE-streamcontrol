import { NextRequest, NextResponse } from 'next/server'

interface DistributorConfig {
  id: string
  name: string
  contact_info: {
    email: string
    phone: string
    technical_contact: string
    support_contact: string
  }
  technical_requirements: {
    video_codec: string
    audio_codec: string
    resolution: string
    bitrate: number
    framerate: number
    keyframe_interval: number
    audio_channels: number
    audio_sample_rate: number
  }
  scte35_requirements: {
    enabled: boolean
    pid: number
    segmentation_types: string[]
    upid_format: string
    time_signal_format: string
    required_descriptors: string[]
  }
  ssai_requirements: {
    enabled: boolean
    ad_break_duration: number[]
    max_ads_per_break: number
    min_ad_duration: number
    max_ad_duration: number
    ad_formats: string[]
    tracking_requirements: {
      impression_tracking: boolean
      click_tracking: boolean
      quartile_tracking: boolean
      custom_tracking: boolean
    }
  }
  delivery_methods: {
    primary: 'srt' | 'rtmp' | 'hls' | 'udp'
    backup: 'srt' | 'rtmp' | 'hls' | 'udp'
    primary_endpoint: string
    backup_endpoint: string
    authentication: {
      type: 'none' | 'basic' | 'token' | 'certificate'
      credentials: Record<string, any>
    }
  }
  monitoring: {
    health_check_interval: number
    alert_thresholds: {
      bitrate_min: number
      bitrate_max: number
      latency_max: number
      packet_loss_max: number
    }
    notification_endpoints: string[]
  }
  compliance: {
    scte35_compliance: boolean
    ad_insertion_compliance: boolean
    quality_standards: string[]
    reporting_requirements: string[]
    audit_frequency: string
  }
  status: 'active' | 'inactive' | 'pending' | 'suspended'
  created_at: string
  updated_at: string
}

interface ComplianceReport {
  id: string
  distributor_id: string
  report_period: {
    start: string
    end: string
  }
  scte35_compliance: {
    total_events: number
    compliant_events: number
    non_compliant_events: number
    compliance_rate: number
    issues: ComplianceIssue[]
  }
  ssai_compliance: {
    total_ad_breaks: number
    successful_insertions: number
    failed_insertions: number
    fill_rate: number
    issues: ComplianceIssue[]
  }
  quality_metrics: {
    uptime_percentage: number
    average_bitrate: number
    average_latency: number
    packet_loss_rate: number
    error_rate: number
  }
  overall_score: number
  status: 'pass' | 'fail' | 'warning'
  generated_at: string
}

interface ComplianceIssue {
  id: string
  type: 'scte35' | 'ssai' | 'quality' | 'delivery'
  severity: 'low' | 'medium' | 'high' | 'critical'
  description: string
  timestamp: string
  affected_streams: string[]
  recommendation: string
  resolved: boolean
}

// In-memory storage (in production, use database)
let distributorConfigs: DistributorConfig[] = []
let complianceReports: ComplianceReport[] = []

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const action = searchParams.get('action')
    const distributorId = searchParams.get('distributorId')
    const limit = parseInt(searchParams.get('limit') || '50')
    const offset = parseInt(searchParams.get('offset') || '0')

    if (action === 'list_distributors') {
      const paginatedConfigs = distributorConfigs.slice(offset, offset + limit)
      
      return NextResponse.json({
        success: true,
        data: {
          distributors: paginatedConfigs,
          total: distributorConfigs.length,
          limit,
          offset,
          timestamp: new Date().toISOString()
        }
      })
    }

    if (action === 'get_distributor' && distributorId) {
      const distributor = distributorConfigs.find(d => d.id === distributorId)
      
      if (!distributor) {
        return NextResponse.json(
          { success: false, error: 'Distributor not found' },
          { status: 404 }
        )
      }

      return NextResponse.json({
        success: true,
        data: {
          distributor,
          timestamp: new Date().toISOString()
        }
      })
    }

    if (action === 'get_compliance_reports') {
      const reports = distributorId 
        ? complianceReports.filter(r => r.distributor_id === distributorId)
        : complianceReports

      const paginatedReports = reports.slice(offset, offset + limit)

      return NextResponse.json({
        success: true,
        data: {
          reports: paginatedReports,
          total: reports.length,
          limit,
          offset,
          timestamp: new Date().toISOString()
        }
      })
    }

    if (action === 'get_compliance_report' && distributorId) {
      const report = complianceReports.find(r => r.distributor_id === distributorId)
      
      if (!report) {
        return NextResponse.json(
          { success: false, error: 'Compliance report not found' },
          { status: 404 }
        )
      }

      return NextResponse.json({
        success: true,
        data: {
          report,
          timestamp: new Date().toISOString()
        }
      })
    }

    if (action === 'validate_config' && distributorId) {
      const distributor = distributorConfigs.find(d => d.id === distributorId)
      
      if (!distributor) {
        return NextResponse.json(
          { success: false, error: 'Distributor not found' },
          { status: 404 }
        )
      }

      const validation = validateDistributorConfig(distributor)

      return NextResponse.json({
        success: true,
        data: {
          validation,
          distributorId,
          timestamp: new Date().toISOString()
        }
      })
    }

    return NextResponse.json(
      { success: false, error: 'Invalid action specified' },
      { status: 400 }
    )

  } catch (error) {
    console.error('Error in distributor API:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to process distributor request' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { action, distributor, config } = body

    let result = {}

    switch (action) {
      case 'create_distributor':
        if (!distributor) {
          return NextResponse.json(
            { success: false, error: 'Distributor data is required' },
            { status: 400 }
          )
        }

        const validation = validateDistributorConfig(distributor)
        if (!validation.valid) {
          return NextResponse.json(
            { success: false, error: 'Invalid distributor configuration', validation },
            { status: 400 }
          )
        }

        const newDistributor: DistributorConfig = {
          id: `dist_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
          name: distributor.name,
          contact_info: distributor.contact_info,
          technical_requirements: distributor.technical_requirements,
          scte35_requirements: distributor.scte35_requirements,
          ssai_requirements: distributor.ssai_requirements,
          delivery_methods: distributor.delivery_methods,
          monitoring: distributor.monitoring,
          compliance: distributor.compliance,
          status: distributor.status || 'pending',
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        }

        distributorConfigs.push(newDistributor)

        result = {
          action: 'create_distributor',
          distributor: newDistributor,
          validation,
          success: true
        }
        break

      case 'update_distributor':
        if (!distributor || !distributor.id) {
          return NextResponse.json(
            { success: false, error: 'Distributor ID and data are required' },
            { status: 400 }
          )
        }

        const distributorIndex = distributorConfigs.findIndex(d => d.id === distributor.id)
        if (distributorIndex === -1) {
          return NextResponse.json(
            { success: false, error: 'Distributor not found' },
            { status: 404 }
          )
        }

        const updateValidation = validateDistributorConfig(distributor)
        if (!updateValidation.valid) {
          return NextResponse.json(
            { success: false, error: 'Invalid distributor configuration', updateValidation },
            { status: 400 }
          )
        }

        distributorConfigs[distributorIndex] = {
          ...distributorConfigs[distributorIndex],
          ...distributor,
          updated_at: new Date().toISOString()
        }

        result = {
          action: 'update_distributor',
          distributor: distributorConfigs[distributorIndex],
          validation: updateValidation,
          success: true
        }
        break

      case 'delete_distributor':
        if (!distributor || !distributor.id) {
          return NextResponse.json(
            { success: false, error: 'Distributor ID is required' },
            { status: 400 }
          )
        }

        const deleteIndex = distributorConfigs.findIndex(d => d.id === distributor.id)
        if (deleteIndex === -1) {
          return NextResponse.json(
            { success: false, error: 'Distributor not found' },
            { status: 404 }
          )
        }

        const deletedDistributor = distributorConfigs.splice(deleteIndex, 1)[0]

        // Also delete related compliance reports
        complianceReports = complianceReports.filter(r => r.distributor_id !== distributor.id)

        result = {
          action: 'delete_distributor',
          distributor: deletedDistributor,
          success: true
        }
        break

      case 'generate_compliance_report':
        if (!distributorId) {
          return NextResponse.json(
            { success: false, error: 'Distributor ID is required' },
            { status: 400 }
          )
        }

        const targetDistributor = distributorConfigs.find(d => d.id === distributorId)
        if (!targetDistributor) {
          return NextResponse.json(
            { success: false, error: 'Distributor not found' },
            { status: 404 }
          )
        }

        const report = await generateComplianceReport(targetDistributor)
        complianceReports.push(report)

        result = {
          action: 'generate_compliance_report',
          report,
          distributorId,
          success: true
        }
        break

      case 'test_delivery':
        if (!config || !config.distributorId || !config.streamName) {
          return NextResponse.json(
            { success: false, error: 'Distributor ID and stream name are required' },
            { status: 400 }
          )
        }

        const testDistributor = distributorConfigs.find(d => d.id === config.distributorId)
        if (!testDistributor) {
          return NextResponse.json(
            { success: false, error: 'Distributor not found' },
            { status: 404 }
          )
        }

        const testResult = await testDeliveryConfiguration(testDistributor, config.streamName, config)

        result = {
          action: 'test_delivery',
          testResult,
          distributorId: config.distributorId,
          streamName: config.streamName,
          success: testResult.success
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
    console.error('Error executing distributor action:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to execute distributor action' },
      { status: 500 }
    )
  }
}

export async function PUT(request: NextRequest) {
  try {
    const body = await request.json()
    const { distributorId, config } = body

    if (!distributorId || !config) {
      return NextResponse.json(
        { success: false, error: 'Distributor ID and configuration are required' },
        { status: 400 }
      )
    }

    const distributorIndex = distributorConfigs.findIndex(d => d.id === distributorId)
    if (distributorIndex === -1) {
      return NextResponse.json(
        { success: false, error: 'Distributor not found' },
        { status: 404 }
      )
    }

    const validation = validateDistributorConfig(config)
    if (!validation.valid) {
      return NextResponse.json(
        { success: false, error: 'Invalid distributor configuration', validation },
        { status: 400 }
      )
    }

    distributorConfigs[distributorIndex] = {
      ...distributorConfigs[distributorIndex],
      ...config,
      updated_at: new Date().toISOString()
    }

    return NextResponse.json({
      success: true,
      distributor: distributorConfigs[distributorIndex],
      validation,
      timestamp: new Date().toISOString()
    })

  } catch (error) {
    console.error('Error updating distributor configuration:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to update distributor configuration' },
      { status: 500 }
    )
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const distributorId = searchParams.get('distributorId')

    if (!distributorId) {
      return NextResponse.json(
        { success: false, error: 'Distributor ID is required' },
        { status: 400 }
      )
    }

    const distributorIndex = distributorConfigs.findIndex(d => d.id === distributorId)
    if (distributorIndex === -1) {
      return NextResponse.json(
        { success: false, error: 'Distributor not found' },
        { status: 404 }
      )
    }

    const deletedDistributor = distributorConfigs.splice(distributorIndex, 1)[0]

    // Also delete related compliance reports
    complianceReports = complianceReports.filter(r => r.distributor_id !== distributorId)

    return NextResponse.json({
      success: true,
      distributor: deletedDistributor,
      timestamp: new Date().toISOString()
    })

  } catch (error) {
    console.error('Error deleting distributor:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to delete distributor' },
      { status: 500 }
    )
  }
}

function validateDistributorConfig(config: any): { valid: boolean; errors: string[]; warnings: string[] } {
  const errors: string[] = []
  const warnings: string[] = []

  // Required fields validation
  if (!config.name || config.name.trim() === '') {
    errors.push('Distributor name is required')
  }

  if (!config.contact_info?.email) {
    errors.push('Contact email is required')
  }

  if (!config.technical_requirements?.video_codec) {
    errors.push('Video codec specification is required')
  }

  if (!config.technical_requirements?.audio_codec) {
    errors.push('Audio codec specification is required')
  }

  if (!config.delivery_methods?.primary) {
    errors.push('Primary delivery method is required')
  }

  // Email format validation
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  if (config.contact_info?.email && !emailRegex.test(config.contact_info.email)) {
    errors.push('Invalid email format')
  }

  // Technical requirements validation
  if (config.technical_requirements?.bitrate && (config.technical_requirements.bitrate < 1000 || config.technical_requirements.bitrate > 50000)) {
    warnings.push('Bitrate outside recommended range (1000-50000 kbps)')
  }

  if (config.technical_requirements?.framerate && (config.technical_requirements.framerate < 24 || config.technical_requirements.framerate > 60)) {
    warnings.push('Framerate outside recommended range (24-60 fps)')
  }

  // SCTE-35 validation
  if (config.scte35_requirements?.enabled && !config.scte35_requirements?.pid) {
    errors.push('SCTE-35 PID is required when SCTE-35 is enabled')
  }

  if (config.scte35_requirements?.pid && (config.scte35_requirements.pid < 1 || config.scte35_requirements.pid > 8190)) {
    errors.push('SCTE-35 PID must be between 1 and 8190')
  }

  // Delivery methods validation
  const validDeliveryMethods = ['srt', 'rtmp', 'hls', 'udp']
  if (config.delivery_methods?.primary && !validDeliveryMethods.includes(config.delivery_methods.primary)) {
    errors.push('Invalid primary delivery method')
  }

  if (config.delivery_methods?.backup && !validDeliveryMethods.includes(config.delivery_methods.backup)) {
    errors.push('Invalid backup delivery method')
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings
  }
}

async function generateComplianceReport(distributor: DistributorConfig): Promise<ComplianceReport> {
  // Simulate compliance report generation
  // In production, this would analyze actual stream data and SCTE-35 events
  
  const report: ComplianceReport = {
    id: `report_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
    distributor_id: distributor.id,
    report_period: {
      start: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
      end: new Date().toISOString()
    },
    scte35_compliance: {
      total_events: 150,
      compliant_events: 145,
      non_compliant_events: 5,
      compliance_rate: 96.7,
      issues: [
        {
          id: 'issue_1',
          type: 'scte35',
          severity: 'medium',
          description: 'Some events missing required descriptors',
          timestamp: new Date().toISOString(),
          affected_streams: ['channel_1', 'channel_2'],
          recommendation: 'Update SCTE-35 encoder configuration',
          resolved: false
        }
      ]
    },
    ssai_compliance: {
      total_ad_breaks: 75,
      successful_insertions: 72,
      failed_insertions: 3,
      fill_rate: 96.0,
      issues: [
        {
          id: 'issue_2',
          type: 'ssai',
          severity: 'low',
          description: 'Occasional ad fill rate below target',
          timestamp: new Date().toISOString(),
          affected_streams: ['channel_3'],
          recommendation: 'Increase ad inventory or adjust fill settings',
          resolved: false
        }
      ]
    },
    quality_metrics: {
      uptime_percentage: 99.8,
      average_bitrate: 4980,
      average_latency: 1800,
      packet_loss_rate: 0.02,
      error_rate: 0.01
    },
    overall_score: 96.3,
    status: 'pass',
    generated_at: new Date().toISOString()
  }

  return report
}

async function testDeliveryConfiguration(distributor: DistributorConfig, streamName: string, config: any): Promise<any> {
  // Simulate delivery configuration test
  // In production, this would actually test the delivery endpoints
  
  const testResult = {
    success: true,
    primary_endpoint: {
      reachable: true,
      latency: 45,
      bandwidth: 10000000,
      authentication: 'passed'
    },
    backup_endpoint: {
      reachable: true,
      latency: 52,
      bandwidth: 8000000,
      authentication: 'passed'
    },
    stream_configuration: {
      compatible: true,
      codec_supported: true,
      bitrate_within_range: true,
      resolution_supported: true
    },
    scte35_compatibility: {
      supported: true,
      pid_accepted: true,
      segmentation_types_supported: true
    },
    recommendations: [
      'Consider enabling redundant delivery for critical streams',
      'Monitor latency during peak hours'
    ],
    test_duration: 5000,
    timestamp: new Date().toISOString()
  }

  return testResult
}