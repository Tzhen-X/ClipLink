import http from '@ohos.net.http';
import { BusinessError } from '@kit.BasicServicesKit';
import { MultipartField } from '../types/ApiTypes';

/**
 * HTTP Client - simple wrapper for SyncClipboard API requests
 */
export class HttpClient {
  private baseUrl: string = '';
  private username: string = '';
  private password: string = '';

  constructor(baseUrl?: string, username?: string, password?: string) {
    if (baseUrl) {
      this.setBaseUrl(baseUrl);
    }
    if (username) {
      this.username = username;
    }
    if (password) {
      this.password = password;
    }
  }

  /**
   * Set base URL
   */
  setBaseUrl(url: string): void {
    this.baseUrl = url.endsWith('/') ? url.slice(0, -1) : url;
  }

  /**
   * Set credentials
   */
  setCredentials(username: string, password: string): void {
    this.username = username;
    this.password = password;
  }

  /**
   * Create authorization header
   */
  private getAuthHeader(): string {
    if (this.username && this.password) {
      const credentials = `${this.username}:${this.password}`;
      const encoded = this.base64Encode(credentials);
      return `Basic ${encoded}`;
    }
    return '';
  }

  /**
   * Simple base64 encoding
   */
  private base64Encode(str: string): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    const bytes: number[] = this.stringToBytes(str);
    let result = '';
    for (let i = 0; i < bytes.length; i += 3) {
      const a: number = bytes[i];
      const hasB = i + 1 < bytes.length;
      const hasC = i + 2 < bytes.length;
      const b: number = hasB ? bytes[i + 1] : 0;
      const c: number = hasC ? bytes[i + 2] : 0;
      const bitmap = (a << 16) | (b << 8) | c;
      result += chars.charAt((bitmap >> 18) & 63);
      result += chars.charAt((bitmap >> 12) & 63);
      result += hasB ? chars.charAt((bitmap >> 6) & 63) : '=';
      result += hasC ? chars.charAt(bitmap & 63) : '=';
    }
    return result;
  }

  private stringToBytes(str: string): number[] {
    const bytes: number[] = [];
    for (let i = 0; i < str.length; i++) {
      const code = str.charCodeAt(i);
      if (code <= 0x7f) {
        bytes.push(code);
      } else if (code <= 0x7ff) {
        bytes.push(0xc0 | (code >> 6));
        bytes.push(0x80 | (code & 0x3f));
      } else {
        bytes.push(0xe0 | (code >> 12));
        bytes.push(0x80 | ((code >> 6) & 0x3f));
        bytes.push(0x80 | (code & 0x3f));
      }
    }
    return bytes;
  }

  private parseJson<T>(json: string): T {
    const parsed: T = JSON.parse(json) as T;
    return parsed;
  }

  private buildHeaders(contentType: string = 'application/json'): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': contentType
    };

    const auth = this.getAuthHeader();
    if (auth) {
      headers.Authorization = auth;
    }

    return headers;
  }

  private request(path: string, method: http.RequestMethod, body: string = '', contentType: string = 'application/json'): Promise<string> {
    return new Promise((resolve, reject) => {
      const request = http.createHttp();
      const options: http.HttpRequestOptions = {
        method,
        header: this.buildHeaders(contentType),
        readTimeout: 30000,
        connectTimeout: 30000,
        expectDataType: http.HttpDataType.STRING
      };

      if (body.length > 0) {
        options.extraData = body;
      }

      request.request(`${this.baseUrl}${path}`, options, (err: BusinessError, data: http.HttpResponse) => {
        request.destroy();

        if (err) {
          reject(new Error(`REQUEST_${err.code}`));
          return;
        }

        const resultText = typeof data.result === 'string' ? data.result : JSON.stringify(data.result ?? '');
        if (data.responseCode < 200 || data.responseCode > 299) {
          reject(new Error(`HTTP ${data.responseCode}: ${resultText}`));
          return;
        }

        resolve(resultText);
      });
    });
  }

  private requestArrayBuffer(path: string, method: http.RequestMethod): Promise<ArrayBuffer> {
    return new Promise((resolve, reject) => {
      const request = http.createHttp();
      const options: http.HttpRequestOptions = {
        method,
        header: this.buildHeaders(''),
        readTimeout: 30000,
        connectTimeout: 30000,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      };

      request.request(`${this.baseUrl}${path}`, options, (err: BusinessError, data: http.HttpResponse) => {
        request.destroy();

        if (err) {
          reject(new Error(`REQUEST_${err.code}`));
          return;
        }

        if (data.responseCode < 200 || data.responseCode > 299) {
          reject(new Error(`HTTP ${data.responseCode}`));
          return;
        }

        if (data.result instanceof ArrayBuffer) {
          resolve(data.result);
          return;
        }
        reject(new Error('Unexpected binary response type'));
      });
    });
  }

  /**
   * GET request
   */
  async get<T>(path: string): Promise<T> {
    console.info(`[HttpClient] GET ${this.baseUrl}${path}`);
    const resultText = await this.request(path, http.RequestMethod.GET);
    return this.parseJson<T>(resultText);
  }

  async getText(path: string): Promise<string> {
    return await this.request(path, http.RequestMethod.GET, '', '');
  }

  async getArrayBuffer(path: string): Promise<ArrayBuffer> {
    return await this.requestArrayBuffer(path, http.RequestMethod.GET);
  }

  /**
   * PUT request
   */
  async put(path: string, data: object): Promise<void> {
    console.info(`[HttpClient] PUT ${this.baseUrl}${path}`);
    await this.request(path, http.RequestMethod.PUT, JSON.stringify(data));
  }

  /**
   * POST request
   */
  async post<T>(path: string, data: object): Promise<T> {
    console.info(`[HttpClient] POST ${this.baseUrl}${path}`);
    const resultText = await this.request(path, http.RequestMethod.POST, JSON.stringify(data));
    return this.parseJson<T>(resultText);
  }

  async postMultipart<T>(path: string, fields: MultipartField[]): Promise<T> {
    const boundary = `----SyncClipboard${Date.now()}${Math.random().toString(16).slice(2)}`;
    const body = this.buildMultipartBody(boundary, fields);
    const resultText = await this.request(
      path,
      http.RequestMethod.POST,
      body,
      `multipart/form-data; boundary=${boundary}`
    );
    if (!resultText) {
      return this.parseJson<T>('null');
    }
    return this.parseJson<T>(resultText);
  }

  private buildMultipartBody(boundary: string, fields: MultipartField[]): string {
    let body = '';
    fields.forEach((field: MultipartField): void => {
      if (field.value.includes(boundary)) {
        throw new Error(`Multipart field "${field.key}" contains boundary token`);
      }
      body += `--${boundary}\r\n`;
      body += `Content-Disposition: form-data; name="${field.key}"\r\n\r\n`;
      body += `${field.value}\r\n`;
    });
    body += `--${boundary}--\r\n`;
    return body;
  }
}
