'use client'

import { useState, useEffect } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Progress } from '@/components/ui/progress'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { 
  Terminal, 
  CheckCircle, 
  XCircle, 
  RefreshCw, 
  Activity,
  Cpu,
  HardDrive,
  Zap
} from 'lucide-react'

interface FFmpegStatus {
  installed: boolean
  version: string
  path: string
  buildConfig: string[]
  processes: FFmpegProcess[]
}

interface FFmpegProcess {
  pid: number
  command: string
  cpu: number
  memory: number
  status: 'running' | 'stopped' | 'error'
  startTime: Date
  uptime: number
}

export default function FFmpegStatus() {
  const [ffmpegStatus, setFFmpegStatus] = useState<FFmpegStatus | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const checkFFmpegStatus = async () => {
    setLoading(true)
    setError(null)
    
    try {
      const response = await fetch('/api/ffmpeg/status')
      if (!response.ok) {
        throw new Error('Failed to check FFmpeg status')
      }
      
      const data = await response.json()
      setFFmpegStatus(data)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error')
      setFFmpegStatus(null)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    checkFFmpegStatus()
    
    // Auto-refresh every 30 seconds
    const interval = setInterval(checkFFmpegStatus, 30000)
    return () => clearInterval(interval)
  }, [])

  const formatUptime = (seconds: number) => {
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    const secs = seconds % 60
    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }

  if (loading && !ffmpegStatus) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center space-x-2">
            <Terminal className="w-5 h-5" />
            <span>FFmpeg Status</span>
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-center justify-center py-8">
            <RefreshCw className="w-6 h-6 animate-spin mr-2" />
            <span>Checking FFmpeg status...</span>
          </div>
        </CardContent>
      </Card>
    )
  }

  if (error) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center space-x-2">
            <Terminal className="w-5 h-5" />
            <span>FFmpeg Status</span>
          </CardTitle>
        </CardHeader>
        <CardContent>
          <Alert variant="destructive">
            <XCircle className="w-4 h-4" />
            <AlertDescription>
              {error}
            </AlertDescription>
          </Alert>
          <Button onClick={checkFFmpegStatus} className="mt-4" variant="outline">
            <RefreshCw className="w-4 h-4 mr-2" />
            Retry
          </Button>
        </CardContent>
      </Card>
    )
  }

  if (!ffmpegStatus) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center space-x-2">
            <Terminal className="w-5 h-5" />
            <span>FFmpeg Status</span>
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-center py-8 text-muted-foreground">
            <Terminal className="w-12 h-12 mx-auto mb-4" />
            <p>Unable to check FFmpeg status</p>
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center space-x-2">
          <Terminal className="w-5 h-5" />
          <span>FFmpeg Status</span>
          <Button 
            onClick={checkFFmpegStatus} 
            variant="outline" 
            size="sm"
            className="ml-auto"
          >
            <RefreshCw className="w-4 h-4" />
          </Button>
        </CardTitle>
        <CardDescription>
          FFmpeg installation status and running processes
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* Installation Status */}
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium">Installation Status</span>
            <Badge variant={ffmpegStatus.installed ? 'default' : 'destructive'}>
              {ffmpegStatus.installed ? (
                <>
                  <CheckCircle className="w-3 h-3 mr-1" />
                  Installed
                </>
              ) : (
                <>
                  <XCircle className="w-3 h-3 mr-1" />
                  Not Installed
                </>
              )}
            </Badge>
          </div>

          {ffmpegStatus.installed && (
            <>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <Label className="text-sm font-medium">Version</Label>
                  <div className="text-sm text-muted-foreground mt-1">
                    {ffmpegStatus.version}
                  </div>
                </div>
                <div>
                  <Label className="text-sm font-medium">Path</Label>
                  <div className="text-sm text-muted-foreground mt-1 font-mono">
                    {ffmpegStatus.path}
                  </div>
                </div>
              </div>

              {ffmpegStatus.buildConfig && ffmpegStatus.buildConfig.length > 0 && (
                <div>
                  <Label className="text-sm font-medium">Build Configuration</Label>
                  <div className="mt-2 p-3 bg-gray-50 rounded text-xs font-mono max-h-32 overflow-y-auto">
                    {ffmpegStatus.buildConfig.join('\n')}
                  </div>
                </div>
              )}
            </>
          )}
        </div>

        {/* Running Processes */}
        {ffmpegStatus.installed && (
          <>
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium">Active Processes</span>
                <Badge variant="secondary">
                  {ffmpegStatus.processes.length} running
                </Badge>
              </div>

              {ffmpegStatus.processes.length > 0 ? (
                <div className="space-y-2">
                  {ffmpegStatus.processes.map((process) => (
                    <div key={process.pid} className="p-3 border rounded-lg">
                      <div className="flex items-center justify-between mb-2">
                        <div className="flex items-center space-x-2">
                          <Activity className="w-4 h-4" />
                          <span className="text-sm font-medium">PID {process.pid}</span>
                          <Badge variant={process.status === 'running' ? 'default' : 'secondary'}>
                            {process.status}
                          </Badge>
                        </div>
                        <span className="text-xs text-muted-foreground">
                          {formatUptime(process.uptime)}
                        </span>
                      </div>
                      
                      <div className="text-xs text-muted-foreground mb-2 font-mono truncate">
                        {process.command}
                      </div>
                      
                      <div className="grid grid-cols-2 gap-4">
                        <div className="flex items-center space-x-2">
                          <Cpu className="w-3 h-3" />
                          <span className="text-xs">CPU: {process.cpu.toFixed(1)}%</span>
                          <Progress value={process.cpu} className="h-1 flex-1" />
                        </div>
                        <div className="flex items-center space-x-2">
                          <HardDrive className="w-3 h-3" />
                          <span className="text-xs">Memory: {process.memory.toFixed(1)}%</span>
                          <Progress value={process.memory} className="h-1 flex-1" />
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-4 text-muted-foreground">
                  <Activity className="w-8 h-8 mx-auto mb-2" />
                  <p className="text-sm">No FFmpeg processes running</p>
                </div>
              )}
            </div>
          </>
        )}

        {/* Installation Instructions */}
        {!ffmpegStatus.installed && (
          <Alert>
            <XCircle className="w-4 h-4" />
            <AlertDescription>
              FFmpeg is not installed. Please install it using:
              <div className="mt-2 p-2 bg-gray-100 rounded font-mono text-sm">
                sudo apt install -y ffmpeg
              </div>
            </AlertDescription>
          </Alert>
        )}
      </CardContent>
    </Card>
  )
}

function Label({ children, className }: { children: React.ReactNode; className?: string }) {
  return <div className={className}>{children}</div>
}