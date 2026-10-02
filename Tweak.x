#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <notify.h>
#import <objc/runtime.h>

#define NOTIFY_START_STOP_VIDEO "com.spark.SneakyCam.startstopvideo"

// State tracking for Volume Up (+) triple-tap
static int g_volUpTapCount = 0;
static NSTimeInterval g_lastVolUpTime = 0;

static void triggerSneakyCamVideo(void) {
    // 1. Post Darwin notification to mediaserverd (where SneakyCam recording engine is running)
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR(NOTIFY_START_STOP_VIDEO),
        NULL,
        NULL,
        YES
    );
    
    // 2. Play subtle haptic feedback (Taptic Engine) so the user feels that SneakyCam has toggled
    AudioServicesPlaySystemSound(1519); // Light Peek vibration
}

static void handleVolumeUpPress(void) {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval delta = now - g_lastVolUpTime;
    
    // 1. Holding button check:
    // When holding down the volume button, iOS generates repeated events rapidly (< 0.12s).
    // The user requested to ELIMINATE holding button activation, so reset count on hold!
    if (delta < 0.12) {
        g_volUpTapCount = 0;
        return;
    }
    
    // 2. Timeout check:
    // If more than 0.8 seconds have passed since the last tap, reset to first tap.
    if (delta > 0.80) {
        g_volUpTapCount = 1;
        g_lastVolUpTime = now;
        return;
    }
    
    // 3. Valid consecutive tap (0.12s <= delta <= 0.80s):
    g_volUpTapCount++;
    g_lastVolUpTime = now;
    
    // Tap 2: Do NOTHING! (User requested to ELIMINATE 2-tap activation)
    if (g_volUpTapCount == 2) {
        return;
    }
    
    // Tap 3: EXACTLY 3 CONSECUTIVE TAPS -> ACTIVATE / DEACTIVATE SNEAKYCAM!
    if (g_volUpTapCount == 3) {
        g_volUpTapCount = 0; // Reset counter
        triggerSneakyCamVideo();
    }
}

// Hook SpringBoard volume control
%hook SBVolumeControl

- (void)increaseVolume {
    %orig; // Maintain standard iOS volume behavior
    handleVolumeUpPress();
}

- (void)decreaseVolume {
    // Volume Down (-) never triggers SneakyCam photo or video
    g_volUpTapCount = 0; // Reset any pending Volume Up taps
    %orig;
}

%end

// Suppress SneakyCam's built-in 2-tap and volume-down handlers in SparkRecorder
%hook SparkRecorder

- (void)increaseVolumePressed {
    // Completely disable SneakyCam's built-in 2-tap volume up!
}

- (void)decreaseVolumePressed {
    // Completely disable SneakyCam's volume down photo!
}

%end

%ctor {
    %init(SBVolumeControl = objc_getClass("SBVolumeControl"),
          SparkRecorder = objc_getClass("SparkRecorder"));
}
