import fs from 'node:fs';
import path from 'node:path';

const URL = 'http://download.osgeo.org/postgis/windows/pg16/postgis-bundle-pg16-3.6.2x64.zip';
const TARGET = 'C:\\tools\\postgis.zip';
const NUM_CHUNKS = 16;

async function download() {
  console.log('Fetching file size...');
  const headRes = await fetch(URL, { method: 'HEAD' });
  const totalLength = parseInt(headRes.headers.get('content-length') || '0', 10);
  console.log(`Total length: ${(totalLength / (1024 * 1024)).toFixed(1)} MB (${totalLength} bytes)`);

  if (!totalLength) {
    throw new Error('Unable to determine content length');
  }

  const chunkSize = Math.ceil(totalLength / NUM_CHUNKS);
  const chunks = [];

  for (let i = 0; i < NUM_CHUNKS; i++) {
    const start = i * chunkSize;
    const end = Math.min(start + chunkSize - 1, totalLength - 1);
    chunks.push({ i, start, end, file: `C:\\tools\\postgis_chunk_${i}.tmp` });
  }

  console.log(`Starting parallel download with ${NUM_CHUNKS} chunks...`);

  let completedChunks = 0;
  await Promise.all(
    chunks.map(async (chunk) => {
      if (fs.existsSync(chunk.file)) {
        const stat = fs.statSync(chunk.file);
        if (stat.size === chunk.end - chunk.start + 1) {
          completedChunks++;
          console.log(`Chunk ${chunk.i} already cached (${stat.size} bytes). (${completedChunks}/${NUM_CHUNKS})`);
          return;
        }
      }

      console.log(`Downloading chunk ${chunk.i}: bytes=${chunk.start}-${chunk.end}...`);
      const res = await fetch(URL, {
        headers: { Range: `bytes=${chunk.start}-${chunk.end}` },
      });

      if (!res.ok && res.status !== 206) {
        throw new Error(`Chunk ${chunk.i} failed with status: ${res.status}`);
      }

      const buffer = await res.arrayBuffer();
      fs.writeFileSync(chunk.file, Buffer.from(buffer));
      completedChunks++;
      console.log(`Finished chunk ${chunk.i} (${(buffer.byteLength / 1024).toFixed(0)} KB). (${completedChunks}/${NUM_CHUNKS})`);
    })
  );

  console.log('All chunks downloaded! Assembling final zip...');
  const out = fs.createWriteStream(TARGET);
  for (const chunk of chunks) {
    const data = fs.readFileSync(chunk.file);
    out.write(data);
    fs.unlinkSync(chunk.file);
  }
  out.end();

  await new Promise((resolve) => out.on('finish', resolve));
  const finalStat = fs.statSync(TARGET);
  console.log(`Success! Assembled ${TARGET} (${(finalStat.size / (1024 * 1024)).toFixed(1)} MB).`);
}

download().catch((err) => {
  console.error('Download failed:', err);
  process.exit(1);
});
