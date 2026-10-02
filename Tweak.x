#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <notify.h>
#import <objc/runtime.h>

#define NOTIFY_START_STOP_VIDEO "com.spark.SneakyCam.startstopvideo"

@interface _UIStatusBar : UIView
@end

@interface UIStatusBar_Modern : UIView
@end

@interface SCHoldGestureDelegate : NSObject <UIGestureRecognizerDelegate>
+ (instancetype)sharedDelegate;
@end

@implementation SCHoldGestureDelegate

+ (instancetype)sharedDelegate {
    static SCHoldGestureDelegate *d = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        d = [[SCHoldGestureDelegate alloc] init];
    });
    return d;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

@end

static NSTimeInterval g_lastSneakyTriggerTime = 0;

static void triggerSneakyCamAction(void) {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - g_lastSneakyTriggerTime < 1.0) {
        return; // Debounce 1.0s
    }
    g_lastSneakyTriggerTime = now;

    // 1. Rung nhẹ xúc giác Taptic Engine (Peek vibration)
    AudioServicesPlaySystemSound(1519);

    // 2. Phát sóng Darwin notification toàn hệ thống tới mediaserverd (nơi SneakyCam chạy ngầm)
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR(NOTIFY_START_STOP_VIDEO),
        NULL,
        NULL,
        YES
    );
}

static void addHoldGestureToStatusBar(UIView *view) {
    if (!view) return;

    static const char *kSCHoldGestureKey = "kSCHoldLeftNotchGesture";
    if (objc_getAssociatedObject(view, kSCHoldGestureKey)) {
        return;
    }

    UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc] initWithTarget:view action:@selector(sc_handleLeftHold:)];
    hold.minimumPressDuration = 0.45;
    hold.cancelsTouchesInView = NO;
    hold.delaysTouchesBegan = NO;
    hold.delaysTouchesEnded = NO;
    hold.delegate = [SCHoldGestureDelegate sharedDelegate];
    [view addGestureRecognizer:hold];
    objc_setAssociatedObject(view, kSCHoldGestureKey, hold, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void handleStatusBarLeftHold(UIView *view, UILongPressGestureRecognizer *gesture) {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    CGPoint loc = [gesture locationInView:view];
    // Tai thỏ bên trái (khu vực hiển thị Đồng hồ / Thời gian): x < width * 0.35
    if (loc.x < view.bounds.size.width * 0.35) {
        triggerSneakyCamAction();
    }
}

%hook _UIStatusBar

- (void)layoutSubviews {
    %orig;
    addHoldGestureToStatusBar(self);
}

%new
- (void)sc_handleLeftHold:(UILongPressGestureRecognizer *)gesture {
    handleStatusBarLeftHold(self, gesture);
}

%end

%hook UIStatusBar_Modern

- (void)layoutSubviews {
    %orig;
    addHoldGestureToStatusBar(self);
}

%new
- (void)sc_handleLeftHold:(UILongPressGestureRecognizer *)gesture {
    handleStatusBarLeftHold(self, gesture);
}

%end

// TẮT HOÀN TOÀN CÁC CƠ CHẾ KÍCH HOẠT CŨ BẰNG PHÍM ÂM LƯỢNG CỦA SNEAKYCAM
%hook SparkRecorder

- (void)increaseVolumePressed {
    // Vô hiệu hóa hoàn toàn cơ chế bấm phím tăng âm lượng của SneakyCam
}

- (void)decreaseVolumePressed {
    // Vô hiệu hóa hoàn toàn cơ chế bấm phím giảm âm lượng của SneakyCam
}

%end

%ctor {
    %init(SparkRecorder = objc_getClass("SparkRecorder"));
}
