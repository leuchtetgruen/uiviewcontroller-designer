

#import <UIKit/UIKit.h>

@class UIViewControllerAndDesignViewController;

@interface UIViewControllerAndDesignAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    UIViewControllerAndDesignViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UIViewControllerAndDesignViewController *viewController;

@end

