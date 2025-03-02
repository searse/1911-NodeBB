const fs = require('fs');
const path = require('path');

// Log the current directory and its contents
console.log('Current directory:', process.cwd());
console.log('Directory contents:', fs.readdirSync('.'));

// Check if package.json exists
if (fs.existsSync('./package.json')) {
  console.log('Found package.json in current directory');
} else {
  console.log('No package.json in current directory');
}
