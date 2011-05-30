

#import "UIViewController+Design.h"


@implementation UIViewControllerWithDesignerExtensions



#pragma mark -
#pragma mark Touch and move


- (void) viewDidLoad {
	[super viewDidLoad];	
	connectedSockets = [[NSMutableArray alloc] init];
}

- (UIView *) findElementWithPoint:(CGPoint) point andSuperView:(UIView *) superview {
	NSLog(@"Checking for Point %f,%f in view %@", point.x, point.y, superview);
	for (UIView *subview in superview.subviews) {
		NSLog(@"Trying to check subview %@", subview);
		if (CGRectContainsPoint(subview.frame, point)) {
			NSInteger usableSubViews = 0;
			CGRect frame = subview.frame;
			// Avoid stuff you put as bgimages etc
			CGFloat widthLmt = (superview.frame.size.width * 5) / 6;
			CGFloat heightLmt = (superview.frame.size.height * 5) / 6;	
			NSLog(@"Wont check if width > %f and height > %f", widthLmt, heightLmt);
			if ((frame.size.width > widthLmt) && (frame.size.height > heightLmt) && ([subview.subviews count]==0)) continue;
			
			if (subview.hidden) continue;
			NSLog(@"Checking subview %@", subview);			
			
			UIView *subviewToCheck = subview;
			if ([subview isKindOfClass:[UITableViewCell class]]) subviewToCheck = [(UITableViewCell *) subview contentView];
			

			for (UIView *subSubView in subviewToCheck.subviews) {
				NSLog(@"Checking SubSubView %@", subSubView);
				if ([subSubView isKindOfClass:[UIButton class]]) usableSubViews++;
				if ([subSubView isKindOfClass:[UILabel class]]) usableSubViews++;	
				if ([subSubView isKindOfClass:[UITextField class]]) usableSubViews++;
				if ([subSubView isKindOfClass:[UITextView class]]) usableSubViews++;
				if ([subSubView isKindOfClass:[UIImageView class]]) usableSubViews++;
				if ([subSubView isKindOfClass:[UITableViewCell class]]) usableSubViews++;
				if ([subSubView isKindOfClass:[UITableView class]]) usableSubViews++;
				if ([subSubView isMemberOfClass:[UIView class]]) usableSubViews++;				
				// Add your own classes here
			}
			NSLog(@"Found %u usable subviews", usableSubViews);
			if (usableSubViews == 0) return subview;
			else {
				CGPoint newPoint = CGPointMake(point.x - subview.frame.origin.x, point.y - subview.frame.origin.y);
				UIView *ret = [self findElementWithPoint:newPoint andSuperView:subviewToCheck];
				if (ret == nil) return subview;
				else return ret;
			}
		}
	}
	return nil;
}

- (UIView *) elementForTouch:(CGPoint) point {
	return [self findElementWithPoint:point andSuperView:self.view];
}


- (void) recursevilyDisableUI:(UIView *) view {
	for (UIView *subview in view.subviews) {
		if ([subview respondsToSelector:@selector(setEnabled:)]) [subview setEnabled:NO];
		if ([subview.subviews count] > 0) [self recursevilyDisableUI:subview];
	}
}

- (void) recursevilyEnableUI:(UIView *) view {
	for (UIView *subview in view.subviews) {
		if ([subview respondsToSelector:@selector(setEnabled:)]) [subview setEnabled:YES];
		if ([subview.subviews count] > 0) [self recursevilyDisableUI:subview];
	}
}


- (void) toggleDesignMode {
	designMode = !designMode;
	if (!designMode) {
		if (chosenElement!=nil) chosenElement.layer.borderWidth = 0;
		[self recursevilyEnableUI:self.view];
		[self disableTelnetInterface];
		
	}
	else {
		NSLog(@"Now in design mode");
		[self recursevilyDisableUI:self.view];
		[self enableTelnetInterface];
	}
	isMoving = NO;
	isResizing = NO;
	offsetX = 0;
	offsetY = 0;
	
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	NSLog(@"Touches began %@", touch);
	if (touch.tapCount == 2) {
		[self toggleDesignMode];
		return;
	}
	
	if (!designMode) return;
	
	CGPoint location = [touch locationInView:self.view];
	UIView *element = [self elementForTouch:location];
	isMoving = NO;
	isResizing = NO;
	if (element != nil) {
		if (chosenElement != nil) {
			chosenElement.layer.borderWidth = 0;
			chosenElement = nil;
		}		
		element.layer.borderColor = [UIColor redColor].CGColor;
		element.layer.borderWidth = 2;
		chosenElement = element;
		CGPoint locationInView = [touch locationInView:element];
		CGSize viewFrameExpansion = element.frame.size;
		if ((locationInView.x > (2*(viewFrameExpansion.width / 3))) &&
			(locationInView.y > (2*(viewFrameExpansion.height / 3)))) {
			isResizing = YES;
			offsetX = viewFrameExpansion.width - locationInView.x;
			offsetY = viewFrameExpansion.height - locationInView.y;
		}
		else isMoving = YES;
	}
	
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	if (!designMode) return;	
	
	UITouch *touch = [touches anyObject];
	CGPoint location = [touch locationInView:self.view];
	if (isMoving) [chosenElement setCenter:location];
	if (isResizing) {
		NSInteger newWidth = location.x - chosenElement.frame.origin.x + offsetX;
		NSInteger newHeight = location.y - chosenElement.frame.origin.y + offsetY;
		CGRect frame = chosenElement.frame;
		frame.size.width = newWidth;
		frame.size.height = newHeight;
		chosenElement.frame = frame;
	}
	
	
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	if (!designMode) return;	
	
	isMoving = NO;
	isResizing = NO;
	offsetX = 0;
	offsetY = 0;
}

#pragma mark -
#pragma mark Socket

- (void) enableTelnetInterface {
	listenSocket = [[AsyncSocket alloc] initWithDelegate:self];
	[listenSocket acceptOnPort:DESIGN_PORT error:nil];
}

- (void) disableTelnetInterface {
	[listenSocket disconnect];
	
	for(int i = 0; i < [connectedSockets count]; i++)
	{
		// Call disconnect on the socket,
		// which will invoke the onSocketDidDisconnect: method,
		// which will remove the socket from the list.
		[[connectedSockets objectAtIndex:i] disconnect];
	}
	[listenSocket release];
	listenSocket = nil;
}

- (void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket {
	NSLog(@"New Socket %@", newSocket);
	[connectedSockets addObject:newSocket];
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
	
	NSString *welcomeMsg = @"Welcome to UIViewController+Design \r\n";
	NSData *welcomeData = [welcomeMsg dataUsingEncoding:NSUTF8StringEncoding];
	
	[sock writeData:welcomeData withTimeout:-1 tag:WELCOME_MSG];
	
	// We could call readDataToData:withTimeout:tag: here - that would be perfectly fine.
	// If we did this, we'd want to add a check in onSocket:didWriteDataWithTag: and only
	// queue another read if tag != WELCOME_MSG.
}

- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	[sock readDataToData:[AsyncSocket CRLFData] withTimeout:-1 tag:0];
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	NSData *strData = [data subdataWithRange:NSMakeRange(0, [data length] - 2)];
	NSString *msg = [[[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding] autorelease];
	// Even if we were unable to write the incoming data to the log,
	// we're still going to echo it back to the client.
	
	NSString *retStr = [self parseCommand:[msg stringByReplacingOccurrencesOfString:@"\n" withString:@""]];
	NSData *retData = [retStr dataUsingEncoding:NSUTF8StringEncoding];
	[sock writeData:retData withTimeout:-1 tag:ECHO_MSG];
}


- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
	[connectedSockets removeObject:sock];
}

#pragma mark -
#pragma mark Message parsing

- (NSString *) parseCommand:(NSString *) cmdString {
	if (chosenElement == nil) return;
	
	NSArray *parsedCommand = [cmdString componentsSeparatedByString:@":"];
	
	NSString *command = [[parsedCommand objectAtIndex:0] lowercaseString];
	
	// A lot of stuff 
	if ([command isEqualToString:@"down"]) {
		NSInteger offset = [[parsedCommand objectAtIndex:1] integerValue];
		CGRect frame = chosenElement.frame;
		frame.origin.y += offset;
		chosenElement.frame = frame;
	}
	if ([command isEqualToString:@"up"]) {
		NSInteger offset = [[parsedCommand objectAtIndex:1] integerValue];
		CGRect frame = chosenElement.frame;
		frame.origin.y -= offset;
		chosenElement.frame = frame;
	}
	if ([command isEqualToString:@"left"]) {
		NSInteger offset = [[parsedCommand objectAtIndex:1] integerValue];
		CGRect frame = chosenElement.frame;
		frame.origin.x -= offset;
		chosenElement.frame = frame;
	}
	if ([command isEqualToString:@"right"]) {
		NSInteger offset = [[parsedCommand objectAtIndex:1] integerValue];
		CGRect frame = chosenElement.frame;
		frame.origin.x += offset;
		chosenElement.frame = frame;
	}
	if ([command isEqualToString:@"height"]) {
		NSInteger offset = [[parsedCommand objectAtIndex:1] integerValue];
		CGRect frame = chosenElement.frame;
		frame.size.height += offset;
		chosenElement.frame = frame;
	}
	if ([command isEqualToString:@"width"]) {
		NSInteger offset = [[parsedCommand objectAtIndex:1] integerValue];
		CGRect frame = chosenElement.frame;
		frame.size.width += offset;
		chosenElement.frame = frame;
	}
	if ([command isEqualToString:@"bgcolor"]) {
		CGFloat red = [[parsedCommand objectAtIndex:1] integerValue] / 255;
		CGFloat green = [[parsedCommand objectAtIndex:2] integerValue] / 255;
		CGFloat blue = [[parsedCommand objectAtIndex:3] integerValue] / 255;		
		CGFloat alpha = ([parsedCommand count] > 4) ? ([[parsedCommand objectAtIndex:4] integerValue] / 255) : 1;
		chosenElement.backgroundColor = [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
	}
	if ([command isEqualToString:@"textcolor"]) {
		UIView *curView = chosenElement;
		if ([chosenElement isKindOfClass:[UIButton class]]) curView = [(UIButton *) chosenElement titleLabel];
		
		
		CGFloat red = [[parsedCommand objectAtIndex:1] integerValue] / 255;
		CGFloat green = [[parsedCommand objectAtIndex:2] integerValue] / 255;
		CGFloat blue = [[parsedCommand objectAtIndex:3] integerValue] / 255;		
		CGFloat alpha = ([parsedCommand count] > 4) ? ([[parsedCommand objectAtIndex:4] integerValue] / 255) : 1;
		if ([curView respondsToSelector:@selector(setTextColor:)]) {
			[curView performSelector:@selector(setTextColor:) withObject:[UIColor colorWithRed:red green:green blue:blue alpha:alpha]];
		}
		else return @"Cannot set text color on this object.\r\n";
	}
	if ([command isEqualToString:@"alignment"]) {
		UIView *curView = chosenElement;
		if ([chosenElement isKindOfClass:[UIButton class]]) curView = [(UIButton *) chosenElement titleLabel];

		
		UITextAlignment alignment;
		NSString *alignString = [[parsedCommand objectAtIndex:1] lowercaseString];
		if ([alignString isEqualToString:@"right"]) alignment = UITextAlignmentRight;
		else if ([alignString isEqualToString:@"center"]) alignment = UITextAlignmentCenter;
		else alignment = UITextAlignmentLeft;
		
		if ([curView respondsToSelector:@selector(setTextAlignment:)]) {
			[curView setTextAlignment:alignment];
		}
		else return @"Cannot set textalignment on this object.\r\n";
	}
	if ([command isEqualToString:@"text"]) {
		UIView *curView = chosenElement;
		if ([chosenElement isKindOfClass:[UIButton class]]) curView = [(UIButton *) chosenElement titleLabel];
		if ([curView respondsToSelector:@selector(setText:)]) {
			[curView performSelector:@selector(setText:) withObject:[parsedCommand objectAtIndex:1]];
		}
		else return @"Cannot set text on this object.\r\n";
	}
	if ([command isEqualToString:@"font"]) {
		UIFont *font = [UIFont fontWithName:[parsedCommand objectAtIndex:1] size:[[parsedCommand objectAtIndex:2] floatValue]];
		
		UIView *curView = chosenElement;
		if ([chosenElement isKindOfClass:[UIButton class]]) curView = [(UIButton *) chosenElement titleLabel];
		if ([curView respondsToSelector:@selector(setFont:)]) {
			[curView performSelector:@selector(setFont:) withObject:font];
		}
		else return @"Cannot set font on this object.\r\n";
	}
	if ([command isEqualToString:@"fontsize"]) {
		UIView *curView = chosenElement;
		if ([chosenElement isKindOfClass:[UIButton class]]) curView = [(UIButton *) chosenElement titleLabel];
		if ([curView respondsToSelector:@selector(setFont:)]) {
			UIFont *curFont = [chosenElement font];
			UIFont *font = [UIFont fontWithName:[curFont fontName] size:[[parsedCommand objectAtIndex:1] floatValue]];			
			[curView performSelector:@selector(setFont:) withObject:font];
		}
		else return @"Cannot set fontsize on this object.\r\n";
	}
	
	
	if ([command isEqualToString:@"describe"]) return [self describeElement];
	
	return @"Roger that\r\n";
}

- (NSString *) describeElement {

	if (chosenElement == nil) return @"";
	NSMutableString *descr = [NSMutableString string];
	CGRect frame = chosenElement.frame;
	NSString *class = NSStringFromClass([chosenElement class]);
	
	
	NSString *constr = [NSString stringWithFormat:@"%@ element = [[%@ alloc] init];\r\n", class, class];
	[descr appendString:constr];
	
	NSString *rect = [NSString stringWithFormat:@"element.frame = CGRectMake(%.0f, %.0f, %.0f, %.0f);\r\n", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height];
	[descr appendString:rect];
	
	NSString *bgColor = [NSString stringWithFormat:@"element.backgroundColor = %@;\r\n", [self colorToString:chosenElement.backgroundColor]];
	[descr appendString:bgColor];
	
	if ([chosenElement respondsToSelector:@selector(textColor)]) {
		NSString *txtColor = [NSString stringWithFormat:@"element.textColor = %@;\r\n", [self colorToString:[chosenElement textColor]]];
		[descr appendString:txtColor];
	}
	
	if ([chosenElement respondsToSelector:@selector(textAlignment)]) {
		UITextAlignment textAlignment = (UITextAlignment) [chosenElement textAlignment];
		NSString *align = @"";
		if (textAlignment==UITextAlignmentLeft) align = @"UITextAlignmentLeft";
		if (textAlignment==UITextAlignmentRight) align = @"UITextAlignmentRight";
		if (textAlignment==UITextAlignmentCenter) align = @"UITextAlignmentCenter";		
		NSString *alignString = [NSString stringWithFormat:@"element.textAlignment = %@;\r\n", align];
		[descr appendString:alignString];
	}

	if ([chosenElement respondsToSelector:@selector(text)]) {
		[descr appendString:[NSString stringWithFormat:@"element.text = @\"%@\";\r\n", [chosenElement text]]];
	}
	
	if ([chosenElement respondsToSelector:@selector(font)]) {
		UIFont *font = [chosenElement font];
		NSString *fontStr = [NSString stringWithFormat:@"element.font = [UIFont fontWithName:@\"%@\" size:%0.f];\r\n", [font fontName], [font pointSize]];
		[descr appendString:fontStr];
	}
	
	return descr;
}

- (NSString *) colorToString:(UIColor *) color {
	return [NSString stringWithFormat:@"[UIColor colorWithRed:%.3f green:%3.f blue:%3.f alpha:%3.f]", [color red], [color green], [color blue], [color alpha]];
}

@end
