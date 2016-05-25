//
//  NSString+PDRegex.h
//  RegexOnNSString
//
//  Created by Carl Brown on 10/3/11.
//  Copyright 2011 PDAgent, LLC. Released under MIT License.
//

#import <Foundation/Foundation.h>

//就是怕和VV的类重名而两者不能共存，不知道有没影响，为了保险起见。
@interface NSString (RENAME_PDRegex)

-(NSString *) vvv_stringByReplacingRegexPattern:(NSString *)regex withString:(NSString *) replacement;
-(NSString *) vvv_stringByReplacingRegexPattern:(NSString *)regex withString:(NSString *) replacement caseInsensitive:(BOOL) ignoreCase;
-(NSString *) vvv_stringByReplacingRegexPattern:(NSString *)regex withString:(NSString *) replacement caseInsensitive:(BOOL) ignoreCase treatAsOneLine:(BOOL) assumeMultiLine;
-(NSArray *) vvv_stringsByExtractingGroupsUsingRegexPattern:(NSString *)regex;
-(NSArray *) vvv_stringsByExtractingGroupsUsingRegexPattern:(NSString *)regex caseInsensitive:(BOOL) ignoreCase treatAsOneLine:(BOOL) assumeMultiLine;
-(BOOL) vvv_matchesPatternRegexPattern:(NSString *)regex;
-(BOOL) vvv_matchesPatternRegexPattern:(NSString *)regex caseInsensitive:(BOOL) ignoreCase treatAsOneLine:(BOOL) assumeMultiLine;
-(NSString *) vvv_textUntilNextString:(NSString *)findString currentLocation:(NSInteger)location;

@end
