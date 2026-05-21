package seline.book.read;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import ohos.stage.ability.adapter.StageActivity;


public class EntryEntryAbilityActivity extends StageActivity {
    static {
        System.loadLibrary("jniseline_read");
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        Log.e("HiHelloWorld", "EntryEntryAbilityActivity");

        Intent intent = getIntent();
        if (intent != null) {
            intent.putExtra("test", "test");
            intent.putExtra("bundleName", "bundleName");
            intent.putExtra("moduleName", "moduleName");
            intent.putExtra("unittest", "unittest");
            intent.putExtra("timeout", "101");
        }

        setInstanceName("seline.book.read:entry:EntryAbility:");
        super.onCreate(savedInstanceState);
        avoidSafeArea.setupImmersive(getWindow());
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            avoidSafeArea.hideSystemUI(getWindow());
        }
    }
}
