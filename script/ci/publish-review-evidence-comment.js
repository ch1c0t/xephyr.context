const fs = require('fs')
const crypto = require('crypto')

module.exports = async ({ github, context, core }) => {
  const marker = '<!-- review-evidence -->'
  const fingerprintMarker = '<!-- review-evidence-fingerprint:'
  const owner = context.repo.owner
  const repo = context.repo.repo
  const issue_number = context.payload.pull_request.number

  const readJson = (path) => {
    try {
      return JSON.parse(fs.readFileSync(path, 'utf8'))
    } catch {
      return null
    }
  }

  const manifest = readJson('review-evidence/manifest.json')
  const commandRecords = readJson('review-evidence/test-results/commands.json') || []
  const expectedHead = process.env.REVIEW_PR_HEAD_SHA
  const checkedHead = manifest?.commit?.pull_request_head_sha || expectedHead

  // A slower run for an older commit must never replace newer evidence.
  const { data: pullRequest } = await github.rest.pulls.get({
    owner,
    repo,
    pull_number: issue_number
  })
  if (checkedHead && pullRequest.head.sha !== checkedHead) {
    core.info('Skipping stale review evidence for ' + checkedHead + '; current PR head is ' + pullRequest.head.sha + '.')
    return
  }

  const checks = manifest?.checks || {}
  const checkResult = checks.result || 'incomplete'
  const artifactUrl = process.env.ARTIFACT_URL
  const artifactUploaded = process.env.UPLOAD_OUTCOME === 'success' && Boolean(artifactUrl)

  let overallStatus
  if (!manifest) {
    overallStatus = 'Evidence generation failed'
  } else if (checkResult === 'failed') {
    overallStatus = 'Checks failed'
  } else if (checkResult !== 'passed') {
    overallStatus = 'Evidence incomplete'
  } else if (!artifactUploaded) {
    overallStatus = 'Evidence artifact unavailable'
  } else {
    overallStatus = 'Passed'
  }

  const escapeCell = (value) => String(value ?? '—').replace(/\|/g, '\\|').replace(/[\r\n]+/g, ' ')
  const commitSha = checkedHead || manifest?.commit?.checked_out_sha || 'unavailable'
  const commitLink = /^[0-9a-f]{40}$/i.test(commitSha)
    ? '[' + commitSha.slice(0, 12) + '](' + context.serverUrl + '/' + owner + '/' + repo + '/commit/' + commitSha + ')'
    : escapeCell(commitSha)

  const rows = commandRecords.map(record =>
    '| ' + escapeCell(record.name) + ' | ' + escapeCell(record.status?.toUpperCase()) + ' | ' +
    escapeCell(record.duration_seconds) + 's | ' + escapeCell(record.exit_code) + ' |'
  )
  const failingChecks = commandRecords.filter(record => record.status !== 'passed')
  const missingChecks = Array.isArray(checks.missing) ? checks.missing : []

  const bodyParts = [
    marker,
    '',
    '## Review evidence',
    '',
    '**Overall result:** ' + overallStatus,
    '**Tested commit:** ' + commitLink,
    '**Workflow run:** [View run](' + process.env.RUN_URL + ')',
    artifactUploaded
      ? '**Evidence bundle:** [Download review evidence](' + artifactUrl + ') (14-day retention)'
      : '**Evidence bundle:** Not available; see the workflow run for diagnostics.',
    '',
    '### Checks',
    '',
    '| Check | Result | Duration | Exit code |',
    '| --- | --- | ---: | ---: |',
    ...(rows.length ? rows : ['| No command results recorded | — | — | — |'])
  ]

  if (failingChecks.length) {
    bodyParts.push('', '### Failed checks', '')
    for (const record of failingChecks) {
      bodyParts.push('- **' + escapeCell(record.name) + '** — exit code ' + escapeCell(record.exit_code) + '; see its command log in the evidence bundle or workflow run.')
    }
  }

  if (missingChecks.length) {
    bodyParts.push('', '### Checks not completed', '')
    for (const name of missingChecks) bodyParts.push('- ' + escapeCell(name))
  }

  if (!manifest) {
    bodyParts.push('', 'The evidence manifest was not generated. Inspect the workflow run for the failure that prevented evidence finalization.')
  } else if (checkResult === 'passed' && !artifactUploaded) {
    bodyParts.push('', 'All recorded checks passed, but the evidence artifact could not be uploaded. The workflow is not considered review-ready.')
  }

  bodyParts.push('', '_This comment is maintained automatically. Identical reruns do not create duplicate updates._')
  const fingerprintPayload = {
    commit: commitSha,
    result: overallStatus,
    checks: commandRecords.map(record => ({
      name: record.name,
      status: record.status,
      exit_code: record.exit_code
    })),
    missing: missingChecks,
    artifact_uploaded: artifactUploaded
  }
  const fingerprint = crypto
    .createHash('sha256')
    .update(JSON.stringify(fingerprintPayload))
    .digest('hex')
  bodyParts.splice(1, 0, fingerprintMarker + fingerprint + ' -->')
  const body = bodyParts.join('\n')

  const comments = await github.paginate(github.rest.issues.listComments, {
    owner,
    repo,
    issue_number,
    per_page: 100
  })
  const existing = comments.find(comment =>
    comment.user?.type === 'Bot' && comment.body?.includes(marker)
  )
  const existingFingerprint = existing?.body?.match(/<!-- review-evidence-fingerprint:([0-9a-f]{64}) -->/)?.[1]

  if (existing && existingFingerprint === fingerprint) {
    core.info('Review evidence comment is already up to date; skipping.')
    return
  }

  if (existing) {
    await github.rest.issues.updateComment({
      owner,
      repo,
      comment_id: existing.id,
      body
    })
    core.info('Updated review evidence comment ' + existing.id + '.')
  } else {
    const { data: comment } = await github.rest.issues.createComment({
      owner,
      repo,
      issue_number,
      body
    })
    core.info('Created review evidence comment ' + comment.id + '.')
  }
}
