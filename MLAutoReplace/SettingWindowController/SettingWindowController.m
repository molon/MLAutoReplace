//
//  SettingWindowController.m
//  MLAutoReplace
//
//  Created by molon on 4/26/14.
//  Copyright (c) 2014 molon. All rights reserved.
//

#import "SettingWindowController.h"
#import "MLAutoReplace.h"
#import "MLAutoReplaceUserDefault.h"
#import "Debug.h"

#define kEditPlistApplicationName @"Xcode"

@interface SettingWindowController ()

@property (weak) IBOutlet NSButton *useAutoReIndentCheckBox;

@end

@implementation SettingWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    self.useAutoReIndentCheckBox.state = [MLAutoReplaceUserDefault shareInstance].isUseAutoReIndent;
}

- (void)dealloc
{
	DLOG(@"SettingWindowController dealloc");
}

- (IBAction)openGetterPlist:(id)sender {
    //打开替换getter的plist文件
    NSString *documentDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString *documentPath  = [documentDirectory stringByAppendingPathComponent:@"XCodePluginSetting/MLAutoReplace/ReplaceGetter.plist"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentPath]){
        NSString *tips = [NSString stringWithFormat:@"Please check whether .plist file exists.\n\nThe path:\n%@",documentPath];
        [MLAutoReplace showSimpleTips:tips];
        return;
    }
    
    [[NSWorkspace sharedWorkspace]openFile:documentPath withApplication:kEditPlistApplicationName];
}

- (IBAction)openOtherPlist:(id)sender {
    //打开替换getter的plist文件
    NSString *documentDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString *documentPath  = [documentDirectory stringByAppendingPathComponent:@"XCodePluginSetting/MLAutoReplace/ReplaceOther.plist"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentPath]){
        NSString *tips = [NSString stringWithFormat:@"Please check whether .plist file exists.\n\nThe path:\n%@",documentPath];
        [MLAutoReplace showSimpleTips:tips];
        return;
    }
    
    [[NSWorkspace sharedWorkspace]openFile:documentPath withApplication:kEditPlistApplicationName];
}

- (IBAction)reloadPlist:(id)sender {
    if ([[MLAutoReplace sharedInstance]loadReplacePlist]) {
        [MLAutoReplace showSimpleTips:@"Reload the data of .plist successfuly!"];
    }else{
        [MLAutoReplace showSimpleTips:@"Reload the data of .plist failed! Please retry."];
    }
}

- (IBAction)autoReIndentSwitch:(id)sender {
    NSButton *checkBox = (NSButton*)sender;
    [MLAutoReplaceUserDefault shareInstance].isUseAutoReIndent = checkBox.state;
}

@end
