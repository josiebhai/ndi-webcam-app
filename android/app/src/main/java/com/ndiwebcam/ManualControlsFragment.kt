package com.ndiwebcam

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.SeekBar
import androidx.fragment.app.Fragment
import com.ndiwebcam.databinding.FragmentManualControlsBinding

class ManualControlsFragment : Fragment() {

    private var _binding: FragmentManualControlsBinding? = null
    private val binding get() = _binding!!

    private val cameraFragment: CameraFragment?
        get() = parentFragmentManager.findFragmentById(R.id.fragment_container) as? CameraFragment

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        _binding = FragmentManualControlsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Exposure bias: -3 to +3 EV, slider 0-60
        binding.seekExposure.max = 60
        binding.seekExposure.progress = 30
        binding.seekExposure.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(sb: SeekBar, progress: Int, fromUser: Boolean) {
                val bias = progress - 30  // -30..+30 steps
                binding.labelExposureValue.text = if (bias >= 0) "+$bias" else "$bias"
                cameraFragment?.setExposureBias(bias)
            }
            override fun onStartTrackingTouch(sb: SeekBar) {}
            override fun onStopTrackingTouch(sb: SeekBar) {}
        })

        // ISO: 100–3200 (log scale), slider 0-100
        binding.seekIso.max = 100
        binding.seekIso.progress = 0
        binding.seekIso.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(sb: SeekBar, progress: Int, fromUser: Boolean) {
                // Map linear 0..100 to log ISO 100..3200
                val iso = (100.0 * Math.pow(32.0, progress / 100.0)).toLong().coerceIn(100, 3200)
                binding.labelIsoValue.text = "$iso"
                cameraFragment?.setManualISO(iso)
            }
            override fun onStartTrackingTouch(sb: SeekBar) {}
            override fun onStopTrackingTouch(sb: SeekBar) {}
        })

        // Shutter: 1/8000s to 1/2s (log scale), slider 0-100
        binding.seekShutter.max = 100
        binding.seekShutter.progress = 80
        binding.seekShutter.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(sb: SeekBar, progress: Int, fromUser: Boolean) {
                // Exposure time in nanoseconds: 125_000 ns (1/8000s) to 500_000_000 ns (1/2s)
                val minNs = 125_000L
                val maxNs = 500_000_000L
                val ns = (minNs.toDouble() * Math.pow(maxNs.toDouble() / minNs, progress / 100.0)).toLong()
                val fraction = 1_000_000_000L / ns
                binding.labelShutterValue.text = "1/$fraction"
                cameraFragment?.setManualShutter(ns)
            }
            override fun onStartTrackingTouch(sb: SeekBar) {}
            override fun onStopTrackingTouch(sb: SeekBar) {}
        })

        // White balance presets
        binding.btnWbAuto.setOnClickListener { cameraFragment?.setWhiteBalanceAuto() }
        binding.btnWbDaylight.setOnClickListener { cameraFragment?.setWhiteBalanceDaylight() }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
