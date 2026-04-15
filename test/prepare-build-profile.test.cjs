const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const {
  prepareBuildProfile,
} = require('../scripts/prepare-build-profile.cjs');

function makeTempDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'cliplink-build-profile-'));
}

test('prefers build-profile.local.json5 when present', () => {
  const rootDir = makeTempDir();
  const templatePath = path.join(rootDir, 'build-profile.template.json5');
  const localPath = path.join(rootDir, 'build-profile.local.json5');

  fs.writeFileSync(templatePath, 'template-config');
  fs.writeFileSync(localPath, 'local-config');

  const result = prepareBuildProfile({ rootDir });
  const generatedPath = path.join(rootDir, 'build-profile.json5');

  assert.equal(result.mode, 'local');
  assert.equal(result.sourcePath, localPath);
  assert.equal(result.targetPath, generatedPath);
  assert.equal(fs.readFileSync(generatedPath, 'utf8'), 'local-config');
});

test('falls back to build-profile.template.json5 when no local config exists', () => {
  const rootDir = makeTempDir();
  const templatePath = path.join(rootDir, 'build-profile.template.json5');

  fs.writeFileSync(templatePath, 'template-config');

  const result = prepareBuildProfile({ rootDir });
  const generatedPath = path.join(rootDir, 'build-profile.json5');

  assert.equal(result.mode, 'template');
  assert.equal(result.sourcePath, templatePath);
  assert.equal(result.targetPath, generatedPath);
  assert.equal(fs.readFileSync(generatedPath, 'utf8'), 'template-config');
});

test('throws a clear error when neither local nor template config exists', () => {
  const rootDir = makeTempDir();

  assert.throws(
    () => prepareBuildProfile({ rootDir }),
    /Missing build profile source/
  );
});
