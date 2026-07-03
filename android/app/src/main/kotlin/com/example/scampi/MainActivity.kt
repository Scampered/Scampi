package com.example.scampi

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by the
// `health` package's Health Connect permission flow on Android 14+,
// which needs to cast the Activity to a ComponentActivity to use
// registerForActivityResult.
class MainActivity : FlutterFragmentActivity()
