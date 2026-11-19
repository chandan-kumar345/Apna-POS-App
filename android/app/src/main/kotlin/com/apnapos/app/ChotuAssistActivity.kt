package com.apnapos.app

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.ProgressBar
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class ChotuAssistActivity : FlutterActivity() {
    private var startupCard: FrameLayout? = null
    private var flutterVisible = false

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        flutterVisible = true
        startupCard?.let { (it.parent as? android.view.ViewGroup)?.removeView(it) }
        startupCard = null
    }

    private fun showStartupCard() {
        if (flutterVisible) return
        fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
        val root = FrameLayout(this)
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(22), dp(20), dp(22), dp(20))
            background = GradientDrawable().apply {
                setColor(Color.rgb(250, 252, 255))
                cornerRadius = dp(26).toFloat()
            }
        }
        card.addView(TextView(this).apply {
            text = "Chotu AI"
            textSize = 20f
            setTextColor(Color.rgb(16, 43, 72))
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        })
        card.addView(TextView(this).apply {
            text = "Getting ready…"
            textSize = 14f
            setTextColor(Color.rgb(53, 73, 95))
            setPadding(0, dp(12), 0, dp(16))
        })
        card.addView(ProgressBar(this), LinearLayout.LayoutParams(dp(28), dp(28)))
        root.addView(card, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM
        ).apply { setMargins(dp(16), dp(16), dp(16), dp(24)) })
        addContentView(root, android.view.ViewGroup.LayoutParams(-1, -1))
        startupCard = root
    }
    companion object {
        private const val OVERLAY_CHANNEL = "com.apnapos.app/chotu_assist_overlay"
    }

    override fun getBackgroundMode(): FlutterActivityLaunchConfigs.BackgroundMode {
        return FlutterActivityLaunchConfigs.BackgroundMode.transparent
    }

    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }

    override fun getDartEntrypointFunctionName(): String {
        return "chotuAssistMain"
    }

    override fun getInitialRoute(): String {
        return "/chotu-assist"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        intent.putExtra("background_mode", FlutterActivityLaunchConfigs.BackgroundMode.transparent.name)
        if (!intent.hasExtra("route")) {
            intent.putExtra("route", "/chotu-assist")
        }
        window.setFormat(PixelFormat.TRANSLUCENT)
        window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        window.setDimAmount(0f)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { splashScreenView ->
                splashScreenView.remove()
            }
        }
        super.onCreate(savedInstanceState)
        showStartupCard()
        wakeAndUnlock()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        wakeAndUnlock()
    }

    private fun wakeAndUnlock() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            km?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAssistActivity" -> {
                    result.success(true)
                }
                "closeAssist" -> {
                    finish()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        overrideActivityTransition(OVERRIDE_TRANSITION_CLOSE, 0, android.R.anim.fade_out)
                    } else {
                        @Suppress("DEPRECATION")
                        overridePendingTransition(0, android.R.anim.fade_out)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onBackPressed() {
        finish()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            overrideActivityTransition(OVERRIDE_TRANSITION_CLOSE, 0, android.R.anim.fade_out)
        } else {
            @Suppress("DEPRECATION")
            overridePendingTransition(0, android.R.anim.fade_out)
        }
    }
}
