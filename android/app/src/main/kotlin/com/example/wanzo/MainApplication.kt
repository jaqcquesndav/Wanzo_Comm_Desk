package com.example.wanzo

import androidx.multidex.MultiDexApplication // Import MultiDexApplication
import io.flutter.embedding.android.FlutterActivity

// Change FlutterApplication to MultiDexApplication
class MainApplication : MultiDexApplication() {
    // You can leave this empty or add custom application logic here
}
