# Customer storefront sheets and media

Guest details now use a white, light-themed modal bottom sheet with scrolling
content and keyboard padding. Product details use 60% screen height, a bounded
hero, scrolling content and persistent quantity/Add controls. Rounded search
styling and resizeToAvoidBottomInset=false keep the main QR menu stable while
the keyboard opens. Popular picks wrap up to ten available products.

QR media previously set isMini=true, disabling videos/sliding despite autoplay
flags; the regular storefront explicitly disabled autoplay. Both now enable
muted independent playback and automatic slides. The existing shared media
component advances after video completion, times image slides, wraps to the
first item and loops a video-only product. Multiple players no longer compete
for the shared playback budget. Actual device decoder/network limits still apply.

Validation: QR suite passes 7 checks, including 60% height, ten-of-twelve popular
products, guest bottom sheet and stable Scaffold dimensions under keyboard
insets. Media suite passes 11 checks including simultaneous independent players.
Two additional capture checks pass. Real-font guest/product screenshots were
visually inspected in build/storefront_sheet_validation/previews/. Source
analysis and web build evidence are in the same folder. The two sheet files
analyze cleanly; the regular-menu file retains two existing style infos at
lines 901 and 963, outside the playback change. The initial web release
built in 134.1s; web-final.log records the final successful 118.5s build including regular-menu
autoplay. No production orders/payments or deployment were performed.

Concurrent tracking changes were already present in backend files, storefront
models/API/my-orders and table_qr_order_screen.dart. They were preserved. No
whole-file commit/push was made to avoid including that unrelated work.
