import fs from '@ohos.file.fs';

export interface StorageCleanupResult {
  removedCount: number;
  failedCount: number;
}

export function isManagedTemporaryPath(path: string): boolean {
  const normalized = path.toLowerCase();
  return normalized.endsWith('.json.tmp') ||
    normalized.endsWith('.import.tmp') ||
    normalized.endsWith('.restore.tmp') ||
    /\.import-\d+\.tmp$/.test(normalized) ||
    /\.restore-\d+\.tmp$/.test(normalized);
}

export class StorageMaintenanceService {
  cleanup(filesDir: string): StorageCleanupResult {
    const result: StorageCleanupResult = {
      removedCount: 0,
      failedCount: 0
    };
    this.cleanupRoot(`${filesDir}/library`, result);
    this.cleanupRoot(`${filesDir}/backups`, result);
    return result;
  }

  private cleanupRoot(root: string, result: StorageCleanupResult): void {
    let entries: string[] = [];
    try {
      entries = fs.listFileSync(root, { recursion: true });
    } catch (error) {
      return;
    }
    entries.forEach((entry: string): void => {
      const normalized = entry.startsWith('/') ? entry.substring(1) : entry;
      if (!isManagedTemporaryPath(normalized)) {
        return;
      }
      const path = `${root}/${normalized}`;
      try {
        if (fs.statSync(path).isFile()) {
          fs.unlinkSync(path);
          result.removedCount++;
        }
      } catch (error) {
        result.failedCount++;
      }
    });
  }
}
