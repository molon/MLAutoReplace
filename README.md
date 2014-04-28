MLAutoReplace
=============

XCode plugin , Thanks for [VVDocumenter-Xcode](https://github.com/onevcat/VVDocumenter-Xcode).  

You can input common getter quickly.  
![replace getter](https://raw.githubusercontent.com/molon/MLAutoReplace/master/replaceGetter.gif)  

You can custom other replacer with regex.  
![replace getter](https://raw.githubusercontent.com/molon/MLAutoReplace/master/replaceOther.gif)  

You can use `Shift+Command+\` to auto re-indent all source of the current edit file.  

##Getter replacer

You need add your own common syntax to the getter replacer.  
![replace getter](https://raw.githubusercontent.com/molon/MLAutoReplace/master/addReplaceGetter.gif)  

`<name>` means the property name.  
`<#xxx#>` means where need to input in,it is recommended to provide.  

Exmple:

```
- (UIImageView *)<name>
{
    if (!_<name>) {
		UIImageView *imageView = [[UIImageView alloc]init];
        imageView.image = [UIImage imageNamed:@"<#imageName#>"];
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        <#custom#>

        _<name> = imageView;
    }
    return _<name>;
}
```  
  
You must reload .plist file with shortcut `control+option+command+\` after editing and saving it.   
You can also reload it with the `Reload .plist Data` button in MLAutoReplace window.   

##Regex replacer

Exmple:  
![replace getter](https://raw.githubusercontent.com/molon/MLAutoReplace/master/regex.png)  
This item means that plugin will replace `@s/` to `@property (nonatomic, strong) <#custom#>`.  


The plugin will detect the content of current input line.  


