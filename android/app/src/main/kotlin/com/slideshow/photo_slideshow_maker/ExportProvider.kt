package com.slideshow.photo_slideshow_maker

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.File
import java.io.FileNotFoundException
import java.util.UUID

class ExportProvider : ContentProvider() {
    override fun onCreate() = true

    private fun video(uri: Uri): File {
        val parts = uri.pathSegments
        if (parts.size != 2 || parts[1] != "Slideshow.mp4") throw FileNotFoundException()
        val id = runCatching { UUID.fromString(parts[0]).toString() }.getOrNull()
        if (id != parts[0]) throw FileNotFoundException()
        return File(context!!.cacheDir, "exports/$id/Slideshow.mp4").takeIf { it.isFile }
            ?: throw FileNotFoundException()
    }

    override fun getType(uri: Uri) = "video/mp4"

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw FileNotFoundException()
        return ParcelFileDescriptor.open(video(uri), ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun query(uri: Uri, projection: Array<out String>?, selection: String?,
        selectionArgs: Array<out String>?, sortOrder: String?): Cursor {
        val file = video(uri)
        val columns = (projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)).toList()
        return MatrixCursor(columns.toTypedArray()).apply {
            addRow(columns.map {
                when (it) {
                    OpenableColumns.DISPLAY_NAME -> file.name
                    OpenableColumns.SIZE -> file.length()
                    else -> null
                }
            })
        }
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?) = 0
}
