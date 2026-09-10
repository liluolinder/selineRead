#ifndef CANGHUI_UIKIT_HOST_VIEW_H
#define CANGHUI_UIKIT_HOST_VIEW_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/** UIKit ingress shared by CangHui-owned iOS surfaces. */
@interface CangHuiUIKitHostView : UIView
- (int64_t)canghuiSurfaceGeneration;
- (void)canghuiForwardTraits;
@end

NS_ASSUME_NONNULL_END

#endif
