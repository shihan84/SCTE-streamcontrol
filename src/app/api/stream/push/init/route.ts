/**
 * SCTE-35 Streaming Control Center - Push Stream Initialization API
 * 
 * This endpoint initializes the global streaming components
 * 
 * © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.
 */

import { NextRequest, NextResponse } from 'next/server';
import { GlobalInstanceManager } from '@/lib/global-instances';

export async function POST(request: NextRequest) {
    try {
        const result = await GlobalInstanceManager.initialize();
        
        if (result.success) {
            return NextResponse.json({
                success: true,
                message: 'Streaming components initialized successfully',
                status: GlobalInstanceManager.getStatus()
            });
        } else {
            return NextResponse.json({
                success: false,
                error: 'Failed to initialize streaming components',
                details: result.error
            }, { status: 500 });
        }

    } catch (error) {
        console.error('❌ Error in initialization endpoint:', error);
        return NextResponse.json({
            success: false,
            error: 'Failed to initialize streaming components',
            details: error instanceof Error ? error.message : 'Unknown error'
        }, { status: 500 });
    }
}

export async function GET() {
    return NextResponse.json({
        success: true,
        ...GlobalInstanceManager.getStatus()
    });
}