

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import "AsyncSocket.h"
#import "UIColor-Expanded.h"


#define DESIGN_PORT 10096
#define WELCOME_MSG  0
#define ECHO_MSG     1

@interface UIViewControllerWithDesignerExtensions : UIViewController {
	
	BOOL isResizing;
	BOOL isMoving;
	UIView *chosenElement;
	
	NSInteger offsetX;
	NSInteger offsetY;
	
	BOOL designMode;
	
	AsyncSocket *listenSocket;
	NSMutableArray *connectedSockets;
	

	
}



- (UIView *) findElementWithPoint:(CGPoint) point andSuperView:(UIView *) superview;
- (UIView *) elementForTouch:(CGPoint) point;
- (void) recursevilyDisableUI:(UIView *) view;
- (void) recursevilyEnableUI:(UIView *) view;
- (void) enableTelnetInterface;
- (void) disableTelnetInterface;
- (void) toggleDesignMode;

- (NSString *) describeElement;
- (NSString *) colorToString:(UIColor *) color;

@end
