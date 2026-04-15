const fs = require('node:fs');
const path = require('node:path');

function resolveBuildProfileSource({ rootDir }) {
  const targetPath = path.join(rootDir, 'build-profile.json5');
  const localPath = path.join(rootDir, 'build-profile.local.json5');
  const templatePath = path.join(rootDir, 'build-profile.template.json5');

  if (fs.existsSync(localPath)) {
    return { mode: 'local', sourcePath: localPath, targetPath };
  }

  if (fs.existsSync(templatePath)) {
    return { mode: 'template', sourcePath: templatePath, targetPath };
  }

  throw new Error(
    `Missing build profile source. Expected one of: ${localPath}, ${templatePath}`
  );
}

function prepareBuildProfile({ rootDir = process.cwd() } = {}) {
  const resolved = resolveBuildProfileSource({ rootDir });
  fs.copyFileSync(resolved.sourcePath, resolved.targetPath);
  return resolved;
}

if (require.main === module) {
  const result = prepareBuildProfile({ rootDir: process.cwd() });
  console.log(
    `[build-profile] using ${result.mode} config: ${path.basename(result.sourcePath)}`
  );
}

module.exports = {
  prepareBuildProfile,
  resolveBuildProfileSource,
};
