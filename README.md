MLAutoReplace
=============

XCode plugin 

You can input common getter quickly.
![replace getter](https://raw.githubusercontent.com/molon/MLAutoReplace/master/replaceGetter.gif)

You can custom other replacer with regex.
![replace getter](https://raw.githubusercontent.com/molon/MLAutoReplace/master/replaceOther.gif)

You need add your own syntax of getter replacer.
![replace getter](https://raw.githubusercontent.com/molon/MLAutoReplace/master/addReplaceGetter.gif)

##getter replacer
`<name>` means the property name.  
`<#xxx#>` means need to input,it is recommended to provide

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
  
You must reload .plist file with shortcut `control+option+command+\` after saving it.   
You can also reload it with the reload button in MLAutoReplace window.   

##regex replacer

Exmple:

