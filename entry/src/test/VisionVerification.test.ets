import { describe, expect, it } from '@ohos/hypium';
import { RuntimeModelConfig } from '../main/ets/models/ModelConfig';
import {
  HttpTransport,
  HttpTransportRequest,
  HttpTransportResponse,
  TransportError,
  TransportErrorKind,
  VerificationCandidate,
  VerificationConfirmations,
  VerificationError,
  VerificationErrorCategory
} from '../main/ets/models/VerificationModels';
import { ConfigVerificationCoordinator } from '../main/ets/services/ConfigVerificationCoordinator';
import { VerifiedConfigWriter } from '../main/ets/services/ConfigStoragePorts';
import {
  ParsedServiceURL,
  ServiceURLParser
} from '../main/ets/services/UrlPreflight';
import { VisionVerificationGate } from '../main/ets/services/VisionVerificationGate';

class FakeServiceURLParser implements ServiceURLParser {
  parse(rawURL: string): ParsedServiceURL {
    if (rawURL === 'https://api.example.com/v1') {
      return {
        protocol: 'https:', hostname: 'api.example.com', username: '', password: '', search: '', hash: '',
        origin: 'https://api.example.com', serialized: rawURL
      };
    }
    if (rawURL === 'http://example.com/v1') {
      return {
        protocol: 'http:', hostname: 'example.com', username: '', password: '', search: '', hash: '',
        origin: 'http://example.com', serialized: rawURL
      };
    }
    if (rawURL === 'http://localhost.evil.com/v1') {
      return {
        protocol: 'http:', hostname: 'localhost.evil.com', username: '', password: '', search: '', hash: '',
        origin: 'http://localhost.evil.com', serialized: rawURL
      };
    }
    if (rawURL === 'http://127.0.0.1:8080/v1') {
      return {
        protocol: 'http:', hostname: '127.0.0.1', username: '', password: '', search: '', hash: '',
        origin: 'http://127.0.0.1:8080', serialized: rawURL
      };
    }
    throw new Error('invalid test URL');
  }
}

class FakeTransport implements HttpTransport {
  response: HttpTransportResponse = { statusCode: 200, body: successStringBody('RED_LEFT_BLUE') };
  failure?: TransportError;
  lastRequest?: HttpTransportRequest;
  sendCount: number = 0;

  async send(request: HttpTransportRequest): Promise<HttpTransportResponse> {
    this.sendCount += 1;
    this.lastRequest = {
      url: request.url,
      apiKey: request.apiKey,
      body: request.body,
      timeoutMs: request.timeoutMs
    };
    if (this.failure !== undefined) {
      throw this.failure;
    }
    return this.response;
  }
}

class FakeWriter implements VerifiedConfigWriter {
  writeCount: number = 0;
  lastConfig?: RuntimeModelConfig;

  async replaceVerified(config: RuntimeModelConfig): Promise<void> {
    this.writeCount += 1;
    this.lastConfig = {
      baseURL: config.baseURL,
      apiKey: config.apiKey,
      model: config.model,
      verifiedAt: config.verifiedAt,
      verificationProtocolVersion: config.verificationProtocolVersion,
      trustedOrigin: config.trustedOrigin
    };
  }
}

function candidate(baseURL: string = 'https://api.example.com/v1'): VerificationCandidate {
  return { baseURL: baseURL, apiKey: 'test-only-key', model: 'vision-model' };
}

function confirmations(): VerificationConfirmations {
  return { customOriginTrusted: true, loopbackHttpAccepted: true };
}

function gate(transport: HttpTransport): VisionVerificationGate {
  return new VisionVerificationGate(transport, () => 0, new FakeServiceURLParser());
}

function successStringBody(answer: string): string {
  return '{"choices":[{"message":{"content":"' + answer + '"}}]}';
}

function successArrayBody(): string {
  return '{"choices":[{"message":{"content":[' +
    '{"type":"text","text":"RED_LEFT_"},' +
    '{"type":"text","text":"BLUE"}]}}]}';
}

async function capturedCategory(gate: VisionVerificationGate,
  value: VerificationCandidate = candidate()): Promise<VerificationErrorCategory | undefined> {
  try {
    await gate.verify(value, confirmations());
    return undefined;
  } catch (error) {
    return (error as VerificationError).category;
  }
}

export default function visionVerificationTest() {
  describe('VisionVerificationGate', () => {
    it('builds an OpenAI vision request and accepts string content', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      const verifier: VisionVerificationGate = gate(transport);

      const result = await verifier.verify(candidate(), confirmations());

      expect(result.challengeId).assertEqual('red-circle-left-blue-square-v1');
      expect(result.normalizedBaseURL).assertEqual('https://api.example.com/v1');
      expect(transport.lastRequest?.url).assertEqual('https://api.example.com/v1/chat/completions');
      expect(transport.lastRequest?.body.includes('"type":"image_url"')).assertTrue();
      expect(transport.lastRequest?.body.includes('data:image/png;base64,')).assertTrue();
      expect(transport.lastRequest?.body.includes('"model":"vision-model"')).assertTrue();
    });

    it('accepts text array content', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      transport.response = { statusCode: 200, body: successArrayBody() };
      const verifier: VisionVerificationGate = gate(transport);

      const result = await verifier.verify(candidate(), confirmations());

      expect(result.challengeId).assertEqual('red-circle-left-blue-square-v1');
    });

    it('selects another visual challenge from the injected random source', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      transport.response = { statusCode: 200, body: successStringBody('GREEN_ABOVE_BLACK') };
      const verifier: VisionVerificationGate = new VisionVerificationGate(
        transport,
        () => 0.99,
        new FakeServiceURLParser()
      );

      const result = await verifier.verify(candidate(), confirmations());

      expect(result.challengeId).assertEqual('green-triangle-above-black-square-v1');
    });

    it('classifies HTTP 401 as authentication failure', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      transport.response = { statusCode: 401, body: '{"error":"unauthorized"}' };
      expect(await capturedCategory(gate(transport)))
        .assertEqual(VerificationErrorCategory.AUTHENTICATION);
    });

    it('classifies HTTP 403 as authentication failure', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      transport.response = { statusCode: 403, body: '{"error":"forbidden"}' };
      expect(await capturedCategory(gate(transport)))
        .assertEqual(VerificationErrorCategory.AUTHENTICATION);
    });

    it('classifies HTTP 404 as endpoint failure', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      transport.response = { statusCode: 404, body: '{"error":"not found"}' };
      expect(await capturedCategory(gate(transport)))
        .assertEqual(VerificationErrorCategory.ADDRESS);
    });

    it('classifies explicit image rejection as vision failure', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      transport.response = { statusCode: 400, body: '{"error":{"message":"image input is not supported"}}' };
      expect(await capturedCategory(gate(transport)))
        .assertEqual(VerificationErrorCategory.VISION);
    });

    it('classifies a wrong challenge answer as vision failure', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      transport.response = { statusCode: 200, body: successStringBody('CANNOT_SEE') };
      expect(await capturedCategory(gate(transport)))
        .assertEqual(VerificationErrorCategory.VISION);
    });

    it('classifies transport timeout as network failure', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      transport.failure = new TransportError(TransportErrorKind.TIMEOUT);
      expect(await capturedCategory(gate(transport)))
        .assertEqual(VerificationErrorCategory.NETWORK);
    });

    it('classifies HTTP 5xx as service failure', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      transport.response = { statusCode: 503, body: '<html>unavailable</html>' };
      expect(await capturedCategory(gate(transport)))
        .assertEqual(VerificationErrorCategory.SERVICE);
    });

    it('classifies invalid JSON as response failure', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      transport.response = { statusCode: 200, body: '{broken' };
      expect(await capturedCategory(gate(transport)))
        .assertEqual(VerificationErrorCategory.RESPONSE);
    });

    it('classifies missing choices as response failure', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      transport.response = { statusCode: 200, body: '{}' };
      expect(await capturedCategory(gate(transport)))
        .assertEqual(VerificationErrorCategory.RESPONSE);
    });

    it('classifies missing message as response failure', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      transport.response = { statusCode: 200, body: '{"choices":[{}]}' };
      expect(await capturedCategory(gate(transport)))
        .assertEqual(VerificationErrorCategory.RESPONSE);
    });

    it('classifies missing content as response failure', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      transport.response = { statusCode: 200, body: '{"choices":[{"message":{}}]}' };
      expect(await capturedCategory(gate(transport)))
        .assertEqual(VerificationErrorCategory.RESPONSE);
    });

    it('rejects remote HTTP before transport', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      const verifier: VisionVerificationGate = gate(transport);

      expect(await capturedCategory(verifier, candidate('http://example.com/v1')))
        .assertEqual(VerificationErrorCategory.ADDRESS);
      expect(await capturedCategory(verifier, candidate('http://localhost.evil.com/v1')))
        .assertEqual(VerificationErrorCategory.ADDRESS);
      expect(transport.sendCount).assertEqual(0);
    });

    it('requires explicit trust for a custom HTTPS origin', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      const verifier: VisionVerificationGate = gate(transport);
      const denied: VerificationConfirmations = {
        customOriginTrusted: false,
        loopbackHttpAccepted: false
      };
      let category: VerificationErrorCategory | undefined;

      try {
        await verifier.verify(candidate(), denied);
      } catch (error) {
        category = (error as VerificationError).category;
      }

      expect(category).assertEqual(VerificationErrorCategory.TRUST);
      expect(transport.sendCount).assertEqual(0);
    });

    it('allows confirmed loopback HTTP', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      const verifier: VisionVerificationGate = gate(transport);

      const result = await verifier.verify(candidate('http://127.0.0.1:8080/v1'), confirmations());

      expect(result.trustedOrigin).assertEqual('http://127.0.0.1:8080');
      expect(transport.sendCount).assertEqual(1);
    });

    it('does not save when the visual gate fails', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      transport.response = { statusCode: 200, body: successStringBody('WRONG') };
      const writer: FakeWriter = new FakeWriter();
      const coordinator: ConfigVerificationCoordinator = new ConfigVerificationCoordinator(
        gate(transport),
        writer
      );

      try {
        await coordinator.verifyAndSave(candidate(), confirmations());
      } catch (_error) {
      }

      expect(writer.writeCount).assertEqual(0);
    });

    it('saves exactly once after a successful visual gate', 0, async () => {
      const transport: FakeTransport = new FakeTransport();
      const writer: FakeWriter = new FakeWriter();
      const coordinator: ConfigVerificationCoordinator = new ConfigVerificationCoordinator(
        gate(transport),
        writer
      );

      await coordinator.verifyAndSave(candidate(), confirmations());

      expect(writer.writeCount).assertEqual(1);
      expect(writer.lastConfig?.baseURL).assertEqual('https://api.example.com/v1');
      expect(writer.lastConfig?.model).assertEqual('vision-model');
    });
  });
}
