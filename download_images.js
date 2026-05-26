const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');

const indexPath = path.join(__dirname, 'lib', 'yffun.eu.org', 'htdocs', 'index.html');
const outputDir = path.join(__dirname, 'lib', 'image');

const requestHeaders = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36',
  Referer: 'https://www.bilibili.com/',
};

function extractImageUrls(html) {
  const urls = new Set();
  const patterns = [
    /<div[^>]+class="[^"]*bg-img[^"]*"[^>]+data-image-src="([^"]+)"/g,
    /<i[^>]+class="[^"]*img[^"]*"[^>]+data-src="([^"]+)"/g,
  ];

  for (const pattern of patterns) {
    let match;
    while ((match = pattern.exec(html)) !== null) {
      urls.add(match[1].replace(/&amp;/g, '&'));
    }
  }

  return [...urls];
}

function getExtension(url, contentType) {
  const pathname = new URL(url).pathname;
  const ext = path.extname(pathname).toLowerCase();
  if (ext && ext.length <= 5) return ext;

  if (contentType.includes('png')) return '.png';
  if (contentType.includes('webp')) return '.webp';
  if (contentType.includes('gif')) return '.gif';
  return '.jpg';
}

function download(url, redirectCount = 0) {
  return new Promise((resolve, reject) => {
    if (redirectCount > 5) {
      reject(new Error(`Too many redirects: ${url}`));
      return;
    }

    const client = url.startsWith('https:') ? https : http;
    const req = client.get(url, { headers: requestHeaders }, (res) => {
      if ([301, 302, 303, 307, 308].includes(res.statusCode)) {
        const location = res.headers.location;
        res.resume();
        if (!location) {
          reject(new Error(`Redirect without location: ${url}`));
          return;
        }
        resolve(download(new URL(location, url).toString(), redirectCount + 1));
        return;
      }

      if (res.statusCode !== 200) {
        res.resume();
        reject(new Error(`HTTP ${res.statusCode}: ${url}`));
        return;
      }

      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => {
        resolve({
          buffer: Buffer.concat(chunks),
          contentType: res.headers['content-type'] || '',
        });
      });
    });

    req.on('error', reject);
    req.setTimeout(30000, () => {
      req.destroy(new Error(`Timeout: ${url}`));
    });
  });
}

async function main() {
  if (!fs.existsSync(indexPath)) {
    throw new Error(`index.html not found: ${indexPath}`);
  }

  fs.mkdirSync(outputDir, { recursive: true });

  const html = fs.readFileSync(indexPath, 'utf8');
  const urls = extractImageUrls(html);

  if (urls.length === 0) {
    console.log('No image URLs found.');
    return;
  }

  console.log(`Found ${urls.length} image URLs.`);

  for (let i = 0; i < urls.length; i++) {
    const url = urls[i];
    const prefix = String(i + 1).padStart(2, '0');

    try {
      console.log(`[${i + 1}/${urls.length}] Downloading ${url}`);
      const { buffer, contentType } = await download(url);
      const ext = getExtension(url, contentType);
      const filePath = path.join(outputDir, `bg_${prefix}${ext}`);
      fs.writeFileSync(filePath, buffer);
      console.log(`Saved: ${path.relative(__dirname, filePath)}`);
    } catch (error) {
      console.error(`Failed: ${url}`);
      console.error(error.message);
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
