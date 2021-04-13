package com.pavelclaudiustefan.flutter_snapchat

import android.content.DialogInterface
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.annotation.Nullable
import androidx.fragment.app.DialogFragment
import androidx.fragment.app.FragmentTransaction.TRANSIT_FRAGMENT_FADE
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
import com.snapchat.kit.sdk.bitmoji.ui.BitmojiFragment
import com.snapchat.kit.sdk.bitmoji.ui.BitmojiFragmentSearchMode

class BitmojiPickerBottomSheet : BottomSheetDialogFragment() {

    private var bitmojiFragment: BitmojiFragment? = null
    private var isReplySubmitted: Boolean = false

    var hasSearchBar: Boolean = true
    var hasSearchPills: Boolean = true
    var isDarkTheme: Boolean = false
    var friendUserId: String? = null
    var onBitmojiClickedListener: ((bitmojiUrl: String)->Unit)? = null
    var onDismissListener: ((isReplySubmitted: Boolean)->Unit)? = null

    companion object {
        fun newInstance(
                hasSearchBar: Boolean = true,
                hasSearchPills: Boolean = true,
                isDarkTheme: Boolean = false,
                friendUserId: String?,
                onBitmojiClickedListener: ((String)->Unit)?,
                onDismissListener: ((Boolean)->Unit)?): BitmojiPickerBottomSheet {

            val bitmojiPickerBottomSheet = BitmojiPickerBottomSheet()

//            bitmojiPickerBottomSheet.setStyle(DialogFragment.STYLE_NORMAL, R.style.CustomBottomSheetDialog)

            bitmojiPickerBottomSheet.hasSearchBar = hasSearchBar
            bitmojiPickerBottomSheet.hasSearchPills = hasSearchPills
            bitmojiPickerBottomSheet.isDarkTheme = isDarkTheme
            bitmojiPickerBottomSheet.friendUserId = friendUserId
            bitmojiPickerBottomSheet.onBitmojiClickedListener = onBitmojiClickedListener
            bitmojiPickerBottomSheet.onDismissListener = onDismissListener

            return bitmojiPickerBottomSheet
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

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
                dismiss()
            }

            if (!friendUserId.isNullOrBlank()) {
                bitmojiFragment!!.setFriend(friendUserId)
            }

            bitmojiFragment!!.allowEnterTransitionOverlap = true
        }

        // TODO - Add indeterminate progress bar while loading bitmoji picker

        childFragmentManager
                .beginTransaction()
//                .setCustomAnimations(R.anim.frag_slide_in_from_bottom, 0)
//                .setTransition(TRANSIT_FRAGMENT_FADE)
                .setCustomAnimations(R.anim.frag_slide_in_from_bottom, 0 , R.anim.frag_slide_in_from_bottom, 0)
                .replace(R.id.fragment_container_view, bitmojiFragment!!, "bitmoji_picker")
                .commit()
    }

    @Nullable
    override fun onCreateView(inflater: LayoutInflater,
                              @Nullable container: ViewGroup?,
                              @Nullable savedInstanceState: Bundle?): View {

        val view = inflater.inflate(R.layout.layout_bitmoji_picker_bottom_sheet, container, false)

//        val lightTheme = R.style.BitmojiPickerLight
//        val darkTheme = R.style.BitmojiPickerDark
//
//        if (bitmojiFragment == null) {
//            Log.i("ShadowDebug", "Creating bitmoji fragment")
//
//            bitmojiFragment = BitmojiFragment
//                    .builder()
//                    .withShowSearchBar(hasSearchBar)
//                    .withShowSearchPills(hasSearchPills)
//                    .withTheme(if (isDarkTheme) darkTheme else lightTheme)
//                    .build()
//
//            bitmojiFragment!!.setOnBitmojiSelectedListener { bitmojiUrl, _ ->
//                onBitmojiClickedListener?.invoke(bitmojiUrl)
//                isReplySubmitted = true
//                dismiss()
//            }
//
//            if (!friendUserId.isNullOrBlank()) {
//                bitmojiFragment!!.setFriend(friendUserId)
//            }
//
//            bitmojiFragment!!.allowEnterTransitionOverlap = true
//        }
//
//        // TODO - Add indeterminate progress bar while loading bitmoji picker
//
//        childFragmentManager
//                .beginTransaction()
////                .setCustomAnimations(R.anim.frag_slide_in_from_bottom, 0)
////                .setTransition(TRANSIT_FRAGMENT_FADE)
//                .replace(R.id.fragment_container_view, bitmojiFragment!!, "BitmojiPicker")
//                .commit()









//        if (childFragmentManager.findFragmentByTag("BitmojiPicker") == null) {
//            Log.i("ShadowDebug", "Adding bitmoji picker")
//            childFragmentManager
//                    .beginTransaction()
//                    .setCustomAnimations(R.anim.frag_slide_in_from_bottom, 0)
//                    .setTransition(TRANSIT_FRAGMENT_FADE)
//                    .add(R.id.fragment_container_view, bitmojiFragment!!, "BitmojiPicker")
//                    .commitNow()
//        } else {
//            Log.i("ShadowDebug", "Showing bitmoji picker")
//
//            childFragmentManager
//                    .beginTransaction()
//                    .setCustomAnimations(R.anim.frag_slide_in_from_bottom, 0)
//                    .show(bitmojiFragment!!)
//                    .setTransition(TRANSIT_FRAGMENT_FADE)
//                    .commitNow()
//        }

//        view.findViewById<ProgressBar>(R.id.progress_bar).visibility = View.INVISIBLE

        return view
    }

//    override fun onCancel(dialog: DialogInterface) {
//        onDismissListener?.invoke(isReplySubmitted)
//        super.onCancel(dialog)
//    }

    override fun onDismiss(dialog: DialogInterface) {
        onDismissListener?.invoke(isReplySubmitted)
        super.onDismiss(dialog)
    }

//    override fun getTheme(): Int {
//        return R.style.CustomBottomSheetDialog
//    }

    fun setSearchText(searchText: String?, searchMode: BitmojiFragmentSearchMode = BitmojiFragmentSearchMode.SEARCH_RESULT_ONLY) {
        bitmojiFragment?.setSearchText(searchText ?: "", searchMode)
    }
}