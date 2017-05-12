//
//  MLAutoReplace.m
//  MLAutoReplace
//
//  Created by molon on 4/25/14.
//    Copyright (c) 2014 molon. All rights reserved.
//

#import "MLAutoReplace.h"
#import "MLKeyboardEventSender.h"
#import "SettingWindowController.h"
#import "NSTextView+Addition.h"
#import "NSString+Addition.h"
#import "NSString+PDRegex.h"
#import "NSDate+Addition.h"

#import "Debug.h"

static MLAutoReplace *sharedPlugin;

#define kSourceTextViewClass NSClassFromString(@"DVTSourceTextView")

@interface MLAutoReplace()

@property (nonatomic, strong) NSBundle *bundle;
@property (nonatomic, strong) NSDictionary *replaceGetters;
@property (nonatomic, strong) NSArray *replaceOthers;

@property (nonatomic, strong) id eventMonitor;

@property (nonatomic, strong) SettingWindowController *settingWC;

@property (nonatomic, assign) BOOL checkSwitch;

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
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidFinishLaunching:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
    }
    return self;
}

+ (void)showSimpleTips:(NSString*)tips
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:@"MLAutoReplace"];
    [alert setInformativeText:tips];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert runModal];
}

- (void)applicationDidFinishLaunching: (NSNotification*) noti {
    //加载替换配置文件
    if (![self loadReplacePlist]) {
        [MLAutoReplace showSimpleTips:@"Load plist failed! Please retart Xcode to retry."];
        return;
    }
    
    //添加按键检测 ,检测shift+command+|，用来自动去处理当前自动re-indent
    //当前的弊端是如果用户打开XCode之后从来木有编辑过一次程序，那就没有用
    __weak __typeof(self)weakSelf = self;
    self.eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask handler:^NSEvent *(NSEvent *incomingEvent) {
        __strong __typeof(weakSelf)sSelf = weakSelf;
        if ([incomingEvent type] == NSKeyDown && [incomingEvent keyCode] == kVK_ANSI_Backslash
            && (incomingEvent.modifierFlags&kCGEventFlagMaskShift)&&(incomingEvent.modifierFlags&kCGEventFlagMaskCommand)) {
            
            //如果设置里不需要此功能则返回
            if (![sSelf.settingWC isUseAutoReIntent]) {
                return incomingEvent;
            }
            
            if (![incomingEvent.window.firstResponder isKindOfClass:kSourceTextViewClass]) {
                return incomingEvent;
            }
            
            NSTextView *textView = (NSTextView *)incomingEvent.window.firstResponder;
            
            DLOG(@"按了shift+command+|,window:%@，windowNumber:%ld，并且执行自动re-indent",incomingEvent.window,incomingEvent.windowNumber);
            
            NSUInteger locationOfCurrentLine = [textView ml_beginLocationOfCurrentLine];
            
            MLKeyboardEventSender *kes = [[MLKeyboardEventSender alloc] init];
            [kes beginKeyBoradEvents];
            
            //全选
            [kes sendKeyCode:kVK_ANSI_A withModifierCommand:YES alt:NO shift:NO control:NO];
            //ReIndent
            [kes sendKeyCode:kVK_ANSI_I withModifierCommand:NO alt:NO shift:NO control:YES];
            
            [kes endKeyBoradEvents];
            
            //防止越界
            if (textView.textStorage.length<=locationOfCurrentLine) {
                return nil;
            }
            
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
            [sSelf.settingWC reloadPlist:nil]; //简单调用下WC的方法即可
        }
        return incomingEvent;
    }];
    
    self.checkSwitch = YES;
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
        SettingWindowController *wc = [SettingWindowController alloc];
        wc = [wc initWithWindowNibName:@"SettingWindowController" owner:wc];
        _settingWC = wc;
    }
    return _settingWC;
}

- (void)doMenuAction
{
    [self.settingWC showWindow:nil];
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
    if (!self.checkSwitch) {
        return;
    }
    
    if (![[noti object] isKindOfClass:kSourceTextViewClass]) {
        return;
    }
    
    //本来以下是在后台线程里做的，现在去掉了，实则不必要，也免得发生可能的不稳定。懒得深入研究。
    NSTextView *textView = (NSTextView *)[noti object];
    if (![textView.window.firstResponder isEqual:textView]) {
        return;
    }
    
    NSString *currentLine = [textView ml_textOfCurrentLine];
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
}

#pragma mark - check and replace
- (BOOL)checkAndReplaceGetterWithCurrentLine:(NSString*)currentLine  ofTextView:(NSTextView*)textView
{
    //eg:- (UIView *)view///
    static NSString *lastCurrentLine = nil;
    if(![currentLine vvv_matchesPatternRegexPattern:@"^\\s*-\\s*\\(\\s*\\w+\\s*\\*?\\s*\\)\\s*\\w+\\s*/{3}$"]){
        lastCurrentLine = currentLine;
        return NO;
    }
    
    //这里用来保证是一个字一个字把最后三个/敲出来的，而不是复制啊，或者从中间敲的
    if(![[lastCurrentLine stringByAppendingString:@"/"]isEqualToString:currentLine]||[textView ml_endLocationOfCurrentLine]+1!=[textView ml_currentCurseLocation]){
        lastCurrentLine = currentLine;
        return NO;
    }
    lastCurrentLine = currentLine;
    
    
    //get the return type of getter
    NSArray *array = [currentLine vvv_stringsByExtractingGroupsUsingRegexPattern:@"\\(\\s*(\\w+\\s*\\*?)\\s*\\)"];
    if (array.count<=0) {
        return NO;
    }
    NSString *type = [array[0] stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    //get the name of getter
    array = [currentLine vvv_stringsByExtractingGroupsUsingRegexPattern:@"\\)\\s*(\\w+)\\s*/{3}$"];
    if (array.count<=0) {
        return NO;
    }
    NSString *name = array[0];
    
    NSLog(@"%@,%@",type,name);
    
    //根据type找到对应的替换文本
    NSString *replaceContent =  nil;
    
    NSString * const defaultReplaceGetterOfScalar = @"\t<#custom#>\n}\n";
    
    NSString * replaceGetter = nil;
    @synchronized(self.replaceGetters){ //简单同步
        replaceGetter = self.replaceGetters[type];
    }
    if (replaceGetter) {
        replaceContent =  [replaceGetter stringByReplacingOccurrencesOfString:@"<name>" withString:name];
    }else{
        NSString *replaceGetter = defaultReplaceGetterOfScalar;
        if ([type hasSuffix:@"*"]||[type isEqualToString:@"id"]) {
            NSString * const defaultReplaceGetterOfPointer = @"\tif (!_<name>) {%@\n\t\t<#custom#>\n\t}\n\treturn _<name>;\n}\n";
            NSString *otherContent = @"";
            if ([type hasSuffix:@"*"]) {
                NSString *typeWithoutStar = [[type substringToIndex:type.length-1]stringByReplacingOccurrencesOfString:@" " withString:@""];
                otherContent = [NSString stringWithFormat:@"\n\t\t_<name> = [%@ new];",typeWithoutStar];
                
                type = [[type substringToIndex:type.length-1] stringByAppendingString:@" *"];
            }
            replaceGetter = [NSString stringWithFormat:defaultReplaceGetterOfPointer,otherContent];
        }
        replaceContent = [[NSString stringWithFormat:@"- (%@)<name> {\n%@",type,replaceGetter] stringByReplacingOccurrencesOfString:@"<name>" withString:name];
    }
    
    if ([NSString IsNilOrEmpty:replaceContent]) {
        return NO;
    }
    
    //时间标签会替换成当前时间
    if ([replaceContent rangeOfString:@"<datetime>"].location!=NSNotFound) {
        replaceContent = [replaceContent stringByReplacingOccurrencesOfString:@"<datetime>" withString:[NSDate ml_nowString]];
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
    if (finalReplaceOthers.count<=0) {
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
        if(![currentLine vvv_matchesPatternRegexPattern:regex]){
            continue;
        }
        
        //时间标签会替换成当前时间
        if ([replaceContent rangeOfString:@"<datetime>"].location!=NSNotFound) {
            replaceContent = [replaceContent stringByReplacingOccurrencesOfString:@"<datetime>" withString:[NSDate ml_nowString]];
        }
        
        //如果有获取下面的类名的标签，必须继承自某父类才可以
        if ([replaceContent rangeOfString:@"<declare_class_below>"].location!=NSNotFound) {
            //找到下面的最近的直到最近的一些特殊标记
            NSString *textUntilColon = [textView ml_textUntilNextString:@":"];
            if (textUntilColon.length<=0) {
                continue;
            }
            //探测其是否满足 @interface XXX: 这样的格式，满足的话就拎出来XXX
            NSArray *array = [textUntilColon vvv_stringsByExtractingGroupsUsingRegexPattern:@"@interface\\s+(\\w+)\\s*:"];
            if (array.count<=0) {
                continue;
            }
            replaceContent = [replaceContent stringByReplacingOccurrencesOfString:@"<declare_class_below>" withString:array[0]];
        }
        
        if ([replaceContent vvv_matchesPatternRegexPattern:@"\\<\\{\\d+\\}\\>"]) {
            //有位置占位符
            NSArray *array = [currentLine vvv_stringsByExtractingGroupsUsingRegexPattern:regex];
            if (array.count<=0) {
                continue;
            }
            //ok 我们挨个去替换
            for (NSInteger i=0; i<array.count; i++) {
                NSString *element = array[i];
                replaceContent = [replaceContent stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"<{%ld}>",i] withString:element];
            }
            //替换完了，但是还是发现有没找到的，就肯定还是有问题就啥也不做。
            if ([replaceContent vvv_matchesPatternRegexPattern:@"\\<\\{\\d+\\}\\>"]) {
                continue;
            }
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
    NSUInteger currentLocation = [textView ml_beginLocationOfCurrentLine];
    NSUInteger tabBeginLocation = currentLocation;
    
    //根据replaceContent里的内容检查是否需要自动Tab
    BOOL isNeedAutoTab = NO;
    if([replaceContent vvv_matchesPatternRegexPattern:@"<#\\w+#>"]){
        isNeedAutoTab = YES;
        
        //找到第一个可tab的所在位置
        NSArray *array = [replaceContent vvv_stringsByExtractingGroupsUsingRegexPattern:@"(<#\\w+#>)"];
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
    
    DLOG(@"开始替换");
    
    //保存以前剪切板内容
    NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
    if (!pasteBoard) {
        return;
    }
    NSString *originPBString = [pasteBoard stringForType:NSPasteboardTypeString];
    DLOG(@"原剪切板内容:%@",originPBString);
    
    //复制要添加内容到剪切板
    [pasteBoard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pasteBoard setString:replaceContent forType:NSStringPboardType];
    DLOG(@"设置新剪切板内容:%@",replaceContent);
    
    self.checkSwitch = NO;
    dispatch_block_t block = ^{
        MLKeyboardEventSender *kes = [[MLKeyboardEventSender alloc] init];
        BOOL useDvorakLayout = [MLKeyboardEventSender useDvorakLayout];
        
        [kes beginKeyBoradEvents];
        
        //光标移到此行结束的位置,这样才能一次把一行都删去
        [textView setSelectedRange:NSMakeRange([textView ml_endLocationOfCurrentLine]+1, 0)];
        //删掉当前这一行光标位置前面的内容 Command+Delete
        [kes sendKeyCode:kVK_Delete withModifierCommand:YES alt:NO shift:NO control:NO];
        DLOG(@"删除此行");
        
        //粘贴剪切板内容
        NSInteger kKeyVCode = useDvorakLayout?kVK_ANSI_Period : kVK_ANSI_V;
        [kes sendKeyCode:kKeyVCode withModifierCommand:YES alt:NO shift:NO control:NO];
        DLOG(@"粘贴新内容:%@",replaceContent);
        
        //这个按键用来模拟下上个命令执行完毕了，然后需要还原剪切板 ,按键是同步进行的,所以接到F20的时候应该之前的都执行完毕了
        [kes sendKeyCode:kVK_F20];
        
        [kes endKeyBoradEvents];
        
        static id eventMonitor = nil;
        eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask handler:^NSEvent *(NSEvent *incomingEvent) {
            if ([incomingEvent type] == NSKeyDown && [incomingEvent keyCode] == kVK_F20) {
                [NSEvent removeMonitor:eventMonitor];
                eventMonitor = nil;
                
                //还原剪切板
                [pasteBoard setString:originPBString forType:NSStringPboardType];
                DLOG(@"还原剪切板内容:%@",originPBString);
                
                if (isNeedAutoTab) {
                    [kes beginKeyBoradEvents];
                    
                    //光标移到tab开始的位置
                    [textView setSelectedRange:NSMakeRange(tabBeginLocation, 0)];
                    //Send a 'tab' after insert the doc. For our lazy programmers. :)
                    [kes sendKeyCode:kVK_Tab];
                    DLOG(@"去tab位置");
                    
                    [kes endKeyBoradEvents];
                }
                
                self.checkSwitch = YES;
                
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
