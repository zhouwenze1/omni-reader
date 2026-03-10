package com.example.reader_mobile

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.BatteryManager
import android.provider.DocumentsContract
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val FOLDER_IMPORT_REQUEST_CODE = 41021
    }

    private var pendingFolderImportResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "reader_mobile/device_status",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBatteryLevel" -> result.success(readBatteryLevel())
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "reader_mobile/folder_import",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickEpubFilesFromDirectory" -> openFolderImportPicker(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != FOLDER_IMPORT_REQUEST_CODE) {
            return
        }

        val result = pendingFolderImportResult ?: return
        pendingFolderImportResult = null

        if (resultCode != RESULT_OK) {
            result.success(null)
            return
        }

        handleFolderImportResult(data?.data, result)
    }

    private fun readBatteryLevel(): Int? {
        val batteryManager = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val capacity = batteryManager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            ?: return null
        return capacity.takeIf { it >= 0 }
    }

    private fun openFolderImportPicker(result: MethodChannel.Result) {
        if (pendingFolderImportResult != null) {
            result.error("busy", "Folder import picker is already active.", null)
            return
        }

        pendingFolderImportResult = result
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
            }
            startActivityForResult(intent, FOLDER_IMPORT_REQUEST_CODE)
        } catch (error: Throwable) {
            pendingFolderImportResult = null
            result.error("launch_failed", error.message, null)
        }
    }

    private fun handleFolderImportResult(uri: Uri?, result: MethodChannel.Result) {
        if (uri == null) {
            result.success(null)
            return
        }

        try {
            try {
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            } catch (_: SecurityException) {
            }

            val root = DocumentFile.fromTreeUri(this, uri)
            if (root == null || !root.isDirectory) {
                result.error("invalid_directory", "Unable to open selected directory.", null)
                return
            }

            val sessionDir = File(cacheDir, "folder_import/${System.currentTimeMillis()}")
            if (!sessionDir.exists()) {
                sessionDir.mkdirs()
            }

            val filePaths = mutableListOf<String>()
            collectEpubFiles(root, sessionDir, "", filePaths)

            val payload = hashMapOf<String, Any?>(
                "directoryName" to resolveDirectoryName(root),
                "paths" to filePaths,
                "cleanupRoots" to listOf(sessionDir.absolutePath),
            )
            result.success(payload)
        } catch (error: Throwable) {
            result.error("folder_import_failed", error.message, null)
        }
    }

    private fun collectEpubFiles(
        directory: DocumentFile,
        sessionDir: File,
        relativeDir: String,
        outputPaths: MutableList<String>,
    ) {
        val children = try {
            directory.listFiles()
        } catch (_: Throwable) {
            return
        }

        for (child in children) {
            if (child.isDirectory) {
                val segment = sanitizePathSegment(child.name ?: "folder")
                val nextRelativeDir = if (relativeDir.isEmpty()) {
                    segment
                } else {
                    "$relativeDir/$segment"
                }
                collectEpubFiles(child, sessionDir, nextRelativeDir, outputPaths)
                continue
            }

            if (!isEpubDocument(child)) {
                continue
            }

            val targetDir = if (relativeDir.isEmpty()) {
                sessionDir
            } else {
                File(sessionDir, relativeDir).apply {
                    if (!exists()) {
                        mkdirs()
                    }
                }
            }
            val targetFile = buildUniqueTargetFile(
                targetDir,
                ensureEpubExtension(child.name ?: "book.epub"),
            )
            copyDocumentToFile(child, targetFile)
            outputPaths.add(targetFile.absolutePath)
        }
    }

    private fun copyDocumentToFile(source: DocumentFile, target: File) {
        target.parentFile?.let { parent ->
            if (!parent.exists()) {
                parent.mkdirs()
            }
        }

        contentResolver.openInputStream(source.uri).use { input ->
            if (input == null) {
                throw IllegalStateException("Unable to read document: ${source.uri}")
            }
            FileOutputStream(target).use { output ->
                input.copyTo(output)
            }
        }
    }

    private fun isEpubDocument(file: DocumentFile): Boolean {
        val name = file.name?.lowercase()
        if (name != null && name.endsWith(".epub")) {
            return true
        }

        val type = file.type?.lowercase()
        if (type == "application/epub+zip") {
            return true
        }

        return type?.contains("epub") == true
    }

    private fun ensureEpubExtension(fileName: String): String {
        return if (fileName.lowercase().endsWith(".epub")) {
            fileName
        } else {
            "$fileName.epub"
        }
    }

    private fun buildUniqueTargetFile(directory: File, fileName: String): File {
        val safeName = sanitizePathSegment(fileName)
        var target = File(directory, safeName)
        if (!target.exists()) {
            return target
        }

        val dotIndex = safeName.lastIndexOf('.')
        val baseName = if (dotIndex > 0) safeName.substring(0, dotIndex) else safeName
        val extension = if (dotIndex > 0) safeName.substring(dotIndex) else ""

        var index = 1
        while (target.exists()) {
            target = File(directory, "${baseName}_$index$extension")
            index += 1
        }
        return target
    }

    private fun sanitizePathSegment(value: String): String {
        val sanitized = value.replace(Regex("[\\\\/:*?\"<>|]"), "_").trim()
        return if (sanitized.isEmpty()) "item" else sanitized
    }

    private fun resolveDirectoryName(root: DocumentFile): String {
        val name = root.name?.trim()
        if (!name.isNullOrEmpty()) {
            return name
        }
        val docId = try {
            DocumentsContract.getTreeDocumentId(root.uri)
        } catch (_: Throwable) {
            null
        }
        if (!docId.isNullOrEmpty()) {
            val candidate = docId.substringAfterLast(':').trim()
            if (candidate.isNotEmpty()) {
                return candidate
            }
        }
        return "未分类"
    }
}
