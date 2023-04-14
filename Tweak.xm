#import "Tweak.h"
#import "TXTConstants.h"
#import "TXTStyleManager.h"
#import "NSString+Stylize.h"

static UIImage * resizeImage(UIImage *original, CGSize size) {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [original drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

%group Textyle

%hook UICalloutBar

%property (nonatomic, retain) UIMenuItem *txtMainMenuItem;
%property (nonatomic, retain) NSArray *txtStyleMenuItems;

- (id)initWithFrame:(CGRect)arg1 {
    self = %orig;

    if (!self.txtMainMenuItem) {
        self.txtMainMenuItem = [[UIMenuItem alloc] initWithTitle:menuLabel action:@selector(txtOpenStyleMenu:)];
        self.txtMainMenuItem.dontDismiss = YES;
    }

    if (!self.txtStyleMenuItems) {
        NSMutableArray *items = [NSMutableArray array];

        NSArray *styles = [styleManager enabledStyles];
        for (NSDictionary *style in styles) {
            NSString *action = [NSString stringWithFormat:@"txt_%@", style[@"name"]];
            UIMenuItem *item = [[UIMenuItem alloc] initWithTitle:style[@"label"] action:NSSelectorFromString(action)];

            [items addObject:item];
        }

        self.txtStyleMenuItems = items;
    }

    return self;
}

- (void)updateAvailableButtons {
    %orig;

    if (!self.extraItems) self.extraItems = @[];

    BOOL isSelected = NO;
    NSMutableArray *currentSystemButtons = MSHookIvar<NSMutableArray *>(self, "m_currentSystemButtons");
    for (UICalloutBarButton *btn in currentSystemButtons) {
        if (btn.action == @selector(cut:)) {
            isSelected = YES;
            break;
        }
    }

    NSMutableArray *items = [self.extraItems mutableCopy];

    if (isSelected && enabled) {
        if (![items containsObject:self.txtMainMenuItem]) [items addObject:self.txtMainMenuItem];
    } else [items removeObject:self.txtMainMenuItem];

    if (menuOpen) {
        items = [NSMutableArray array];
        for (UIMenuItem *item in self.txtStyleMenuItems) {
            if (![items containsObject:item]) [items addObject:item];
        }
    } else for (UIMenuItem *item in self.txtStyleMenuItems) {
        [items removeObject:item];
    }

    self.extraItems = items;

    %orig;

    if (menuOpen) {
        for (UICalloutBarButton *btn in currentSystemButtons) {
            [btn removeFromSuperview];
        }
        [currentSystemButtons removeAllObjects];
    }
}

%end

@interface UICalloutBarBackground : UIView {
	UIImageView* _separatorView;
	UIVisualEffectView* _blurView;
}
@end

%hook UICalloutBar

- (void)layoutSubviews {
    %orig;

    UIView *tint = MSHookIvar<UIView *>(self, "m_buttonView");

    if (menuOpen && tintMenu) tint.backgroundColor = kAccentColorAlpha;
    else tint.backgroundColor = nil;
}

%end

%subclass TXTImageView : UIImageView

-(long long)_defaultRenderingMode {
    return 2;
}

%end

%hook UICalloutBarButton

- (void)setupWithTitle:(id)arg1 action:(SEL)arg2 type:(int)arg3 {
    if (menuIcon && arg2 == @selector(txtOpenStyleMenu:)) {
        #ifdef THEOS_PACKAGE_INSTALL_PREFIX
        UIImage *image = resizeImage([UIImage imageWithContentsOfFile:@"/var/jb/Library/PreferenceBundles/Textyle.bundle/menuIcon.png"], CGSizeMake(18, 18));
        #else
        UIImage *image = resizeImage([UIImage imageWithContentsOfFile:@"/Library/PreferenceBundles/Textyle.bundle/menuIcon.png"], CGSizeMake(18, 18));
        #endif
        [self setupWithImage:image action:arg2 type:arg3];

        if (tintIcon) {
            object_setClass(self.imageView, %c(TXTImageView));
            [self.imageView setTintColor:kAccentColor];
        }
    } else %orig;
}

%end

%hook UIResponder

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    NSString *sel = NSStringFromSelector(action);
    NSRange match = [sel rangeOfString:@"txt_"];

    if (menuOpen) return match.location == 0;
    else return %orig;
}

%new
- (void)txtOpenStyleMenu:(UIResponder *)sender {
    menuOpen = YES;

    UICalloutBar *calloutBar = [UICalloutBar sharedCalloutBar];
    [calloutBar resetPage];
    [calloutBar update];
}

%new
- (void)txtCloseStyleMenu {
    menuOpen = NO;
}

- (BOOL)becomeFirstResponder {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(txtCloseStyleMenu) name:UIMenuControllerDidHideMenuNotification object:nil];
    return %orig;
}

%new
- (void)txtDidSelectStyle:(NSString *)name {
    menuOpen = NO;

    NSDictionary *style = [styleManager styleWithName:name];
    NSRange selectedRange = [self _selectedNSRange];
    NSString *original = [self _fullText];
    NSString *selectedText = [original substringWithRange:selectedRange];
    UITextRange *textRange = [self _textRangeFromNSRange:selectedRange];

    [self replaceRange:textRange withText:[NSString stylizeText:selectedText withStyle:style]];
}

%end

%hook UITextField

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return %orig(sel) ?: %orig(@selector(txtDidSelectStyle:));
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    NSString *sel = NSStringFromSelector([invocation selector]);
    NSRange match = [sel rangeOfString:@"txt_"];

    if (match.location == 0) [self txtDidSelectStyle:[sel substringFromIndex:4]];
    else %orig(invocation);
}

%end

%hook UITextView

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return %orig(sel) ?: %orig(@selector(txtDidSelectStyle:));
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    NSString *sel = NSStringFromSelector([invocation selector]);
    NSRange match = [sel rangeOfString:@"txt_"];

    if (match.location == 0) [self txtDidSelectStyle:[sel substringFromIndex:4]];
    else %orig(invocation);
}

%end

%end

%group ToggleMenu

%hook UIKeyboardDockItem

- (id)initWithImageName:(id)arg1 identifier:(id)arg2 {
    return %orig(arg1, [arg2 isEqualToString:@"dictation"] ? @"textyle" : arg2);
}

- (void)setEnabled:(BOOL)arg1 {
    %orig([self.identifier isEqualToString:@"textyle"] ?: arg1);
}

%end

%subclass TXTDockItemButton : UIKeyboardDockItemButton

- (void)setTintColor:(UIColor *)arg1 {
    %orig(active ? kAccentColorAlpha : arg1);
}

-(void)setImage:(UIImage *)image forState:(NSUInteger)state{
    #ifdef THEOS_PACKAGE_INSTALL_PREFIX
    %orig([UIImage imageWithContentsOfFile:@"/var/jb/Library/PreferenceBundles/Textyle.bundle/menuIcon.png"], state);
    #else
    %orig([UIImage imageWithContentsOfFile:@"/Library/PreferenceBundles/Textyle.bundle/menuIcon.png"], state);
    #endif
}

%end

%hook UISystemKeyboardDockController

- (void)loadView {
    %orig;

    UIKeyboardDockItem *dockItem = MSHookIvar<UIKeyboardDockItem *>(self, "_dictationDockItem");
    object_setClass(dockItem.button, %c(TXTDockItemButton));

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(txtLongPress:)];
    longPress.cancelsTouchesInView = NO;
    longPress.minimumPressDuration = 0.3f;
    [dockItem.button addGestureRecognizer:longPress];

    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(txtToggleActive)];
    singleTap.numberOfTapsRequired = 1;
    [dockItem.button addGestureRecognizer:singleTap];
}

- (void)dictationItemButtonWasPressed:(id)arg1 withEvent:(id)arg2 {
    return;
}

%new
- (void)txtToggleActive {
    active = !active;
    if (active) spongebobCounter = 0;

    UIKeyboardDockItem *dockItem = MSHookIvar<UIKeyboardDockItem *>(self, "_dictationDockItem");
    [dockItem.button setTintColor:kAccentColorAlpha];
}

%new
- (void)txtLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIImpactFeedbackGenerator *hapticFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [hapticFeedbackGenerator prepare];

        if (!active) {
            active = true;
            spongebobCounter = 0;

            UIKeyboardDockItem *dockItem = MSHookIvar<UIKeyboardDockItem *>(self, "_dictationDockItem");
            [dockItem.button setTintColor:kAccentColorAlpha];
        }
        
        if (!selectionWindow) {
            selectionWindow = [[TXTStyleSelectionController alloc] init];
            selectionWindow.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
            selectionWindow.modalPresentationStyle = UIModalPresentationOverFullScreen;
        }

        if (self.presentedViewController == nil)
            [self presentViewController:selectionWindow animated:true completion:nil];

        [hapticFeedbackGenerator impactOccurred];
        hapticFeedbackGenerator = nil;
    }
}

%end

%hook UIKBInputDelegateManager

- (void)insertText:(NSString *)text {
    if (active) {
        NSDictionary *activeStyle = [styleManager activeStyle];
        if ([activeStyle[@"function"] isEqualToString:@"spongebob"]) {
            NSCharacterSet *letters = [NSCharacterSet letterCharacterSet];
            BOOL isLetter = [letters characterIsMember:[text characterAtIndex:0]];
            text = isLetter ? [NSString stylizeTextSpongebobActive:text counter:&spongebobCounter] : text;
        } else {
            text = [NSString stylizeText:text withStyle:activeStyle];
        }
    }

    %orig(text);
}

-(BOOL)callShouldReplaceExtendedRange:(long long)arg1 withText:(NSString *)arg2 includeMarkedText:(BOOL)arg3  {
    if (arg1) {
        for (int i = 0; i < arg1; i++) {
            [self deleteBackward];
        }
        [self insertText:arg2];
    }
   
    return %orig;
}

// -(void)replaceRange:(id)arg1 withText:(id)text forKeyboardAction:(int)arg3{ // This method doesn't get called when active is true?
//     %orig;
// }

%end

%end

%ctor {
    NSString *const identifier = (__bridge NSString *) CFBundleGetIdentifier(CFBundleGetMainBundle());
    NSArray *const args = [[NSProcessInfo processInfo] arguments];
    BOOL const isSpringBoard = [identifier isEqualToString:@"com.apple.springboard"];

    if (args.count != 0) {
        NSString *executablePath = args[0];
        if (executablePath) {
            BOOL isApplication = [executablePath rangeOfString:@"/Application"].location != NSNotFound;
            if (!(isSpringBoard || isApplication)) {
                return;
            }
        }
    }

    #ifdef THEOS_PACKAGE_INSTALL_PREFIX
    NSString *path = [NSString stringWithFormat:@"/var/jb/var/mobile/Library/Preferences/com.ryannair05.textyle.plist"];
    #else
    NSString *path = [NSString stringWithFormat:@"var/mobile/Library/Preferences/com.ryannair05.textyle.plist"];
    #endif

    NSDictionary *preferences = [[NSDictionary alloc] initWithContentsOfFile:path];

    enabled = [([preferences objectForKey:@"Enabled"] ?: @(YES)) boolValue];
    toggleMenu = [([preferences objectForKey:@"ToggleMenu"] ?: @(YES)) boolValue];
    tintMenu = [([preferences objectForKey:@"TintMenu"] ?: @(YES)) boolValue];
    menuIcon = [([preferences objectForKey:@"MenuIcon"] ?: @(YES)) boolValue];
    tintIcon = [([preferences objectForKey:@"TintIcon"] ?: @(NO)) boolValue];
    menuLabel = ([preferences objectForKey:@"MenuLabel"] ?: @"Styles");

    NSArray *enabledApps = [preferences objectForKey:@"enabledApps"];
    if (enabledApps && [enabledApps containsObject:identifier]) {
        return;
    }

    styleManager = [TXTStyleManager sharedManager];
    NSString *styleName = [preferences objectForKey:@"ActiveStyle"];
    if (!styleName){
        styleName = styleManager.enabledStyles[0][@"name"];
    }

    styleManager.activeStyle = [styleManager styleWithName:styleName];

    menuOpen = NO;
    active = NO;
    spongebobCounter = 0;

    %init(Textyle);

    if (enabled && toggleMenu) {
        %init(ToggleMenu);
    }
}
