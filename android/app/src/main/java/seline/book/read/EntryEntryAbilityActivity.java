package seline.book.read;

import android.os.Bundle;
import android.util.Log;

import ohos.stage.ability.adapter.StageActivity;

import cangjie.lang.LibraryLoader;

public class EntryEntryAbilityActivity extends StageActivity {
    // Required for Cangjie initialization
    static {
        LibraryLoader.loadLibrary("ohos_app_cangjie_entry");
    }
    @Override
    protected void onResume() {
        super.onResume();
        seline.book.prefs.WindowBridge.attach(this);
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        Log.e("HiHelloWorld", "EntryEntryAbilityActivity");

        // Bundle OpenSSL 3 with an errno shim so stdx TLS does not fall back to
        // the system BoringSSL libcrypto (which lacks CRYPTO_get_ex_new_index).
        try {
            OpenSslPreload.load(getApplicationInfo().nativeLibraryDir);
        } catch (Throwable t) {
            Log.e("HiHelloWorld", "OpenSSL preload failed", t);
        }

        // SelineRead platform services: SharedPreferences + edge-to-edge window metrics.
        seline.book.prefs.PrefsStore.attach(this);
        seline.book.prefs.WindowBridge.attach(this);

        String abilityName = getIntent().getStringExtra("keels.test.abilityName");
        if (abilityName == null || abilityName.isEmpty()) {
            abilityName = "EntryAbility";
        }
        setInstanceName("seline.book.read:entry:" + abilityName + ":");
        super.onCreate(savedInstanceState);
    }
}


