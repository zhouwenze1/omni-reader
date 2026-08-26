import { createHash } from 'node:crypto'
import { readFile, readdir, stat } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const workspaceRoot = path.resolve(scriptDir, '..')
const rendererRoot = path.join(
  workspaceRoot,
  'packages',
  'engines',
  'epub',
  'assets',
  'renderer',
)
const pubspecPath = path.join(
  workspaceRoot,
  'packages',
  'engines',
  'epub',
  'pubspec.yaml',
)

async function listFiles(root) {
  const files = []
  async function visit(current) {
    const entries = await readdir(current, { withFileTypes: true })
    for (const entry of entries) {
      const absolute = path.join(current, entry.name)
      if (entry.isDirectory()) {
        await visit(absolute)
      } else if (entry.isFile()) {
        files.push(absolute)
      }
    }
  }
  await visit(root)
  return files
}

async function sha256(filePath) {
  const data = await readFile(filePath)
  return createHash('sha256').update(data).digest('hex')
}

function localReferencePath(reference) {
  const withoutQuery = reference.split(/[?#]/, 1)[0]
  if (!withoutQuery || /^(?:data:|https?:|javascript:)/i.test(withoutQuery)) {
    return null
  }
  return path.posix.normalize(withoutQuery.replace(/^\/+/, ''))
}

async function main() {
  const failures = []
  const warnings = []
  const indexPath = path.join(rendererRoot, 'index.html')
  const manifestPath = path.join(rendererRoot, 'renderer-manifest.json')
  const index = await readFile(indexPath, 'utf8').catch(() => null)
  if (index == null) {
    failures.push(`missing ${indexPath}`)
  }

  const actualFiles = new Set()
  if (index != null) {
    for (const file of await listFiles(rendererRoot)) {
      actualFiles.add(path.relative(rendererRoot, file).replaceAll(path.sep, '/'))
    }
    const references = [...index.matchAll(/\b(?:src|href)=["']([^"']+)["']/gi)]
      .map((match) => localReferencePath(match[1]))
      .filter((value) => value != null)
    for (const reference of references) {
      if (!actualFiles.has(reference)) {
        failures.push(`index.html references missing file: ${reference}`)
      }
    }

    for (const file of actualFiles) {
      if (/^assets\/index-[^/]+\.(?:js|css)$/.test(file) && !references.includes(file)) {
        failures.push(`stale Vite entry asset is not referenced by index.html: ${file}`)
      }
    }
  }

  const manifestText = await readFile(manifestPath, 'utf8').catch(() => null)
  if (manifestText == null) {
    failures.push(`missing ${manifestPath}`)
  } else {
    let manifest
    try {
      manifest = JSON.parse(manifestText)
    } catch (error) {
      failures.push(`invalid renderer-manifest.json: ${String(error)}`)
    }
    if (manifest != null) {
      if (manifest.renderer !== 'vue-book-renderer') {
        failures.push('renderer-manifest.json has an unexpected renderer name')
      }
      if (!manifest.rendererCommit) {
        warnings.push('renderer-manifest.json has no source commit')
      }
      for (const [relative, expected] of Object.entries(manifest.files ?? {})) {
        const absolute = path.join(rendererRoot, relative)
        const fileStat = await stat(absolute).catch(() => null)
        if (fileStat == null) {
          failures.push(`manifest references missing file: ${relative}`)
          continue
        }
        if (fileStat.size !== expected.bytes) {
          failures.push(`size mismatch for ${relative}`)
        }
        if (await sha256(absolute) !== expected.sha256) {
          failures.push(`sha256 mismatch for ${relative}`)
        }
      }
    }
  }

  const pubspec = await readFile(pubspecPath, 'utf8').catch(() => null)
  if (pubspec == null) {
    failures.push(`missing ${pubspecPath}`)
  } else if (!/^\s*-\s+assets\/renderer\//m.test(pubspec)) {
    failures.push('pubspec.yaml does not list renderer assets')
  } else {
    const listed = new Set(
      [...pubspec.matchAll(/^\s*-\s+(assets\/renderer\/[^\s]+)\s*$/gm)]
        .map((match) => match[1].replace(/^assets\/renderer\//, '')),
    )
    for (const file of actualFiles) {
      if (!listed.has(file)) {
        failures.push(`renderer file is not listed in pubspec.yaml: ${file}`)
      }
    }
  }

  if (warnings.length > 0) {
    for (const warning of warnings) {
      console.warn(`[renderer-assets] warning: ${warning}`)
    }
  }
  if (failures.length > 0) {
    for (const failure of failures) {
      console.error(`[renderer-assets] ${failure}`)
    }
    process.exitCode = 1
    return
  }
  console.log('[renderer-assets] renderer index, referenced assets, manifest and pubspec are consistent')
}

main().catch((error) => {
  console.error(`[renderer-assets] ${error instanceof Error ? error.message : String(error)}`)
  process.exitCode = 1
})
