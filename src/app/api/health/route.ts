/**
 * SCTE-35 Streaming Control Center - Health Check API
 * 
 * © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.
 * 
 * This software is the property of Morus Broadcasting Pvt Ltd and is protected by
 * copyright law and international treaties. Unauthorized use, reproduction, or
 * distribution is strictly prohibited.
 */

import { NextResponse } from "next/server";

export async function GET() {
  return NextResponse.json({ message: "Good!" });
}