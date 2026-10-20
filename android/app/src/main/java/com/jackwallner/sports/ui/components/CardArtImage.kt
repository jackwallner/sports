package com.jackwallner.sports.ui.components

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/**
 * `CardArtStore`: Pollinations' free tier allows one in-flight request per IP
 * (HTTP 402 past that) and takes seconds per fresh image. Every download goes
 * through one lock, 402 and 429 back off and retry, and successes land on disk
 * so a card's art is fetched at most once.
 */
object CardArtStore {
    private val memory = object : LruCache<String, Bitmap>(24 * 1024 * 1024) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }
    private val serial = Mutex()

    fun cached(context: Context, url: String): Bitmap? {
        memory.get(url)?.let { return it }
        val file = diskFile(context, url)
        if (!file.isFile) return null
        return BitmapFactory.decodeFile(file.path)?.also { memory.put(url, it) }
    }

    suspend fun fetch(context: Context, url: String): Bitmap? {
        cached(context, url)?.let { return it }
        return serial.withLock {
            cached(context, url) ?: withContext(Dispatchers.IO) { download(context, url) }
        }
    }

    private suspend fun download(context: Context, url: String): Bitmap? {
        for (attempt in 0 until 3) {
            val result = runCatching {
                val connection = URL(url).openConnection() as HttpURLConnection
                connection.connectTimeout = 20_000
                connection.readTimeout = 60_000
                try {
                    val status = connection.responseCode
                    status to if (status in 200..299) connection.inputStream.use { it.readBytes() } else null
                } finally {
                    connection.disconnect()
                }
            }.getOrNull() ?: return null
            val (status, bytes) = result
            if (bytes != null) {
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
                memory.put(url, bitmap)
                runCatching { diskFile(context, url).writeBytes(bytes) }
                return bitmap
            }
            // 402/429: our one free slot is busy. Wait it out and try again.
            if ((status != 402 && status != 429) || attempt >= 2) return null
            delay(5_000L * (attempt + 1))
        }
        return null
    }

    /** Caches/CardArt, purgeable by the system. FNV-1a 64 of the URL names the file, as on iOS. */
    private fun diskFile(context: Context, url: String): File {
        var hash = -0x340d631b7bdddcdbL // 14695981039346656037
        for (byte in url.toByteArray(Charsets.UTF_8)) {
            hash = hash xor (byte.toLong() and 0xFF)
            hash *= 1_099_511_628_211L
        }
        val dir = File(context.cacheDir, "CardArt").apply { mkdirs() }
        return File(dir, "${java.lang.Long.toUnsignedString(hash)}.img")
    }

    /** Warms each card's primary URL; the chain's fallbacks are for failures only. */
    fun prefetch(context: Context, urls: List<String>, scope: CoroutineScope) {
        for (url in urls) {
            if (memory.get(url) != null) continue
            scope.launch { fetch(context, url) }
        }
    }
}

/**
 * `CardArtImage`: renders nothing until an image is in hand, so the card's
 * gradient stays the floor and the art fades in. Walks its URL chain in order.
 */
@Composable
fun CardArtImage(urls: List<String>, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    var bitmap by remember(urls) { mutableStateOf(urls.firstNotNullOfOrNull { CardArtStore.cached(context, it) }) }
    val fade = remember(urls) { Animatable(if (bitmap != null) 1f else 0f) }
    LaunchedEffect(urls) {
        if (bitmap != null) return@LaunchedEffect
        for (url in urls) {
            if (!isActive) return@LaunchedEffect
            val fetched = CardArtStore.fetch(context, url)
            if (fetched != null) {
                bitmap = fetched
                fade.animateTo(1f, tween(350))
                return@LaunchedEffect
            }
        }
    }
    Box(modifier.fillMaxSize().clipToBounds()) {
        bitmap?.let {
            Image(it.asImageBitmap(), null, Modifier.fillMaxSize().alpha(fade.value), contentScale = ContentScale.Crop)
        }
    }
}
