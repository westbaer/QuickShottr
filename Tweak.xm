#include <CoreGraphics/CoreGraphics.h>

@class QuickShottr;

static NSMutableDictionary *configDir;
static QuickShottr *qs; 

/* Functions {{{*/

// Thanks, DHowett
static bool QSSBoolValue(id key, bool value) {
	if(!configDir) return value;
	id obj = [configDir objectForKey:key];
	if(!obj) return value;
	else return [obj boolValue];
}

/*
static void _qss_error_alert(NSError *desc) {
	UIAlertView *_ = [[UIAlertView alloc] initWithTitle:@"QuickShottr" message:[desc localizedDescription] delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
	[_ show];
	[_ release];
}
*/

static void _load_qsettings() {
	if(configDir) CFRelease(configDir); configDir = nil;
	configDir = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/me.nhaunold.QuickShottr.plist"];
}
/*}}}*/

/* QuickShottr Class {{{*/
@interface QuickShottr : NSObject {
	UIPasteboard *pasteboard;
	NSMutableData *serverData;
}


- (void)uploadPhotoWithData:(NSData *)data;
- (void)done;
@end

@implementation QuickShottr

- (id)init {
	if((self = [super init])) {
		pasteboard = [UIPasteboard generalPasteboard];
	}

	return self;
}

- (void)uploadPhotoWithData:(NSData *)data {
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://www.imageshack.us/index.php"]];
	[request setHTTPMethod:@"POST"];

	NSString *stringBoundary = @"________1dxXQuickShottr23zt234z_WESTBAER!212____";
	NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", stringBoundary];
	[request addValue:contentType forHTTPHeaderField:@"Content-Type"];

	NSMutableData *postBody = [NSMutableData data];
	[postBody appendData:[[NSString stringWithFormat:@"--%@\r\n",stringBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
  
	[postBody appendData:[@"Content-Disposition: form-data; name=\"xml\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
	[postBody appendData:[@"yes" dataUsingEncoding:NSUTF8StringEncoding]];	
	[postBody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",stringBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
		
	[postBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"quickshottya.png\"\r\n", @"fileupload"] dataUsingEncoding:NSUTF8StringEncoding]];
	[postBody appendData:[[NSString stringWithString:@"Content-Type: image/png\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
	[postBody appendData:data];
	[postBody appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",stringBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
	
	[request setHTTPBody:postBody];

	[[NSURLConnection alloc] initWithRequest:request delegate:self];
	serverData = [[NSMutableData alloc] init];

	[request release];
	[postBody release];
}

- (void)shortUrl:(NSString *)url {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSURL *shorturl = [NSURL URLWithString:[NSString stringWithFormat:@"http://is.gd/api.php?longurl=%@", url]];
	NSURLRequest *r = [NSURLRequest requestWithURL:shorturl];
	NSData *d2 = [NSURLConnection sendSynchronousRequest:r returningResponse:nil error:nil];
	NSString *val = [[NSString alloc] initWithData:d2 encoding:NSUTF8StringEncoding];

	if(val != nil && ![val isEqualToString:@""]) {
		[self performSelectorOnMainThread:@selector(save:) withObject:val waitUntilDone:YES];
	}

	[val release];
	[pool release];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	[serverData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[serverData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	[connection release];
	[serverData release];
	
	[self done];
	//_qss_error_alert(error);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	NSString *resp = [[NSString alloc] initWithData:serverData encoding:NSUTF8StringEncoding];
	NSArray *lines = [resp componentsSeparatedByString:@"\n"];
	NSString *url = [lines objectAtIndex:1];
	url = [url stringByReplacingOccurrencesOfString:@" " withString:@""];
	url = [url stringByReplacingOccurrencesOfString:@"<image_link>" withString:@""];
	url = [url stringByReplacingOccurrencesOfString:@"</image_link>" withString:@""];
	
	
	if(QSSBoolValue(@"QSShortize", false) == true) {
		[NSThread detachNewThreadSelector:@selector(shortUrl:) toTarget:self withObject:url]; 
	} else {
		[self save:[url copy]];
	}

	[resp release];
}

- (void)save:(NSString *)url {
	[pasteboard setString:url];
	[self done];
}

- (void)done {
	id sb = [NSClassFromString(@"SBStatusBarController") sharedStatusBarController];
	[sb removeStatusBarItem:@"QuickShottr_3"];
}

- (void)dealloc {
	[super dealloc];
}

@end
/*}}}*/

/* SBScreenShotter Hook {{{*/
%hook SBScreenShotter
- (void)finishedWritingScreenshot:(id)fp8 didFinishSavingWithError:(id)fp12 context:(void *)fp16 {
	if(QSSBoolValue(@"QSEnabled", false) == true) {
		id sb = [NSClassFromString(@"SBStatusBarController") sharedStatusBarController];
		[sb addStatusBarItem:@"QuickShottr_3"];
		[qs uploadPhotoWithData:UIImagePNGRepresentation(fp8)];
	}

	%orig(fp8, fp12, fp16);
}
%end
/*}}}*/

/* Constructor {{{*/
static __attribute__((constructor)) void QuickShottrInitialize() {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	qs = [[QuickShottr alloc] init];

	%init;

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)_load_qsettings, CFSTR("QuickShottr_Refresh"), NULL, 0);

	_load_qsettings();

	[pool release];
}
/*}}}*/
