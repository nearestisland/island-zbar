#import <zbar/ZBarReaderView.h>
#import <zbar/ZBarReaderViewController.h>

#define MODULE ZBarReaderView
#import "debug.h"

// hack around missing simulator support for AVCapture interfaces

@interface ZBarReaderViewController(Simulator)
@end

@implementation ZBarReaderViewController(Simulator)

- (void) initSimulator
{
    UILongPressGestureRecognizer *press =
        [[UILongPressGestureRecognizer alloc]
            initWithTarget: self
            action: @selector(takePicture)];
    [self.view addGestureRecognizer: press];
    press.numberOfTouchesRequired = 2;
    [press release];
}

- (void) takePicture
{
    UIImagePickerController *picker =
        [UIImagePickerController new];
    picker.delegate = (id<UINavigationControllerDelegate,
                          UIImagePickerControllerDelegate>)self;
    [self presentModalViewController: picker
          animated: YES];
    [picker release];
}

- (void)  imagePickerController: (UIImagePickerController*) picker
  didFinishPickingMediaWithInfo: (NSDictionary*) info
{
    UIImage *image = [info objectForKey: UIImagePickerControllerOriginalImage];
    [picker dismissModalViewControllerAnimated: YES];
    [readerView performSelector: @selector(scanImage:)
                withObject: image
                afterDelay: .1];
}

- (void) imagePickerControllerDidCancel: (UIImagePickerController*) picker
{
    [picker dismissModalViewControllerAnimated: YES];
}

@end

// protected APIs
@interface ZBarReaderView()
- (void) initSubviews;
- (void) setImageSize: (CGSize) size;
- (void) didTrackSymbols: (ZBarSymbolSet*) syms;
@end

@interface ZBarReaderViewImpl
    : ZBarReaderView
{
    ZBarImageScanner *scanner;
    UIImage *scanImage;
    BOOL enableCache;
}
@end

@implementation ZBarReaderViewImpl

@synthesize scanner, enableCache;

- (id) initWithImageScanner: (ZBarImageScanner*) _scanner
{
    self = [super initWithImageScanner: _scanner];
    if(!self)
        return(nil);

    scanner = [_scanner retain];

    [self initSubviews];
    return(self);
}

- (void) initSubviews
{
    UILabel *label =
        [[UILabel alloc]
            initWithFrame: CGRectMake(16, 165, 288, 96)];
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont boldSystemFontOfSize: 20];
    label.numberOfLines = 4;
    label.textAlignment = UITextAlignmentCenter;
    label.text = @"Camera Simulation\n\n"
        @"Tap and hold with two \"fingers\" to select image";
    [self addSubview: label];
    [label release];

    preview = [CALayer new];
    preview.frame = self.bounds;
    [self.layer addSublayer: preview];

    [super initSubviews];
}

- (void) dealloc
{
    [scanner release];
    scanner = nil;
    [super dealloc];
}

- (void) start
{
    if(started)
        return;
    [super start];
    running = YES;
}

- (void) stop
{
    if(!started)
        return;
    [super stop];
    running = NO;
}

- (void) scanImage: (UIImage*) image
{
    // strip EXIF info
    CGImageRef cgimage = image.CGImage;
    image = [[UIImage alloc]
                initWithCGImage: cgimage
                scale: 1.0
                orientation: UIImageOrientationUp];

    CGSize size = image.size;
    overlay.bounds = CGRectMake(0, 0, size.width, size.height);
    [self setImageSize: size];

    preview.contentsScale = imageScale;
    preview.contentsGravity = kCAGravityCenter;
    preview.contents = (id)cgimage;

    // match overlay to image
    CGFloat scale = 1 / imageScale;
    overlay.transform = CATransform3DMakeScale(scale, scale, 1);

    ZBarImage *zimg =
        [[ZBarImage alloc]
            initWithCGImage: cgimage];

    size = zimg.size;
    zimg.crop = CGRectMake(zoomCrop.origin.y * size.width,
                           zoomCrop.origin.x * size.height,
                           zoomCrop.size.height * size.width,
                           zoomCrop.size.width * size.height);

    int nsyms = [scanner scanImage: zimg];
    zlog(@"scan image: %@ crop=%@ nsyms=%d",
         NSStringFromCGSize(size), NSStringFromCGRect(zimg.crop), nsyms);
    [zimg release];

    if(nsyms > 0) {
        scanImage = [image retain];
        ZBarSymbolSet *syms = scanner.results;
        [self performSelector: @selector(didReadSymbols:)
              withObject: syms
              afterDelay: .4];
        [self performSelector: @selector(didTrackSymbols:)
              withObject: syms
              afterDelay: .001];
    }
    [image release];
}

- (void) didReadSymbols: (ZBarSymbolSet*) syms
{
    [readerDelegate
        readerView: self
        didReadSymbols: syms
        fromImage: scanImage];
    [scanImage release];
    scanImage = nil;
}

@end
