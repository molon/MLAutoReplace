//
//  MLAutoReplace.m
//  MLAutoReplace
//
//  Created by molon on 4/25/14.
//    Copyright (c) 2014 molon. All rights reserved.
//

#import "MLAutoReplace.h"
#import "VVKeyboardEventSender.h"

static MLAutoReplace *sharedPlugin;

@interface MLAutoReplace()

@property (nonatomic, strong) NSBundle *bundle;
@property (nonatomic, strong) NSDictionary *replaceGetters;

@end

@implementation MLAutoReplace

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init]) {
        // reference to plugin's bundle, for resource acccess
        self.bundle = plugin;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidFinishLaunching:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
    }
    return self;
}

- (void) applicationDidFinishLaunching: (NSNotification*) noti {
    
    //加载替换配置文件
    [self loadReplacePlist];
    
    //监控文本改变
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textStorageDidChange:)
                                                 name:NSTextDidChangeNotification
                                               object:nil];
    
    
    // Sample Menu Item:
    NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Window"];
    if (menuItem) {
        [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
        NSMenuItem *actionMenuItem = [[NSMenuItem alloc] initWithTitle:@"MLAutoReplace" action:@selector(doMenuAction) keyEquivalent:@""];
        [actionMenuItem setTarget:self];
        [[menuItem submenu] addItem:actionMenuItem];
    }
}


// Sample Action, for menu item:
- (void)doMenuAction
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"Hello, World" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
    [alert runModal];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - load replace plist
- (void)loadReplacePlist
{
    //加载替换getter的plist文件
    NSString *documentDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString *documentPath  = [documentDirectory stringByAppendingPathComponent:@"XCodePluginSetting/MLAutoReplace/"];//添加储存的文件夹名字
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentPath]){
        NSError *error = nil;
        if(![[NSFileManager defaultManager] createDirectoryAtPath:documentPath withIntermediateDirectories:YES attributes:nil error:&error]){
            NSLog(@"%@",error);
            return;
        }
    }
    
    documentPath = [documentPath stringByAppendingString:@"/ReplaceGetter.plist"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentPath]){
        //找到工程下的默认plist
        NSString *defaultReplaceGetterPlistPathOfBundle = [[NSBundle bundleForClass:[self class]]pathForResource:@"DefaultReplaceGetter" ofType:@"plist"];
        
        NSDictionary *defaultDict = [NSDictionary dictionaryWithContentsOfFile:defaultReplaceGetterPlistPathOfBundle];
        
        if ([defaultDict writeToFile:documentPath atomically:YES]) {
            NSLog(@"归档到%@成功",documentPath);
        }else{
            NSLog(@"归档到%@失败,defaulPlist路径为%@",documentPath,defaultReplaceGetterPlistPathOfBundle);
            return;
        }
    }
    
    NSDictionary *replaceGetters = [NSDictionary dictionaryWithContentsOfFile:documentPath];
    
    //将其key全部都设置为无空格的
    NSMutableDictionary *finalReplaceGetters = [NSMutableDictionary dictionary];
    for (NSString *key in [replaceGetters allKeys]) {
        NSString *value = replaceGetters[key];
        //如果结尾不是回车就添加上
        if ([value characterAtIndex:value.length-1]!='\n') {
            value = [value stringByAppendingString:@"\n"];
        }
        finalReplaceGetters[[key stringByReplacingOccurrencesOfString:@" " withString:@""]] = value;
    }
    
    self.replaceGetters = finalReplaceGetters;

}


#pragma mark - text change monitor
- (void) textStorageDidChange:(NSNotification *)noti {
    
    if ([[noti object] isKindOfClass:[NSTextView class]]) {
        NSTextView *textView = (NSTextView *)[noti object];
        
        NSString *currentLine = [textView textOfCurrentLine];
        //empty should be ignored
        if ([NSString IsNilOrEmpty:currentLine]) {
            return;
        }
        
        //check if the input is getter
        //eg:- (UIView *)view///
        if(![currentLine vv_matchesPatternRegexPattern:@"^\\s*-\\s*\\(\\s*\\w+\\s*\\*?\\s*\\)\\s*\\w+\\s*/{3}$"]){
            return;
        }
        
        //get the return type of getter
        NSArray *array = [currentLine vv_stringsByExtractingGroupsUsingRegexPattern:@"\\(\\s*(\\w+\\s*\\*?)\\s*\\)"];
        if (array.count<=0) {
            return;
        }
        NSString *type = [array[0] stringByReplacingOccurrencesOfString:@" " withString:@""];
        
        //get the name of getter
        array = [currentLine vv_stringsByExtractingGroupsUsingRegexPattern:@"\\)\\s*(\\w+)\\s*/{3}$"];
        if (array.count<=0) {
            return;
        }
        NSString *name = array[0];
        
        NSLog(@"%@,%@",type,name);
        
        //根据type找到对应的替换文本
        NSString *replaceContent =  nil;
        
        NSString * const defaultReplaceGetterOfPointer = @"{\n\tif (!_<name>) {\n\t\t<#custom#>\n\t}\n\treturn _<name>;\n}\n";
        NSString * const defaultReplaceGetterOfScalar = @"{\n\t<#custom#>\n}\n";
        if (self.replaceGetters[type]) {
            replaceContent =  [self.replaceGetters[type] stringByReplacingOccurrencesOfString:@"<name>" withString:name];
        }else{
            NSString *replaceGetter = defaultReplaceGetterOfScalar;
            if ([type hasSuffix:@"*"]||[type isEqualToString:@"id"]) {
                if ([type hasSuffix:@"*"]) {
                    type = [[type substringToIndex:type.length-1] stringByAppendingString:@" *"];
                }
                replaceGetter = defaultReplaceGetterOfPointer;
            }
            replaceContent = [[NSString stringWithFormat:@"- (%@)<name>\n%@",type,replaceGetter] stringByReplacingOccurrencesOfString:@"<name>" withString:name];
        }
        
        if ([NSString IsNilOrEmpty:replaceContent]) {
            return;
        }
        
        //按键以完成替换
        [self removeCurrentLineContentAndInputContent:replaceContent ofTextView:textView];
    }
}

#pragma mark - auto input content and remove orig conten of current line
- (void)removeCurrentLineContentAndInputContent:(NSString*)replaceContent ofTextView:(NSTextView*)textView
{
    //根据replaceContent里的内容检查是否需要自动Tab
    BOOL isNeedAutoTab = NO;
    if([replaceContent vv_matchesPatternRegexPattern:@"<#\\w+#>"]){
        isNeedAutoTab = YES;
    }
    
    //记录下光标位置，找到此行开头的位置
    NSUInteger currentLocation = [textView locationOfCurrentLine];
    
    //保存以前剪切板内容
    NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
    NSString *originPBString = [pasteBoard stringForType:NSPasteboardTypeString];
    
    //复制要添加内容到剪切板
    [pasteBoard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pasteBoard setString:replaceContent forType:NSStringPboardType];
    
    
    VVKeyboardEventSender *kes = [[VVKeyboardEventSender alloc] init];
    BOOL useDvorakLayout = [VVKeyboardEventSender useDvorakLayout];
    
    [kes beginKeyBoradEvents];
    //删掉当前这一行光标位置前面的内容 Command+Delete
    [kes sendKeyCode:kVK_Delete withModifierCommand:YES alt:NO shift:NO control:NO];
    //删掉当前这一行光标位置后面的内容 Control+K
    [kes sendKeyCode:kVK_ANSI_K withModifierCommand:NO alt:NO shift:NO control:YES];
    //粘贴剪切板内容
    NSInteger kKeyVCode = useDvorakLayout?kVK_ANSI_Period : kVK_ANSI_V;
    [kes sendKeyCode:kKeyVCode withModifierCommand:YES alt:NO shift:NO control:NO];
    
    //这个按键用来模拟下上个命令执行完毕了，然后需要还原剪切板 ,按键是同步进行的,所以接到F20的时候应该之前的都执行完毕了
    [kes sendKeyCode:kVK_F20];
    
    static id eventMonitor = nil;
    eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask handler:^NSEvent *(NSEvent *incomingEvent) {
        if ([incomingEvent type] == NSKeyDown && [incomingEvent keyCode] == kVK_F20) {
            [NSEvent removeMonitor:eventMonitor];
            eventMonitor = nil;
            
            //还原剪切板
            [pasteBoard setString:originPBString forType:NSStringPboardType];
            
            if (isNeedAutoTab) {
                //光标移到开始的位置
                [textView setSelectedRange:NSMakeRange(currentLocation, 0)];
                //Send a 'tab' after insert the doc. For our lazy programmers. :)
                [kes sendKeyCode:kVK_Tab];
            }
            
            [kes endKeyBoradEvents];
            
            //让默认行为无效
            return nil;
        }
        return incomingEvent;
    }];

}

@end
