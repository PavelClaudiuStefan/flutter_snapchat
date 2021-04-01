package com.pavelclaudiustefan.flutter_snapchat

import android.content.DialogInterface
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.annotation.Nullable
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
import com.snapchat.kit.sdk.bitmoji.ui.BitmojiFragment

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

            bitmojiPickerBottomSheet.hasSearchBar = hasSearchBar
            bitmojiPickerBottomSheet.hasSearchPills = hasSearchPills
            bitmojiPickerBottomSheet.isDarkTheme = isDarkTheme
            bitmojiPickerBottomSheet.friendUserId = friendUserId
            bitmojiPickerBottomSheet.onBitmojiClickedListener = onBitmojiClickedListener
            bitmojiPickerBottomSheet.onDismissListener = onDismissListener

            return bitmojiPickerBottomSheet
        }
    }

    @Nullable
    override fun onCreateView(inflater: LayoutInflater,
                              @Nullable container: ViewGroup?,
                              @Nullable savedInstanceState: Bundle?): View {

        val view = inflater.inflate(R.layout.layout_bitmoji_picker_bottom_sheet, container, false)

        val lightTheme = R.style.SnapKitBitmojiFragment_Light
        val darkTheme = R.style.SnapKitBitmojiFragment_Dark

        if (bitmojiFragment == null) {
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
        }

        childFragmentManager
                .beginTransaction()
                .replace(R.id.frameLayout, bitmojiFragment!!)
                .addToBackStack("BitmojiPicker")
                .commitAllowingStateLoss()

        return view
    }

    override fun onDismiss(dialog: DialogInterface) {
        onDismissListener?.invoke(isReplySubmitted)
        super.onDismiss(dialog)
    }

    override fun getTheme(): Int {
        return R.style.CustomBottomSheetDialog
    }
}