package com.ndiwebcam

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.preference.*

class SettingsActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        if (savedInstanceState == null) {
            supportFragmentManager.beginTransaction()
                .replace(R.id.settings_container, SettingsFragment())
                .commit()
        }
    }

    override fun onSupportNavigateUp(): Boolean {
        onBackPressedDispatcher.onBackPressed()
        return true
    }
}

class SettingsFragment : PreferenceFragmentCompat() {

    override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
        val context = preferenceManager.context
        val screen  = preferenceManager.createPreferenceScreen(context)

        // Source
        screen.addPreference(PreferenceCategory(context).apply { title = "Source" })
        screen.addPreference(EditTextPreference(context).apply {
            key     = "sourceName"
            title   = "NDI Source Name"
            summary = "Name shown in OBS / vMix source list"
            setDefaultValue(android.os.Build.MODEL)
        })

        // Video
        screen.addPreference(PreferenceCategory(context).apply { title = "Video" })
        screen.addPreference(ListPreference(context).apply {
            key      = "resolution"
            title    = "Resolution"
            entries  = arrayOf("720p", "1080p", "4K")
            entryValues = arrayOf("720", "1080", "2160")
            setDefaultValue("1080")
            summaryProvider = ListPreference.SimpleSummaryProvider.getInstance()
        })
        screen.addPreference(ListPreference(context).apply {
            key      = "fps"
            title    = "Frame Rate"
            entries  = arrayOf("24 fps", "30 fps", "60 fps")
            entryValues = arrayOf("24", "30", "60")
            setDefaultValue("30")
            summaryProvider = ListPreference.SimpleSummaryProvider.getInstance()
        })
        screen.addPreference(ListPreference(context).apply {
            key      = "ndiMode"
            title    = "NDI Mode"
            entries  = arrayOf("NDI|HX (recommended for Wi-Fi)", "Full NDI")
            entryValues = arrayOf("HX", "FULL")
            setDefaultValue("HX")
            summaryProvider = ListPreference.SimpleSummaryProvider.getInstance()
        })

        // Audio
        screen.addPreference(PreferenceCategory(context).apply { title = "Audio" })
        screen.addPreference(buildAudioDevicePreference(context))

        // Network
        screen.addPreference(PreferenceCategory(context).apply { title = "Network" })
        screen.addPreference(EditTextPreference(context).apply {
            key     = "discoveryServer"
            title   = "NDI Discovery Server"
            summary = "Leave blank for mDNS auto-discovery on local network"
        })

        preferenceScreen = screen
    }

    private fun buildAudioDevicePreference(context: Context): ListPreference {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val devices = am.getDevices(AudioManager.GET_DEVICES_INPUTS)

        val names = devices.map { it.toDisplayName() }.toTypedArray()
        val ids   = devices.map { it.id.toString() }.toTypedArray()

        return ListPreference(context).apply {
            key      = "audioDevice"
            title    = "Microphone"
            entries  = names
            entryValues = ids
            setDefaultValue(ids.firstOrNull() ?: "")
            summaryProvider = ListPreference.SimpleSummaryProvider.getInstance()
        }
    }

    private fun AudioDeviceInfo.toDisplayName(): String = when (type) {
        AudioDeviceInfo.TYPE_BUILTIN_MIC    -> "Built-in Microphone"
        AudioDeviceInfo.TYPE_WIRED_HEADSET  -> "Wired Headset"
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO  -> "Bluetooth (SCO)"
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "Bluetooth (A2DP)"
        AudioDeviceInfo.TYPE_USB_DEVICE     -> "USB Microphone"
        AudioDeviceInfo.TYPE_USB_HEADSET    -> "USB Headset"
        else -> "Audio Device ($id)"
    }
}
