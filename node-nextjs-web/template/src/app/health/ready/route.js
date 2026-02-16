export async function GET() {
  return Response.json({
    status: 'ready',
    timestamp: new Date().toISOString(),
  });
}
