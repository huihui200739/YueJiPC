import { MAX_URL_LENGTH } from '../model/Models';

export interface UrlValidationResult {
  valid: boolean;
  normalized: string;
  message: string;
}

export function normalizeHttpUrl(value: string): string {
  const trimmed = value.trim();
  if (/^https?:\/\//i.test(trimmed)) {
    return trimmed;
  }
  return `https://${trimmed}`;
}

export function validateHttpUrl(value: string, allowMissingProtocol: boolean = true): UrlValidationResult {
  const trimmed = value.trim();
  if (trimmed.length === 0) {
    return { valid: false, normalized: '', message: '网址为空' };
  }
  const normalized = allowMissingProtocol ? normalizeHttpUrl(trimmed) : trimmed;
  if (normalized.length > MAX_URL_LENGTH) {
    return { valid: false, normalized: normalized, message: '网址超过长度限制' };
  }
  if (/\s/.test(normalized)) {
    return { valid: false, normalized: normalized, message: '网址不能包含空白字符' };
  }
  const match = normalized.match(/^https?:\/\/([^/?#]+)(?:[/?#][^\s]*)?$/i);
  if (match === null || match.length < 2) {
    return { valid: false, normalized: normalized, message: '网址缺少有效主机名' };
  }

  let host = match[1];
  const colonIndex = host.lastIndexOf(':');
  if (colonIndex >= 0) {
    const portText = host.substring(colonIndex + 1);
    if (!/^\d{1,5}$/.test(portText)) {
      return { valid: false, normalized: normalized, message: '网址端口无效' };
    }
    const port = Number(portText);
    if (!Number.isInteger(port) || port < 1 || port > 65535) {
      return { valid: false, normalized: normalized, message: '网址端口超出范围' };
    }
    host = host.substring(0, colonIndex);
  }
  if (host.toLowerCase() === 'localhost') {
    return { valid: true, normalized: normalized, message: '网址格式可用' };
  }
  if (/^(?:\d{1,3}\.){3}\d{1,3}$/.test(host)) {
    const validIpv4 = host.split('.').every((part: string): boolean => {
      const partValue = Number(part);
      return Number.isInteger(partValue) && partValue >= 0 && partValue <= 255;
    });
    return validIpv4 ?
      { valid: true, normalized: normalized, message: '网址格式可用' } :
      { valid: false, normalized: normalized, message: '网址 IPv4 地址无效' };
  }

  const labels = host.split('.');
  if (labels.length < 2 || labels[labels.length - 1].length < 2) {
    return { valid: false, normalized: normalized, message: '网址域名不完整' };
  }
  const validHost = labels.every((label: string): boolean =>
    /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/i.test(label));
  return validHost ?
    { valid: true, normalized: normalized, message: '网址格式可用' } :
    { valid: false, normalized: normalized, message: '网址域名包含无效字符' };
}

export function isValidHttpUrl(value: string, allowMissingProtocol: boolean = true): boolean {
  return validateHttpUrl(value, allowMissingProtocol).valid;
}
