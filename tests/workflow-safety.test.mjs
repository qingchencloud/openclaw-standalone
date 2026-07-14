import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const workflow = readFileSync(new URL('../.github/workflows/build.yml', import.meta.url), 'utf8')

test('standalone matrix builds Intel Mac archives for both editions', () => {
  for (const edition of ['zh', 'en']) {
    assert.match(
      workflow,
      new RegExp(`platform: mac-x64[\\s\\S]{0,160}edition: ${edition}`),
      `missing mac-x64 ${edition} build`,
    )
  }
})

test('R2 upload failures stop the workflow before latest.json is published', () => {
  const uploadStart = workflow.indexOf('- name: Upload files to R2')
  const manifestStart = workflow.indexOf('- name: Upload latest.json to R2')
  const uploadStep = workflow.slice(uploadStart, manifestStart)

  assert.ok(uploadStart >= 0 && manifestStart > uploadStart)
  assert.match(uploadStep, /if \[ "\$FAILED" -ne 0 \]; then/)
  assert.match(uploadStep, /exit 1/)
})

test('release validates every manifest asset before publishing', () => {
  const collectStart = workflow.indexOf('- name: Collect all files')
  const manifestStart = workflow.indexOf('- name: Generate latest.json manifest')
  const collectStep = workflow.slice(collectStart, manifestStart)

  assert.match(collectStep, /Validate release asset completeness/)
  assert.match(collectStep, /mac-x64/)
  assert.match(collectStep, /MISSING/)
  assert.match(collectStep, /exit 1/)
})
