import { Controller, All, Get, Req, Res, Logger, HttpStatus } from '@nestjs/common';
import { Request, Response } from 'express';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosResponse } from 'axios';

/**
 * Timeouts pour les requêtes proxy (configurables via env)
 * - AI_TIMEOUT: Pour les routes chat/adha/analysis qui communiquent avec ADHA AI (120s)
 * - STREAMING_TIMEOUT: Pour les routes SSE/streaming (180s - plus long car flux continu)
 * - DEFAULT_TIMEOUT: Pour les autres routes (30s)
 */
const AI_TIMEOUT = parseInt(process.env.AI_TIMEOUT || '120000');
const STREAMING_TIMEOUT = parseInt(process.env.STREAMING_TIMEOUT || '180000');
const DEFAULT_TIMEOUT = parseInt(process.env.DEFAULT_TIMEOUT || '30000');

/**
 * Headers spécifiques pour les requêtes SSE/streaming
 */
const SSE_HEADERS = {
  'Cache-Control': 'no-cache, no-transform',
  'Connection': 'keep-alive',
  'X-Accel-Buffering': 'no', // Désactive le buffering Nginx
};

/**
 * Vérifie si une route nécessite un timeout étendu (routes AI)
 */
function isAiRoute(path: string): boolean {
  return path.includes('/chat') || path.includes('/adha') || path.includes('/analysis');
}

/**
 * Vérifie si la requête est pour du streaming SSE
 */
function isStreamingRequest(req: Request): boolean {
  const acceptHeader = req.headers.accept || '';
  const pathHints = req.path.includes('/stream') || req.path.includes('/duplex');
  return acceptHeader.includes('text/event-stream') || pathHints;
}

@ApiTags('proxy')
@Controller()
export class ProxyController {
  private readonly logger = new Logger(ProxyController.name);
  
  constructor(private readonly configService: ConfigService) {
    this.logger.log('🚀 ProxyController initialized - Ready to handle requests');
  }

  // Health endpoint removed to avoid conflict with HealthModule
  // The dedicated HealthController in HealthModule handles /health requests

  @All('land/api/v1/*')
  @ApiOperation({ 
    summary: 'Proxy to Customer Service',
    description: 'Routes all requests starting with land/api/v1 to the customer service'
  })
  @ApiResponse({ status: 200, description: 'Request successfully proxied' })
  @ApiResponse({ status: 404, description: 'Service not found' })
  @ApiResponse({ status: 500, description: 'Internal server error' })
  async proxyToCustomerService(@Req() req: Request, @Res() res: Response): Promise<void> {
    const { method, path, headers, body } = req;
    const startTime = Date.now();
    
    this.logger.log(`🚀 CUSTOMER SERVICE PROXY: ${method} ${path}`);
    this.logger.log(`📋 Headers received: ${JSON.stringify(Object.keys(headers))}`);
    
    // Check for Authorization header (case insensitive)
    const authHeader = headers.authorization || headers.Authorization;
    if (authHeader) {
      const authValue = Array.isArray(authHeader) ? authHeader[0] : authHeader;
      this.logger.log(`🔑 Authorization header found and will be forwarded: ${authValue.substring(0, 20)}...`);
    } else {
      this.logger.log(`❌ No Authorization header found - this may cause authentication issues`);
    }
    
    try {
      // Extract path after 'land/api/v1'
      const targetPath = path.replace('/land/api/v1', '');
      const customerServiceUrl = this.configService.get('CUSTOMER_SERVICE_URL', 'http://kiota-customer-service-dev:3011');
      const targetUrl = `${customerServiceUrl}${targetPath}`;
      
      this.logger.log(`📡 Forwarding to: ${targetUrl}`);
      
      // Prepare headers - ensure Authorization header is properly forwarded
      const forwardHeaders: Record<string, any> = {};
      
      // Copy all headers except problematic ones
      Object.keys(headers).forEach(key => {
        if (!['host', 'content-length', 'connection'].includes(key.toLowerCase())) {
          forwardHeaders[key] = headers[key];
        }
      });
      
      // Ensure Authorization header is explicitly set (both cases)
      if (authHeader) {
        const authValue = Array.isArray(authHeader) ? authHeader[0] : authHeader;
        forwardHeaders['Authorization'] = authValue;
        forwardHeaders['authorization'] = authValue; // Sometimes lowercase is needed
        this.logger.log(`🔑 Authorization header explicitly set in forward headers: ${authValue.substring(0, 20)}...`);
      }
      
      // Set correct host for the target service
      forwardHeaders['host'] = customerServiceUrl.replace('http://', '').replace('https://', '');
      
      this.logger.log(`📤 Forward headers keys: ${JSON.stringify(Object.keys(forwardHeaders))}`);
      
      // Make the request - timeout dynamique selon le type de route
      const timeout = isAiRoute(targetPath) ? AI_TIMEOUT : DEFAULT_TIMEOUT;
      const response: AxiosResponse = await axios({
        method: method.toLowerCase() as any,
        url: targetUrl,
        headers: forwardHeaders,
        data: body,
        timeout,
        validateStatus: () => true
      });
      
      const duration = Date.now() - startTime;
      this.logger.log(`✅ Customer service responded: ${response.status} (${duration}ms, timeout: ${timeout}ms)`);
      
      if (response.status !== 200) {
        this.logger.warn(`⚠️ Non-200 response from customer service: ${response.status} - ${JSON.stringify(response.data)}`);
      }
      
      // Forward response headers
      if (response.headers) {
        Object.keys(response.headers).forEach(key => {
          if (!['content-encoding', 'content-length', 'transfer-encoding', 'connection'].includes(key.toLowerCase())) {
            res.set(key, response.headers[key]);
          }
        });
      }
      
      res.status(response.status).send(response.data);
      
    } catch (error) {
      const duration = Date.now() - startTime;
      this.handleError(error, req, res, duration);
    }
  }

  @All('adha/api/v1/*')
  @ApiOperation({ 
    summary: 'Proxy to Adha AI Service',
    description: 'Routes all requests starting with adha/api/v1 to the adha-ai service. Supports SSE streaming.'
  })
  @ApiResponse({ status: 200, description: 'Request successfully proxied' })
  @ApiResponse({ status: 404, description: 'Service not found' })
  @ApiResponse({ status: 500, description: 'Internal server error' })
  async proxyToAdhaAiService(@Req() req: Request, @Res() res: Response): Promise<void> {
    const { method, path, headers, body } = req;
    const startTime = Date.now();
    const isStreaming = isStreamingRequest(req);
    
    this.logger.log(`🤖 ADHA AI SERVICE PROXY: ${method} ${path} ${isStreaming ? '[STREAMING]' : ''}`);
    this.logger.log(`📋 Headers received: ${JSON.stringify(Object.keys(headers))}`);
    
    // Check for Authorization header (case insensitive)
    const authHeader = headers.authorization || headers.Authorization;
    if (authHeader) {
      const authValue = Array.isArray(authHeader) ? authHeader[0] : authHeader;
      this.logger.log(`🔑 Authorization header found and will be forwarded: ${authValue.substring(0, 20)}...`);
    } else {
      this.logger.log(`❌ No Authorization header found - this may cause authentication issues`);
    }
    
    try {
      // Extract path after 'adha/api/v1' and add /api prefix for the adha-ai service
      const targetPath = path.replace('/adha/api/v1', '/api');
      const adhaServiceUrl = this.configService.get('ADHA_AI_SERVICE_URL', 'http://kiota-adha-ai-service:8002');
      const targetUrl = `${adhaServiceUrl}${targetPath}`;
      
      this.logger.log(`📡 Forwarding to: ${targetUrl}`);
      
      // Prepare headers - ensure Authorization header is properly forwarded
      const serviceHost = adhaServiceUrl.replace('http://', '').replace('https://', '');
      const forwardHeaders: Record<string, any> = {
        ...headers,
        host: serviceHost
      };
      delete forwardHeaders['content-length'];
      
      // Ensure Authorization header is preserved (case sensitive handling)
      if (authHeader) {
        forwardHeaders['Authorization'] = Array.isArray(authHeader) ? authHeader[0] : authHeader;
        this.logger.log(`🔑 Authorization header set in forward headers`);
      }
      
      // SSE STREAMING MODE
      if (isStreaming) {
        this.logger.log(`🌊 SSE Streaming mode enabled for ${targetUrl}`);
        
        // Add SSE-specific headers to request
        forwardHeaders['Accept'] = 'text/event-stream';
        forwardHeaders['Cache-Control'] = 'no-cache';
        
        const response = await axios({
          method: method.toLowerCase() as any,
          url: targetUrl,
          headers: forwardHeaders,
          data: body,
          timeout: 0, // No timeout for SSE streams
          responseType: 'stream',
          validateStatus: () => true,
        });
        
        // Set SSE headers on response
        res.set({
          'Content-Type': 'text/event-stream',
          ...SSE_HEADERS,
          'Access-Control-Allow-Origin': headers.origin || '*',
          'Access-Control-Allow-Credentials': 'true',
        });
        
        res.status(response.status);
        
        // Pipe the stream directly
        response.data.pipe(res);
        
        // Handle stream close
        req.on('close', () => {
          const duration = Date.now() - startTime;
          this.logger.log(`🔌 SSE stream closed by client after ${duration}ms`);
          response.data.destroy();
        });
        
        response.data.on('error', (error: Error) => {
          this.logger.error(`❌ SSE stream error: ${error.message}`);
          if (!res.headersSent) {
            res.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
              error: 'Stream Error',
              message: error.message,
            });
          }
        });
        
        response.data.on('end', () => {
          const duration = Date.now() - startTime;
          this.logger.log(`✅ SSE stream completed after ${duration}ms`);
        });
        
        return; // Don't send response, stream handles it
      }
      
      // STANDARD REQUEST MODE
      const timeout = isAiRoute(targetPath) ? AI_TIMEOUT : DEFAULT_TIMEOUT;
      const response: AxiosResponse = await axios({
        method: method.toLowerCase() as any,
        url: targetUrl,
        headers: forwardHeaders,
        data: body,
        timeout,
        validateStatus: () => true
      });
      
      const duration = Date.now() - startTime;
      this.logger.log(`✅ Admin service responded: ${response.status} (${duration}ms, timeout: ${timeout}ms)`);
      
      // Forward response headers
      if (response.headers) {
        Object.keys(response.headers).forEach(key => {
          if (!['content-encoding', 'content-length', 'transfer-encoding', 'connection'].includes(key.toLowerCase())) {
            res.set(key, response.headers[key]);
          }
        });
      }
      
      res.status(response.status).send(response.data);
      
    } catch (error) {
      const duration = Date.now() - startTime;
      this.handleError(error, req, res, duration);
    }
  }

  @All('accounting/api/v1/*')
  @ApiOperation({ 
    summary: 'Proxy to Accounting Service',
    description: 'Routes all requests starting with accounting/api/v1 to the accounting service'
  })
  @ApiResponse({ status: 200, description: 'Request successfully proxied' })
  @ApiResponse({ status: 404, description: 'Service not found' })
  @ApiResponse({ status: 500, description: 'Internal server error' })
  async proxyToAccountingService(@Req() req: Request, @Res() res: Response): Promise<void> {
    const { method, path, headers, body } = req;
    const startTime = Date.now();
    
    this.logger.log(`💰 ACCOUNTING SERVICE PROXY: ${method} ${path}`);
    this.logger.log(`📋 Headers received: ${JSON.stringify(Object.keys(headers))}`);
    
    // Check for Authorization header (case insensitive)
    const authHeader = headers.authorization || headers.Authorization;
    if (authHeader) {
      const authValue = Array.isArray(authHeader) ? authHeader[0] : authHeader;
      this.logger.log(`🔑 Authorization header found and will be forwarded: ${authValue.substring(0, 20)}...`);
    } else {
      this.logger.log(`❌ No Authorization header found - this may cause authentication issues`);
    }
    
    try {
      // Extract path after 'accounting/api/v1' - No /v1 prefix needed since accounting service routes are at root level
      const targetPath = path.replace('/accounting/api/v1', '');
      const accountingServiceUrl = this.configService.get('ACCOUNTING_SERVICE_URL', 'http://kiota-accounting-service:3001');
      const targetUrl = `${accountingServiceUrl}${targetPath}`;
      
      this.logger.log(`📡 Forwarding to: ${targetUrl}`);
      
      // Prepare headers - ensure Authorization header is properly forwarded
      const serviceHost = accountingServiceUrl.replace('http://', '').replace('https://', '');
      const forwardHeaders = {
        ...headers,
        host: serviceHost
      };
      delete forwardHeaders['content-length'];
      
      // Ensure Authorization header is preserved (case sensitive handling)
      if (authHeader) {
        forwardHeaders['Authorization'] = Array.isArray(authHeader) ? authHeader[0] : authHeader;
        this.logger.log(`🔑 Authorization header set in forward headers`);
      }
      
      // Make the request - timeout dynamique selon le type de route
      const timeout = isAiRoute(targetPath) ? AI_TIMEOUT : DEFAULT_TIMEOUT;
      const response: AxiosResponse = await axios({
        method: method.toLowerCase() as any,
        url: targetUrl,
        headers: forwardHeaders,
        data: body,
        timeout,
        validateStatus: () => true
      });
      
      const duration = Date.now() - startTime;
      this.logger.log(`✅ Accounting service (long path) responded: ${response.status} (${duration}ms, timeout: ${timeout}ms)`);
      
      // Forward response headers
      if (response.headers) {
        Object.keys(response.headers).forEach(key => {
          if (!['content-encoding', 'content-length', 'transfer-encoding', 'connection'].includes(key.toLowerCase())) {
            res.set(key, response.headers[key]);
          }
        });
      }
      
      res.status(response.status).send(response.data);
      
    } catch (error) {
      const duration = Date.now() - startTime;
      this.handleError(error, req, res, duration);
    }
  }

  @All('portfolio/api/v1/*')
  @ApiOperation({ 
    summary: 'Proxy to Portfolio Institution Service',
    description: 'Routes all requests starting with portfolio/api/v1 to the portfolio-institution service'
  })
  @ApiResponse({ status: 200, description: 'Request successfully proxied' })
  @ApiResponse({ status: 404, description: 'Service not found' })
  @ApiResponse({ status: 500, description: 'Internal server error' })
  async proxyToPortfolioInstitutionService(@Req() req: Request, @Res() res: Response): Promise<void> {
    const { method, path, headers, body } = req;
    const startTime = Date.now();
    
    this.logger.log(`🏦 PORTFOLIO INSTITUTION SERVICE PROXY: ${method} ${path}`);
    this.logger.log(`📋 Headers received: ${JSON.stringify(Object.keys(headers))}`);
    
    // Check for Authorization header (case insensitive)
    const authHeader = headers.authorization || headers.Authorization;
    if (authHeader) {
      const authValue = Array.isArray(authHeader) ? authHeader[0] : authHeader;
      this.logger.log(`🔑 Authorization header found and will be forwarded: ${authValue.substring(0, 20)}...`);
    } else {
      this.logger.log(`❌ No Authorization header found - this may cause authentication issues`);
    }
    
    try {
      // Extract path after 'portfolio/api/v1' and route directly to service root (no /api/v1 prefix)  
      const targetPath = path.replace('/portfolio/api/v1', '');
      const portfolioServiceUrl = this.configService.get('PORTFOLIO_INSTITUTION_SERVICE_URL', 'http://kiota-portfolio-institution-service-dev:3005');
      const targetUrl = `${portfolioServiceUrl}${targetPath}`;
      
      this.logger.log(`📡 Forwarding to: ${targetUrl}`);
      
      // Prepare headers - ensure Authorization header is properly forwarded
      const serviceHost = portfolioServiceUrl.replace('http://', '').replace('https://', '');
      const forwardHeaders = {
        ...headers,
        host: serviceHost
      };
      delete forwardHeaders['content-length'];
      
      // Ensure Authorization header is preserved (case sensitive handling)
      if (authHeader) {
        forwardHeaders['Authorization'] = Array.isArray(authHeader) ? authHeader[0] : authHeader;
        this.logger.log(`🔑 Authorization header set in forward headers`);
      }
      
      // Make the request - timeout dynamique selon le type de route
      const timeout = isAiRoute(targetPath) ? AI_TIMEOUT : DEFAULT_TIMEOUT;
      const response: AxiosResponse = await axios({
        method: method.toLowerCase() as any,
        url: targetUrl,
        headers: forwardHeaders,
        data: body,
        timeout,
        validateStatus: () => true
      });
      
      const duration = Date.now() - startTime;
      this.logger.log(`✅ Portfolio Institution service responded: ${response.status} (${duration}ms, timeout: ${timeout}ms)`);
      
      // Forward response headers
      if (response.headers) {
        Object.keys(response.headers).forEach(key => {
          if (!['content-encoding', 'content-length', 'transfer-encoding', 'connection'].includes(key.toLowerCase())) {
            res.set(key, response.headers[key]);
          }
        });
      }
      
      res.status(response.status).send(response.data);
      
    } catch (error) {
      const duration = Date.now() - startTime;
      this.handleError(error, req, res, duration);
    }
  }

  @All('accounting/*')
  @ApiOperation({ 
    summary: 'Proxy to Accounting Service (Short Path)',
    description: 'Routes all requests starting with accounting/ to the accounting service (backward compatibility)'
  })
  @ApiResponse({ status: 200, description: 'Request successfully proxied' })
  @ApiResponse({ status: 404, description: 'Service not found' })
  @ApiResponse({ status: 500, description: 'Internal server error' })
  async proxyToAccountingServiceShort(@Req() req: Request, @Res() res: Response): Promise<void> {
    const { method, path, headers, body } = req;
    const startTime = Date.now();
    
    this.logger.log(`💰 ACCOUNTING SERVICE PROXY (SHORT): ${method} ${path}`);
    this.logger.log(`📋 Headers received: ${JSON.stringify(Object.keys(headers))}`);
    
    // Check for Authorization header (case insensitive)
    const authHeader = headers.authorization || headers.Authorization;
    if (authHeader) {
      const authValue = Array.isArray(authHeader) ? authHeader[0] : authHeader;
      this.logger.log(`🔑 Authorization header found and will be forwarded: ${authValue.substring(0, 20)}...`);
    } else {
      this.logger.log(`❌ No Authorization header found - this may cause authentication issues`);
    }
    
    try {
      // Extract path after 'accounting' without adding /v1 prefix since accounting service routes are at root level
      const targetPath = path.replace('/accounting', '');
      const accountingServiceUrl = this.configService.get('ACCOUNTING_SERVICE_URL', 'http://kiota-accounting-service:3001');
      const targetUrl = `${accountingServiceUrl}${targetPath}`;
      
      this.logger.log(`📡 Forwarding to: ${targetUrl}`);
      
      // Prepare headers - ensure Authorization header is properly forwarded
      const serviceHost = accountingServiceUrl.replace('http://', '').replace('https://', '');
      const forwardHeaders = {
        ...headers,
        host: serviceHost
      };
      delete forwardHeaders['content-length'];
      
      // Ensure Authorization header is preserved (case sensitive handling)
      if (authHeader) {
        forwardHeaders['Authorization'] = Array.isArray(authHeader) ? authHeader[0] : authHeader;
        this.logger.log(`🔑 Authorization header set in forward headers`);
      }
      
      // Make the request - timeout dynamique selon le type de route
      const timeout = isAiRoute(targetPath) ? AI_TIMEOUT : DEFAULT_TIMEOUT;
      const response: AxiosResponse = await axios({
        method: method.toLowerCase() as any,
        url: targetUrl,
        headers: forwardHeaders,
        data: body,
        timeout,
        validateStatus: () => true
      });
      
      const duration = Date.now() - startTime;
      this.logger.log(`✅ Accounting service responded: ${response.status} (${duration}ms, timeout: ${timeout}ms)`);
      
      // Forward response headers
      if (response.headers) {
        Object.keys(response.headers).forEach(key => {
          if (!['content-encoding', 'content-length', 'transfer-encoding', 'connection'].includes(key.toLowerCase())) {
            res.set(key, response.headers[key]);
          }
        });
      }
      
      res.status(response.status).send(response.data);
      
    } catch (error) {
      const duration = Date.now() - startTime;
      this.handleError(error, req, res, duration);
    }
  }

  @All('commerce/api/v1/*')
  @ApiOperation({ 
    summary: 'Proxy to Commerce Service',
    description: 'Routes all requests starting with commerce/api/v1 to the gestion commerciale service (mobile app)'
  })
  @ApiResponse({ status: 200, description: 'Request successfully proxied' })
  @ApiResponse({ status: 404, description: 'Service not found' })
  @ApiResponse({ status: 500, description: 'Internal server error' })
  async proxyToCommerceService(@Req() req: Request, @Res() res: Response): Promise<void> {
    const { method, path, headers, body } = req;
    const startTime = Date.now();
    
    this.logger.log(`🛒 COMMERCE SERVICE PROXY: ${method} ${path}`);
    this.logger.log(`📋 Headers received: ${JSON.stringify(Object.keys(headers))}`);
    
    // Check for Authorization header (case insensitive)
    const authHeader = headers.authorization || headers.Authorization;
    if (authHeader) {
      const authValue = Array.isArray(authHeader) ? authHeader[0] : authHeader;
      this.logger.log(`🔑 Authorization header found and will be forwarded: ${authValue.substring(0, 20)}...`);
    } else {
      this.logger.log(`❌ No Authorization header found - this may cause authentication issues`);
    }
    
    try {
      // Extract path after 'commerce/api/v1' and prepend /api since commerce service has global prefix 'api'
      const targetPath = path.replace('/commerce/api/v1', '/api');
      
      const commerceServiceUrl = this.configService.get('COMMERCE_SERVICE_URL', 'http://kiota-gestion-commerciale-service:3006');
      const targetUrl = `${commerceServiceUrl}${targetPath}`;
      
      this.logger.log(`📡 Forwarding to: ${targetUrl}`);
      
      // Prepare headers - ensure Authorization header is properly forwarded
      const serviceHost = commerceServiceUrl.replace('http://', '').replace('https://', '');
      const forwardHeaders = {
        ...headers,
        host: serviceHost
      };
      delete forwardHeaders['content-length'];
      
      // Ensure Authorization header is preserved (case sensitive handling)
      if (authHeader) {
        forwardHeaders['Authorization'] = Array.isArray(authHeader) ? authHeader[0] : authHeader;
        this.logger.log(`🔑 Authorization header set in forward headers`);
      }
      
      const timeout = isAiRoute(targetPath) ? AI_TIMEOUT : DEFAULT_TIMEOUT;
      const response = await axios({
        method: method.toLowerCase() as any,
        url: targetUrl,
        headers: forwardHeaders,
        data: body,
        timeout,
        validateStatus: () => true // Accept all status codes
      });
      
      const duration = Date.now() - startTime;
      this.logger.log(`✅ COMMERCE SERVICE RESPONSE: ${response.status} (${duration}ms, timeout: ${timeout}ms)`);
      
      // Forward response headers
      Object.entries(response.headers).forEach(([key, value]) => {
        if (key.toLowerCase() !== 'transfer-encoding') {
          res.set(key, value as string);
        }
      });
      
      res.status(response.status).send(response.data);
      
    } catch (error) {
      const duration = Date.now() - startTime;
      this.handleError(error, req, res, duration);
    }
  }

  @All('admin/api/v1/*')
  @ApiOperation({ 
    summary: 'Proxy to Admin Service',
    description: 'Routes all requests starting with admin/api/v1 to the admin service'
  })
  @ApiResponse({ status: 200, description: 'Request successfully proxied' })
  @ApiResponse({ status: 404, description: 'Service not found' })
  @ApiResponse({ status: 500, description: 'Internal server error' })
  async proxyToAdminService(@Req() req: Request, @Res() res: Response): Promise<void> {
    const { method, path, headers, body } = req;
    const startTime = Date.now();
    
    this.logger.log(`🚀 ADMIN SERVICE PROXY: ${method} ${path}`);
    this.logger.log(`📋 Headers received: ${JSON.stringify(Object.keys(headers))}`);
    
    // Check for Authorization header (case insensitive)
    const authHeader = headers.authorization || headers.Authorization;
    if (authHeader) {
      const authValue = Array.isArray(authHeader) ? authHeader[0] : authHeader;
      this.logger.log(`🔑 Authorization header found and will be forwarded: ${authValue.substring(0, 20)}...`);
    } else {
      this.logger.log(`❌ No Authorization header found - this may cause authentication issues`);
    }
    
    try {
      // Extract path after 'admin/api' and keep '/v1' for admin service versioning
      const targetPath = path.replace('/admin/api', '');
      
      const adminServiceUrl = this.configService.get('ADMIN_SERVICE_URL', 'http://kiota-admin-service-dev:3001');
      const targetUrl = `${adminServiceUrl}${targetPath}`;
      
      this.logger.log(`📡 Forwarding to: ${targetUrl}`);
      
      // Prepare headers - ensure Authorization header is properly forwarded
      const serviceHost = adminServiceUrl.replace('http://', '').replace('https://', '');
      const forwardHeaders = {
        ...headers,
        host: serviceHost
      };
      delete forwardHeaders['content-length'];
      
      // Ensure Authorization header is preserved (case sensitive handling)
      if (authHeader) {
        forwardHeaders['Authorization'] = Array.isArray(authHeader) ? authHeader[0] : authHeader;
        this.logger.log(`🔑 Authorization header set in forward headers`);
      }
      
      const timeout = isAiRoute(targetPath) ? AI_TIMEOUT : DEFAULT_TIMEOUT;
      const response = await axios({
        method: method.toLowerCase() as any,
        url: targetUrl,
        headers: forwardHeaders,
        data: body,
        timeout,
        validateStatus: () => true // Accept all status codes
      });
      
      const duration = Date.now() - startTime;
      this.logger.log(`✅ ADMIN SERVICE RESPONSE: ${response.status} (${duration}ms, timeout: ${timeout}ms)`);
      
      // Forward response headers
      Object.entries(response.headers).forEach(([key, value]) => {
        if (key.toLowerCase() !== 'transfer-encoding') {
          res.set(key, value as string);
        }
      });
      
      res.status(response.status).send(response.data);
      
    } catch (error) {
      const duration = Date.now() - startTime;
      this.handleError(error, req, res, duration);
    }
  }

  @All('*')
  @ApiOperation({ 
    summary: 'Catch-All Route',
    description: 'Handles all requests that don\'t match specific routes'
  })
  async catchAll(@Req() req: Request, @Res() res: Response): Promise<void> {
    const { method, path } = req;
    
    this.logger.warn(`🚫 CATCH-ALL: No route found for ${method} ${path}`);
    
    res.status(HttpStatus.NOT_FOUND).json({
      error: 'Route Not Found',
      message: `No service configured to handle path: ${path}`,
      path: path,
      method: method,
      timestamp: new Date().toISOString(),
      availableRoutes: [
        'GET /health - API Gateway health check',
        'ANY /admin/api/v1/* - Admin service routes',
        'ANY /land/api/v1/* - Customer service routes',
        'ANY /portfolio/api/v1/* - Portfolio Institution service routes',
        'ANY /adha/api/v1/* - Adha AI service routes',
        'ANY /accounting/api/v1/* - Accounting service routes (full path)',
        'ANY /accounting/* - Accounting service routes (short path)',
        'ANY /commerce/api/v1/* - Commerce service routes (mobile app)'
      ]
    });
  }

  private handleError(error: unknown, req: Request, res: Response, duration: number): void {
    const { method, path } = req;
    
    if (axios.isAxiosError(error)) {
      const status = error.response?.status || HttpStatus.BAD_GATEWAY;
      const message = error.response?.data?.message || error.message || 'Service unavailable';
      
      this.logger.error(`❌ Proxy error: ${method} ${path} → ${status} (${duration}ms) - ${message}`);
      
      res.status(status).json({
        error: 'Proxy Error',
        message: message,
        path: path,
        targetService: error.config?.url || 'unknown',
        timestamp: new Date().toISOString()
      });
    } else {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(`❌ Unexpected error: ${method} ${path} (${duration}ms)`, error);
      
      res.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
        error: 'Internal Server Error',
        message: 'An unexpected error occurred while processing the request',
        path: path,
        timestamp: new Date().toISOString()
      });
    }
  }
}
