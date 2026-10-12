const http = require('http');
const fs = require('fs');
const path = require('path');

const port = process.env.PORT || 3000;
const publicDir = path.join(__dirname, 'public');

const mimeTypes = {
  html: 'text/html',
  css: 'text/css',
  js: 'application/javascript',
  png: 'image/png',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  gif: 'image/gif',
  svg: 'image/svg+xml',
  json: 'application/json',
};

function serveFile(filePath, res) {
  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.statusCode = 404;
      res.setHeader('Content-Type', 'text/plain');
      res.end('404 Not Found');
      return;
    }

    const ext = path.extname(filePath).slice(1);
    res.statusCode = 200;
    res.setHeader('Content-Type', mimeTypes[ext] || 'application/octet-stream');
    res.end(data);
  });
}

const server = http.createServer((req, res) => {
  let requestPath = req.url.split('?')[0];
  if (requestPath === '/') {
    requestPath = '/index.html';
  }

  const filePath = path.join(publicDir, decodeURIComponent(requestPath));
  if (!filePath.startsWith(publicDir)) {
    res.statusCode = 400;
    res.end('Bad Request');
    return;
  }

  serveFile(filePath, res);
});

server.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
