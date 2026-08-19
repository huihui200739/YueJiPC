import fs from '@ohos.file.fs';
import cryptoFramework from '@ohos.security.cryptoFramework';

const HASH_ALGORITHM: string = 'SHA256';
const CHUNK_SIZE: number = 1024 * 1024;

export class FileFingerprintService {
  async sha256(path: string): Promise<string> {
    const stat = fs.statSync(path);
    if (!stat.isFile()) {
      throw new Error('待校验的 PDF 文件不存在');
    }
    const digest = cryptoFramework.createMd(HASH_ALGORITHM);
    const file = await fs.open(path, fs.OpenMode.READ_ONLY);
    const buffer = new ArrayBuffer(CHUNK_SIZE);
    let offset = 0;
    try {
      while (offset < stat.size) {
        const bytesRead = await fs.read(file.fd, buffer, {
          offset: offset,
          length: Math.min(CHUNK_SIZE, stat.size - offset)
        });
        if (bytesRead <= 0) {
          break;
        }
        const chunk = new Uint8Array(buffer.slice(0, bytesRead));
        await digest.update({ data: chunk });
        offset += bytesRead;
      }
    } finally {
      await fs.close(file);
    }
    if (offset !== stat.size) {
      throw new Error('PDF 文件读取不完整，无法计算指纹');
    }
    const result = await digest.digest();
    return this.toHex(result.data);
  }

  private toHex(bytes: Uint8Array): string {
    return Array.from(bytes)
      .map((value: number): string => value.toString(16).padStart(2, '0'))
      .join('');
  }
}
