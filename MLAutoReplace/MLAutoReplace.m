//
//  MLAutoReplace.m
//  MLAutoReplace
//
//  Created by molon on 4/25/14.
//    Copyright (c) 2014 molon. All rights reserved.
//

#import "MLAutoReplace.h"
#import "VVKeyboardEventSender.h"
#import "SettingWindowController.h"
#import "MLAutoReplaceUserDefault.h"

static MLAutoReplace *sharedPlugin;

#define kSourceTextViewClass NSClassFromString(@"DVTSourceTextView")

@interface MLAutoReplace()

@property (nonatomic, strong) NSBundle *bundle;
@property (nonatomic, strong) NSDictionary *replaceGetters;
@property (nonatomic, strong) NSArray *replaceOthers;

@property (nonatomic, strong) id eventMonitor;

@property (nonatomic, strong) SettingWindowController *settingWC;

@property (nonatomic, strong) dispatch_queue_t textCheckQueue;

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

+ (id)sharedInstance {
    return sharedPlugin;
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init]) {
        // reference to plugin's bundle, for resource acccess
        self.bundle = plugin;
        
        self.textCheckQueue = dispatch_queue_create("com.molon.textCheckQueue", NULL);
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidFinishLaunching:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
    }
    return self;
}

- (void)applicationDidFinishLaunching: (NSNotification*) noti {
    
    //加载替换配置文件
    if (![self loadReplacePlist]) {
        NSAlert *alert = [NSAlert alertWithMessageText:@"MLAutoReplace: Load plist failed! Please retart Xcode to retry." defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
        [alert runModal];
        return;
    }
    
    //添加按键检测 ,检测shift+command+|，用来自动去处理当前自动re-indent
    //当前的弊端是如果用户打开XCode之后从来木有编辑过一次程序，那就没有用
    self.eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask handler:^NSEvent *(NSEvent *incomingEvent) {
        if ([incomingEvent type] == NSKeyDown && [incomingEvent keyCode] == kVK_ANSI_Backslash
            && (incomingEvent.modifierFlags&kCGEventFlagMaskShift)&&(incomingEvent.modifierFlags&kCGEventFlagMaskCommand)) {
            
            //如果设置里不需要此功能则返回
            if (![MLAutoReplaceUserDefault shareInstance].isUseAutoReIndent) {
                return incomingEvent;
            }
            
            NSTextView *textView = nil;
            //找到源码编辑窗口
            for (NSView *subView in [((NSView*)incomingEvent.window.contentView) allSubviews]) {
                if ([subView isKindOfClass:kSourceTextViewClass]) {
                    textView = (NSTextView*)subView;
                }
            }
            
            if (!textView||![incomingEvent.window.firstResponder isEqual:textView]) {
                //没找到或者当前的第一响应View不是源代码编辑窗口就忽略了。
                return incomingEvent;
            }
            DLOG(@"按了shift+command+|,window:%@，windowNumber:%ld，并且执行自动re-indent",incomingEvent.window,incomingEvent.windowNumber);
            
            NSUInteger locationOfCurrentLine = [textView locationOfCurrentLine];
            
            VVKeyboardEventSender *kes = [[VVKeyboardEventSender alloc] init];
            [kes beginKeyBoradEvents];
            
            //全选
            [kes sendKeyCode:kVK_ANSI_A withModifierCommand:YES alt:NO shift:NO control:NO];
            //ReIndent
            [kes sendKeyCode:kVK_ANSI_Backslash withModifierCommand:NO alt:NO shift:YES control:YES];
            
            [kes endKeyBoradEvents];
            
            //光标移到原本所在行的头部位置，隔个0.1秒再触发,其实最终有可能不是目标位置，因为re-indent之后文本会被调整
            //差不多就成了
            double delayInSeconds = 0.1f;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [textView setSelectedRange:NSMakeRange(locationOfCurrentLine, 0)];
            });
            
            //让默认行为无效
            return nil;
        }else if ([incomingEvent type] == NSKeyDown && [incomingEvent keyCode] == kVK_ANSI_Backslash
                  && (incomingEvent.modifierFlags&kCGEventFlagMaskControl)&&(incomingEvent.modifierFlags&kCGEventFlagMaskCommand)&&(incomingEvent.modifierFlags&kCGEventFlagMaskAlternate)) {
            //Control+Alt+Command+|  快捷键重载plist
            [self.settingWC reloadPlist:nil]; //简单调用下WC的方法即可
        }
        return incomingEvent;
    }];
    
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

- (SettingWindowController *)settingWC
{
	if (!_settingWC) {
		_settingWC = [[SettingWindowController alloc]initWithWindowNibName:@"SettingWindowController"];
	}
	return _settingWC;
}

- (void)doMenuAction
{
    [self.settingWC showWindow:self.settingWC];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [NSEvent removeMonitor:self.eventMonitor];
    self.eventMonitor = nil;
}

#pragma mark - load replace plist
- (BOOL)loadReplacePlist
{
    //加载替换getter的plist文件
    NSString *documentDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES) objectAtIndex:0];
    
    documentDirectory  = [documentDirectory stringByAppendingPathComponent:@"XCodePluginSetting/MLAutoReplace/"];//添加储存的文件夹名字
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentDirectory]){
        NSError *error = nil;
        if(![[NSFileManager defaultManager] createDirectoryAtPath:documentDirectory withIntermediateDirectories:YES attributes:nil error:&error]){
            NSLog(@"%@",error);
            return NO;
        }
    }
    
    //replaceGetters
    NSString *documentPath = [documentDirectory stringByAppendingString:@"/ReplaceGetter.plist"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentPath]){
        //找到工程下的默认plist
        NSString *defaultReplaceGetterPlistPathOfBundle = [self.bundle pathForResource:@"DefaultReplaceGetter" ofType:@"plist"];
        
        NSDictionary *defaultDict = [NSDictionary dictionaryWithContentsOfFile:defaultReplaceGetterPlistPathOfBundle];
        
        if ([defaultDict writeToFile:documentPath atomically:YES]) {
            NSLog(@"归档到%@成功",documentPath);
        }else{
            NSLog(@"归档到%@失败,defaulPlist路径为%@",documentPath,defaultReplaceGetterPlistPathOfBundle);
            return NO;
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
    
    //简单做下同步吧
    @synchronized(self.replaceGetters){
        self.replaceGetters = finalReplaceGetters;
    }
    
    
    //replaceOthers
    documentPath = [documentDirectory stringByAppendingString:@"/ReplaceOther.plist"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentPath]){
        //找到工程下的默认plist,是数组包含字典的形式
        //根目录数组是因为需要按顺序检测正则是否匹配，检测到了就无需匹配下面的
        
        //找到工程下的默认plist
        NSString *defaultReplaceOtherPlistPathOfBundle = [self.bundle pathForResource:@"DefaultReplaceOther" ofType:@"plist"];
        
        NSArray *defaultArray = [NSArray arrayWithContentsOfFile:defaultReplaceOtherPlistPathOfBundle];
        
        if ([defaultArray writeToFile:documentPath atomically:YES]) {
            NSLog(@"归档到%@成功",documentPath);
        }else{
            NSLog(@"归档到%@失败,defaulPlist路径为%@",documentPath,defaultReplaceOtherPlistPathOfBundle);
            return NO;
        }
    }
    
    //简单做下同步吧
    @synchronized(self.replaceOthers){
        self.replaceOthers = [NSArray arrayWithContentsOfFile:documentPath];
    }
    
    return YES;
}

#pragma mark - text change monitor
- (void)textStorageDidChange:(NSNotification *)noti {
    if (![[noti object] isKindOfClass:kSourceTextViewClass]) {
        return;
    }
    
    //在后台线程里做。
    dispatch_async(self.textCheckQueue, ^{
        NSTextView *textView = (NSTextView *)[noti object];
        
        NSString *currentLine = [textView textOfCurrentLine];
        //empty should be ignored
        if ([NSString IsNilOrEmpty:currentLine]) {
            return;
        }
        
        //getter replace
        if ([self checkAndReplaceGetterWithCurrentLine:currentLine ofTextView:textView]) {
            return;
        }
        //other replace
        [self checkAndReplaceOtherWithCurrentLine:currentLine ofTextView:textView];
    });
}

#pragma mark - check and replace
- (BOOL)checkAndReplaceGetterWithCurrentLine:(NSString*)currentLine  ofTextView:(NSTextView*)textView
{
    //eg:- (UIView *)view///
    static NSString *lastCurrentLine = nil;
    if(![currentLine vv_matchesPatternRegexPattern:@"^\\s*-\\s*\\(\\s*\\w+\\s*\\*?\\s*\\)\\s*\\w+\\s*/{3}$"]){
        lastCurrentLine = currentLine;
        return NO;
    }
    
    //这里用来保证是一个字一个字把最后三个/敲出来的，而不是复制啊，或者从中间敲的
    if(![[lastCurrentLine stringByAppendingString:@"/"]isEqualToString:currentLine]||[textView endLocationOfCurrentLine]+1!=[textView currentCurseLocation]){
        lastCurrentLine = currentLine;
        return NO;
    }
    lastCurrentLine = currentLine;
    
    
    //get the return type of getter
    NSArray *array = [currentLine vv_stringsByExtractingGroupsUsingRegexPattern:@"\\(\\s*(\\w+\\s*\\*?)\\s*\\)"];
    if (array.count<=0) {
        return NO;
    }
    NSString *type = [array[0] stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    //get the name of getter
    array = [currentLine vv_stringsByExtractingGroupsUsingRegexPattern:@"\\)\\s*(\\w+)\\s*/{3}$"];
    if (array.count<=0) {
        return NO;
    }
    NSString *name = array[0];
    
    NSLog(@"%@,%@",type,name);
    
    //根据type找到对应的替换文本
    NSString *replaceContent =  nil;
    
    NSString * const defaultReplaceGetterOfScalar = @"{\n\t<#custom#>\n}\n";
    
    NSString * replaceGetter = nil;
    @synchronized(self.replaceGetters){ //简单同步
        replaceGetter = self.replaceGetters[type];
    }
    if (replaceGetter) {
        replaceContent =  [replaceGetter stringByReplacingOccurrencesOfString:@"<name>" withString:name];
    }else{
        NSString *replaceGetter = defaultReplaceGetterOfScalar;
        if ([type hasSuffix:@"*"]||[type isEqualToString:@"id"]) {
            NSString * const defaultReplaceGetterOfPointer = @"{\n\tif (!_<name>) {%@\n\t\t<#custom#>\n\t}\n\treturn _<name>;\n}\n";
            NSString *otherContent = @"";
            if ([type hasSuffix:@"*"]) {
                NSString *typeWithoutStar = [[type substringToIndex:type.length-1]stringByReplacingOccurrencesOfString:@" " withString:@""];
                otherContent = [NSString stringWithFormat:@"\n\t\t_<name> = [%@ new];",typeWithoutStar];
                
                type = [[type substringToIndex:type.length-1] stringByAppendingString:@" *"];
            }
            replaceGetter = [NSString stringWithFormat:defaultReplaceGetterOfPointer,otherContent];
        }
        replaceContent = [[NSString stringWithFormat:@"- (%@)<name>\n%@",type,replaceGetter] stringByReplacingOccurrencesOfString:@"<name>" withString:name];
    }
    
    if ([NSString IsNilOrEmpty:replaceContent]) {
        return NO;
    }
    
    //按键以完成替换
    [self removeCurrentLineContentAndInputContent:replaceContent ofTextView:textView];
    
    return YES;
}

- (BOOL)checkAndReplaceOtherWithCurrentLine:(NSString*)currentLine  ofTextView:(NSTextView*)textView
{
    //对于@s/,@w/,@a/作为默认的。如果存储的没找到就放在最后面，检测这三个默认的
    //    NSArray * const defaultArray = @[
    //                              @{
    //                                  @"regex":@"^\\s*@s/$",
    //                                  @"replaceContent": @"@property (nonatomic, strong) <#custom#>"
    //                                  }
    //                              ,
    //                              @{
    //                                  @"regex":@"^\\s*@w/$",
    //                                  @"replaceContent": @"@property (nonatomic, weak) <#custom#>"
    //                                  }
    //                              ,
    //                              @{
    //                                  @"regex":@"^\\s*@a/$",
    //                                  @"replaceContent": @"@property (nonatomic, assign) <#custom#>"
    //                                  }
    //                              ,
    //                              ];
    //找到工程下的默认plist,默认的三个存储在这里面
    NSString *defaultReplaceOtherPlistPathOfBundle = [self.bundle pathForResource:@"DefaultReplaceOther" ofType:@"plist"];
    
    NSArray *defaultArray = [NSArray arrayWithContentsOfFile:defaultReplaceOtherPlistPathOfBundle];
    
    NSMutableArray *finalReplaceOthers = nil;
    @synchronized(self.replaceOthers){ //简单同步
        finalReplaceOthers = [self.replaceOthers mutableCopy];
    }
    if (finalReplaceOthers) {
        [finalReplaceOthers addObjectsFromArray:defaultArray];
    }else{
        finalReplaceOthers = [defaultArray mutableCopy];
    }
    for (NSDictionary *aRegexDict in finalReplaceOthers) {
        //找到正则
        NSString *regex = aRegexDict[@"regex"];
        //找到替换内容
        NSString *replaceContent = aRegexDict[@"replaceContent"];
        if ([NSString IsNilOrEmpty:regex]||[NSString IsNilOrEmpty:replaceContent]) {
            continue;
        }
        
        //检测是否匹配
        if(![currentLine vv_matchesPatternRegexPattern:regex]){
            continue;
        }
        //按键以完成替换
        [self removeCurrentLineContentAndInputContent:replaceContent ofTextView:textView];
        return YES;
        
    }
    
    return NO;
    
}

#pragma mark - auto input content and remove orig conten of current line
- (void)removeCurrentLineContentAndInputContent:(NSString*)replaceContent ofTextView:(NSTextView*)textView
{
    //记录下光标位置，找到此行开头的位置
    NSUInteger currentLocation = [textView locationOfCurrentLine];
    NSUInteger tabBeginLocation = currentLocation;
    
    //根据replaceContent里的内容检查是否需要自动Tab
    BOOL isNeedAutoTab = NO;
    if([replaceContent vv_matchesPatternRegexPattern:@"<#\\w+#>"]){
        isNeedAutoTab = YES;
        
        //找到第一个可tab的所在位置
        NSArray *array = [replaceContent vv_stringsByExtractingGroupsUsingRegexPattern:@"(<#\\w+#>)"];
        if (array.count<=0) {
            return;
        }
        NSUInteger index = [replaceContent rangeOfString:array[0]].location;
        if (index==NSNotFound) {
            isNeedAutoTab = NO;
        }else{
            tabBeginLocation = currentLocation+index;
        }
    }
    
    //保存以前剪切板内容
    NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
    NSString *originPBString = [pasteBoard stringForType:NSPasteboardTypeString];
    
    //复制要添加内容到剪切板
    [pasteBoard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pasteBoard setString:replaceContent forType:NSStringPboardType];
    
    dispatch_block_t block = ^{
        VVKeyboardEventSender *kes = [[VVKeyboardEventSender alloc] init];
        BOOL useDvorakLayout = [VVKeyboardEventSender useDvorakLayout];
        
        [kes beginKeyBoradEvents];
        
        //光标移到此行结束的位置,这样才能一次把一行都删去
        [textView setSelectedRange:NSMakeRange([textView endLocationOfCurrentLine]+1, 0)];
        //删掉当前这一行光标位置前面的内容 Command+Delete
        [kes sendKeyCode:kVK_Delete withModifierCommand:YES alt:NO shift:NO control:NO];
        
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
                    //光标移到tab开始的位置
                    [textView setSelectedRange:NSMakeRange(tabBeginLocation, 0)];
                    //Send a 'tab' after insert the doc. For our lazy programmers. :)
                    [kes sendKeyCode:kVK_Tab];
                }
                
                [kes endKeyBoradEvents];
                
                //让默认行为无效
                return nil;
            }
            return incomingEvent;
        }];
    };
    
    //键盘操作放到主线程去做
    dispatch_async(dispatch_get_main_queue(), block);
    
}

@end
