import { createHash } from 'node:crypto'
import { spawnSync } from 'node:child_process'
import { cp, mkdir, readFile, readdir, rm, stat, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const workspaceRoot = path.resolve(scriptDir, '..')
const defaultRendererRoot = path.resolve(workspaceRoot, '..', 'vue-book-renderer')
const targetRoot = path.join(
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

function argumentValue(name) {
  const index = process.argv.indexOf(name)
  return index >= 0 ? process.argv[index + 1] : undefined
}

function run(command, args, cwd) {
  const executable = process.platform === 'win32' && command === 'pnpm'
    ? 'pnpm.cmd'
    : command
  const commandLine = [executable, ...args].join(' ')
  const result = process.platform === 'win32'
    ? spawnSync(process.env.ComSpec ?? 'cmd.exe', ['/d', '/s', '/c', commandLine], {
        cwd,
        encoding: 'utf8',
        stdio: 'inherit',
      })
    : spawnSync(executable, args, {
        cwd,
        encoding: 'utf8',
        stdio: 'inherit',
      })
  if (result.error || result.status !== 0) {
    throw result.error ?? new Error(`${executable} ${args.join(' ')} failed`)
  }
}

function capture(command, args, cwd) {
  const result = spawnSync(command, args, {
    cwd,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'ignore'],
  })
  if (result.status !== 0) {
    return null
  }
  return result.stdout.trim()
}

async function listFiles(root) {
  const files = []
  async function visit(current) {
    const entries = await readdir(current, { withFileTypes: true })
    entries.sort((left, right) => left.name.localeCompare(right.name))
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

async function updatePubspec(assetFiles) {
  const source = await readFile(pubspecPath, 'utf8')
  const assetLines = assetFiles
    .map((file) => `    - assets/renderer/${file.replaceAll(path.sep, '/')}`)
    .join('\n')
  const replacement = `flutter:\n  assets:\n${assetLines}\n`
  const pattern = /^flutter:\r?\n(?:  assets:\r?\n(?:    - .*\r?\n)*)?/m
  if (!pattern.test(source)) {
    throw new Error(`Unable to locate flutter asset section in ${pubspecPath}`)
  }
  await writeFile(pubspecPath, source.replace(pattern, replacement), 'utf8')
}

async function copyRuntimeFiles(rendererDist) {
  await cp(
    path.join(rendererDist, 'index.html'),
    path.join(targetRoot, 'index.html'),
  )

  const faviconPath = path.join(rendererDist, 'favicon.ico')
  if (await stat(faviconPath).catch(() => null)) {
    await cp(faviconPath, path.join(targetRoot, 'favicon.ico'))
  }

  const assetsPath = path.join(rendererDist, 'assets')
  if (!(await stat(assetsPath).catch(() => null))) {
    throw new Error(`Renderer build output is missing ${assetsPath}`)
  }
  await cp(assetsPath, path.join(targetRoot, 'assets'), { recursive: true })
}

async function main() {
  const rendererRoot = path.resolve(
    argumentValue('--renderer') ?? process.env.RENDERER_PATH ?? defaultRendererRoot,
  )
  const rendererDist = path.join(rendererRoot, 'dist')
  const skipBuild = process.argv.includes('--skip-build')

  if (!skipBuild) {
    console.log(`[renderer-sync] building ${rendererRoot}`)
    run('pnpm', ['build-only'], rendererRoot)
  }

  const indexPath = path.join(rendererDist, 'index.html')
  if (!(await stat(indexPath).catch(() => null))) {
    throw new Error(`Renderer build output is missing ${indexPath}`)
  }

  await rm(targetRoot, { recursive: true, force: true })
  await mkdir(targetRoot, { recursive: true })
  await copyRuntimeFiles(rendererDist)

  const copiedFiles = await listFiles(targetRoot)
  const relativeFiles = copiedFiles
    .map((file) => path.relative(targetRoot, file).replaceAll(path.sep, '/'))
    .filter((file) => file !== 'renderer-manifest.json')
    .sort()
  const fileEntries = {}
  for (const relative of relativeFiles) {
    const absolute = path.join(targetRoot, relative)
    const fileStat = await stat(absolute)
    fileEntries[relative] = {
      bytes: fileStat.size,
      sha256: await sha256(absolute),
    }
  }

  const commit = capture('git', ['rev-parse', 'HEAD'], rendererRoot)
  const dirty = capture('git', ['status', '--porcelain'], rendererRoot)
  const manifest = {
    renderer: 'vue-book-renderer',
    rendererCommit: commit,
    rendererDirty: dirty != null && dirty.length > 0,
    files: fileEntries,
  }
  await writeFile(
    path.join(targetRoot, 'renderer-manifest.json'),
    `${JSON.stringify(manifest, null, 2)}\n`,
    'utf8',
  )

  await updatePubspec([...relativeFiles, 'renderer-manifest.json'])
  console.log(`[renderer-sync] copied ${relativeFiles.length} files`)
  console.log(`[renderer-sync] renderer commit: ${commit ?? 'unknown'}`)
  if (manifest.rendererDirty) {
    console.warn('[renderer-sync] source renderer has uncommitted changes')
  }
  console.log(`[renderer-sync] target: ${targetRoot}`)
}

main().catch((error) => {
  console.error(`[renderer-sync] ${error instanceof Error ? error.message : String(error)}`)
  process.exitCode = 1
})
