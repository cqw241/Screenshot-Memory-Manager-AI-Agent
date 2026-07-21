import { http } from '@kit.NetworkKit';
import {
  HttpTransport,
  HttpTransportRequest,
  HttpTransportResponse,
  TransportError,
  TransportErrorKind
} from '../models/VerificationModels';

interface RequestHeaders {
  'Content-Type': string;
  Authorization: string;
}

export class HarmonyHttpTransport implements HttpTransport {
  async send(request: HttpTransportRequest): Promise<HttpTransportResponse> {
    const client: http.HttpRequest = http.createHttp();
    const headers: RequestHeaders = {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${request.apiKey}`
    };
    try {
      const response: http.HttpResponse = await client.request(request.url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: request.body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: request.timeoutMs,
        readTimeout: request.timeoutMs,
        usingCache: false
      });
      const body: string = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      return { statusCode: response.responseCode as number, body: body };
    } catch (error) {
      const message: string = (error as Error).message.toLowerCase();
      const timeout: boolean = message.includes('timeout') || message.includes('timed out');
      throw new TransportError(timeout ? TransportErrorKind.TIMEOUT : TransportErrorKind.NETWORK);
    } finally {
      headers.Authorization = '';
      client.destroy();
    }
  }
}
