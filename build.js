const fs = require('fs');
const path = require('path');

const projectDir = __dirname;
const publicDir = path.join(projectDir, 'public');
const buildDir = path.join(projectDir, 'build');

console.log('Building the project...');
fs.mkdirSync(buildDir, { recursive: true });
fs.cpSync(publicDir, buildDir, { recursive: true });
console.log(`Build output created at ${buildDir}`);