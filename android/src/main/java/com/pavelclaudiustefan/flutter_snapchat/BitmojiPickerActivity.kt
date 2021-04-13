package com.pavelclaudiustefan.flutter_snapchat

import android.app.Activity
import android.content.Intent
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import android.util.Log
import com.snapchat.kit.sdk.bitmoji.ui.BitmojiFragment

class BitmojiPickerActivity : AppCompatActivity() {
    private var bitmojiFragment: BitmojiFragment? = null
    private var isReplySubmitted: Boolean = false

    var hasSearchBar: Boolean = true
    var hasSearchPills: Boolean = true
    var isDarkTheme: Boolean = false
    var friendUserId: String? = null
    var onBitmojiClickedListener: ((bitmojiUrl: String)->Unit)? = null
    var onDismissListener: ((isReplySubmitted: Boolean)->Unit)? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_bitmoji_picker)

        val lightTheme = R.style.BitmojiPickerLight
        val darkTheme = R.style.BitmojiPickerDark

        if (bitmojiFragment == null) {
            Log.i("ShadowDebug", "Creating bitmoji fragment")

            bitmojiFragment = BitmojiFragment
                    .builder()
                    .withShowSearchBar(hasSearchBar)
                    .withShowSearchPills(hasSearchPills)
                    .withTheme(if (isDarkTheme) darkTheme else lightTheme)
                    .build()

            bitmojiFragment!!.setOnBitmojiSelectedListener { bitmojiUrl, _ ->
                onBitmojiClickedListener?.invoke(bitmojiUrl)
                isReplySubmitted = true

                val resultIntent = Intent()
                resultIntent.putExtra("bitmojiUrl", bitmojiUrl)

                setResult(Activity.RESULT_OK, resultIntent);
                finish()
            }

            if (!friendUserId.isNullOrBlank()) {
                bitmojiFragment!!.setFriend(friendUserId)
            }

            bitmojiFragment!!.allowEnterTransitionOverlap = true
        }

        // TODO - Add indeterminate progress bar while loading bitmoji picker

        Log.i("ShadowDebug", "Last version")

        supportFragmentManager
                .beginTransaction()
//                .setCustomAnimations(R.anim.frag_slide_in_from_bottom, 0)
//                .setTransition(TRANSIT_FRAGMENT_FADE)
                .setCustomAnimations(R.anim.frag_slide_in_from_bottom, 0 , R.anim.frag_slide_in_from_bottom, 0)
                .add(R.id.fragment_container_view, bitmojiFragment!!, "BitmojiPicker")
                .commit()
    }
}