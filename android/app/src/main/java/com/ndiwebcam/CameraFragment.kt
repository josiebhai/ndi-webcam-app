package com.ndiwebcam

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.ImageFormat
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.media.Image
import android.media.ImageReader
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.util.Range
import android.view.LayoutInflater
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import com.ndiwebcam.databinding.FragmentCameraBinding
import java.nio.ByteBuffer

class CameraFragment : Fragment() {

    // MARK: Binding / NDI

    private var _binding: FragmentCameraBinding? = null
    private val binding get() = _binding!!

    val ndiStreamer = NDIStreamer()
    private lateinit var audioManager: NDIAudioManager

    // MARK: Camera2

    private val cameraManager by lazy {
        requireContext().getSystemService(Context.CAMERA_SERVICE) as CameraManager
    }

    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null

    private var usingFrontCamera = false
    private var targetWidth  = 1920
    private var targetHeight = 1080
    private var targetFps    = 30

    // Manual control values
    private var exposureBias     = 0
    private var manualISO        = -1L     // -1 = auto
    private var manualShutterNs  = -1L     // -1 = auto
    private var manualWBMode     = CameraMetadata.CONTROL_AWB_MODE_AUTO

    // MARK: Fragment lifecycle

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        _binding = FragmentCameraBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        audioManager = NDIAudioManager(requireContext())

        binding.textureView.surfaceTextureListener = surfaceTextureListener
        setupButtonListeners()
    }

    override fun onResume() {
        super.onResume()
        startBackgroundThread()
        if (binding.textureView.isAvailable) {
            openCamera()
        }
    }

    override fun onPause() {
        closeCamera()
        stopBackgroundThread()
        super.onPause()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }

    // MARK: Camera open/close

    @SuppressLint("MissingPermission")
    private fun openCamera() {
        val cameraId = selectCamera(usingFrontCamera)
        imageReader = ImageReader.newInstance(targetWidth, targetHeight, ImageFormat.YUV_420_888, 2)
        imageReader!!.setOnImageAvailableListener({ reader ->
            val image = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
            processFrame(image)
            image.close()
        }, backgroundHandler)

        cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
            override fun onOpened(camera: CameraDevice) {
                cameraDevice = camera
                createCaptureSession()
            }
            override fun onDisconnected(camera: CameraDevice) { camera.close(); cameraDevice = null }
            override fun onError(camera: CameraDevice, error: Int) {
                camera.close(); cameraDevice = null
                Log.e(TAG, "Camera error $error")
            }
        }, backgroundHandler)
    }

    private fun closeCamera() {
        captureSession?.close(); captureSession = null
        cameraDevice?.close();   cameraDevice   = null
        imageReader?.close();    imageReader    = null
    }

    private fun selectCamera(front: Boolean): String {
        return cameraManager.cameraIdList.first { id ->
            val chars = cameraManager.getCameraCharacteristics(id)
            val facing = chars.get(CameraCharacteristics.LENS_FACING)
            val wanted = if (front) CameraCharacteristics.LENS_FACING_FRONT
                         else       CameraCharacteristics.LENS_FACING_BACK
            facing == wanted
        }
    }

    // MARK: Capture session

    private fun createCaptureSession() {
        val device = cameraDevice ?: return
        val reader = imageReader ?: return
        val texture = binding.textureView.surfaceTexture ?: return
        texture.setDefaultBufferSize(targetWidth, targetHeight)
        val previewSurface = Surface(texture)
        val readerSurface  = reader.surface

        device.createCaptureSession(
            listOf(previewSurface, readerSurface),
            object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    captureSession = session
                    startRepeatingCapture(previewSurface, readerSurface)
                }
                override fun onConfigureFailed(session: CameraCaptureSession) {
                    Log.e(TAG, "Capture session configuration failed")
                }
            },
            backgroundHandler
        )
    }

    private fun startRepeatingCapture(previewSurface: Surface, readerSurface: Surface) {
        val device  = cameraDevice ?: return
        val session = captureSession ?: return

        val builder = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
            addTarget(previewSurface)
            addTarget(readerSurface)
            set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, Range(targetFps, targetFps))
            applyManualControls(this)
        }

        session.setRepeatingRequest(builder.build(), null, backgroundHandler)
    }

    private fun applyManualControls(builder: CaptureRequest.Builder) {
        if (manualISO > 0 && manualShutterNs > 0) {
            builder.set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_OFF)
            builder.set(CaptureRequest.SENSOR_SENSITIVITY, manualISO.toInt())
            builder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, manualShutterNs)
        } else {
            builder.set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON)
            builder.set(CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION, exposureBias)
        }
        builder.set(CaptureRequest.CONTROL_AWB_MODE, manualWBMode)
    }

    // MARK: Frame processing

    // Converts YUV_420_888 Image to UYVY ByteArray and sends to NDI.
    private fun processFrame(image: Image) {
        if (!ndiStreamer.isStreaming) return

        val yPlane  = image.planes[0]
        val uPlane  = image.planes[1]
        val vPlane  = image.planes[2]

        val width   = image.width
        val height  = image.height
        val uvWidth = width / 2

        // UYVY: [U0, Y0, V0, Y1] per 2-pixel block
        val uyvySize = width * height * 2
        val uyvy = ByteArray(uyvySize)

        val yBuf = yPlane.buffer
        val uBuf = uPlane.buffer
        val vBuf = vPlane.buffer

        val yStride = yPlane.rowStride
        val uStride = uPlane.rowStride
        val uvPixelStride = uPlane.pixelStride

        for (row in 0 until height) {
            val uyvyRowOffset = row * width * 2
            val yRowOffset    = row * yStride
            val uvRowOffset   = (row / 2) * uStride

            for (col in 0 until uvWidth) {
                val yIdx  = yRowOffset + col * 2
                val uvIdx = uvRowOffset + col * uvPixelStride
                val dstIdx = uyvyRowOffset + col * 4

                uyvy[dstIdx]     = uBuf.get(uvIdx)           // U
                uyvy[dstIdx + 1] = yBuf.get(yIdx)            // Y0
                uyvy[dstIdx + 2] = vBuf.get(uvIdx)           // V
                uyvy[dstIdx + 3] = yBuf.get(yIdx + 1)        // Y1
            }
        }

        ndiStreamer.sendVideoFrame(uyvy, width, height, targetFps * 1000, 1000)
    }

    // MARK: Button listeners

    private fun setupButtonListeners() {
        binding.btnStream.setOnClickListener {
            if (ndiStreamer.isStreaming) stopStreaming() else startStreaming()
        }
        binding.btnSwitchCamera.setOnClickListener {
            usingFrontCamera = !usingFrontCamera
            closeCamera()
            openCamera()
        }
        binding.btnTorch.setOnClickListener { toggleTorch() }
        binding.btnManualControls.setOnClickListener {
            binding.manualControlsPanel.visibility =
                if (binding.manualControlsPanel.visibility == View.GONE) View.VISIBLE else View.GONE
        }
    }

    private fun startStreaming() {
        val prefs = requireContext().getSharedPreferences("settings", Context.MODE_PRIVATE)
        val name  = prefs.getString("sourceName", android.os.Build.MODEL) ?: android.os.Build.MODEL

        if (ndiStreamer.start(name)) {
            audioManager.startCapture(ndiStreamer)
            binding.btnStream.text = "Stop"
            binding.tallyIndicator.visibility = View.VISIBLE
            StreamingService.start(requireContext())
        } else {
            Toast.makeText(requireContext(), "Failed to start NDI", Toast.LENGTH_SHORT).show()
        }
    }

    private fun stopStreaming() {
        audioManager.stopCapture()
        ndiStreamer.stop()
        binding.btnStream.text = "Go Live"
        binding.tallyIndicator.visibility = View.GONE
        StreamingService.stop(requireContext())
    }

    private fun toggleTorch() {
        if (usingFrontCamera) return
        try {
            val cameraId = selectCamera(false)
            val chars    = cameraManager.getCameraCharacteristics(cameraId)
            val hasFlash = chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            if (hasFlash) {
                cameraManager.setTorchMode(cameraId, binding.btnTorch.isActivated.not())
                binding.btnTorch.isActivated = !binding.btnTorch.isActivated
            }
        } catch (e: Exception) {
            Log.e(TAG, "Torch error: ${e.message}")
        }
    }

    // MARK: Manual controls (called from ManualControlsFragment)

    fun setExposureBias(steps: Int) {
        exposureBias = steps
        refreshCapture()
    }

    fun setManualISO(iso: Long) {
        manualISO = iso
        refreshCapture()
    }

    fun setManualShutter(durationNs: Long) {
        manualShutterNs = durationNs
        refreshCapture()
    }

    fun setWhiteBalanceAuto() {
        manualWBMode = CameraMetadata.CONTROL_AWB_MODE_AUTO
        refreshCapture()
    }

    fun setWhiteBalanceDaylight() {
        manualWBMode = CameraMetadata.CONTROL_AWB_MODE_DAYLIGHT
        refreshCapture()
    }

    private fun refreshCapture() {
        val previewTexture = binding.textureView.surfaceTexture ?: return
        val previewSurface = Surface(previewTexture)
        val readerSurface  = imageReader?.surface ?: return
        startRepeatingCapture(previewSurface, readerSurface)
    }

    // MARK: Background thread

    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("CameraBackground").also { it.start() }
        backgroundHandler = Handler(backgroundThread!!.looper)
    }

    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        backgroundThread?.join()
        backgroundThread = null
        backgroundHandler = null
    }

    // MARK: SurfaceTexture listener

    private val surfaceTextureListener = object : TextureView.SurfaceTextureListener {
        override fun onSurfaceTextureAvailable(surface: SurfaceTexture, w: Int, h: Int) = openCamera()
        override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, w: Int, h: Int) {}
        override fun onSurfaceTextureDestroyed(surface: SurfaceTexture) = true
        override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {}
    }

    companion object {
        private const val TAG = "CameraFragment"
    }
}
