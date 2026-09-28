export interface StorageFile {
  key: string;
  buffer: Buffer;
  contentType: string;
}

export interface StoredFileResult {
  key: string;
  url: string;
}

export interface MediaStorageProvider {
  uploadFile(file: StorageFile): Promise<StoredFileResult>;
  deleteFile(key: string): Promise<void>;
  getFile(key: string): Promise<{ buffer: Buffer; contentType: string } | null>;
  getPublicUrl(key: string): string;
}
