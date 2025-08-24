import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { app, name, addr, flashver, swfurl, tcurl, pageurl } = body;

    console.log('RTMP Play Event:', {
      app,
      name,
      addr,
      flashver,
      swfurl,
      tcurl,
      pageurl,
      timestamp: new Date().toISOString()
    });

    // Here you can add logic to handle stream play events
    // For example: track viewers, update analytics, etc.

    return NextResponse.json({ 
      success: true, 
      message: 'Play event received',
      stream: name,
      client: addr,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error handling play event:', error);
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    );
  }
}