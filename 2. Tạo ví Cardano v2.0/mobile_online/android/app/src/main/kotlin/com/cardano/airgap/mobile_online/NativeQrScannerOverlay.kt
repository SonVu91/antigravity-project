package com.cardano.airgap.mobile_online

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.*
import android.graphics.drawable.GradientDrawable
import android.hardware.Camera
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.*
import android.widget.*
import com.google.zxing.*
import com.google.zxing.common.GlobalHistogramBinarizer
import com.google.zxing.common.HybridBinarizer
import io.flutter.plugin.common.MethodChannel
import java.util.EnumMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs
import kotlin.math.min

@Suppress("DEPRECATION")
class NativeQrScannerOverlay(
    private val activity: Activity,
    private val channel: MethodChannel
) : TextureView.SurfaceTextureListener, Camera.PreviewCallback {

    companion object {
        const val CAMERA_PERMISSION_REQ_CODE = 9102
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val decodeExecutor = Executors.newSingleThreadExecutor()
    private val isDecodingFrame = AtomicBoolean(false)

    private var rootOverlay: FrameLayout? = null
    private var textureView: TextureView? = null
    private var viewfinderView: ViewfinderView? = null
    private var statusTextView: TextView? = null
    private var progressContainer: LinearLayout? = null
    private var progressLabelText: TextView? = null
    private var progressBar: ProgressBar? = null
    private var flashButton: Button? = null
    private var switchCamButton: Button? = null

    private var camera: Camera? = null
    private var currentCameraFacing = Camera.CameraInfo.CAMERA_FACING_BACK
    private var isTorchOn = false
    private var previewWidth = 0
    private var previewHeight = 0
    private var displayOrientation = 90
    private var previewBuffer: ByteArray? = null

    private var lastDecodedText: String = ""
    private var lastDecodedTimeMs: Long = 0L
    private val collectedMultipartIndices = mutableSetOf<Int>()
    private var multipartTotalCount = 0

    private val multiFormatReader = MultiFormatReader().apply {
        val hints = EnumMap<DecodeHintType, Any>(DecodeHintType::class.java)
        hints[DecodeHintType.POSSIBLE_FORMATS] = listOf(BarcodeFormat.QR_CODE)
        hints[DecodeHintType.CHARACTER_SET] = "UTF-8"
        hints[DecodeHintType.TRY_HARDER] = java.lang.Boolean.TRUE
        setHints(hints)
    }

    private val autoFocusPulseRunnable = object : Runnable {
        override fun run() {
            val cam = camera ?: return
            if (rootOverlay == null) return
            try {
                val params = cam.parameters
                val focusModes = params?.supportedFocusModes ?: emptyList()
                if (focusModes.contains(Camera.Parameters.FOCUS_MODE_AUTO) &&
                    !focusModes.contains(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE)
                ) {
                    cam.autoFocus(null)
                }
            } catch (_: Exception) {}
            mainHandler.postDelayed(this, 3200L)
        }
    }

    val isShowing: Boolean
        get() = rootOverlay != null

    fun startScannerWithPermissionCheck() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (activity.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                activity.requestPermissions(
                    arrayOf(Manifest.permission.CAMERA),
                    CAMERA_PERMISSION_REQ_CODE
                )
                return
            }
        }
        showOverlay()
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != CAMERA_PERMISSION_REQ_CODE) return false
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            showOverlay()
        } else {
            channel.invokeMethod(
                "onCameraError",
                "Chưa cấp quyền Camera. Vui lòng cho phép quyền Camera trên điện thoại để quét mã QR."
            )
        }
        return true
    }

    fun showOverlay() {
        mainHandler.post {
            if (rootOverlay != null) {
                return@post
            }
            collectedMultipartIndices.clear()
            multipartTotalCount = 0
            lastDecodedText = ""
            lastDecodedTimeMs = 0L
            isTorchOn = false

            val contentParent = activity.window?.decorView?.findViewById<ViewGroup>(android.R.id.content)
            if (contentParent == null) {
                channel.invokeMethod("onCameraError", "Không tìm thấy khung hiển thị màn hình.")
                return@post
            }

            val container = buildOverlayUi(activity)
            rootOverlay = container
            contentParent.addView(
                container,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
            )
            container.requestFocus()
        }
    }

    fun stopScanner(notifyFlutterClosed: Boolean = false) {
        mainHandler.post {
            mainHandler.removeCallbacks(autoFocusPulseRunnable)
            releaseCamera()
            val overlay = rootOverlay
            rootOverlay = null
            textureView = null
            viewfinderView = null
            if (overlay != null) {
                val parent = overlay.parent as? ViewGroup
                parent?.removeView(overlay)
            }
            if (notifyFlutterClosed) {
                channel.invokeMethod("onCameraClosed", null)
            }
        }
    }

    fun updateMultipartProgress(received: Int, total: Int) {
        mainHandler.post {
            if (total <= 1) return@post
            progressContainer?.visibility = View.VISIBLE
            val pct = min(100, (received * 100) / total)
            progressLabelText?.text = "Tiến độ quét QR Động: $received / $total mảnh ($pct%)"
            progressBar?.max = total
            progressBar?.progress = received
            statusTextView?.text = "Đang thu thập QR động ($received/$total)... Giữ nguyên camera"
        }
    }

    private fun buildOverlayUi(ctx: Context): FrameLayout {
        val root = FrameLayout(ctx).apply {
            setBackgroundColor(Color.parseColor("#0B0E14"))
            isClickable = true
            isFocusable = true
            isFocusableInTouchMode = true
            setOnKeyListener { _, keyCode, event ->
                if (keyCode == KeyEvent.KEYCODE_BACK && event.action == KeyEvent.ACTION_UP) {
                    stopScanner(notifyFlutterClosed = true)
                    true
                } else {
                    false
                }
            }
        }

        val texView = TextureView(ctx).apply {
            surfaceTextureListener = this@NativeQrScannerOverlay
            setOnClickListener {
                triggerTapToFocus()
            }
        }
        textureView = texView
        root.addView(
            texView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.CENTER
            )
        )

        val vf = ViewfinderView(ctx)
        viewfinderView = vf
        root.addView(
            vf,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )

        val topBar = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), dp(14), dp(16), dp(14))
            setBackgroundColor(Color.parseColor("#DD12161F"))
        }

        val titleCol = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }
        val titleTv = TextView(ctx).apply {
            text = "📷 Ví Nóng: Quét Mã QR Cardano"
            setTextColor(Color.parseColor("#FF6B00"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            typeface = Typeface.DEFAULT_BOLD
        }
        val subTv = TextView(ctx).apply {
            text = "Hỗ trợ mã QR tĩnh & QR động nhiều mảnh • Chạm màn hình để lấy nét"
            setTextColor(Color.parseColor("#94A3B8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f)
        }
        titleCol.addView(titleTv)
        titleCol.addView(subTv)

        val closeTopBtn = Button(ctx).apply {
            text = "✕ Đóng"
            isAllCaps = false
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setPadding(dp(14), dp(6), dp(14), dp(6))
            background = roundedRect(Color.parseColor("#2A2E39"), dp(8).toFloat(), Color.parseColor("#454D5D"))
            setOnClickListener {
                stopScanner(notifyFlutterClosed = true)
            }
        }

        topBar.addView(titleCol)
        topBar.addView(closeTopBtn)
        root.addView(
            topBar,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP
            )
        )

        val bottomPanel = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(14), dp(16), dp(20))
            setBackgroundColor(Color.parseColor("#DD12161F"))
        }

        val statusTv = TextView(ctx).apply {
            text = "Đưa mã QR từ Ví Lạnh vào giữa khung ngắm"
            setTextColor(Color.parseColor("#E2E8F0"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(10))
        }
        statusTextView = statusTv
        bottomPanel.addView(statusTv)

        val progBox = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.GONE
            setPadding(dp(12), dp(10), dp(12), dp(10))
            background = roundedRect(Color.parseColor("#181C24"), dp(10).toFloat(), Color.parseColor("#FF6B00"))
            val lp = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            lp.bottomMargin = dp(12)
            layoutParams = lp
        }
        val progLabel = TextView(ctx).apply {
            text = "Tiến độ quét QR Động: 0 / 0 mảnh (0%)"
            setTextColor(Color.parseColor("#FF6B00"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(0, 0, 0, dp(6))
        }
        val progBar = ProgressBar(ctx, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progress = 0
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(8))
        }
        progBox.addView(progLabel)
        progBox.addView(progBar)
        progressContainer = progBox
        progressLabelText = progLabel
        progressBar = progBar
        bottomPanel.addView(progBox)

        val btnRow = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }

        val flashBtn = Button(ctx).apply {
            text = "⚡ Đèn Flash: TẮT"
            isAllCaps = false
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
            background = roundedRect(Color.parseColor("#1E2430"), dp(10).toFloat(), Color.parseColor("#FF6B00"))
            layoutParams = LinearLayout.LayoutParams(0, dp(44), 1f).apply {
                rightMargin = dp(8)
            }
            setOnClickListener {
                toggleTorch()
            }
        }
        flashButton = flashBtn

        val switchBtn = Button(ctx).apply {
            text = "🔄 Đổi Camera"
            isAllCaps = false
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
            background = roundedRect(Color.parseColor("#1E2430"), dp(10).toFloat(), Color.parseColor("#64748B"))
            layoutParams = LinearLayout.LayoutParams(0, dp(44), 1f)
            setOnClickListener {
                switchCameraFacing()
            }
        }
        switchCamButton = switchBtn

        btnRow.addView(flashBtn)
        btnRow.addView(switchBtn)
        bottomPanel.addView(btnRow)

        root.addView(
            bottomPanel,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM
            )
        )

        return root
    }

    override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
        openAndStartCamera(surface, width, height)
    }

    override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {
        configureTextureTransform(width, height)
    }

    override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
        releaseCamera()
        return true
    }

    override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {}

    private fun openAndStartCamera(surface: SurfaceTexture, viewWidth: Int, viewHeight: Int) {
        releaseCamera()
        try {
            val numCameras = Camera.getNumberOfCameras()
            if (numCameras <= 0) {
                channel.invokeMethod("onCameraError", "Thiết bị không có phần cứng Camera.")
                stopScanner(notifyFlutterClosed = false)
                return
            }

            var selectedId = 0
            val info = Camera.CameraInfo()
            for (i in 0 until numCameras) {
                Camera.getCameraInfo(i, info)
                if (info.facing == currentCameraFacing) {
                    selectedId = i
                    break
                }
            }

            val cam = Camera.open(selectedId)
            camera = cam
            Camera.getCameraInfo(selectedId, info)

            val rotation = activity.windowManager.defaultDisplay.rotation
            val degrees = when (rotation) {
                Surface.ROTATION_0 -> 0
                Surface.ROTATION_90 -> 90
                Surface.ROTATION_180 -> 180
                Surface.ROTATION_270 -> 270
                else -> 0
            }

            displayOrientation = if (info.facing == Camera.CameraInfo.CAMERA_FACING_FRONT) {
                val r = (info.orientation + degrees) % 360
                (360 - r) % 360
            } else {
                (info.orientation - degrees + 360) % 360
            }
            cam.setDisplayOrientation(displayOrientation)

            val params = cam.parameters
            val bestSize = chooseOptimalPreviewSize(params.supportedPreviewSizes, 1280, 720, params.previewSize)
            previewWidth = bestSize.width
            previewHeight = bestSize.height
            params.setPreviewSize(previewWidth, previewHeight)
            params.previewFormat = ImageFormat.NV21

            val focusModes = params.supportedFocusModes ?: emptyList()
            when {
                focusModes.contains(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE) ->
                    params.focusMode = Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE
                focusModes.contains(Camera.Parameters.FOCUS_MODE_CONTINUOUS_VIDEO) ->
                    params.focusMode = Camera.Parameters.FOCUS_MODE_CONTINUOUS_VIDEO
                focusModes.contains(Camera.Parameters.FOCUS_MODE_AUTO) ->
                    params.focusMode = Camera.Parameters.FOCUS_MODE_AUTO
                focusModes.contains(Camera.Parameters.FOCUS_MODE_MACRO) ->
                    params.focusMode = Camera.Parameters.FOCUS_MODE_MACRO
            }

            try {
                cam.parameters = params
            } catch (_: Exception) {
                val fallbackParams = cam.parameters
                fallbackParams.setPreviewSize(previewWidth, previewHeight)
                cam.parameters = fallbackParams
            }

            configureTextureTransform(viewWidth, viewHeight)

            val bitsPerPixel = ImageFormat.getBitsPerPixel(ImageFormat.NV21)
            val bufferSize = (previewWidth * previewHeight * bitsPerPixel) / 8
            previewBuffer = ByteArray(bufferSize)
            cam.addCallbackBuffer(previewBuffer)
            cam.setPreviewCallbackWithBuffer(this)
            cam.setPreviewTexture(surface)
            cam.startPreview()

            mainHandler.removeCallbacks(autoFocusPulseRunnable)
            mainHandler.postDelayed(autoFocusPulseRunnable, 2500L)
        } catch (e: Exception) {
            channel.invokeMethod("onCameraError", "Không thể mở Camera: ${e.message}")
            stopScanner(notifyFlutterClosed = false)
        }
    }

    private fun configureTextureTransform(viewWidth: Int, viewHeight: Int) {
        val tex = textureView ?: return
        if (viewWidth <= 0 || viewHeight <= 0 || previewWidth <= 0 || previewHeight <= 0) return

        val isPortrait = displayOrientation == 90 || displayOrientation == 270
        val camW = if (isPortrait) previewHeight.toFloat() else previewWidth.toFloat()
        val camH = if (isPortrait) previewWidth.toFloat() else previewHeight.toFloat()
        val viewW = viewWidth.toFloat()
        val viewH = viewHeight.toFloat()

        val camAspect = camW / camH
        val viewAspect = viewW / viewH

        var scaleX = 1f
        var scaleY = 1f
        if (camAspect > viewAspect) {
            scaleX = camAspect / viewAspect
        } else {
            scaleY = viewAspect / camAspect
        }

        val matrix = Matrix()
        matrix.setScale(scaleX, scaleY, viewW / 2f, viewH / 2f)
        tex.setTransform(matrix)
    }

    private fun chooseOptimalPreviewSize(
        sizes: List<Camera.Size>?,
        targetW: Int,
        targetH: Int,
        fallback: Camera.Size
    ): Camera.Size {
        if (sizes.isNullOrEmpty()) {
            return fallback
        }
        val targetRatio = targetW.toDouble() / targetH.toDouble()
        var optimalSize: Camera.Size? = null
        var minDiff = Double.MAX_VALUE

        for (size in sizes) {
            if (size.width > 1920 || size.height > 1080 || size.width < 480) continue
            val ratio = size.width.toDouble() / size.height.toDouble()
            if (abs(ratio - targetRatio) > 0.25) continue
            val diff = abs(size.height - targetH).toDouble() + abs(size.width - targetW) * 0.5
            if (diff < minDiff) {
                optimalSize = size
                minDiff = diff
            }
        }

        if (optimalSize == null) {
            minDiff = Double.MAX_VALUE
            for (size in sizes) {
                if (size.width > 1920) continue
                val diff = abs(size.height - targetH).toDouble()
                if (diff < minDiff) {
                    optimalSize = size
                    minDiff = diff
                }
            }
        }
        return optimalSize ?: sizes[0]
    }

    override fun onPreviewFrame(data: ByteArray?, cam: Camera?) {
        if (data == null || cam == null || rootOverlay == null) return

        if (!isDecodingFrame.compareAndSet(false, true)) {
            cam.addCallbackBuffer(data)
            return
        }

        val w = previewWidth
        val h = previewHeight
        val frameCopy = data.copyOf(w * h)
        cam.addCallbackBuffer(data)

        decodeExecutor.execute {
            try {
                val decoded = decodeLuminanceFrame(frameCopy, w, h)
                if (!decoded.isNullOrEmpty()) {
                    onQrCodeDetected(decoded)
                }
            } catch (_: Exception) {
            } finally {
                isDecodingFrame.set(false)
            }
        }
    }

    private fun decodeLuminanceFrame(yPlane: ByteArray, width: Int, height: Int): String? {
        if (width <= 0 || height <= 0 || yPlane.size < width * height) return null

        val minDim = min(width, height)
        val cropSize = (minDim * 85) / 100
        val cropLeft = (width - cropSize) / 2
        val cropTop = (height - cropSize) / 2

        val rotatedSquare = ByteArray(cropSize * cropSize)
        for (y in 0 until cropSize) {
            val srcRow = (cropTop + y) * width + cropLeft
            for (x in 0 until cropSize) {
                rotatedSquare[x * cropSize + (cropSize - 1 - y)] = yPlane[srcRow + x]
            }
        }

        val cropSource = PlanarYUVLuminanceSource(
            rotatedSquare,
            cropSize,
            cropSize,
            0,
            0,
            cropSize,
            cropSize,
            false
        )

        decodeWithSource(cropSource)?.let { return it }

        val fullSource = PlanarYUVLuminanceSource(
            yPlane,
            width,
            height,
            0,
            0,
            width,
            height,
            false
        )
        return decodeWithSource(fullSource)
    }

    private fun decodeWithSource(source: LuminanceSource): String? {
        try {
            val res = multiFormatReader.decodeWithState(BinaryBitmap(HybridBinarizer(source)))
            if (!res.text.isNullOrBlank()) return res.text
        } catch (_: NotFoundException) {
        } finally {
            multiFormatReader.reset()
        }

        try {
            val res = multiFormatReader.decodeWithState(BinaryBitmap(GlobalHistogramBinarizer(source)))
            if (!res.text.isNullOrBlank()) return res.text
        } catch (_: NotFoundException) {
        } finally {
            multiFormatReader.reset()
        }

        try {
            val inverted = source.invert()
            val res = multiFormatReader.decodeWithState(BinaryBitmap(HybridBinarizer(inverted)))
            if (!res.text.isNullOrBlank()) return res.text
        } catch (_: NotFoundException) {
        } finally {
            multiFormatReader.reset()
        }

        return null
    }

    private fun onQrCodeDetected(rawText: String) {
        val clean = rawText.trim()
        if (clean.isEmpty()) return

        val now = System.currentTimeMillis()
        if (clean == lastDecodedText && (now - lastDecodedTimeMs) < 350L) {
            return
        }
        lastDecodedText = clean
        lastDecodedTimeMs = now

        mainHandler.post {
            if (rootOverlay == null) return@post

            // Multipart progress (UR:CARDANO-TX[-Z]/<seq>OF<total>/...) is tracked by the Dart
            // MultipartQrDecoder, which pushes it back via updateMultipartProgress().
            if (!clean.startsWith("UR:CARDANO-TX")) {
                statusTextView?.text = "✓ Đã nhận diện mã QR!"
            }

            channel.invokeMethod("onQrScanned", clean)
        }
    }

    private fun triggerTapToFocus() {
        val cam = camera ?: return
        try {
            statusTextView?.text = "Đang lấy nét ống kính..."
            cam.cancelAutoFocus()
            val params = cam.parameters
            val modes = params.supportedFocusModes ?: emptyList()
            if (modes.contains(Camera.Parameters.FOCUS_MODE_AUTO)) {
                params.focusMode = Camera.Parameters.FOCUS_MODE_AUTO
                cam.parameters = params
            }
            cam.autoFocus { _, c ->
                try {
                    val p = c.parameters
                    if (p.supportedFocusModes?.contains(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE) == true) {
                        p.focusMode = Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE
                        c.parameters = p
                    }
                } catch (_: Exception) {}
                mainHandler.post {
                    if (multipartTotalCount <= 1) {
                        statusTextView?.text = "Đã lấy nét • Đưa mã QR vào giữa khung ngắm"
                    }
                }
            }
        } catch (_: Exception) {}
    }

    private fun toggleTorch() {
        val cam = camera ?: return
        try {
            val params = cam.parameters
            val flashModes = params.supportedFlashModes ?: emptyList()
            if (!flashModes.contains(Camera.Parameters.FLASH_MODE_TORCH)) {
                Toast.makeText(activity, "Camera hiện tại không hỗ trợ đèn Flash.", Toast.LENGTH_SHORT).show()
                return
            }
            isTorchOn = !isTorchOn
            params.flashMode = if (isTorchOn) {
                Camera.Parameters.FLASH_MODE_TORCH
            } else {
                Camera.Parameters.FLASH_MODE_OFF
            }
            cam.parameters = params
            flashButton?.text = if (isTorchOn) "⚡ Đèn Flash: BẬT" else "⚡ Đèn Flash: TẮT"
            flashButton?.background = if (isTorchOn) {
                roundedRect(Color.parseColor("#C2410C"), dp(10).toFloat(), Color.parseColor("#FF6B00"))
            } else {
                roundedRect(Color.parseColor("#1E2430"), dp(10).toFloat(), Color.parseColor("#FF6B00"))
            }
        } catch (_: Exception) {}
    }

    private fun switchCameraFacing() {
        val numCameras = Camera.getNumberOfCameras()
        if (numCameras < 2) {
            Toast.makeText(activity, "Thiết bị chỉ có 1 Camera.", Toast.LENGTH_SHORT).show()
            return
        }
        currentCameraFacing = if (currentCameraFacing == Camera.CameraInfo.CAMERA_FACING_BACK) {
            Camera.CameraInfo.CAMERA_FACING_FRONT
        } else {
            Camera.CameraInfo.CAMERA_FACING_BACK
        }
        isTorchOn = false
        flashButton?.text = "⚡ Đèn Flash: TẮT"
        val tex = textureView
        val surface = tex?.surfaceTexture
        if (tex != null && surface != null) {
            openAndStartCamera(surface, tex.width, tex.height)
        }
    }

    private fun releaseCamera() {
        try {
            camera?.setPreviewCallbackWithBuffer(null)
            camera?.stopPreview()
        } catch (_: Exception) {}
        try {
            camera?.release()
        } catch (_: Exception) {}
        camera = null
        previewBuffer = null
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            activity.resources.displayMetrics
        ).toInt()
    }

    private fun roundedRect(fillColor: Int, radiusPx: Float, strokeColor: Int): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = radiusPx
            setColor(fillColor)
            setStroke(dp(1), strokeColor)
        }
    }

    private inner class ViewfinderView(context: Context) : View(context) {
        private val maskPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#990B0E14")
            style = Paint.Style.FILL
        }
        private val clearPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            xfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR)
        }
        private val frameBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#55FF6B00")
            style = Paint.Style.STROKE
            strokeWidth = dp(1).toFloat()
        }
        private val cornerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#FF6B00")
            style = Paint.Style.STROKE
            strokeWidth = dp(4).toFloat()
            strokeCap = Paint.Cap.ROUND
        }
        private val laserPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#CCFF6B00")
            style = Paint.Style.STROKE
            strokeWidth = dp(2).toFloat()
        }

        private var scanLineRatio = 0.1f
        private var scanDirection = 1
        private val boxRect = RectF()

        init {
            setLayerType(LAYER_TYPE_HARDWARE, null)
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val w = width.toFloat()
            val h = height.toFloat()
            if (w <= 0f || h <= 0f) return

            val boxSize = min(w, h) * 0.72f
            val left = (w - boxSize) / 2f
            val top = (h - boxSize) / 2f - dp(12)
            val right = left + boxSize
            val bottom = top + boxSize
            boxRect.set(left, top, right, bottom)

            val cornerRadius = dp(16).toFloat()
            canvas.drawRect(0f, 0f, w, h, maskPaint)
            canvas.drawRoundRect(boxRect, cornerRadius, cornerRadius, clearPaint)
            canvas.drawRoundRect(boxRect, cornerRadius, cornerRadius, frameBorderPaint)

            val len = dp(28).toFloat()
            canvas.drawLine(left, top + len, left, top, cornerPaint)
            canvas.drawLine(left, top, left + len, top, cornerPaint)
            canvas.drawLine(right - len, top, right, top, cornerPaint)
            canvas.drawLine(right, top, right, top + len, cornerPaint)
            canvas.drawLine(left, bottom - len, left, bottom, cornerPaint)
            canvas.drawLine(left, bottom, left + len, bottom, cornerPaint)
            canvas.drawLine(right - len, bottom, right, bottom, cornerPaint)
            canvas.drawLine(right, bottom - len, right, bottom, cornerPaint)

            val laserY = top + (boxSize * scanLineRatio)
            canvas.drawLine(left + dp(12), laserY, right - dp(12), laserY, laserPaint)

            scanLineRatio += 0.018f * scanDirection
            if (scanLineRatio >= 0.92f) {
                scanLineRatio = 0.92f
                scanDirection = -1
            } else if (scanLineRatio <= 0.08f) {
                scanLineRatio = 0.08f
                scanDirection = 1
            }
            postInvalidateDelayed(30L)
        }
    }
}
