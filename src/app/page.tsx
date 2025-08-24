/**
 * SCTE-35 Streaming Control Center
 * 
 * © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.
 * 
 * This software is the property of Morus Broadcasting Pvt Ltd and is protected by
 * copyright law and international treaties. Unauthorized use, reproduction, or
 * distribution is strictly prohibited.
 */

'use client'

import { useState, useEffect } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Switch } from '@/components/ui/switch'
import { Separator } from '@/components/ui/separator'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { useToast } from '@/hooks/use-toast'
import FFmpegStatus from '@/components/FFmpegStatus'
import { 
  Play, 
  Square, 
  Settings, 
  Monitor, 
  Calendar, 
  AlertTriangle, 
  CheckCircle,
  Clock,
  Radio,
  Tv,
  Volume2,
  Zap,
  Wifi,
  WifiOff,
  Download,
  Copy,
  Eye,
  Users,
  BarChart3,
  Shield,
  Database,
  FileText,
  TrendingUp,
  Activity,
  Building2,
  Truck,
  Target,
  Bell,
  RefreshCw,
  PlayCircle,
  PauseCircle,
  CheckSquare,
  XSquare,
  Terminal,
  Video,
  RadioIcon,
  RadioReceiver,
  Server,
  Cloud,
  Send,
  Plus,
  Save,
  Upload,
  DollarSign
} from 'lucide-react'

interface StreamConfig {
  serviceName: string
  videoResolution: string
  videoCodec: string
  pcr: string
  profileLevel: string
  gop: number
  bFrames: number
  videoBitrate: number
  chroma: string
  aspectRatio: string
  audioCodec: string
  audioBitrate: number
  audioLKFS: number
  audioSamplingRate: number
  scteDataPID: number
  nullPID: number
  latency: number
}

interface SCTEEvent {
  id: string
  eventId: number
  type: 'CUE-OUT' | 'CUE-IN'
  adDuration: number
  preRollDuration: number
  timestamp: Date
  status: 'pending' | 'active' | 'completed'
}

interface SCTE35Template {
  id: string
  name: string
  description: string
  adDuration: number
  eventId: number
  cueOutCommand: string
  cueInCommand: string
  crashOutCommand: string
  preRollDuration: number
  scteDataPid: number
  isDefault: boolean
  createdAt: Date
  lastUsed?: Date
}

interface StreamStatus {
  isLive: boolean
  viewers: number
  bitrate: number
  fps: number
  audioLevel: number
  latency: number
  health: 'good' | 'warning' | 'error'
  lastSCTEEvent: string | null
}

interface MediaServerConfig {
  type: 'self-hosted'
  serverUrl: string
  rtmpPort: number
  hlsPort: number
  scte35Pid: number
  streamName: string
  inputSource: string
  outputSettings: {
    hls: {
      enabled: boolean
      segmentDuration: number
      playlistLength: number
    }
    rtmp: {
      enabled: boolean
      port: number
    }
  }
}

interface SelfHostedStream {
  id: string
  name: string
  status: 'starting' | 'active' | 'stopping' | 'stopped' | 'error'
  config: any
  startTime?: Date
  viewers: number
  metrics: {
    bitrate: number
    fps: number
    audioLevel: number
    latency: number
    uptime: number
  }
  health: 'good' | 'warning' | 'error'
}

interface DistributorConfig {
  id: string
  name: string
  status: 'active' | 'inactive' | 'warning' | 'error'
  contact_info: {
    email: string
    phone: string
    technical_contact: string
  }
  streams_count: number
  compliance_score: number
  delivery_success_rate: number
  last_activity: string
  issues_count: number
}

interface MonitoringMetrics {
  server_metrics: {
    cpu_usage: number
    memory_usage: number
    disk_usage: number
    uptime: number
  }
  stream_metrics: {
    total_streams: number
    active_streams: number
    total_viewers: number
    total_bandwidth: number
  }
  scte35_metrics: {
    total_events: number
    events_last_hour: number
    success_rate: number
  }
  ssai_metrics: {
    total_ad_insertions: number
    fill_rate: number
    ad_impressions: number
  }
  distributor_metrics: {
    total_distributors: number
    active_distributors: number
    compliance_score: number
  }
}

interface AdSchedule {
  id: string
  name: string
  stream: string
  type: 'CUE-OUT' | 'BREAK' | 'PREROLL' | 'MIDROLL' | 'POSTROLL'
  duration: number
  preRoll: number
  enabled: boolean
  recurrence: {
    type: 'none' | 'daily' | 'weekly' | 'monthly' | 'hourly' | 'custom'
    interval?: number
    days?: number[]
    time?: string
    startDate?: string
    endDate?: string
    customCron?: string
  }
  restrictions: {
    maxPerHour?: number
    minInterval?: number
    blackoutPeriods?: Array<{
      start: string
      end: string
      reason: string
    }>
    contentRestrictions?: {
      noDuringLiveEvents?: boolean
      noDuringPrimetime?: boolean
      maxPerDay?: number
    }
  }
  targeting: {
    demographics?: string[]
    regions?: string[]
    devices?: string[]
    timezones?: string[]
  }
  metadata: {
    campaignId?: string
    advertiser?: string
    creativeId?: string
    upid?: string
    segmentationTypeId?: number
    segmentationMessage?: string
    providerId?: string
  }
  createdAt: string
  updatedAt: string
  lastTriggered?: string
  nextTrigger?: string
  triggerCount: number
  status: 'active' | 'paused' | 'expired' | 'error'
}

interface ScheduleExecution {
  id: string
  scheduleId: string
  scheduledTime: string
  actualTriggerTime?: string
  status: 'pending' | 'triggered' | 'completed' | 'failed' | 'skipped'
  result?: {
    success: boolean
    eventId?: string
    error?: string
  }
  retryCount: number
  maxRetries: number
}

export default function Home() {
  const { toast } = useToast()
  const [streamConfig, setStreamConfig] = useState<StreamConfig>({
    serviceName: 'Live TV Channel',
    videoResolution: '1920x1080',
    videoCodec: 'H.264',
    pcr: 'Video Embedded',
    profileLevel: 'High@Auto',
    gop: 12,
    bFrames: 5,
    videoBitrate: 5,
    chroma: '4:2:0',
    aspectRatio: '16:9',
    audioCodec: 'AAC-LC',
    audioBitrate: 128,
    audioLKFS: -20,
    audioSamplingRate: 48,
    scteDataPID: 500,
    nullPID: 8191,
    latency: 2000
  })

  const [streamStatus, setStreamStatus] = useState<StreamStatus>({
    isLive: false,
    viewers: 0,
    bitrate: 0,
    fps: 0,
    audioLevel: -20,
    latency: 0,
    health: 'good',
    lastSCTEEvent: null
  })

  const [scteEvents, setScteEvents] = useState<SCTEEvent[]>([])
  const [nextEventId, setNextEventId] = useState(100023)
  const [adDuration, setAdDuration] = useState(600)
  const [preRollDuration, setPreRollDuration] = useState(0)

  // SCTE-35 Templates
  const [scte35Templates, setScte35Templates] = useState<SCTE35Template[]>([
    {
      id: 'template_1',
      name: 'Standard Ad Break',
      description: 'Standard 10-minute commercial break with 2-second pre-roll',
      adDuration: 600,
      eventId: 100023,
      cueOutCommand: 'CUE-OUT',
      cueInCommand: 'CUE-IN',
      crashOutCommand: 'CUE-IN',
      preRollDuration: 2,
      scteDataPid: 500,
      isDefault: true,
      createdAt: new Date(),
      lastUsed: new Date()
    },
    {
      id: 'template_2',
      name: 'Short Break',
      description: '30-second commercial break with no pre-roll',
      adDuration: 30,
      eventId: 100024,
      cueOutCommand: 'CUE-OUT',
      cueInCommand: 'CUE-IN',
      crashOutCommand: 'CUE-IN',
      preRollDuration: 0,
      scteDataPid: 500,
      isDefault: false,
      createdAt: new Date()
    },
    {
      id: 'template_3',
      name: 'Extended Break',
      description: '15-minute extended commercial break with 5-second pre-roll',
      adDuration: 900,
      eventId: 100025,
      cueOutCommand: 'CUE-OUT',
      cueInCommand: 'CUE-IN',
      crashOutCommand: 'CUE-IN',
      preRollDuration: 5,
      scteDataPid: 500,
      isDefault: false,
      createdAt: new Date()
    }
  ])
  const [selectedTemplate, setSelectedTemplate] = useState<SCTE35Template | null>(null)
  const [showTemplateDialog, setShowTemplateDialog] = useState(false)
  const [editingTemplate, setEditingTemplate] = useState<Partial<SCTE35Template> | null>(null)

  // Media server configuration
  const [mediaServerConfig, setMediaServerConfig] = useState<MediaServerConfig>({
    type: 'self-hosted',
    serverUrl: 'http://localhost:8080',
    rtmpPort: 1935,
    hlsPort: 8080,
    scte35Pid: 500,
    streamName: 'livetv',
    inputSource: 'rtmp://localhost:1935/live',
    outputSettings: {
      hls: {
        enabled: true,
        segmentDuration: 2,
        playlistLength: 6
      },
      rtmp: {
        enabled: true,
        port: 1935
      }
    }
  })

  // Self-hosted media server state
  const [mediaServerConnection, setMediaServerConnection] = useState({
    isConnected: false,
    serverUrl: '',
    status: 'disconnected',
    streams: [] as SelfHostedStream[],
    uptime: 0
  })

  const [currentStream, setCurrentStream] = useState<SelfHostedStream | null>(null)

  const [showOBSConfig, setShowOBSConfig] = useState(false)
  const [obsConfig, setObsConfig] = useState<any>(null)

  // Distributor management state
  const [distributors, setDistributors] = useState<DistributorConfig[]>([])
  const [selectedDistributor, setSelectedDistributor] = useState<DistributorConfig | null>(null)
  const [showDistributorConfig, setShowDistributorConfig] = useState(false)
  const [editingDistributor, setEditingDistributor] = useState<DistributorConfig | null>(null)
  const [newDistributor, setNewDistributor] = useState<Partial<DistributorConfig>>({
    name: '',
    status: 'active',
    contact_info: {
      email: '',
      phone: '',
      technical_contact: ''
    },
    streams_count: 0,
    compliance_score: 95.0,
    delivery_success_rate: 98.0,
    last_activity: new Date().toISOString(),
    issues_count: 0
  })

  // Monitoring state
  const [monitoringMetrics, setMonitoringMetrics] = useState<MonitoringMetrics | null>(null)
  const [systemHealth, setSystemHealth] = useState<'healthy' | 'warning' | 'critical'>('healthy')
  const [alerts, setAlerts] = useState<any[]>([])

  // Ad Scheduler state
  const [adSchedules, setAdSchedules] = useState<AdSchedule[]>([])
  const [scheduleExecutions, setScheduleExecutions] = useState<ScheduleExecution[]>([])
  const [selectedSchedule, setSelectedSchedule] = useState<AdSchedule | null>(null)
  const [showScheduleForm, setShowScheduleForm] = useState(false)
  const [newSchedule, setNewSchedule] = useState<Partial<AdSchedule>>({
    name: '',
    stream: '',
    type: 'CUE-OUT',
    duration: 30,
    preRoll: 2,
    enabled: true,
    recurrence: {
      type: 'daily',
      interval: 1,
      time: '12:00',
      days: [1, 2, 3, 4, 5] // Monday to Friday
    },
    restrictions: {
      maxPerHour: 4,
      minInterval: 300,
      contentRestrictions: {
        maxPerDay: 24
      }
    },
    targeting: {},
    metadata: {}
  })

  // Multi-format streaming state
  const [multiFormatConfig, setMultiFormatConfig] = useState({
    name: '',
    sourceUrl: '',
    inputFormat: 'RTMP', // New field for input format selection
    inputSettings: {
      // RTMP settings
      rtmp: {
        enabled: true,
        port: 1935,
        chunkSize: 4096
      },
      // HLS settings
      hls: {
        enabled: false,
        playlistReloadInterval: 10,
        segmentDuration: 2
      },
      // SRT settings
      srt: {
        enabled: false,
        port: 9001,
        latency: 120,
        overheadBandwidth: 25,
        passphrase: ''
      }
    },
    outputFormats: [
      { format: 'HLS', enabled: true, settings: {}, url: '' },
      { format: 'DASH', enabled: false, settings: {}, url: '' },
      { format: 'SRT', enabled: false, settings: {}, url: '' },
      { format: 'RTMP', enabled: false, settings: {}, url: '' },
      { format: 'RTSP', enabled: false, settings: {}, url: '' }
    ],
    videoSettings: {
      codec: 'libx264',
      bitrate: 5,
      resolution: '1920x1080',
      framerate: '29.97',
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
        enabled: false,
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
      enabled: true,
      profiles: [
        {
          name: 'high',
          video: { codec: 'libx264', bitrate: 5, resolution: '1920x1080', framerate: '29.97' },
          audio: { codec: 'aac', bitrate: 128, sampleRate: 48000 }
        },
        {
          name: 'medium',
          video: { codec: 'libx264', bitrate: 2, resolution: '1280x720', framerate: '29.97' },
          audio: { codec: 'aac', bitrate: 96, sampleRate: 48000 }
        },
        {
          name: 'low',
          video: { codec: 'libx264', bitrate: 1, resolution: '854x480', framerate: '29.97' },
          audio: { codec: 'aac', bitrate: 64, sampleRate: 48000 }
        }
      ]
    }
  })

  const [multiFormatStreamStatus, setMultiFormatStreamStatus] = useState<'stopped' | 'starting' | 'active' | 'stopping' | 'error'>('stopped')
  const [multiFormatMetrics, setMultiFormatMetrics] = useState({
    viewers: 0,
    inputBitrate: 0,
    outputBitrate: 0,
    fps: 0,
    audioLevel: -20,
    latency: 0,
    uptime: 0,
    cpuUsage: 0,
    memoryUsage: 0
  })
  const [multiFormatOutputUrls, setMultiFormatOutputUrls] = useState<Record<string, string>>({})
  const [multiFormatSCTE35Events, setMultiFormatSCTE35Events] = useState<SCTEEvent[]>([])
  const [scte35EventType, setScte35EventType] = useState<'CUE-OUT' | 'CUE-IN'>('CUE-OUT')
  const [scte35EventDuration, setScte35EventDuration] = useState(30)
  const [scte35PreRoll, setScte35PreRoll] = useState(2)

  // Simulate stream status updates
  useEffect(() => {
    if (streamStatus.isLive) {
      const interval = setInterval(() => {
        setStreamStatus(prev => ({
          ...prev,
          viewers: Math.floor(Math.random() * 1000) + 100,
          bitrate: streamConfig.videoBitrate + (Math.random() - 0.5) * 0.5,
          fps: 29.97 + (Math.random() - 0.5) * 0.1,
          audioLevel: -20 + (Math.random() - 0.5) * 2,
          latency: streamConfig.latency + (Math.random() - 0.5) * 100
        }))
      }, 2000)

      return () => clearInterval(interval)
    }
  }, [streamStatus.isLive, streamConfig])

  // Simulate monitoring metrics updates
  useEffect(() => {
    const interval = setInterval(() => {
      if (mediaServerConnection.isConnected) {
        setMonitoringMetrics({
          server_metrics: {
            cpu_usage: 30 + Math.random() * 40,
            memory_usage: 40 + Math.random() * 30,
            disk_usage: 60 + Math.random() * 20,
            uptime: 86400 + Math.random() * 3600
          },
          stream_metrics: {
            total_streams: mediaServerConnection.streams.length,
            active_streams: mediaServerConnection.streams.filter(s => s.status === 'active').length,
            total_viewers: mediaServerConnection.streams.reduce((sum, s) => sum + s.viewers, 0),
            total_bandwidth: 50000000 + Math.random() * 100000000
          },
          scte35_metrics: {
            total_events: scteEvents.length,
            events_last_hour: 20 + Math.floor(Math.random() * 30),
            success_rate: 95 + Math.random() * 4
          },
          ssai_metrics: {
            total_ad_insertions: 500 + Math.floor(Math.random() * 200),
            fill_rate: 95 + Math.random() * 4,
            ad_impressions: 10000 + Math.floor(Math.random() * 5000)
          },
          distributor_metrics: {
            total_distributors: distributors.length,
            active_distributors: distributors.filter(d => d.status === 'active').length,
            compliance_score: 95 + Math.random() * 4
          }
        })

        // Update system health based on metrics
        const avgHealth = (
          (monitoringMetrics?.server_metrics.cpu_usage || 50) +
          (monitoringMetrics?.server_metrics.memory_usage || 50) +
          (monitoringMetrics?.scte35_metrics.success_rate || 95) +
          (monitoringMetrics?.ssai_metrics.fill_rate || 95)
        ) / 4

        if (avgHealth > 85) {
          setSystemHealth('healthy')
        } else if (avgHealth > 70) {
          setSystemHealth('warning')
        } else {
          setSystemHealth('critical')
        }
      }
    }, 5000)

    return () => clearInterval(interval)
  }, [mediaServerConnection.isConnected, monitoringMetrics, scteEvents.length, distributors])

  // Initialize sample distributors
  useEffect(() => {
    setDistributors([
      {
        id: 'dist_1',
        name: 'Major Cable Network',
        status: 'active',
        contact_info: {
          email: 'tech@majorcable.com',
          phone: '+1-555-0123',
          technical_contact: 'John Doe'
        },
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
        contact_info: {
          email: 'support@regional.tv',
          phone: '+1-555-0456',
          technical_contact: 'Jane Smith'
        },
        streams_count: 3,
        compliance_score: 92.1,
        delivery_success_rate: 95.8,
        last_activity: new Date(Date.now() - 300000).toISOString(),
        issues_count: 2
      }
    ])
  }, [])

  const sendSCTEEvent = async (type: 'CUE-OUT' | 'CUE-IN') => {
    if (!currentStream) {
      toast({
        title: "No Active Stream",
        description: "Please start a stream first",
        variant: "destructive"
      })
      return
    }

    try {
      const response = await fetch('/api/media-server/scte35/inject', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          type,
          streamId: currentStream.id,
          duration: type === 'CUE-OUT' ? adDuration : 0,
          preRoll: type === 'CUE-OUT' ? preRollDuration : 0,
          eventId: nextEventId
        }),
      })

      if (!response.ok) {
        throw new Error('Failed to send SCTE-35 event')
      }

      const event: SCTEEvent = {
        id: Date.now().toString(),
        eventId: nextEventId,
        type,
        adDuration: type === 'CUE-OUT' ? adDuration : 0,
        preRollDuration: type === 'CUE-OUT' ? preRollDuration : 0,
        timestamp: new Date(),
        status: type === 'CUE-OUT' ? 'active' : 'completed'
      }

      setScteEvents(prev => [event, ...prev])
      setNextEventId(prev => prev + 1)
      setStreamStatus(prev => ({ ...prev, lastSCTEEvent: type }))

      toast({
        title: `SCTE-35 ${type} Event Sent`,
        description: `Event ID: ${event.eventId}, Duration: ${event.adDuration}s`,
      })

      // Simulate event completion
      if (type === 'CUE-OUT') {
        setTimeout(() => {
          setScteEvents(prev => prev.map(e => 
            e.id === event.id ? { ...e, status: 'completed' } : e
          ))
        }, adDuration * 1000)
      }
    } catch (error) {
      toast({
        title: "Failed to Send Event",
        description: error instanceof Error ? error.message : "Unknown error",
        variant: "destructive"
      })
    }
  }

  // Template management functions
  const applyTemplate = (template: SCTE35Template) => {
    setAdDuration(template.adDuration)
    setPreRollDuration(template.preRollDuration)
    setNextEventId(template.eventId)
    setStreamConfig(prev => ({ ...prev, scteDataPID: template.scteDataPid }))
    setSelectedTemplate(template)
    
    // Update last used timestamp
    setScte35Templates(prev => 
      prev.map(t => 
        t.id === template.id 
          ? { ...t, lastUsed: new Date() }
          : t
      )
    )

    toast({
      title: "Template Applied",
      description: `Applied template: ${template.name}`,
    })
  }

  const saveTemplate = (templateData: Partial<SCTE35Template>) => {
    if (!templateData.name || !templateData.adDuration) {
      toast({
        title: "Invalid Template",
        description: "Template name and ad duration are required",
        variant: "destructive"
      })
      return
    }

    const newTemplate: SCTE35Template = {
      id: templateData.id || `template_${Date.now()}`,
      name: templateData.name,
      description: templateData.description || '',
      adDuration: templateData.adDuration,
      eventId: templateData.eventId || nextEventId,
      cueOutCommand: templateData.cueOutCommand || 'CUE-OUT',
      cueInCommand: templateData.cueInCommand || 'CUE-IN',
      crashOutCommand: templateData.crashOutCommand || 'CUE-IN',
      preRollDuration: templateData.preRollDuration || 0,
      scteDataPid: templateData.scteDataPid || 500,
      isDefault: templateData.isDefault || false,
      createdAt: templateData.id ? 
        scte35Templates.find(t => t.id === templateData.id)?.createdAt || new Date() : 
        new Date(),
      lastUsed: new Date()
    }

    if (templateData.id) {
      // Update existing template
      setScte35Templates(prev => 
        prev.map(t => t.id === templateData.id ? newTemplate : t)
      )
      toast({
        title: "Template Updated",
        description: `Updated template: ${newTemplate.name}`,
      })
    } else {
      // Add new template
      setScte35Templates(prev => [...prev, newTemplate])
      toast({
        title: "Template Created",
        description: `Created template: ${newTemplate.name}`,
      })
    }

    setEditingTemplate(null)
    setShowTemplateDialog(false)
  }

  const deleteTemplate = (templateId: string) => {
    setScte35Templates(prev => prev.filter(t => t.id !== templateId))
    if (selectedTemplate?.id === templateId) {
      setSelectedTemplate(null)
    }
    toast({
      title: "Template Deleted",
      description: "Template has been deleted",
    })
  }

  const duplicateTemplate = (template: SCTE35Template) => {
    const duplicate: SCTE35Template = {
      ...template,
      id: `template_${Date.now()}`,
      name: `${template.name} (Copy)`,
      isDefault: false,
      createdAt: new Date(),
      lastUsed: undefined
    }
    setScte35Templates(prev => [...prev, duplicate])
    toast({
      title: "Template Duplicated",
      description: `Created copy of: ${template.name}`,
    })
  }

  const startStream = async () => {
    try {
      const response = await fetch('/api/media-server/start', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          config: mediaServerConfig,
          streamConfig
        }),
      })

      if (!response.ok) {
        throw new Error('Failed to start stream')
      }

      const newStream: SelfHostedStream = {
        id: Date.now().toString(),
        name: streamConfig.serviceName,
        status: 'active',
        config: { ...mediaServerConfig, streamConfig },
        startTime: new Date(),
        viewers: 0,
        metrics: {
          bitrate: 0,
          fps: 0,
          audioLevel: -20,
          latency: 0,
          uptime: 0
        },
        health: 'good'
      }

      setCurrentStream(newStream)
      setMediaServerConnection(prev => ({
        ...prev,
        streams: [...prev.streams, newStream],
        isConnected: true
      }))
      setStreamStatus(prev => ({ ...prev, isLive: true }))

      toast({
        title: "Stream Started",
        description: `${streamConfig.serviceName} is now live`,
      })
    } catch (error) {
      toast({
        title: "Failed to Start Stream",
        description: error instanceof Error ? error.message : "Unknown error",
        variant: "destructive"
      })
    }
  }

  const stopStream = async () => {
    if (!currentStream) return

    try {
      const response = await fetch('/api/media-server/stop', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          streamId: currentStream.id
        }),
      })

      if (!response.ok) {
        throw new Error('Failed to stop stream')
      }

      setMediaServerConnection(prev => ({
        ...prev,
        streams: prev.streams.filter(s => s.id !== currentStream.id)
      }))
      setCurrentStream(null)
      setStreamStatus(prev => ({ ...prev, isLive: false }))

      toast({
        title: "Stream Stopped",
        description: `${streamConfig.serviceName} has been stopped`,
      })
    } catch (error) {
      toast({
        title: "Failed to Stop Stream",
        description: error instanceof Error ? error.message : "Unknown error",
        variant: "destructive"
      })
    }
  }

  const generateOBSConfig = async () => {
    try {
      const response = await fetch('/api/config/obs', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          serviceName: streamConfig.serviceName,
          videoResolution: streamConfig.videoResolution,
          videoCodec: streamConfig.videoCodec,
          profileLevel: streamConfig.profileLevel,
          gop: streamConfig.gop,
          bFrames: streamConfig.bFrames,
          videoBitrate: streamConfig.videoBitrate,
          chroma: streamConfig.chroma,
          aspectRatio: streamConfig.aspectRatio,
          audioCodec: streamConfig.audioCodec,
          audioBitrate: streamConfig.audioBitrate,
          audioLKFS: streamConfig.audioLKFS,
          audioSamplingRate: streamConfig.audioSamplingRate,
          scteDataPID: streamConfig.scteDataPID,
          nullPID: streamConfig.nullPID,
          latency: streamConfig.latency,
          serverUrl: `rtmp://localhost:${mediaServerConfig.rtmpPort}/live/${streamConfig.serviceName.toLowerCase().replace(/\s+/g, '_')}`
        }),
      })

      if (!response.ok) {
        throw new Error('Failed to generate OBS configuration')
      }

      const data = await response.json()
      setObsConfig(data.config)
      setShowOBSConfig(true)
      
      toast({
        title: "OBS Configuration Generated",
        description: "Configuration has been generated successfully",
      })
    } catch (error) {
      toast({
        title: "Failed to Generate Configuration",
        description: error instanceof Error ? error.message : "Unknown error",
        variant: "destructive"
      })
    }
  }

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text)
    toast({
      title: "Copied to Clipboard",
      description: "Configuration copied successfully",
    })
  }

  const connectToMediaServer = async () => {
    try {
      const response = await fetch('/api/media-server/status', {
        method: 'GET',
      })

      if (response.ok) {
        const data = await response.json()
        setMediaServerConnection(prev => ({
          ...prev,
          isConnected: true,
          serverUrl: mediaServerConfig.serverUrl,
          status: 'connected',
          uptime: data.uptime || 0
        }))

        toast({
          title: "Connected to Media Server",
          description: "Successfully connected to self-hosted media server",
        })
      } else {
        throw new Error('Failed to connect to media server')
      }
    } catch (error) {
      toast({
        title: "Connection Failed",
        description: error instanceof Error ? error.message : "Unknown error",
        variant: "destructive"
      })
    }
  }

  const formatDuration = (seconds: number) => {
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    const secs = seconds % 60
    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }

  const formatDate = (date: Date) => {
    return new Intl.DateTimeFormat('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    }).format(date)
  }

  const getHealthColor = (health: string) => {
    switch (health) {
      case 'good':
      case 'healthy':
      case 'active':
        return 'text-green-600'
      case 'warning':
        return 'text-yellow-600'
      case 'error':
      case 'critical':
        return 'text-red-600'
      default:
        return 'text-gray-600'
    }
  }

  const getStatusBadge = (status: string) => {
    const variant = status === 'good' || status === 'healthy' || status === 'active' ? 'default' : 
                   status === 'warning' ? 'secondary' : 'destructive'
    return <Badge variant={variant}>{status}</Badge>
  }

  // Multi-format streaming functions
  const startMultiFormatStream = async () => {
    if (!multiFormatConfig.name || !multiFormatConfig.sourceUrl) {
      toast({
        title: "Configuration Error",
        description: "Stream name and source URL are required",
        variant: "destructive"
      })
      return
    }

    try {
      setMultiFormatStreamStatus('starting')

      const response = await fetch('/api/stream/push/start', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(multiFormatConfig),
      })

      if (!response.ok) {
        throw new Error('Failed to start multi-format stream')
      }

      const result = await response.json()
      
      setMultiFormatStreamStatus('active')
      setMultiFormatOutputUrls(result.outputUrls || {})
      
      toast({
        title: "Multi-Format Stream Started",
        description: `Stream '${multiFormatConfig.name}' started successfully`,
      })

      // Start metrics simulation
      const metricsInterval = setInterval(() => {
        if (multiFormatStreamStatus === 'active') {
          setMultiFormatMetrics(prev => ({
            ...prev,
            viewers: Math.floor(Math.random() * 1000) + 100,
            inputBitrate: multiFormatConfig.videoSettings.bitrate + (Math.random() - 0.5) * 0.5,
            outputBitrate: multiFormatConfig.videoSettings.bitrate + (Math.random() - 0.5) * 0.5,
            fps: parseFloat(multiFormatConfig.videoSettings.framerate) + (Math.random() - 0.5) * 0.1,
            audioLevel: -20 + (Math.random() - 0.5) * 2,
            latency: 2000 + (Math.random() - 0.5) * 100,
            uptime: prev.uptime + 2,
            cpuUsage: Math.min(100, Math.max(0, prev.cpuUsage + (Math.random() - 0.5) * 5)),
            memoryUsage: Math.min(100, Math.max(0, prev.memoryUsage + (Math.random() - 0.5) * 3))
          }))
        }
      }, 2000)

      // Store interval ID for cleanup
      ;(window as any).multiFormatMetricsInterval = metricsInterval

    } catch (error) {
      setMultiFormatStreamStatus('error')
      toast({
        title: "Failed to Start Stream",
        description: error instanceof Error ? error.message : "Unknown error",
        variant: "destructive"
      })
    }
  }

  const stopMultiFormatStream = async () => {
    if (multiFormatStreamStatus !== 'active') {
      toast({
        title: "Stream Not Active",
        description: "No active multi-format stream to stop",
        variant: "destructive"
      })
      return
    }

    try {
      setMultiFormatStreamStatus('stopping')

      const response = await fetch('/api/stream/push/stop', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          streamName: multiFormatConfig.name
        }),
      })

      if (!response.ok) {
        throw new Error('Failed to stop multi-format stream')
      }

      // Clear metrics interval
      if ((window as any).multiFormatMetricsInterval) {
        clearInterval((window as any).multiFormatMetricsInterval)
      }

      setMultiFormatStreamStatus('stopped')
      setMultiFormatMetrics({
        viewers: 0,
        inputBitrate: 0,
        outputBitrate: 0,
        fps: 0,
        audioLevel: -20,
        latency: 0,
        uptime: 0,
        cpuUsage: 0,
        memoryUsage: 0
      })
      setMultiFormatOutputUrls({})
      
      toast({
        title: "Multi-Format Stream Stopped",
        description: `Stream '${multiFormatConfig.name}' stopped successfully`,
      })

    } catch (error) {
      setMultiFormatStreamStatus('error')
      toast({
        title: "Failed to Stop Stream",
        description: error instanceof Error ? error.message : "Unknown error",
        variant: "destructive"
      })
    }
  }

  const validateMultiFormatConfig = () => {
    const errors: string[] = []

    if (!multiFormatConfig.name.trim()) {
      errors.push("Stream name is required")
    }

    if (!multiFormatConfig.sourceUrl.trim()) {
      errors.push("Source URL is required")
    }

    // Input format validation
    if (!['RTMP', 'HLS', 'SRT'].includes(multiFormatConfig.inputFormat)) {
      errors.push("Invalid input format selected")
    }

    // Format-specific validation
    if (multiFormatConfig.inputFormat === 'RTMP') {
      if (multiFormatConfig.inputSettings.rtmp.port <= 0 || multiFormatConfig.inputSettings.rtmp.port > 65535) {
        errors.push("RTMP port must be between 1 and 65535")
      }
      if (multiFormatConfig.inputSettings.rtmp.chunkSize <= 0) {
        errors.push("RTMP chunk size must be positive")
      }
    }

    if (multiFormatConfig.inputFormat === 'HLS') {
      if (multiFormatConfig.inputSettings.hls.playlistReloadInterval <= 0) {
        errors.push("HLS playlist reload interval must be positive")
      }
      if (multiFormatConfig.inputSettings.hls.segmentDuration <= 0) {
        errors.push("HLS segment duration must be positive")
      }
    }

    if (multiFormatConfig.inputFormat === 'SRT') {
      if (multiFormatConfig.inputSettings.srt.port <= 0 || multiFormatConfig.inputSettings.srt.port > 65535) {
        errors.push("SRT port must be between 1 and 65535")
      }
      if (multiFormatConfig.inputSettings.srt.latency < 0) {
        errors.push("SRT latency cannot be negative")
      }
      if (multiFormatConfig.inputSettings.srt.overheadBandwidth < 0) {
        errors.push("SRT overhead bandwidth cannot be negative")
      }
    }

    const enabledFormats = multiFormatConfig.outputFormats.filter(f => f.enabled)
    if (enabledFormats.length === 0) {
      errors.push("At least one output format must be enabled")
    }

    if (multiFormatConfig.videoSettings.bitrate <= 0) {
      errors.push("Video bitrate must be positive")
    }

    if (multiFormatConfig.audioSettings.bitrate <= 0) {
      errors.push("Audio bitrate must be positive")
    }

    if (multiFormatConfig.scte35Settings.enabled) {
      if (multiFormatConfig.scte35Settings.pid <= 0 || multiFormatConfig.scte35Settings.pid > 8191) {
        errors.push("SCTE-35 PID must be between 1 and 8191")
      }
    }

    if (errors.length > 0) {
      toast({
        title: "Configuration Validation Failed",
        description: errors.join(", "),
        variant: "destructive"
      })
      return false
    }

    toast({
      title: "Configuration Valid",
      description: "Multi-format stream configuration is valid",
    })
    return true
  }

  const injectSCTE35Event = async () => {
    if (multiFormatStreamStatus !== 'active') {
      toast({
        title: "Stream Not Active",
        description: "Please start a multi-format stream first",
        variant: "destructive"
      })
      return
    }

    try {
      const response = await fetch('/api/stream/push/scte35', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          streamName: multiFormatConfig.name,
          type: scte35EventType,
          duration: scte35EventType === 'CUE-OUT' ? scte35EventDuration : 0,
          preRoll: scte35EventType === 'CUE-OUT' ? scte35PreRoll : 0,
          eventId: Date.now()
        }),
      })

      if (!response.ok) {
        throw new Error('Failed to inject SCTE-35 event')
      }

      const event: SCTEEvent = {
        id: Date.now().toString(),
        eventId: Date.now(),
        type: scte35EventType,
        adDuration: scte35EventType === 'CUE-OUT' ? scte35EventDuration : 0,
        preRollDuration: scte35EventType === 'CUE-OUT' ? scte35PreRoll : 0,
        timestamp: new Date(),
        status: scte35EventType === 'CUE-OUT' ? 'active' : 'completed'
      }

      setMultiFormatSCTE35Events(prev => [event, ...prev])

      toast({
        title: `SCTE-35 ${scte35EventType} Event Injected`,
        description: `Event ID: ${event.eventId}, Duration: ${event.adDuration}s`,
      })

      // Simulate event completion
      if (scte35EventType === 'CUE-OUT') {
        setTimeout(() => {
          setMultiFormatSCTE35Events(prev => prev.map(e => 
            e.id === event.id ? { ...e, status: 'completed' } : e
          ))
        }, scte35EventDuration * 1000)
      }

    } catch (error) {
      toast({
        title: "Failed to Inject Event",
        description: error instanceof Error ? error.message : "Unknown error",
        variant: "destructive"
      })
    }
  }

  const getSCTE35Events = async () => {
    try {
      const response = await fetch(`/api/stream/push/scte35?streamName=${encodeURIComponent(multiFormatConfig.name)}`)
      if (!response.ok) {
        throw new Error('Failed to fetch SCTE-35 events')
      }

      const events = await response.json()
      setMultiFormatSCTE35Events(events)

      toast({
        title: "SCTE-35 Events Refreshed",
        description: `Loaded ${events.length} events`,
      })

    } catch (error) {
      toast({
        title: "Failed to Refresh Events",
        description: error instanceof Error ? error.message : "Unknown error",
        variant: "destructive"
      })
    }
  }

  return (
    <div className="min-h-screen bg-background p-4">
      <div className="max-w-7xl mx-auto space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">SCTE-35 Streaming Control Center</h1>
            <p className="text-muted-foreground">Professional broadcast stream management with ad insertion</p>
          </div>
          <div className="flex items-center space-x-2">
            <Badge variant={systemHealth === 'healthy' ? 'default' : systemHealth === 'warning' ? 'secondary' : 'destructive'}>
              {systemHealth === 'healthy' ? <CheckCircle className="w-4 h-4 mr-1" /> : <AlertTriangle className="w-4 h-4 mr-1" />}
              System {systemHealth}
            </Badge>
            {mediaServerConnection.isConnected && (
              <Badge variant="outline">
                <Wifi className="w-4 h-4 mr-1" />
                Connected
              </Badge>
            )}
          </div>
        </div>

        {/* Main Content */}
        <Tabs defaultValue="stream-control" className="space-y-4">
          <TabsList className="grid w-full grid-cols-8">
            <TabsTrigger value="stream-control" className="flex items-center space-x-2">
              <Play className="w-4 h-4" />
              <span>Stream Control</span>
            </TabsTrigger>
            <TabsTrigger value="multi-format" className="flex items-center space-x-2">
              <Send className="w-4 h-4" />
              <span>Multi-Format</span>
            </TabsTrigger>
            <TabsTrigger value="scte35" className="flex items-center space-x-2">
              <Radio className="w-4 h-4" />
              <span>SCTE-35</span>
            </TabsTrigger>
            <TabsTrigger value="ssai" className="flex items-center space-x-2">
              <DollarSign className="w-4 h-4" />
              <span>SSAI</span>
            </TabsTrigger>
            <TabsTrigger value="monitoring" className="flex items-center space-x-2">
              <Monitor className="w-4 h-4" />
              <span>Monitor</span>
            </TabsTrigger>
            <TabsTrigger value="configuration" className="flex items-center space-x-2">
              <Settings className="w-4 h-4" />
              <span>Config</span>
            </TabsTrigger>
            <TabsTrigger value="distributors" className="flex items-center space-x-2">
              <Building2 className="w-4 h-4" />
              <span>Distributors</span>
            </TabsTrigger>
            <TabsTrigger value="scheduler" className="flex items-center space-x-2">
              <Calendar className="w-4 h-4" />
              <span>Scheduler</span>
            </TabsTrigger>
          </TabsList>

          {/* Stream Control Tab */}
          <TabsContent value="stream-control" className="space-y-4">
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
              {/* Stream Status */}
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center space-x-2">
                    <Tv className="w-5 h-5" />
                    <span>Stream Status</span>
                  </CardTitle>
                  <CardDescription>Current stream information</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-medium">Status</span>
                    {getStatusBadge(streamStatus.isLive ? 'Live' : 'Offline')}
                  </div>
                  
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-sm">Viewers</span>
                      <span className="text-sm font-medium">{streamStatus.viewers}</span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-sm">Bitrate</span>
                      <span className="text-sm font-medium">{streamStatus.bitrate.toFixed(2)} Mbps</span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-sm">FPS</span>
                      <span className="text-sm font-medium">{streamStatus.fps.toFixed(2)}</span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-sm">Audio Level</span>
                      <span className="text-sm font-medium">{streamStatus.audioLevel.toFixed(1)} dB</span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-sm">Latency</span>
                      <span className="text-sm font-medium">{streamStatus.latency.toFixed(0)} ms</span>
                    </div>
                  </div>

                  <div className="flex space-x-2">
                    <Button 
                      onClick={startStream} 
                      disabled={streamStatus.isLive}
                      className="flex-1"
                    >
                      <Play className="w-4 h-4 mr-2" />
                      Start
                    </Button>
                    <Button 
                      onClick={stopStream} 
                      disabled={!streamStatus.isLive}
                      variant="destructive"
                      className="flex-1"
                    >
                      <Square className="w-4 h-4 mr-2" />
                      Stop
                    </Button>
                  </div>

                  <Button 
                    onClick={generateOBSConfig}
                    variant="outline"
                    className="w-full"
                  >
                    <Download className="w-4 h-4 mr-2" />
                    Generate OBS Config
                  </Button>
                </CardContent>
              </Card>

              {/* Media Server Connection */}
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center space-x-2">
                    <Server className="w-5 h-5" />
                    <span>Media Server</span>
                  </CardTitle>
                  <CardDescription>Self-hosted media server connection</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-sm font-medium">Connection</span>
                      {mediaServerConnection.isConnected ? (
                        <Badge variant="default" className="flex items-center">
                          <Wifi className="w-3 h-3 mr-1" />
                          Connected
                        </Badge>
                      ) : (
                        <Badge variant="secondary" className="flex items-center">
                          <WifiOff className="w-3 h-3 mr-1" />
                          Disconnected
                        </Badge>
                      )}
                    </div>
                    
                    <div className="space-y-2">
                      <Label htmlFor="serverUrl">Server URL</Label>
                      <Input
                        id="serverUrl"
                        value={mediaServerConfig.serverUrl}
                        onChange={(e) => setMediaServerConfig(prev => ({ ...prev, serverUrl: e.target.value }))}
                        placeholder="http://localhost:8080"
                      />
                    </div>

                    <div className="grid grid-cols-2 gap-2">
                      <div>
                        <Label htmlFor="rtmpPort">RTMP Port</Label>
                        <Input
                          id="rtmpPort"
                          type="number"
                          value={mediaServerConfig.rtmpPort}
                          onChange={(e) => setMediaServerConfig(prev => ({ ...prev, rtmpPort: parseInt(e.target.value) }))}
                        />
                      </div>
                      <div>
                        <Label htmlFor="hlsPort">HLS Port</Label>
                        <Input
                          id="hlsPort"
                          type="number"
                          value={mediaServerConfig.hlsPort}
                          onChange={(e) => setMediaServerConfig(prev => ({ ...prev, hlsPort: parseInt(e.target.value) }))}
                        />
                      </div>
                    </div>

                    <div>
                      <Label htmlFor="streamName">Stream Name</Label>
                      <Input
                        id="streamName"
                        value={mediaServerConfig.streamName}
                        onChange={(e) => setMediaServerConfig(prev => ({ ...prev, streamName: e.target.value }))}
                      />
                    </div>
                  </div>

                  <Button 
                    onClick={connectToMediaServer}
                    disabled={mediaServerConnection.isConnected}
                    className="w-full"
                  >
                    <Wifi className="w-4 h-4 mr-2" />
                    Connect to Server
                  </Button>

                  {mediaServerConnection.isConnected && (
                    <div className="text-sm text-muted-foreground">
                      <p>Uptime: {formatDuration(mediaServerConnection.uptime)}</p>
                      <p>Active Streams: {mediaServerConnection.streams.filter(s => s.status === 'active').length}</p>
                    </div>
                  )}
                </CardContent>
              </Card>

              {/* Quick Actions */}
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center space-x-2">
                    <Zap className="w-5 h-5" />
                    <span>Quick Actions</span>
                  </CardTitle>
                  <CardDescription>Rapid stream controls</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="space-y-2">
                    <Button 
                      onClick={() => sendSCTEEvent('CUE-OUT')}
                      disabled={!streamStatus.isLive}
                      className="w-full"
                    >
                      <RadioIcon className="w-4 h-4 mr-2" />
                      Send CUE-OUT
                    </Button>
                    <Button 
                      onClick={() => sendSCTEEvent('CUE-IN')}
                      disabled={!streamStatus.isLive}
                      variant="outline"
                      className="w-full"
                    >
                      <RadioReceiver className="w-4 h-4 mr-2" />
                      Send CUE-IN
                    </Button>
                  </div>

                  <Separator />

                  <div className="space-y-2">
                    <Label htmlFor="adDuration">Ad Duration (seconds)</Label>
                    <Input
                      id="adDuration"
                      type="number"
                      value={adDuration}
                      onChange={(e) => setAdDuration(parseInt(e.target.value))}
                    />
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="preRollDuration">Pre-roll (seconds)</Label>
                    <Input
                      id="preRollDuration"
                      type="number"
                      value={preRollDuration}
                      onChange={(e) => setPreRollDuration(parseInt(e.target.value))}
                    />
                  </div>

                  <div className="text-sm text-muted-foreground">
                    <p>Next Event ID: {nextEventId}</p>
                    <p>Last Event: {streamStatus.lastSCTEEvent || 'None'}</p>
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* Active Streams */}
            {mediaServerConnection.streams.length > 0 && (
              <Card>
                <CardHeader>
                  <CardTitle>Active Streams</CardTitle>
                  <CardDescription>Currently running streams</CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    {mediaServerConnection.streams.map((stream) => (
                      <div key={stream.id} className="flex items-center justify-between p-4 border rounded-lg">
                        <div className="flex items-center space-x-4">
                          <div className={`w-3 h-3 rounded-full ${
                            stream.status === 'active' ? 'bg-green-500' :
                            stream.status === 'starting' ? 'bg-yellow-500' :
                            stream.status === 'error' ? 'bg-red-500' : 'bg-gray-500'
                          }`} />
                          <div>
                            <h4 className="font-medium">{stream.name}</h4>
                            <p className="text-sm text-muted-foreground">
                              {stream.startTime && `Started: ${formatDate(stream.startTime)}`}
                            </p>
                          </div>
                        </div>
                        <div className="flex items-center space-x-4">
                          <div className="text-right text-sm">
                            <p>{stream.viewers} viewers</p>
                            <p>{stream.metrics.bitrate.toFixed(2)} Mbps</p>
                          </div>
                          <Badge variant={stream.health === 'good' ? 'default' : stream.health === 'warning' ? 'secondary' : 'destructive'}>
                            {stream.health}
                          </Badge>
                        </div>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>
            )}
          </TabsContent>

          {/* Multi-Format Streaming Tab */}
          <TabsContent value="multi-format" className="space-y-4">
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
              {/* Stream Configuration */}
              <Card className="lg:col-span-2">
                <CardHeader>
                  <CardTitle className="flex items-center space-x-2">
                    <Send className="w-5 h-5" />
                    <span>Multi-Format Stream Push</span>
                  </CardTitle>
                  <CardDescription>
                    Configure and push live streams in multiple formats with SCTE-35 marker support
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="stream-name">Stream Name</Label>
                      <Input
                        id="stream-name"
                        placeholder="Enter stream name"
                        value={multiFormatConfig.name}
                        onChange={(e) => setMultiFormatConfig(prev => ({ ...prev, name: e.target.value }))}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="source-url">Source URL</Label>
                      <Input
                        id="source-url"
                        placeholder="rtmp://localhost:1935/live/test"
                        value={multiFormatConfig.sourceUrl}
                        onChange={(e) => setMultiFormatConfig(prev => ({ ...prev, sourceUrl: e.target.value }))}
                      />
                    </div>
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="input-format">Input Format</Label>
                    <Select value={multiFormatConfig.inputFormat} onValueChange={(value) => 
                      setMultiFormatConfig(prev => ({ 
                        ...prev, 
                        inputFormat: value,
                        // Update input settings based on selected format
                        inputSettings: {
                          ...prev.inputSettings,
                          rtmp: { ...prev.inputSettings.rtmp, enabled: value === 'RTMP' },
                          hls: { ...prev.inputSettings.hls, enabled: value === 'HLS' },
                          srt: { ...prev.inputSettings.srt, enabled: value === 'SRT' }
                        }
                      }))
                    }>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="RTMP">Real-Time Messaging Protocol (RTMP)</SelectItem>
                        <SelectItem value="HLS">HTTP Live Streaming (HLS)</SelectItem>
                        <SelectItem value="SRT">Secure Reliable Transport (SRT)</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>

                  {/* Input Format Settings */}
                  {multiFormatConfig.inputFormat === 'RTMP' && (
                    <div className="space-y-4 p-4 bg-gray-50 rounded-lg">
                      <h4 className="text-sm font-medium">RTMP Input Settings</h4>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="space-y-2">
                          <Label htmlFor="rtmp-port">RTMP Port</Label>
                          <Input
                            id="rtmp-port"
                            type="number"
                            value={multiFormatConfig.inputSettings.rtmp.port}
                            onChange={(e) => setMultiFormatConfig(prev => ({
                              ...prev,
                              inputSettings: {
                                ...prev.inputSettings,
                                rtmp: { ...prev.inputSettings.rtmp, port: parseInt(e.target.value) || 1935 }
                              }
                            }))}
                          />
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="rtmp-chunk-size">Chunk Size</Label>
                          <Input
                            id="rtmp-chunk-size"
                            type="number"
                            value={multiFormatConfig.inputSettings.rtmp.chunkSize}
                            onChange={(e) => setMultiFormatConfig(prev => ({
                              ...prev,
                              inputSettings: {
                                ...prev.inputSettings,
                                rtmp: { ...prev.inputSettings.rtmp, chunkSize: parseInt(e.target.value) || 4096 }
                              }
                            }))}
                          />
                        </div>
                      </div>
                    </div>
                  )}

                  {multiFormatConfig.inputFormat === 'HLS' && (
                    <div className="space-y-4 p-4 bg-gray-50 rounded-lg">
                      <h4 className="text-sm font-medium">HLS Input Settings</h4>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="space-y-2">
                          <Label htmlFor="hls-reload-interval">Playlist Reload Interval (seconds)</Label>
                          <Input
                            id="hls-reload-interval"
                            type="number"
                            value={multiFormatConfig.inputSettings.hls.playlistReloadInterval}
                            onChange={(e) => setMultiFormatConfig(prev => ({
                              ...prev,
                              inputSettings: {
                                ...prev.inputSettings,
                                hls: { ...prev.inputSettings.hls, playlistReloadInterval: parseInt(e.target.value) || 10 }
                              }
                            }))}
                          />
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="hls-segment-duration">Segment Duration (seconds)</Label>
                          <Input
                            id="hls-segment-duration"
                            type="number"
                            value={multiFormatConfig.inputSettings.hls.segmentDuration}
                            onChange={(e) => setMultiFormatConfig(prev => ({
                              ...prev,
                              inputSettings: {
                                ...prev.inputSettings,
                                hls: { ...prev.inputSettings.hls, segmentDuration: parseInt(e.target.value) || 2 }
                              }
                            }))}
                          />
                        </div>
                      </div>
                    </div>
                  )}

                  {multiFormatConfig.inputFormat === 'SRT' && (
                    <div className="space-y-4 p-4 bg-gray-50 rounded-lg">
                      <h4 className="text-sm font-medium">SRT Input Settings</h4>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="space-y-2">
                          <Label htmlFor="srt-port">SRT Port</Label>
                          <Input
                            id="srt-port"
                            type="number"
                            value={multiFormatConfig.inputSettings.srt.port}
                            onChange={(e) => setMultiFormatConfig(prev => ({
                              ...prev,
                              inputSettings: {
                                ...prev.inputSettings,
                                srt: { ...prev.inputSettings.srt, port: parseInt(e.target.value) || 9001 }
                              }
                            }))}
                          />
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="srt-latency">Latency (ms)</Label>
                          <Input
                            id="srt-latency"
                            type="number"
                            value={multiFormatConfig.inputSettings.srt.latency}
                            onChange={(e) => setMultiFormatConfig(prev => ({
                              ...prev,
                              inputSettings: {
                                ...prev.inputSettings,
                                srt: { ...prev.inputSettings.srt, latency: parseInt(e.target.value) || 120 }
                              }
                            }))}
                          />
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="srt-overhead">Overhead Bandwidth (%)</Label>
                          <Input
                            id="srt-overhead"
                            type="number"
                            value={multiFormatConfig.inputSettings.srt.overheadBandwidth}
                            onChange={(e) => setMultiFormatConfig(prev => ({
                              ...prev,
                              inputSettings: {
                                ...prev.inputSettings,
                                srt: { ...prev.inputSettings.srt, overheadBandwidth: parseInt(e.target.value) || 25 }
                              }
                            }))}
                          />
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="srt-passphrase">Passphrase</Label>
                          <Input
                            id="srt-passphrase"
                            type="password"
                            value={multiFormatConfig.inputSettings.srt.passphrase}
                            onChange={(e) => setMultiFormatConfig(prev => ({
                              ...prev,
                              inputSettings: {
                                ...prev.inputSettings,
                                srt: { ...prev.inputSettings.srt, passphrase: e.target.value }
                              }
                            }))}
                          />
                        </div>
                      </div>
                    </div>
                  )}

                  <div className="space-y-2">
                    <Label>Output Formats</Label>
                    <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
                      {[
                        { id: 'HLS', name: 'HTTP Live Streaming', icon: '🌐' },
                        { id: 'DASH', name: 'MPEG-DASH', icon: '📊' },
                        { id: 'SRT', name: 'Secure Reliable Transport', icon: '🔒' },
                        { id: 'RTMP', name: 'Real-Time Messaging Protocol', icon: '📡' },
                        { id: 'RTSP', name: 'Real-Time Streaming Protocol', icon: '🎥' }
                      ].map((format) => (
                        <div key={format.id} className="flex items-center space-x-2 p-2 border rounded">
                          <Switch
                            checked={multiFormatConfig.outputFormats.find(f => f.format === format.id)?.enabled || false}
                            onCheckedChange={(checked) => {
                              setMultiFormatConfig(prev => ({
                                ...prev,
                                outputFormats: prev.outputFormats.map(f => 
                                  f.format === format.id ? { ...f, enabled: checked } : f
                                )
                              }))
                            }}
                          />
                          <span className="text-sm">{format.icon} {format.name}</span>
                        </div>
                      ))}
                    </div>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="video-codec">Video Codec</Label>
                      <Select value={multiFormatConfig.videoSettings.codec} onValueChange={(value) => 
                        setMultiFormatConfig(prev => ({ ...prev, videoSettings: { ...prev.videoSettings, codec: value } }))
                      }>
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="libx264">H.264</SelectItem>
                          <SelectItem value="libx265">H.265</SelectItem>
                          <SelectItem value="libvpx-vp9">VP9</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="video-bitrate">Video Bitrate (Mbps)</Label>
                      <Input
                        id="video-bitrate"
                        type="number"
                        value={multiFormatConfig.videoSettings.bitrate}
                        onChange={(e) => setMultiFormatConfig(prev => ({ 
                          ...prev, 
                          videoSettings: { ...prev.videoSettings, bitrate: parseInt(e.target.value) || 5 }
                        }))}
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="audio-codec">Audio Codec</Label>
                      <Select value={multiFormatConfig.audioSettings.codec} onValueChange={(value) => 
                        setMultiFormatConfig(prev => ({ ...prev, audioSettings: { ...prev.audioSettings, codec: value } }))
                      }>
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="aac">AAC</SelectItem>
                          <SelectItem value="libmp3lame">MP3</SelectItem>
                          <SelectItem value="libopus">Opus</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="audio-bitrate">Audio Bitrate (kbps)</Label>
                      <Input
                        id="audio-bitrate"
                        type="number"
                        value={multiFormatConfig.audioSettings.bitrate}
                        onChange={(e) => setMultiFormatConfig(prev => ({ 
                          ...prev, 
                          audioSettings: { ...prev.audioSettings, bitrate: parseInt(e.target.value) || 128 }
                        }))}
                      />
                    </div>
                  </div>

                  <div className="flex items-center space-x-2">
                    <Switch
                      id="scte35-enabled"
                      checked={multiFormatConfig.scte35Settings.enabled}
                      onCheckedChange={(checked) => 
                        setMultiFormatConfig(prev => ({ 
                          ...prev, 
                          scte35Settings: { ...prev.scte35Settings, enabled: checked }
                        }))
                      }
                    />
                    <Label htmlFor="scte35-enabled">Enable SCTE-35 Markers</Label>
                  </div>

                  {multiFormatConfig.scte35Settings.enabled && (
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4 p-4 bg-gray-50 rounded">
                      <div className="space-y-2">
                        <Label htmlFor="scte35-pid">SCTE-35 PID</Label>
                        <Input
                          id="scte35-pid"
                          type="number"
                          value={multiFormatConfig.scte35Settings.pid}
                          onChange={(e) => setMultiFormatConfig(prev => ({ 
                            ...prev, 
                            scte35Settings: { ...prev.scte35Settings, pid: parseInt(e.target.value) || 500 }
                          }))}
                        />
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="auto-insert">Auto Insert</Label>
                        <Switch
                          id="auto-insert"
                          checked={multiFormatConfig.scte35Settings.autoInsert}
                          onCheckedChange={(checked) => 
                            setMultiFormatConfig(prev => ({ 
                              ...prev, 
                              scte35Settings: { ...prev.scte35Settings, autoInsert: checked }
                            }))
                          }
                        />
                      </div>
                    </div>
                  )}

                  <div className="flex space-x-2">
                    <Button
                      onClick={startMultiFormatStream}
                      disabled={!multiFormatConfig.name || !multiFormatConfig.sourceUrl}
                      className="flex items-center space-x-2"
                    >
                      <Play className="w-4 h-4" />
                      <span>Start Stream</span>
                    </Button>
                    <Button
                      onClick={stopMultiFormatStream}
                      variant="outline"
                      className="flex items-center space-x-2"
                    >
                      <Square className="w-4 h-4" />
                      <span>Stop Stream</span>
                    </Button>
                    <Button
                      onClick={validateMultiFormatConfig}
                      variant="outline"
                      className="flex items-center space-x-2"
                    >
                      <CheckCircle className="w-4 h-4" />
                      <span>Validate</span>
                    </Button>
                  </div>
                </CardContent>
              </Card>

              {/* Stream Status */}
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center space-x-2">
                    <Activity className="w-5 h-5" />
                    <span>Stream Status</span>
                  </CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="space-y-2">
                    <div className="flex justify-between items-center">
                      <span className="text-sm font-medium">Status</span>
                      <Badge variant={multiFormatStreamStatus === 'active' ? 'default' : 'secondary'}>
                        {multiFormatStreamStatus}
                      </Badge>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm font-medium">Viewers</span>
                      <span className="text-sm">{multiFormatMetrics.viewers}</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm font-medium">Input Bitrate</span>
                      <span className="text-sm">{multiFormatMetrics.inputBitrate.toFixed(1)} Mbps</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm font-medium">Output Bitrate</span>
                      <span className="text-sm">{multiFormatMetrics.outputBitrate.toFixed(1)} Mbps</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm font-medium">FPS</span>
                      <span className="text-sm">{multiFormatMetrics.fps.toFixed(1)}</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm font-medium">Latency</span>
                      <span className="text-sm">{multiFormatMetrics.latency.toFixed(0)} ms</span>
                    </div>
                  </div>

                  <Separator />

                  <div className="space-y-2">
                    <Label className="text-sm font-medium">Output URLs</Label>
                    <div className="space-y-1">
                      {Object.entries(multiFormatOutputUrls).map(([format, url]) => (
                        <div key={format} className="flex items-center justify-between p-2 bg-gray-50 rounded text-xs">
                          <span className="font-medium">{format}</span>
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => navigator.clipboard.writeText(url)}
                            className="h-6 w-6 p-0"
                          >
                            <Copy className="w-3 h-3" />
                          </Button>
                        </div>
                      ))}
                    </div>
                  </div>

                  <Separator />

                  <div className="space-y-2">
                    <Label className="text-sm font-medium">SCTE-35 Events</Label>
                    <div className="space-y-1">
                      {multiFormatSCTE35Events.length > 0 ? (
                        multiFormatSCTE35Events.slice(-3).map((event) => (
                          <div key={event.id} className="flex items-center justify-between p-2 bg-gray-50 rounded text-xs">
                            <span>{event.type}</span>
                            <Badge variant={event.status === 'active' ? 'default' : 'secondary'}>
                              {event.status}
                            </Badge>
                          </div>
                        ))
                      ) : (
                        <div className="text-xs text-gray-500 text-center p-2">
                          No SCTE-35 events
                        </div>
                      )}
                    </div>
                  </div>
                </CardContent>
              </Card>

              {/* FFmpeg Status */}
              <FFmpegStatus />
            </div>

            {/* SCTE-35 Control */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center space-x-2">
                  <Radio className="w-5 h-5" />
                  <span>SCTE-35 Marker Control</span>
                </CardTitle>
                <CardDescription>
                  Inject SCTE-35 markers into the multi-format stream
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="event-type">Event Type</Label>
                    <Select value={scte35EventType} onValueChange={(value: 'CUE-OUT' | 'CUE-IN') => setScte35EventType(value)}>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="CUE-OUT">CUE-OUT (Ad Start)</SelectItem>
                        <SelectItem value="CUE-IN">CUE-IN (Ad End)</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="event-duration">Duration (seconds)</Label>
                    <Input
                      id="event-duration"
                      type="number"
                      value={scte35EventDuration}
                      onChange={(e) => setScte35EventDuration(parseInt(e.target.value) || 30)}
                      disabled={scte35EventType === 'CUE-IN'}
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <Label htmlFor="pre-roll">Pre-roll Duration (seconds)</Label>
                  <Input
                    id="pre-roll"
                    type="number"
                    value={scte35PreRoll}
                    onChange={(e) => setScte35PreRoll(parseInt(e.target.value) || 2)}
                    disabled={scte35EventType === 'CUE-IN'}
                  />
                </div>

                <div className="flex space-x-2">
                  <Button
                    onClick={injectSCTE35Event}
                    disabled={multiFormatStreamStatus !== 'active'}
                    className="flex items-center space-x-2"
                  >
                    <Radio className="w-4 h-4" />
                    <span>Inject {scte35EventType}</span>
                  </Button>
                  <Button
                    onClick={getSCTE35Events}
                    variant="outline"
                    className="flex items-center space-x-2"
                  >
                    <RefreshCw className="w-4 h-4" />
                    <span>Refresh Events</span>
                  </Button>
                </div>

                <div className="space-y-2">
                  <Label className="text-sm font-medium">Recent Events</Label>
                  <div className="space-y-1 max-h-32 overflow-y-auto">
                    {multiFormatSCTE35Events.length > 0 ? (
                      multiFormatSCTE35Events.slice(-5).map((event) => (
                        <div key={event.id} className="flex items-center justify-between p-2 bg-gray-50 rounded text-xs">
                          <div>
                            <span className="font-medium">{event.type}</span>
                            <span className="text-gray-500 ml-2">
                              {new Date(event.timestamp).toLocaleTimeString()}
                            </span>
                          </div>
                          <Badge variant={event.status === 'active' ? 'default' : 'secondary'}>
                            {event.status}
                          </Badge>
                        </div>
                      ))
                    ) : (
                      <div className="text-xs text-gray-500 text-center p-2">
                        No SCTE-35 events
                      </div>
                    )}
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          {/* SCTE-35 Tab */}
          <TabsContent value="scte35" className="space-y-4">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
              {/* SCTE-35 Controls */}
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center space-x-2">
                    <Radio className="w-5 h-5" />
                    <span>SCTE-35 Controls</span>
                  </CardTitle>
                  <CardDescription>Ad insertion event management</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <Button 
                      onClick={() => sendSCTEEvent('CUE-OUT')}
                      disabled={!streamStatus.isLive}
                      className="h-20"
                    >
                      <div className="text-center">
                        <RadioIcon className="w-6 h-6 mx-auto mb-2" />
                        <div>CUE-OUT</div>
                        <div className="text-xs opacity-70">Start Ad Break</div>
                      </div>
                    </Button>
                    <Button 
                      onClick={() => sendSCTEEvent('CUE-IN')}
                      disabled={!streamStatus.isLive}
                      variant="outline"
                      className="h-20"
                    >
                      <div className="text-center">
                        <RadioReceiver className="w-6 h-6 mx-auto mb-2" />
                        <div>CUE-IN</div>
                        <div className="text-xs opacity-70">End Ad Break</div>
                      </div>
                    </Button>
                  </div>

                  <Separator />

                  <div className="space-y-4">
                    <div className="space-y-2">
                      <Label htmlFor="scteAdDuration">Ad Break Duration</Label>
                      <div className="flex items-center space-x-2">
                        <Input
                          id="scteAdDuration"
                          type="number"
                          value={adDuration}
                          onChange={(e) => setAdDuration(parseInt(e.target.value))}
                          className="flex-1"
                        />
                        <span className="text-sm text-muted-foreground">seconds</span>
                      </div>
                    </div>

                    <div className="space-y-2">
                      <Label htmlFor="sctePreRoll">Pre-roll Duration</Label>
                      <div className="flex items-center space-x-2">
                        <Input
                          id="sctePreRoll"
                          type="number"
                          value={preRollDuration}
                          onChange={(e) => setPreRollDuration(parseInt(e.target.value))}
                          className="flex-1"
                        />
                        <span className="text-sm text-muted-foreground">seconds</span>
                      </div>
                    </div>

                    <div className="space-y-2">
                      <Label htmlFor="nextEventId">Next Event ID</Label>
                      <Input
                        id="nextEventId"
                        type="number"
                        value={nextEventId}
                        onChange={(e) => setNextEventId(parseInt(e.target.value))}
                      />
                    </div>
                  </div>

                  <Alert>
                    <AlertTriangle className="h-4 w-4" />
                    <AlertDescription>
                      Ensure proper timing coordination with ad content when triggering SCTE-35 events.
                    </AlertDescription>
                  </Alert>
                </CardContent>
              </Card>

              {/* SCTE-35 Templates */}
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center justify-between">
                    <div className="flex items-center space-x-2">
                      <Save className="w-5 h-5" />
                      <span>SCTE-35 Templates</span>
                    </div>
                    <Dialog open={showTemplateDialog} onOpenChange={setShowTemplateDialog}>
                      <DialogTrigger asChild>
                        <Button 
                          size="sm" 
                          onClick={() => setEditingTemplate({
                            adDuration: adDuration,
                            eventId: nextEventId,
                            preRollDuration: preRollDuration,
                            scteDataPid: streamConfig.scteDataPID,
                            cueOutCommand: 'CUE-OUT',
                            cueInCommand: 'CUE-IN',
                            crashOutCommand: 'CUE-IN'
                          })}
                        >
                          <Plus className="w-4 h-4 mr-2" />
                          New Template
                        </Button>
                      </DialogTrigger>
                      <DialogContent className="max-w-2xl">
                        <DialogHeader>
                          <DialogTitle>
                            {editingTemplate?.id ? 'Edit Template' : 'Create New Template'}
                          </DialogTitle>
                          <DialogDescription>
                            Configure SCTE-35 template parameters
                          </DialogDescription>
                        </DialogHeader>
                        <div className="grid grid-cols-2 gap-4">
                          <div className="space-y-2">
                            <Label htmlFor="templateName">Template Name</Label>
                            <Input
                              id="templateName"
                              value={editingTemplate?.name || ''}
                              onChange={(e) => setEditingTemplate(prev => 
                                prev ? { ...prev, name: e.target.value } : null
                              )}
                              placeholder="Enter template name"
                            />
                          </div>
                          <div className="space-y-2">
                            <Label htmlFor="templateDescription">Description</Label>
                            <Input
                              id="templateDescription"
                              value={editingTemplate?.description || ''}
                              onChange={(e) => setEditingTemplate(prev => 
                                prev ? { ...prev, description: e.target.value } : null
                              )}
                              placeholder="Enter template description"
                            />
                          </div>
                          <div className="space-y-2">
                            <Label htmlFor="templateAdDuration">Ad Duration (seconds)</Label>
                            <Input
                              id="templateAdDuration"
                              type="number"
                              value={editingTemplate?.adDuration || ''}
                              onChange={(e) => setEditingTemplate(prev => 
                                prev ? { ...prev, adDuration: parseInt(e.target.value) } : null
                              )}
                              placeholder="600"
                            />
                          </div>
                          <div className="space-y-2">
                            <Label htmlFor="templateEventId">Event ID</Label>
                            <Input
                              id="templateEventId"
                              type="number"
                              value={editingTemplate?.eventId || ''}
                              onChange={(e) => setEditingTemplate(prev => 
                                prev ? { ...prev, eventId: parseInt(e.target.value) } : null
                              )}
                              placeholder="100023"
                            />
                          </div>
                          <div className="space-y-2">
                            <Label htmlFor="templatePreRoll">Pre-roll Duration (seconds)</Label>
                            <Input
                              id="templatePreRoll"
                              type="number"
                              min="0"
                              max="10"
                              value={editingTemplate?.preRollDuration || ''}
                              onChange={(e) => setEditingTemplate(prev => 
                                prev ? { ...prev, preRollDuration: parseInt(e.target.value) } : null
                              )}
                              placeholder="0"
                            />
                          </div>
                          <div className="space-y-2">
                            <Label htmlFor="templateSctePid">SCTE Data PID</Label>
                            <Input
                              id="templateSctePid"
                              type="number"
                              value={editingTemplate?.scteDataPid || ''}
                              onChange={(e) => setEditingTemplate(prev => 
                                prev ? { ...prev, scteDataPid: parseInt(e.target.value) } : null
                              )}
                              placeholder="500"
                            />
                          </div>
                          <div className="space-y-2">
                            <Label htmlFor="templateCueOut">CUE-OUT Command</Label>
                            <Input
                              id="templateCueOut"
                              value={editingTemplate?.cueOutCommand || ''}
                              onChange={(e) => setEditingTemplate(prev => 
                                prev ? { ...prev, cueOutCommand: e.target.value } : null
                              )}
                              placeholder="CUE-OUT"
                            />
                          </div>
                          <div className="space-y-2">
                            <Label htmlFor="templateCueIn">CUE-IN Command</Label>
                            <Input
                              id="templateCueIn"
                              value={editingTemplate?.cueInCommand || ''}
                              onChange={(e) => setEditingTemplate(prev => 
                                prev ? { ...prev, cueInCommand: e.target.value } : null
                              )}
                              placeholder="CUE-IN"
                            />
                          </div>
                          <div className="space-y-2 col-span-2">
                            <Label htmlFor="templateCrashOut">Crash Out Command</Label>
                            <Input
                              id="templateCrashOut"
                              value={editingTemplate?.crashOutCommand || ''}
                              onChange={(e) => setEditingTemplate(prev => 
                                prev ? { ...prev, crashOutCommand: e.target.value } : null
                              )}
                              placeholder="CUE-IN"
                            />
                            <p className="text-xs text-muted-foreground">
                              Command sent to get back to program before defined ad duration
                            </p>
                          </div>
                        </div>
                        <div className="flex justify-end space-x-2 mt-4">
                          <Button 
                            variant="outline" 
                            onClick={() => {
                              setEditingTemplate(null)
                              setShowTemplateDialog(false)
                            }}
                          >
                            Cancel
                          </Button>
                          <Button onClick={() => editingTemplate && saveTemplate(editingTemplate)}>
                            Save Template
                          </Button>
                        </div>
                      </DialogContent>
                    </Dialog>
                  </CardTitle>
                  <CardDescription>
                    Pre-configured SCTE-35 marker templates for quick ad insertion
                    {selectedTemplate && (
                      <span className="ml-2 text-sm text-blue-600">
                        Active: {selectedTemplate.name}
                      </span>
                    )}
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-3">
                    {scte35Templates.length === 0 ? (
                      <p className="text-center text-muted-foreground py-4">No templates available</p>
                    ) : (
                      scte35Templates.map((template) => (
                        <div 
                          key={template.id} 
                          className={`p-4 border rounded-lg ${
                            selectedTemplate?.id === template.id 
                              ? 'border-blue-500 bg-blue-50' 
                              : 'hover:bg-gray-50'
                          }`}
                        >
                          <div className="flex items-start justify-between">
                            <div className="flex-1">
                              <div className="flex items-center space-x-2 mb-1">
                                <h4 className="font-medium">{template.name}</h4>
                                {template.isDefault && (
                                  <Badge variant="secondary" className="text-xs">Default</Badge>
                                )}
                                {template.lastUsed && (
                                  <Badge variant="outline" className="text-xs">
                                    Used {formatDate(template.lastUsed)}
                                  </Badge>
                                )}
                              </div>
                              <p className="text-sm text-muted-foreground mb-2">
                                {template.description}
                              </p>
                              <div className="grid grid-cols-2 md:grid-cols-4 gap-2 text-xs">
                                <div>
                                  <span className="font-medium">Duration:</span> {template.adDuration}s
                                </div>
                                <div>
                                  <span className="font-medium">Event ID:</span> {template.eventId}
                                </div>
                                <div>
                                  <span className="font-medium">Pre-roll:</span> {template.preRollDuration}s
                                </div>
                                <div>
                                  <span className="font-medium">PID:</span> {template.scteDataPid}
                                </div>
                              </div>
                              <div className="grid grid-cols-3 gap-2 text-xs mt-1">
                                <div>
                                  <span className="font-medium">CUE-OUT:</span> {template.cueOutCommand}
                                </div>
                                <div>
                                  <span className="font-medium">CUE-IN:</span> {template.cueInCommand}
                                </div>
                                <div>
                                  <span className="font-medium">Crash:</span> {template.crashOutCommand}
                                </div>
                              </div>
                            </div>
                            <div className="flex items-center space-x-1 ml-4">
                              <Button
                                size="sm"
                                variant={selectedTemplate?.id === template.id ? "default" : "outline"}
                                onClick={() => applyTemplate(template)}
                              >
                                {selectedTemplate?.id === template.id ? "Applied" : "Apply"}
                              </Button>
                              <Button
                                size="sm"
                                variant="ghost"
                                onClick={() => {
                                  setEditingTemplate(template)
                                  setShowTemplateDialog(true)
                                }}
                              >
                                <Settings className="w-4 h-4" />
                              </Button>
                              <Button
                                size="sm"
                                variant="ghost"
                                onClick={() => duplicateTemplate(template)}
                              >
                                <Copy className="w-4 h-4" />
                              </Button>
                              {!template.isDefault && (
                                <Button
                                  size="sm"
                                  variant="ghost"
                                  onClick={() => deleteTemplate(template.id)}
                                >
                                  <XSquare className="w-4 h-4" />
                                </Button>
                              )}
                            </div>
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </CardContent>
              </Card>

              {/* Event History */}
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center space-x-2">
                    <Clock className="w-5 h-5" />
                    <span>Event History</span>
                  </CardTitle>
                  <CardDescription>Recent SCTE-35 events</CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-2 max-h-96 overflow-y-auto">
                    {scteEvents.length === 0 ? (
                      <p className="text-center text-muted-foreground py-8">No events yet</p>
                    ) : (
                      scteEvents.map((event) => (
                        <div key={event.id} className="flex items-center justify-between p-3 border rounded-lg">
                          <div className="flex items-center space-x-3">
                            <div className={`w-2 h-2 rounded-full ${
                              event.status === 'active' ? 'bg-green-500' :
                              event.status === 'completed' ? 'bg-blue-500' : 'bg-gray-500'
                            }`} />
                            <div>
                              <div className="font-medium">{event.type}</div>
                              <div className="text-sm text-muted-foreground">
                                ID: {event.eventId} • {formatDate(event.timestamp)}
                              </div>
                            </div>
                          </div>
                          <div className="text-right">
                            <div className="text-sm font-medium">
                              {event.adDuration > 0 ? `${event.adDuration}s` : '-'}
                            </div>
                            <Badge variant="outline" className="text-xs">
                              {event.status}
                            </Badge>
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* SCTE-35 Configuration */}
            <Card>
              <CardHeader>
                <CardTitle>SCTE-35 Configuration</CardTitle>
                <CardDescription>Advanced SCTE-35 settings</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="scteDataPID">SCTE Data PID</Label>
                    <Input
                      id="scteDataPID"
                      type="number"
                      value={streamConfig.scteDataPID}
                      onChange={(e) => setStreamConfig(prev => ({ ...prev, scteDataPID: parseInt(e.target.value) }))}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="nullPID">Null PID</Label>
                    <Input
                      id="nullPID"
                      type="number"
                      value={streamConfig.nullPID}
                      onChange={(e) => setStreamConfig(prev => ({ ...prev, nullPID: parseInt(e.target.value) }))}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="scteLatency">Latency (ms)</Label>
                    <Input
                      id="scteLatency"
                      type="number"
                      value={streamConfig.latency}
                      onChange={(e) => setStreamConfig(prev => ({ ...prev, latency: parseInt(e.target.value) }))}
                    />
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          {/* SSAI Tab */}
          <TabsContent value="ssai" className="space-y-4">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* SSAI Configuration */}
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center space-x-2">
                    <Settings className="w-5 h-5" />
                    <span>SSAI Configuration</span>
                  </CardTitle>
                  <CardDescription>Configure Server-Side Ad Insertion settings</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="ssaiEnabled">Enable SSAI</Label>
                    <Switch
                      id="ssaiEnabled"
                      checked={mediaServerConnection.isConnected}
                      onCheckedChange={(checked) => {
                        if (checked && !mediaServerConnection.isConnected) {
                          toast({
                            title: "Media Server Required",
                            description: "Please connect to media server first",
                            variant: "destructive"
                          })
                        }
                      }}
                    />
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="adInsertionMethod">Ad Insertion Method</Label>
                    <Select defaultValue="interval">
                      <SelectTrigger>
                        <SelectValue placeholder="Select method" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="interval">Interval-based</SelectItem>
                        <SelectItem value="splicing">Splicing-based</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="midrollInterval">Midroll Interval (seconds)</Label>
                    <Input
                      id="midrollInterval"
                      type="number"
                      defaultValue="180"
                      placeholder="180"
                    />
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="vodLocation">VOD Location</Label>
                    <Input
                      id="vodLocation"
                      defaultValue="ad_vod"
                      placeholder="ad_vod"
                    />
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="authBackend">Auth Backend URL</Label>
                    <Input
                      id="authBackend"
                      placeholder="http://localhost:8080/auth_backend.json"
                    />
                  </div>

                  <Button className="w-full">
                    <Save className="w-4 h-4 mr-2" />
                    Save Configuration
                  </Button>
                </CardContent>
              </Card>

              {/* SSAI Metrics */}
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center space-x-2">
                    <BarChart3 className="w-5 h-5" />
                    <span>SSAI Performance</span>
                  </CardTitle>
                  <CardDescription>Real-time SSAI metrics and performance</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  {monitoringMetrics ? (
                    <div className="space-y-4">
                      <div className="flex justify-between">
                        <span className="text-sm">Total Ad Insertions</span>
                        <span className="font-medium">{monitoringMetrics.ssai_metrics.total_ad_insertions}</span>
                      </div>
                      
                      <div>
                        <div className="flex justify-between text-sm">
                          <span>Fill Rate</span>
                          <span>{monitoringMetrics.ssai_metrics.fill_rate.toFixed(1)}%</span>
                        </div>
                        <Progress value={monitoringMetrics.ssai_metrics.fill_rate} className="h-2" />
                      </div>
                      
                      <div className="flex justify-between">
                        <span className="text-sm">Ad Impressions</span>
                        <span className="font-medium">{monitoringMetrics.ssai_metrics.ad_impressions.toLocaleString()}</span>
                      </div>

                      <Separator />

                      <div className="space-y-2">
                        <Label>Last Activity</Label>
                        <div className="text-sm text-muted-foreground">
                          {new Date().toLocaleString()}
                        </div>
                      </div>

                      <Button variant="outline" className="w-full">
                        <RefreshCw className="w-4 h-4 mr-2" />
                        Refresh Metrics
                      </Button>
                    </div>
                  ) : (
                    <div className="text-center py-8">
                      <BarChart3 className="w-12 h-12 mx-auto mb-4 text-muted-foreground" />
                      <p className="text-muted-foreground">Connect to media server to view SSAI metrics</p>
                    </div>
                  )}
                </CardContent>
              </Card>
            </div>

            {/* Ad Management Section */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* Ad Campaigns */}
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center space-x-2">
                    <Target className="w-5 h-5" />
                    <span>Ad Campaigns</span>
                  </CardTitle>
                  <CardDescription>Manage advertising campaigns</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="flex justify-between items-center">
                    <span className="text-sm font-medium">Active Campaigns</span>
                    <Badge variant="secondary">0</Badge>
                  </div>

                  <div className="space-y-2 max-h-48 overflow-y-auto">
                    <div className="text-center py-8 text-muted-foreground">
                      <Target className="w-8 h-8 mx-auto mb-2" />
                      <p className="text-sm">No campaigns configured</p>
                    </div>
                  </div>

                  <Button className="w-full">
                    <Plus className="w-4 h-4 mr-2" />
                    Create Campaign
                  </Button>
                </CardContent>
              </Card>

              {/* Ad Assets */}
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center space-x-2">
                    <Video className="w-5 h-5" />
                    <span>Ad Assets</span>
                  </CardTitle>
                  <CardDescription>Manage advertisement media files</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="flex justify-between items-center">
                    <span className="text-sm font-medium">Available Assets</span>
                    <Badge variant="secondary">0</Badge>
                  </div>

                  <div className="space-y-2 max-h-48 overflow-y-auto">
                    <div className="text-center py-8 text-muted-foreground">
                      <Video className="w-8 h-8 mx-auto mb-2" />
                      <p className="text-sm">No ad assets uploaded</p>
                    </div>
                  </div>

                  <Button variant="outline" className="w-full">
                    <Upload className="w-4 h-4 mr-2" />
                    Upload Asset
                  </Button>
                </CardContent>
              </Card>
            </div>

            {/* Quick Actions */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center space-x-2">
                  <Zap className="w-5 h-5" />
                  <span>Quick Actions</span>
                </CardTitle>
                <CardDescription>Common SSAI operations</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <Button variant="outline" className="h-20">
                    <div className="text-center">
                      <Play className="w-6 h-6 mx-auto mb-2" />
                      <div>Test Ad Insertion</div>
                      <div className="text-xs opacity-70">Trigger test ad break</div>
                    </div>
                  </Button>
                  
                  <Button variant="outline" className="h-20">
                    <div className="text-center">
                      <Download className="w-6 h-6 mx-auto mb-2" />
                      <div>Export Config</div>
                      <div className="text-xs opacity-70">Download SSAI config</div>
                    </div>
                  </Button>
                  
                  <Button variant="outline" className="h-20">
                    <div className="text-center">
                      <FileText className="w-6 h-6 mx-auto mb-2" />
                      <div>View Logs</div>
                      <div className="text-xs opacity-70">SSAI operation logs</div>
                    </div>
                  </Button>
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          {/* Monitoring Tab */}
          <TabsContent value="monitoring" className="space-y-4">
            {monitoringMetrics ? (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                {/* Server Metrics */}
                <Card>
                  <CardHeader>
                    <CardTitle className="flex items-center space-x-2">
                      <Server className="w-5 h-5" />
                      <span>Server</span>
                    </CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-3">
                    <div>
                      <div className="flex justify-between text-sm">
                        <span>CPU</span>
                        <span>{monitoringMetrics.server_metrics.cpu_usage.toFixed(1)}%</span>
                      </div>
                      <Progress value={monitoringMetrics.server_metrics.cpu_usage} className="h-2" />
                    </div>
                    <div>
                      <div className="flex justify-between text-sm">
                        <span>Memory</span>
                        <span>{monitoringMetrics.server_metrics.memory_usage.toFixed(1)}%</span>
                      </div>
                      <Progress value={monitoringMetrics.server_metrics.memory_usage} className="h-2" />
                    </div>
                    <div>
                      <div className="flex justify-between text-sm">
                        <span>Disk</span>
                        <span>{monitoringMetrics.server_metrics.disk_usage.toFixed(1)}%</span>
                      </div>
                      <Progress value={monitoringMetrics.server_metrics.disk_usage} className="h-2" />
                    </div>
                    <div className="text-sm text-muted-foreground">
                      Uptime: {formatDuration(monitoringMetrics.server_metrics.uptime)}
                    </div>
                  </CardContent>
                </Card>

                {/* Stream Metrics */}
                <Card>
                  <CardHeader>
                    <CardTitle className="flex items-center space-x-2">
                      <Activity className="w-5 h-5" />
                      <span>Streams</span>
                    </CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-3">
                    <div className="flex justify-between">
                      <span className="text-sm">Total Streams</span>
                      <span className="font-medium">{monitoringMetrics.stream_metrics.total_streams}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-sm">Active Streams</span>
                      <span className="font-medium">{monitoringMetrics.stream_metrics.active_streams}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-sm">Total Viewers</span>
                      <span className="font-medium">{monitoringMetrics.stream_metrics.total_viewers.toLocaleString()}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-sm">Bandwidth</span>
                      <span className="font-medium">
                        {(monitoringMetrics.stream_metrics.total_bandwidth / 1000000).toFixed(1)} Mbps
                      </span>
                    </div>
                  </CardContent>
                </Card>

                {/* SCTE-35 Metrics */}
                <Card>
                  <CardHeader>
                    <CardTitle className="flex items-center space-x-2">
                      <Radio className="w-5 h-5" />
                      <span>SCTE-35</span>
                    </CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-3">
                    <div className="flex justify-between">
                      <span className="text-sm">Total Events</span>
                      <span className="font-medium">{monitoringMetrics.scte35_metrics.total_events}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-sm">Events/Hour</span>
                      <span className="font-medium">{monitoringMetrics.scte35_metrics.events_last_hour}</span>
                    </div>
                    <div>
                      <div className="flex justify-between text-sm">
                        <span>Success Rate</span>
                        <span>{monitoringMetrics.scte35_metrics.success_rate.toFixed(1)}%</span>
                      </div>
                      <Progress value={monitoringMetrics.scte35_metrics.success_rate} className="h-2" />
                    </div>
                  </CardContent>
                </Card>

                {/* SSAI Metrics */}
                <Card>
                  <CardHeader>
                    <CardTitle className="flex items-center space-x-2">
                      <Target className="w-5 h-5" />
                      <span>SSAI</span>
                    </CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-3">
                    <div className="flex justify-between">
                      <span className="text-sm">Ad Insertions</span>
                      <span className="font-medium">{monitoringMetrics.ssai_metrics.total_ad_insertions}</span>
                    </div>
                    <div>
                      <div className="flex justify-between text-sm">
                        <span>Fill Rate</span>
                        <span>{monitoringMetrics.ssai_metrics.fill_rate.toFixed(1)}%</span>
                      </div>
                      <Progress value={monitoringMetrics.ssai_metrics.fill_rate} className="h-2" />
                    </div>
                    <div className="flex justify-between">
                      <span className="text-sm">Impressions</span>
                      <span className="font-medium">{monitoringMetrics.ssai_metrics.ad_impressions.toLocaleString()}</span>
                    </div>
                  </CardContent>
                </Card>
              </div>
            ) : (
              <Card>
                <CardContent className="flex items-center justify-center h-64">
                  <div className="text-center">
                    <Monitor className="w-12 h-12 mx-auto mb-4 text-muted-foreground" />
                    <p className="text-muted-foreground">Connect to media server to view monitoring data</p>
                  </div>
                </CardContent>
              </Card>
            )}

            {/* Alerts and Notifications */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center space-x-2">
                  <Bell className="w-5 h-5" />
                  <span>System Alerts</span>
                </CardTitle>
                <CardDescription>Recent system notifications</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-2">
                  {alerts.length === 0 ? (
                    <p className="text-center text-muted-foreground py-4">No active alerts</p>
                  ) : (
                    alerts.map((alert, index) => (
                      <Alert key={index} className={alert.severity === 'critical' ? 'border-red-200' : alert.severity === 'warning' ? 'border-yellow-200' : ''}>
                        <AlertTriangle className="h-4 w-4" />
                        <AlertDescription>
                          <div className="flex justify-between items-start">
                            <div>
                              <div className="font-medium">{alert.title}</div>
                              <div className="text-sm">{alert.message}</div>
                            </div>
                            <div className="text-xs text-muted-foreground">
                              {new Date(alert.timestamp).toLocaleString()}
                            </div>
                          </div>
                        </AlertDescription>
                      </Alert>
                    ))
                  )}
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          {/* Configuration Tab */}
          <TabsContent value="configuration" className="space-y-4">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
              {/* Stream Configuration */}
              <Card>
                <CardHeader>
                  <CardTitle>Stream Configuration</CardTitle>
                  <CardDescription>Video and audio settings</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="serviceName">Service Name</Label>
                    <Input
                      id="serviceName"
                      value={streamConfig.serviceName}
                      onChange={(e) => setStreamConfig(prev => ({ ...prev, serviceName: e.target.value }))}
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="videoResolution">Resolution</Label>
                      <Select value={streamConfig.videoResolution} onValueChange={(value) => setStreamConfig(prev => ({ ...prev, videoResolution: value }))}>
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="1920x1080">1920x1080</SelectItem>
                          <SelectItem value="1280x720">1280x720</SelectItem>
                          <SelectItem value="3840x2160">3840x2160</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="videoCodec">Video Codec</Label>
                      <Select value={streamConfig.videoCodec} onValueChange={(value) => setStreamConfig(prev => ({ ...prev, videoCodec: value }))}>
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="H.264">H.264</SelectItem>
                          <SelectItem value="H.265">H.265</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="videoBitrate">Video Bitrate (Mbps)</Label>
                      <Input
                        id="videoBitrate"
                        type="number"
                        value={streamConfig.videoBitrate}
                        onChange={(e) => setStreamConfig(prev => ({ ...prev, videoBitrate: parseFloat(e.target.value) }))}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="audioBitrate">Audio Bitrate (kbps)</Label>
                      <Input
                        id="audioBitrate"
                        type="number"
                        value={streamConfig.audioBitrate}
                        onChange={(e) => setStreamConfig(prev => ({ ...prev, audioBitrate: parseInt(e.target.value) }))}
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="audioLKFS">Audio Level (dB)</Label>
                      <Input
                        id="audioLKFS"
                        type="number"
                        value={streamConfig.audioLKFS}
                        onChange={(e) => setStreamConfig(prev => ({ ...prev, audioLKFS: parseFloat(e.target.value) }))}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="audioSamplingRate">Sample Rate (kHz)</Label>
                      <Input
                        id="audioSamplingRate"
                        type="number"
                        value={streamConfig.audioSamplingRate}
                        onChange={(e) => setStreamConfig(prev => ({ ...prev, audioSamplingRate: parseInt(e.target.value) }))}
                      />
                    </div>
                  </div>
                </CardContent>
              </Card>

              {/* Advanced Configuration */}
              <Card>
                <CardHeader>
                  <CardTitle>Advanced Configuration</CardTitle>
                  <CardDescription>Advanced stream parameters</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="gop">GOP Size</Label>
                      <Input
                        id="gop"
                        type="number"
                        value={streamConfig.gop}
                        onChange={(e) => setStreamConfig(prev => ({ ...prev, gop: parseInt(e.target.value) }))}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="bFrames">B-Frames</Label>
                      <Input
                        id="bFrames"
                        type="number"
                        value={streamConfig.bFrames}
                        onChange={(e) => setStreamConfig(prev => ({ ...prev, bFrames: parseInt(e.target.value) }))}
                      />
                    </div>
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="profileLevel">Profile@Level</Label>
                    <Select value={streamConfig.profileLevel} onValueChange={(value) => setStreamConfig(prev => ({ ...prev, profileLevel: value }))}>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="High@Auto">High@Auto</SelectItem>
                        <SelectItem value="High@4.1">High@4.1</SelectItem>
                        <SelectItem value="High@4.2">High@4.2</SelectItem>
                        <SelectItem value="Main@3.1">Main@3.1</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="chroma">Chroma Subsampling</Label>
                    <Select value={streamConfig.chroma} onValueChange={(value) => setStreamConfig(prev => ({ ...prev, chroma: value }))}>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="4:2:0">4:2:0</SelectItem>
                        <SelectItem value="4:2:2">4:2:2</SelectItem>
                        <SelectItem value="4:4:4">4:4:4</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="aspectRatio">Aspect Ratio</Label>
                    <Select value={streamConfig.aspectRatio} onValueChange={(value) => setStreamConfig(prev => ({ ...prev, aspectRatio: value }))}>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="16:9">16:9</SelectItem>
                        <SelectItem value="4:3">4:3</SelectItem>
                        <SelectItem value="1:1">1:1</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* SCTE-35 Configuration */}
            <Card>
              <CardHeader>
                <CardTitle>SCTE-35 Configuration</CardTitle>
                <CardDescription>SCTE-35 ad insertion settings</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="scteDataPID">SCTE Data PID</Label>
                    <Input
                      id="scteDataPID"
                      type="number"
                      value={streamConfig.scteDataPID}
                      onChange={(e) => setStreamConfig(prev => ({ ...prev, scteDataPID: parseInt(e.target.value) }))}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="nullPID">Null PID</Label>
                    <Input
                      id="nullPID"
                      type="number"
                      value={streamConfig.nullPID}
                      onChange={(e) => setStreamConfig(prev => ({ ...prev, nullPID: parseInt(e.target.value) }))}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="scteLatency">Latency (ms)</Label>
                    <Input
                      id="scteLatency"
                      type="number"
                      value={streamConfig.latency}
                      onChange={(e) => setStreamConfig(prev => ({ ...prev, latency: parseInt(e.target.value) }))}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="pcr">PCR Source</Label>
                    <Select value={streamConfig.pcr} onValueChange={(value) => setStreamConfig(prev => ({ ...prev, pcr: value }))}>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="Video Embedded">Video Embedded</SelectItem>
                        <SelectItem value="Audio Embedded">Audio Embedded</SelectItem>
                        <SelectItem value="Separate">Separate</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          {/* Distributors Tab */}
          <TabsContent value="distributors" className="space-y-4">
            <div className="flex justify-between items-center">
              <div>
                <h2 className="text-2xl font-bold">Distributor Management</h2>
                <p className="text-muted-foreground">Manage distributor relationships and compliance</p>
              </div>
              <Button onClick={() => setShowDistributorConfig(true)}>
                <Plus className="w-4 h-4 mr-2" />
                Add Distributor
              </Button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {distributors.map((distributor) => (
                <Card key={distributor.id} className="cursor-pointer hover:shadow-md transition-shadow">
                  <CardHeader>
                    <div className="flex items-center justify-between">
                      <CardTitle className="text-lg">{distributor.name}</CardTitle>
                      {getStatusBadge(distributor.status)}
                    </div>
                    <CardDescription>{distributor.contact_info.technical_contact}</CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-3">
                    <div className="grid grid-cols-2 gap-2 text-sm">
                      <div>
                        <span className="text-muted-foreground">Streams:</span>
                        <div className="font-medium">{distributor.streams_count}</div>
                      </div>
                      <div>
                        <span className="text-muted-foreground">Issues:</span>
                        <div className="font-medium">{distributor.issues_count}</div>
                      </div>
                    </div>
                    
                    <div className="space-y-2">
                      <div className="flex justify-between text-sm">
                        <span>Compliance</span>
                        <span className="font-medium">{distributor.compliance_score.toFixed(1)}%</span>
                      </div>
                      <Progress value={distributor.compliance_score} className="h-2" />
                    </div>

                    <div className="space-y-2">
                      <div className="flex justify-between text-sm">
                        <span>Delivery Rate</span>
                        <span className="font-medium">{distributor.delivery_success_rate.toFixed(1)}%</span>
                      </div>
                      <Progress value={distributor.delivery_success_rate} className="h-2" />
                    </div>

                    <div className="text-xs text-muted-foreground">
                      Last activity: {new Date(distributor.last_activity).toLocaleString()}
                    </div>

                    <Button 
                      variant="outline" 
                      className="w-full"
                      onClick={() => setSelectedDistributor(distributor)}
                    >
                      View Details
                    </Button>
                  </CardContent>
                </Card>
              ))}
            </div>

            {/* Distributor Details Modal */}
            {selectedDistributor && (
              <Dialog open={!!selectedDistributor} onOpenChange={() => setSelectedDistributor(null)}>
                <DialogContent className="max-w-2xl">
                  <DialogHeader>
                    <DialogTitle>{selectedDistributor.name}</DialogTitle>
                    <DialogDescription>Distributor details and configuration</DialogDescription>
                  </DialogHeader>
                  <div className="space-y-4">
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <h4 className="font-medium mb-2">Contact Information</h4>
                        <div className="space-y-1 text-sm">
                          <div><span className="text-muted-foreground">Email:</span> {selectedDistributor.contact_info.email}</div>
                          <div><span className="text-muted-foreground">Phone:</span> {selectedDistributor.contact_info.phone}</div>
                          <div><span className="text-muted-foreground">Technical Contact:</span> {selectedDistributor.contact_info.technical_contact}</div>
                        </div>
                      </div>
                      <div>
                        <h4 className="font-medium mb-2">Performance Metrics</h4>
                        <div className="space-y-1 text-sm">
                          <div><span className="text-muted-foreground">Streams:</span> {selectedDistributor.streams_count}</div>
                          <div><span className="text-muted-foreground">Compliance:</span> {selectedDistributor.compliance_score.toFixed(1)}%</div>
                          <div><span className="text-muted-foreground">Delivery Rate:</span> {selectedDistributor.delivery_success_rate.toFixed(1)}%</div>
                          <div><span className="text-muted-foreground">Issues:</span> {selectedDistributor.issues_count}</div>
                        </div>
                      </div>
                    </div>
                    
                    <div className="flex justify-end space-x-2">
                      <Button variant="outline" onClick={() => setSelectedDistributor(null)}>
                        Close
                      </Button>
                      <Button onClick={() => {
                        setEditingDistributor(selectedDistributor)
                        setSelectedDistributor(null)
                      }}>
                        <Settings className="w-4 h-4 mr-2" />
                        Edit Configuration
                      </Button>
                    </div>
                  </div>
                </DialogContent>
              </Dialog>
            )}

            {/* Distributor Configuration Dialog */}
            {editingDistributor && (
              <Dialog open={!!editingDistributor} onOpenChange={() => setEditingDistributor(null)}>
                <DialogContent className="max-w-3xl max-h-[90vh] overflow-y-auto">
                  <DialogHeader>
                    <DialogTitle>
                      {editingDistributor.id ? 'Edit Distributor Configuration' : 'Add New Distributor'}
                    </DialogTitle>
                    <DialogDescription>
                      Configure distributor settings and contact information
                    </DialogDescription>
                  </DialogHeader>
                  <div className="space-y-6">
                    {/* Basic Information */}
                    <div className="space-y-4">
                      <h3 className="text-lg font-medium">Basic Information</h3>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="space-y-2">
                          <Label htmlFor="distributorName">Distributor Name</Label>
                          <Input
                            id="distributorName"
                            value={editingDistributor.name}
                            onChange={(e) => setEditingDistributor(prev => prev ? { ...prev, name: e.target.value } : null)}
                            placeholder="Enter distributor name"
                          />
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="distributorStatus">Status</Label>
                          <Select 
                            value={editingDistributor.status} 
                            onValueChange={(value: any) => setEditingDistributor(prev => prev ? { ...prev, status: value } : null)}
                          >
                            <SelectTrigger>
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              <SelectItem value="active">Active</SelectItem>
                              <SelectItem value="inactive">Inactive</SelectItem>
                              <SelectItem value="warning">Warning</SelectItem>
                              <SelectItem value="error">Error</SelectItem>
                            </SelectContent>
                          </Select>
                        </div>
                      </div>
                    </div>

                    {/* Contact Information */}
                    <div className="space-y-4">
                      <h3 className="text-lg font-medium">Contact Information</h3>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="space-y-2">
                          <Label htmlFor="email">Email Address</Label>
                          <Input
                            id="email"
                            type="email"
                            value={editingDistributor.contact_info.email}
                            onChange={(e) => setEditingDistributor(prev => prev ? { 
                              ...prev, 
                              contact_info: { ...prev.contact_info, email: e.target.value }
                            } : null)}
                            placeholder="contact@distributor.com"
                          />
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="phone">Phone Number</Label>
                          <Input
                            id="phone"
                            value={editingDistributor.contact_info.phone}
                            onChange={(e) => setEditingDistributor(prev => prev ? { 
                              ...prev, 
                              contact_info: { ...prev.contact_info, phone: e.target.value }
                            } : null)}
                            placeholder="+1-555-0123"
                          />
                        </div>
                        <div className="md:col-span-2 space-y-2">
                          <Label htmlFor="technicalContact">Technical Contact</Label>
                          <Input
                            id="technicalContact"
                            value={editingDistributor.contact_info.technical_contact}
                            onChange={(e) => setEditingDistributor(prev => prev ? { 
                              ...prev, 
                              contact_info: { ...prev.contact_info, technical_contact: e.target.value }
                            } : null)}
                            placeholder="Name of technical contact person"
                          />
                        </div>
                      </div>
                    </div>

                    {/* Performance Metrics */}
                    <div className="space-y-4">
                      <h3 className="text-lg font-medium">Performance Metrics</h3>
                      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                        <div className="space-y-2">
                          <Label htmlFor="streamsCount">Number of Streams</Label>
                          <Input
                            id="streamsCount"
                            type="number"
                            value={editingDistributor.streams_count}
                            onChange={(e) => setEditingDistributor(prev => prev ? { ...prev, streams_count: parseInt(e.target.value) || 0 } : null)}
                            min="0"
                          />
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="complianceScore">Compliance Score (%)</Label>
                          <Input
                            id="complianceScore"
                            type="number"
                            value={editingDistributor.compliance_score}
                            onChange={(e) => setEditingDistributor(prev => prev ? { ...prev, compliance_score: parseFloat(e.target.value) || 0 } : null)}
                            min="0"
                            max="100"
                            step="0.1"
                          />
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="deliveryRate">Delivery Success Rate (%)</Label>
                          <Input
                            id="deliveryRate"
                            type="number"
                            value={editingDistributor.delivery_success_rate}
                            onChange={(e) => setEditingDistributor(prev => prev ? { ...prev, delivery_success_rate: parseFloat(e.target.value) || 0 } : null)}
                            min="0"
                            max="100"
                            step="0.1"
                          />
                        </div>
                      </div>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="space-y-2">
                          <Label htmlFor="issuesCount">Active Issues</Label>
                          <Input
                            id="issuesCount"
                            type="number"
                            value={editingDistributor.issues_count}
                            onChange={(e) => setEditingDistributor(prev => prev ? { ...prev, issues_count: parseInt(e.target.value) || 0 } : null)}
                            min="0"
                          />
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="lastActivity">Last Activity</Label>
                          <Input
                            id="lastActivity"
                            value={new Date(editingDistributor.last_activity).toLocaleString()}
                            onChange={(e) => setEditingDistributor(prev => prev ? { ...prev, last_activity: new Date(e.target.value).toISOString() } : null)}
                          />
                        </div>
                      </div>
                    </div>

                    {/* Advanced Configuration */}
                    <div className="space-y-4">
                      <h3 className="text-lg font-medium">Advanced Configuration</h3>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="space-y-2">
                          <Label htmlFor="streamUrl">Stream URL Pattern</Label>
                          <Input
                            id="streamUrl"
                            placeholder="rtmp://distributor.com/live/{stream_name}"
                          />
                          <p className="text-xs text-muted-foreground">
                            URL pattern for stream delivery to this distributor
                          </p>
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="backupUrl">Backup Stream URL</Label>
                          <Input
                            id="backupUrl"
                            placeholder="rtmp://backup-distributor.com/live/{stream_name}"
                          />
                          <p className="text-xs text-muted-foreground">
                            Fallback URL for redundancy
                          </p>
                        </div>
                      </div>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="space-y-2">
                          <Label htmlFor="authToken">Authentication Token</Label>
                          <Input
                            id="authToken"
                            type="password"
                            placeholder="Enter authentication token"
                          />
                          <p className="text-xs text-muted-foreground">
                            Token for secure stream delivery
                          </p>
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="webhookUrl">Webhook URL</Label>
                          <Input
                            id="webhookUrl"
                            placeholder="https://distributor.com/api/webhook"
                          />
                          <p className="text-xs text-muted-foreground">
                            URL for status notifications
                          </p>
                        </div>
                      </div>
                    </div>

                    {/* Delivery Settings */}
                    <div className="space-y-4">
                      <h3 className="text-lg font-medium">Delivery Settings</h3>
                      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                        <div className="space-y-2">
                          <Label htmlFor="bitrate">Target Bitrate (Mbps)</Label>
                          <Input
                            id="bitrate"
                            type="number"
                            defaultValue="5"
                            min="1"
                            max="20"
                          />
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="resolution">Resolution</Label>
                          <Select defaultValue="1920x1080">
                            <SelectTrigger>
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              <SelectItem value="1920x1080">1920x1080 (Full HD)</SelectItem>
                              <SelectItem value="1280x720">1280x720 (HD)</SelectItem>
                              <SelectItem value="854x480">854x480 (SD)</SelectItem>
                            </SelectContent>
                          </Select>
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="protocol">Delivery Protocol</Label>
                          <Select defaultValue="rtmp">
                            <SelectTrigger>
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              <SelectItem value="rtmp">RTMP</SelectItem>
                              <SelectItem value="srt">SRT</SelectItem>
                              <SelectItem value="hls">HLS</SelectItem>
                              <SelectItem value="dash">DASH</SelectItem>
                            </SelectContent>
                          </Select>
                        </div>
                      </div>
                    </div>

                    {/* Monitoring and Alerts */}
                    <div className="space-y-4">
                      <h3 className="text-lg font-medium">Monitoring and Alerts</h3>
                      <div className="space-y-4">
                        <div className="flex items-center justify-between">
                          <div>
                            <Label>Enable Health Monitoring</Label>
                            <p className="text-sm text-muted-foreground">
                              Monitor distributor stream health
                            </p>
                          </div>
                          <Switch defaultChecked />
                        </div>
                        <div className="flex items-center justify-between">
                          <div>
                            <Label>Enable Alerts</Label>
                            <p className="text-sm text-muted-foreground">
                              Send alerts for stream issues
                            </p>
                          </div>
                          <Switch defaultChecked />
                        </div>
                        <div className="flex items-center justify-between">
                          <div>
                            <Label>Enable Analytics</Label>
                            <p className="text-sm text-muted-foreground">
                              Collect performance analytics
                            </p>
                          </div>
                          <Switch defaultChecked />
                        </div>
                      </div>
                    </div>

                    {/* Action Buttons */}
                    <div className="flex justify-end space-x-2 pt-4 border-t">
                      <Button variant="outline" onClick={() => setEditingDistributor(null)}>
                        Cancel
                      </Button>
                      <Button variant="outline" onClick={() => {
                        // Test configuration
                        toast({
                          title: "Configuration Test",
                          description: "Testing distributor configuration...",
                        })
                      }}>
                        <Play className="w-4 h-4 mr-2" />
                        Test Configuration
                      </Button>
                      <Button onClick={() => {
                        if (editingDistributor && editingDistributor.name) {
                          if (editingDistributor.id) {
                            // Update existing distributor
                            setDistributors(prev => 
                              prev.map(d => d.id === editingDistributor.id ? editingDistributor : d)
                            )
                            toast({
                              title: "Distributor Updated",
                              description: `${editingDistributor.name} configuration has been updated`,
                            })
                          } else {
                            // Create new distributor
                            const newDist: DistributorConfig = {
                              ...editingDistributor,
                              id: `dist_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
                            } as DistributorConfig
                            setDistributors(prev => [...prev, newDist])
                            toast({
                              title: "Distributor Added",
                              description: `${newDist.name} has been added successfully`,
                            })
                          }
                          setEditingDistributor(null)
                        } else {
                          toast({
                            title: "Validation Error",
                            description: "Please fill in all required fields",
                            variant: "destructive"
                          })
                        }
                      }}>
                        <Save className="w-4 h-4 mr-2" />
                        Save Configuration
                      </Button>
                    </div>
                  </div>
                </DialogContent>
              </Dialog>
            )}

            {/* Add New Distributor Dialog */}
            {showDistributorConfig && (
              <Dialog open={showDistributorConfig} onOpenChange={setShowDistributorConfig}>
                <DialogContent className="max-w-3xl max-h-[90vh] overflow-y-auto">
                  <DialogHeader>
                    <DialogTitle>Add New Distributor</DialogTitle>
                    <DialogDescription>
                      Create a new distributor configuration
                    </DialogDescription>
                  </DialogHeader>
                  <div className="space-y-6">
                    {/* Basic Information */}
                    <div className="space-y-4">
                      <h3 className="text-lg font-medium">Basic Information</h3>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="space-y-2">
                          <Label htmlFor="newDistributorName">Distributor Name</Label>
                          <Input
                            id="newDistributorName"
                            value={newDistributor.name}
                            onChange={(e) => setNewDistributor(prev => ({ ...prev, name: e.target.value }))}
                            placeholder="Enter distributor name"
                          />
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="newDistributorStatus">Status</Label>
                          <Select 
                            value={newDistributor.status} 
                            onValueChange={(value: any) => setNewDistributor(prev => ({ ...prev, status: value }))}
                          >
                            <SelectTrigger>
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              <SelectItem value="active">Active</SelectItem>
                              <SelectItem value="inactive">Inactive</SelectItem>
                              <SelectItem value="warning">Warning</SelectItem>
                              <SelectItem value="error">Error</SelectItem>
                            </SelectContent>
                          </Select>
                        </div>
                      </div>
                    </div>

                    {/* Contact Information */}
                    <div className="space-y-4">
                      <h3 className="text-lg font-medium">Contact Information</h3>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="space-y-2">
                          <Label htmlFor="newEmail">Email Address</Label>
                          <Input
                            id="newEmail"
                            type="email"
                            value={newDistributor.contact_info?.email || ''}
                            onChange={(e) => setNewDistributor(prev => ({ 
                              ...prev, 
                              contact_info: { ...prev.contact_info!, email: e.target.value }
                            }))}
                            placeholder="contact@distributor.com"
                          />
                        </div>
                        <div className="space-y-2">
                          <Label htmlFor="newPhone">Phone Number</Label>
                          <Input
                            id="newPhone"
                            value={newDistributor.contact_info?.phone || ''}
                            onChange={(e) => setNewDistributor(prev => ({ 
                              ...prev, 
                              contact_info: { ...prev.contact_info!, phone: e.target.value }
                            }))}
                            placeholder="+1-555-0123"
                          />
                        </div>
                        <div className="md:col-span-2 space-y-2">
                          <Label htmlFor="newTechnicalContact">Technical Contact</Label>
                          <Input
                            id="newTechnicalContact"
                            value={newDistributor.contact_info?.technical_contact || ''}
                            onChange={(e) => setNewDistributor(prev => ({ 
                              ...prev, 
                              contact_info: { ...prev.contact_info!, technical_contact: e.target.value }
                            }))}
                            placeholder="Name of technical contact person"
                          />
                        </div>
                      </div>
                    </div>

                    {/* Action Buttons */}
                    <div className="flex justify-end space-x-2 pt-4 border-t">
                      <Button variant="outline" onClick={() => setShowDistributorConfig(false)}>
                        Cancel
                      </Button>
                      <Button onClick={() => {
                        if (newDistributor.name && newDistributor.contact_info?.email) {
                          const newDist: DistributorConfig = {
                            ...newDistributor,
                            id: `dist_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
                          } as DistributorConfig
                          setDistributors(prev => [...prev, newDist])
                          setShowDistributorConfig(false)
                          setNewDistributor({
                            name: '',
                            status: 'active',
                            contact_info: {
                              email: '',
                              phone: '',
                              technical_contact: ''
                            },
                            streams_count: 0,
                            compliance_score: 95.0,
                            delivery_success_rate: 98.0,
                            last_activity: new Date().toISOString(),
                            issues_count: 0
                          })
                          toast({
                            title: "Distributor Added",
                            description: `${newDist.name} has been added successfully`,
                          })
                        } else {
                          toast({
                            title: "Validation Error",
                            description: "Please fill in name and email",
                            variant: "destructive"
                          })
                        }
                      }}>
                        <Plus className="w-4 h-4 mr-2" />
                        Add Distributor
                      </Button>
                    </div>
                  </div>
                </DialogContent>
              </Dialog>
            )}
          </TabsContent>

          {/* Scheduler Tab */}
          <TabsContent value="scheduler" className="space-y-4">
            <div className="flex justify-between items-center">
              <div>
                <h2 className="text-2xl font-bold">Ad Scheduler</h2>
                <p className="text-muted-foreground">Automated SCTE-35 event scheduling</p>
              </div>
              <Button onClick={() => setShowScheduleForm(true)}>
                <Plus className="w-4 h-4 mr-2" />
                New Schedule
              </Button>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
              {/* Active Schedules */}
              <Card>
                <CardHeader>
                  <CardTitle>Active Schedules</CardTitle>
                  <CardDescription>Currently running ad schedules</CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-3 max-h-96 overflow-y-auto">
                    {adSchedules.filter(s => s.enabled && s.status === 'active').length === 0 ? (
                      <p className="text-center text-muted-foreground py-8">No active schedules</p>
                    ) : (
                      adSchedules.filter(s => s.enabled && s.status === 'active').map((schedule) => (
                        <div key={schedule.id} className="p-3 border rounded-lg">
                          <div className="flex items-center justify-between mb-2">
                            <h4 className="font-medium">{schedule.name}</h4>
                            <div className="flex items-center space-x-2">
                              <Badge variant="outline">{schedule.type}</Badge>
                              <Switch checked={schedule.enabled} />
                            </div>
                          </div>
                          <div className="text-sm text-muted-foreground space-y-1">
                            <div>Stream: {schedule.stream}</div>
                            <div>Duration: {schedule.duration}s</div>
                            <div>Next: {schedule.nextTrigger ? new Date(schedule.nextTrigger).toLocaleString() : 'Not scheduled'}</div>
                            <div>Triggered: {schedule.triggerCount} times</div>
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </CardContent>
              </Card>

              {/* Recent Executions */}
              <Card>
                <CardHeader>
                  <CardTitle>Recent Executions</CardTitle>
                  <CardDescription>Latest schedule executions</CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-3 max-h-96 overflow-y-auto">
                    {scheduleExecutions.length === 0 ? (
                      <p className="text-center text-muted-foreground py-8">No executions yet</p>
                    ) : (
                      scheduleExecutions.slice(0, 10).map((execution) => (
                        <div key={execution.id} className="p-3 border rounded-lg">
                          <div className="flex items-center justify-between mb-2">
                            <div className="flex items-center space-x-2">
                              <div className={`w-2 h-2 rounded-full ${
                                execution.status === 'completed' ? 'bg-green-500' :
                                execution.status === 'failed' ? 'bg-red-500' :
                                execution.status === 'triggered' ? 'bg-blue-500' : 'bg-gray-500'
                              }`} />
                              <span className="font-medium text-sm">
                                {adSchedules.find(s => s.id === execution.scheduleId)?.name || 'Unknown'}
                              </span>
                            </div>
                            <Badge variant="outline" className="text-xs">
                              {execution.status}
                            </Badge>
                          </div>
                          <div className="text-sm text-muted-foreground">
                            <div>Scheduled: {new Date(execution.scheduledTime).toLocaleString()}</div>
                            {execution.actualTriggerTime && (
                              <div>Triggered: {new Date(execution.actualTriggerTime).toLocaleString()}</div>
                            )}
                            {execution.result?.error && (
                              <div className="text-red-600">Error: {execution.result.error}</div>
                            )}
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* Schedule Form Modal */}
            {showScheduleForm && (
              <Dialog open={showScheduleForm} onOpenChange={setShowScheduleForm}>
                <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
                  <DialogHeader>
                    <DialogTitle>Create New Schedule</DialogTitle>
                    <DialogDescription>Configure automated SCTE-35 event scheduling</DialogDescription>
                  </DialogHeader>
                  <div className="space-y-4">
                    <div className="grid grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label htmlFor="scheduleName">Schedule Name</Label>
                        <Input
                          id="scheduleName"
                          value={newSchedule.name || ''}
                          onChange={(e) => setNewSchedule(prev => ({ ...prev, name: e.target.value }))}
                          placeholder="Morning Ad Break"
                        />
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="scheduleStream">Stream</Label>
                        <Select value={newSchedule.stream || ''} onValueChange={(value) => setNewSchedule(prev => ({ ...prev, stream: value }))}>
                          <SelectTrigger>
                            <SelectValue placeholder="Select stream" />
                          </SelectTrigger>
                          <SelectContent>
                            <SelectItem value="main">Main Stream</SelectItem>
                            <SelectItem value="backup">Backup Stream</SelectItem>
                          </SelectContent>
                        </Select>
                      </div>
                    </div>

                    <div className="grid grid-cols-3 gap-4">
                      <div className="space-y-2">
                        <Label htmlFor="scheduleType">Event Type</Label>
                        <Select value={newSchedule.type || 'CUE-OUT'} onValueChange={(value: any) => setNewSchedule(prev => ({ ...prev, type: value }))}>
                          <SelectTrigger>
                            <SelectValue />
                          </SelectTrigger>
                          <SelectContent>
                            <SelectItem value="CUE-OUT">CUE-OUT</SelectItem>
                            <SelectItem value="BREAK">BREAK</SelectItem>
                            <SelectItem value="PREROLL">PREROLL</SelectItem>
                            <SelectItem value="MIDROLL">MIDROLL</SelectItem>
                            <SelectItem value="POSTROLL">POSTROLL</SelectItem>
                          </SelectContent>
                        </Select>
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="scheduleDuration">Duration (seconds)</Label>
                        <Input
                          id="scheduleDuration"
                          type="number"
                          value={newSchedule.duration || 30}
                          onChange={(e) => setNewSchedule(prev => ({ ...prev, duration: parseInt(e.target.value) }))}
                        />
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="schedulePreRoll">Pre-roll (seconds)</Label>
                        <Input
                          id="schedulePreRoll"
                          type="number"
                          value={newSchedule.preRoll || 2}
                          onChange={(e) => setNewSchedule(prev => ({ ...prev, preRoll: parseInt(e.target.value) }))}
                        />
                      </div>
                    </div>

                    <div className="space-y-2">
                      <Label>Recurrence</Label>
                      <Select value={newSchedule.recurrence?.type || 'daily'} onValueChange={(value: any) => setNewSchedule(prev => ({ 
                        ...prev, 
                        recurrence: { ...prev.recurrence!, type: value }
                      }))}>
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="none">No Recurrence</SelectItem>
                          <SelectItem value="hourly">Hourly</SelectItem>
                          <SelectItem value="daily">Daily</SelectItem>
                          <SelectItem value="weekly">Weekly</SelectItem>
                          <SelectItem value="monthly">Monthly</SelectItem>
                          <SelectItem value="custom">Custom</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>

                    {newSchedule.recurrence?.type === 'daily' && (
                      <div className="space-y-2">
                        <Label htmlFor="scheduleTime">Time</Label>
                        <Input
                          id="scheduleTime"
                          type="time"
                          value={newSchedule.recurrence?.time || '12:00'}
                          onChange={(e) => setNewSchedule(prev => ({ 
                            ...prev, 
                            recurrence: { ...prev.recurrence!, time: e.target.value }
                          }))}
                        />
                      </div>
                    )}

                    <div className="flex justify-end space-x-2">
                      <Button variant="outline" onClick={() => setShowScheduleForm(false)}>
                        Cancel
                      </Button>
                      <Button onClick={() => {
                        if (newSchedule.name && newSchedule.stream) {
                          const schedule: AdSchedule = {
                            id: Date.now().toString(),
                            name: newSchedule.name,
                            stream: newSchedule.stream,
                            type: newSchedule.type as any,
                            duration: newSchedule.duration || 30,
                            preRoll: newSchedule.preRoll || 2,
                            enabled: true,
                            recurrence: newSchedule.recurrence!,
                            restrictions: newSchedule.restrictions!,
                            targeting: newSchedule.targeting!,
                            metadata: newSchedule.metadata!,
                            createdAt: new Date().toISOString(),
                            updatedAt: new Date().toISOString(),
                            triggerCount: 0,
                            status: 'active'
                          }
                          setAdSchedules(prev => [...prev, schedule])
                          setShowScheduleForm(false)
                          setNewSchedule({
                            name: '',
                            stream: '',
                            type: 'CUE-OUT',
                            duration: 30,
                            preRoll: 2,
                            enabled: true,
                            recurrence: {
                              type: 'daily',
                              interval: 1,
                              time: '12:00',
                              days: [1, 2, 3, 4, 5]
                            },
                            restrictions: {
                              maxPerHour: 4,
                              minInterval: 300,
                              contentRestrictions: {
                                maxPerDay: 24
                              }
                            },
                            targeting: {},
                            metadata: {}
                          })
                          toast({
                            title: "Schedule Created",
                            description: `${schedule.name} has been created successfully`,
                          })
                        }
                      }}>
                        Create Schedule
                      </Button>
                    </div>
                  </div>
                </DialogContent>
              </Dialog>
            )}
          </TabsContent>
        </Tabs>
      </div>

      {/* OBS Configuration Manual Display */}
      <Dialog open={showOBSConfig} onOpenChange={setShowOBSConfig}>
        <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>OBS Studio Configuration</DialogTitle>
            <DialogDescription>Manual configuration for OBS Studio - Copy these settings directly</DialogDescription>
          </DialogHeader>
          <div className="space-y-6">
            {/* Basic Configuration */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Settings className="w-5 h-5" />
                  Basic Settings
                </CardTitle>
                <CardDescription>Essential OBS Studio configuration</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <Label className="text-sm font-medium">Stream Name</Label>
                    <div className="mt-1 p-2 bg-muted rounded font-mono text-sm">
                      {obsConfig?.obsJsonConfig?.name || streamConfig.serviceName}
                    </div>
                  </div>
                  <div>
                    <Label className="text-sm font-medium">Server URL</Label>
                    <div className="mt-1 p-2 bg-muted rounded font-mono text-sm break-all">
                      {obsConfig?.obsJsonConfig?.settings?.server || `rtmp://localhost:${mediaServerConfig.rtmpPort}/live`}
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Video Configuration */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Video className="w-5 h-5" />
                  Video Settings
                </CardTitle>
                <CardDescription>Video encoding and output settings</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                  <div>
                    <Label className="text-sm font-medium">Resolution</Label>
                    <div className="mt-1 p-2 bg-muted rounded font-mono text-sm">
                      {streamConfig.videoResolution}
                    </div>
                  </div>
                  <div>
                    <Label className="text-sm font-medium">Bitrate</Label>
                    <div className="mt-1 p-2 bg-muted rounded font-mono text-sm">
                      {streamConfig.videoBitrate} Mbps
                    </div>
                  </div>
                  <div>
                    <Label className="text-sm font-medium">FPS</Label>
                    <div className="mt-1 p-2 bg-muted rounded font-mono text-sm">
                      29.97
                    </div>
                  </div>
                  <div>
                    <Label className="text-sm font-medium">Codec</Label>
                    <div className="mt-1 p-2 bg-muted rounded font-mono text-sm">
                      {streamConfig.videoCodec}
                    </div>
                  </div>
                  <div>
                    <Label className="text-sm font-medium">Profile</Label>
                    <div className="mt-1 p-2 bg-muted rounded font-mono text-sm">
                      {streamConfig.profileLevel}
                    </div>
                  </div>
                  <div>
                    <Label className="text-sm font-medium">GOP Size</Label>
                    <div className="mt-1 p-2 bg-muted rounded font-mono text-sm">
                      {streamConfig.gop} seconds
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Audio Configuration */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Volume2 className="w-5 h-5" />
                  Audio Settings
                </CardTitle>
                <CardDescription>Audio encoding configuration</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                  <div>
                    <Label className="text-sm font-medium">Bitrate</Label>
                    <div className="mt-1 p-2 bg-muted rounded font-mono text-sm">
                      {streamConfig.audioBitrate} kbps
                    </div>
                  </div>
                  <div>
                    <Label className="text-sm font-medium">Codec</Label>
                    <div className="mt-1 p-2 bg-muted rounded font-mono text-sm">
                      {streamConfig.audioCodec}
                    </div>
                  </div>
                  <div>
                    <Label className="text-sm font-medium">Sample Rate</Label>
                    <div className="mt-1 p-2 bg-muted rounded font-mono text-sm">
                      {streamConfig.audioSamplingRate} kHz
                    </div>
                  </div>
                  <div>
                    <Label className="text-sm font-medium">Target Level</Label>
                    <div className="mt-1 p-2 bg-muted rounded font-mono text-sm">
                      {streamConfig.audioLKFS} LKFS
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* SCTE-35 Configuration */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <RadioIcon className="w-5 h-5" />
                  SCTE-35 Settings
                </CardTitle>
                <CardDescription>SCTE-35 insertion configuration (for reference)</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                  <div>
                    <Label className="text-sm font-medium">Data PID</Label>
                    <div className="mt-1 p-2 bg-muted rounded font-mono text-sm">
                      {streamConfig.scteDataPID}
                    </div>
                  </div>
                  <div>
                    <Label className="text-sm font-medium">Null PID</Label>
                    <div className="mt-1 p-2 bg-muted rounded font-mono text-sm">
                      {streamConfig.nullPID}
                    </div>
                  </div>
                  <div>
                    <Label className="text-sm font-medium">Latency</Label>
                    <div className="mt-1 p-2 bg-muted rounded font-mono text-sm">
                      {streamConfig.latency} ms
                    </div>
                  </div>
                </div>
                <Alert>
                  <AlertTriangle className="h-4 w-4" />
                  <AlertDescription>
                    Note: SCTE-35 insertion is handled externally by the media server, not within OBS Studio itself.
                  </AlertDescription>
                </Alert>
              </CardContent>
            </Card>

            {/* Configuration File Content */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <FileText className="w-5 h-5" />
                  Configuration File
                </CardTitle>
                <CardDescription>INI format configuration for OBS Studio</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="bg-muted p-4 rounded-lg">
                  <pre className="text-xs overflow-x-auto whitespace-pre-wrap">
                    {obsConfig?.obsBasicConfig || 'Configuration not available'}
                  </pre>
                </div>
              </CardContent>
            </Card>

            {/* Action Buttons */}
            <div className="flex justify-between items-center pt-4 border-t">
              <div className="text-sm text-muted-foreground">
                Copy individual sections or the complete configuration
              </div>
              <div className="flex gap-2">
                <Button 
                  variant="outline" 
                  onClick={() => {
                    const basicConfig = obsConfig?.obsBasicConfig || ''
                    copyToClipboard(basicConfig)
                  }}
                >
                  <Copy className="w-4 h-4 mr-2" />
                  Copy INI Config
                </Button>
                <Button 
                  variant="outline" 
                  onClick={() => {
                    const jsonConfig = JSON.stringify(obsConfig?.obsJsonConfig || {}, null, 2)
                    copyToClipboard(jsonConfig)
                  }}
                >
                  <Copy className="w-4 h-4 mr-2" />
                  Copy JSON Config
                </Button>
                <Button variant="outline" onClick={() => setShowOBSConfig(false)}>
                  Close
                </Button>
              </div>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  )
}