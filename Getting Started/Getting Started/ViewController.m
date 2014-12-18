//
//  ViewController.h
//  Getting Started
//
//  Created by Jeff Swartz on 11/19/14.
//  Copyright (c) 2014 TokBox, Inc. All rights reserved.

#import "ViewController.h"
#import <OpenTok/OpenTok.h>

@interface ViewController ()
<OTSessionDelegate, OTSubscriberKitDelegate, OTPublisherDelegate, UITextFieldDelegate, UIScrollViewDelegate>
@property (weak, nonatomic) IBOutlet UIView *controlsView;
@property (weak, nonatomic) IBOutlet UIView *videoContainerView;
@property (weak, nonatomic) IBOutlet UIView *subscriberView;
@property (weak, nonatomic) IBOutlet UIView *publisherView;
@property (weak, nonatomic) IBOutlet UIButton *swapCameraBtn;
@property (weak, nonatomic) IBOutlet UITextView *chatReceivedTextView;
@property (weak, nonatomic) IBOutlet UIButton *publisherAudioBtn;
@property (weak, nonatomic) IBOutlet UIButton *subscriberAudioBtn;
@property (weak, nonatomic) IBOutlet UITextField *chatInputTextField;

@end

@implementation ViewController {
    OTSession* _session;
    OTPublisher* _publisher;
    OTSubscriber* _subscriber;
    NSString* _archiveId;
    NSString* _apiKey;
    NSString* _sessionId;
    NSString* _token;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    _chatInputTextField.delegate = self;

    [self getSessionCredentials];
}

- (void)getSessionCredentials
{
    if (!API_KEY || !SESSION_ID || !TOKEN) {
        // Get the OpenTok API key and a session ID and token from the web service
        NSString* urlPath = SAMPLE_SERVER_BASE_URL;
        urlPath = [urlPath stringByAppendingString:@"/session"];
        NSURL *url = [NSURL URLWithString: urlPath];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10];
        [request setHTTPMethod: @"GET"];
        
        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error){
            if (error){
                NSLog(@"Error,%@, URL: %@", [error localizedDescription],urlPath);
            }
            else{
                NSDictionary *roomInfo = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
                _apiKey = [roomInfo objectForKey:@"apiKey"];
                _token = [roomInfo objectForKey:@"token"];
                _sessionId = [roomInfo objectForKey:@"sessionId"];
                
                if(!_apiKey || !_token || !_sessionId) {
                    NSLog(@"Error invalid response from server, URL: %@",urlPath);
                } else {
                    [self doConnect];
                }
            }
        }];
    } else {
        // Use the hardcoded API key, session ID, and token values,
        // which you should not do in a production application.
        _apiKey = API_KEY;
        _sessionId = SESSION_ID;
        _token = TOKEN;
        [self doConnect];
    }
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:
(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if (UIUserInterfaceIdiomPhone == [[UIDevice currentDevice]
                                      userInterfaceIdiom])
    {
        return NO;
    } else {
        return YES;
    }
}
#pragma mark - OpenTok methods

/**
 * Asynchronously begins the session connect process. Some time later, we will
 * expect a delegate method to call us back with the results of this action.
 */
- (void)doConnect
{
    // Initialize a new instance of OTSession and begin the connection process.
    _session = [[OTSession alloc] initWithApiKey:_apiKey
                                       sessionId:_sessionId
                                        delegate:self];
    OTError *error = nil;
    [_session connectWithToken:_token error:&error];
    if (error)
    {
        NSLog(@"Unable to connect to session (%@)",
              error.localizedDescription);
    }
}

/**
 * Sets up an instance of OTPublisher to use with this session. OTPubilsher
 * binds to the device camera and microphone, and will provide A/V streams
 * to the OpenTok session.
 */
- (void)doPublish
{
    _publisher = [[OTPublisher alloc]
                  initWithDelegate:self];
    
    OTError *error = nil;
    [_session publish:_publisher error:&error];
    if (error)
    {
        NSLog(@"Unable to publish (%@)",
              error.localizedDescription);
    }
    
    [_publisher.view setFrame:CGRectMake(0, 0, _publisherView.bounds.size.width,
                                         _publisherView.bounds.size.height)];
    [_publisherView addSubview:_publisher.view];

    
    _publisherAudioBtn.hidden = NO;
    [_publisherAudioBtn addTarget:self
                          action:@selector(togglePublisherMic)
                forControlEvents:UIControlEventTouchUpInside];
    
    _swapCameraBtn.hidden = NO;
    [_swapCameraBtn addTarget:self
               action:@selector(swapCamera)
     forControlEvents:UIControlEventTouchUpInside];
}


-(void)togglePublisherMic
{
    _publisher.publishAudio = !_publisher.publishAudio;
}

-(void)toggleSubscriberAudio
{
    _subscriber.subscribeToAudio = !_subscriber.subscribeToAudio;
}

-(void)swapCamera
{
    if (_publisher.cameraPosition == AVCaptureDevicePositionFront) {
        _publisher.cameraPosition = AVCaptureDevicePositionBack;
    } else {
        _publisher.cameraPosition = AVCaptureDevicePositionFront;
    }
}

/**
 * Cleans up the publisher and its view. At this point, the publisher is not
 * attached to the session.
 */
- (void)cleanupPublisher {
    [_publisher.view removeFromSuperview];
    _publisher = nil;
}

/**
 * Instantiates a subscriber for the given stream and asynchronously begins the
 * process to begin receiving A/V content for this stream. Unlike doPublish,
 * this method does not add the subscriber to the view hierarchy. Instead, we
 * add the subscriber only after it has connected and begins receiving data.
 */
- (void)doSubscribe:(OTStream*)stream
{
    _subscriber = [[OTSubscriber alloc] initWithStream:stream
                                              delegate:self];
    OTError *error = nil;
    [_session subscribe:_subscriber error:&error];
    if (error)
    {
        NSLog(@"Unable to publish (%@)",
              error.localizedDescription);
    }
}

/**
 * Cleans the subscriber from the view hierarchy.
 */
- (void)cleanupSubscriber
{
    [_subscriber.view removeFromSuperview];
    _subscriber = nil;
}

- (void) sendChatMessage
{
    OTError* error = nil;
    [_session signalWithType:@"chat" string:_chatInputTextField.text connection:nil error:&error];
    if (error) {
        NSLog(@"Signal error: %@", error);
    } else {
        NSLog(@"Signal sent: %@", _chatInputTextField.text);
    }
    _chatInputTextField.text = @"";
}

- (void)logSignalString:(NSString*)string fromSelf:(Boolean)fromSelf {
    int prevLength = _chatReceivedTextView.text.length - 1;
    [_chatReceivedTextView insertText:string];
    [_chatReceivedTextView insertText:@"\n"];
    
    if (fromSelf) {
        NSDictionary* formatDict = @{NSForegroundColorAttributeName: [UIColor blueColor]};
        NSRange textRange = NSMakeRange(prevLength + 1, string.length);
        [_chatReceivedTextView.textStorage setAttributes:formatDict range:textRange];
    }
    [_chatReceivedTextView setContentOffset:_chatReceivedTextView.contentOffset animated:NO];
    [_chatReceivedTextView scrollRangeToVisible:NSMakeRange([_chatReceivedTextView.text length], 0)];
}

# pragma mark - OTSession delegate callbacks

- (void)sessionDidConnect:(OTSession*)session
{
    // We have successfully connected, now start pushing an audio-video stream
    // to the OpenTok session.
    [self doPublish];
}

- (void)sessionDidDisconnect:(OTSession*)session
{
    NSString* alertMessage =
    [NSString stringWithFormat:@"Session disconnected: (%@)",
     session.sessionId];
    NSLog(@"sessionDidDisconnect (%@)", alertMessage);
}

- (void)session:(OTSession*)session
streamCreated:(OTStream *)stream
{
    NSLog(@"session streamCreated (%@)", stream.streamId);
    
    if (nil == _subscriber)
    {
        [self doSubscribe:stream];
    }
}

- (void)session:(OTSession*)session
streamDestroyed:(OTStream *)stream
{
    NSLog(@"session streamDestroyed (%@)", stream.streamId);
    
    if ([_subscriber.stream.streamId isEqualToString:stream.streamId])
    {
        [self cleanupSubscriber];
    }
}

- (void)  session:(OTSession *)session
connectionCreated:(OTConnection *)connection
{
    NSLog(@"session connectionCreated (%@)", connection.connectionId);
}

- (void)    session:(OTSession *)session
connectionDestroyed:(OTConnection *)connection
{
    NSLog(@"session connectionDestroyed (%@)", connection.connectionId);
    if ([_subscriber.stream.connection.connectionId
         isEqualToString:connection.connectionId])
    {
        [self cleanupSubscriber];
    }
}

- (void) session:(OTSession*)session
didFailWithError:(OTError*)error
{
    NSLog(@"didFailWithError: (%@)", error);
}

# pragma mark - OTPublisher delegate callbacks

- (void)publisher:(OTPublisherKit *)publisher
streamCreated:(OTStream *)stream
{
    NSLog(@"Now publishing.");
}

- (void)publisher:(OTPublisherKit*)publisher
streamDestroyed:(OTStream *)stream
{
    [self cleanupPublisher];
}

- (void)session:(OTSession*)session receivedSignalType:(NSString*)type fromConnection:(OTConnection*)connection withString:(NSString*)string {
    NSLog(@"Received signal %@", string);
    Boolean fromSelf = NO;
    if ([connection.connectionId isEqualToString:session.connection.connectionId]) {
        fromSelf = YES;
    }
    [self logSignalString:string fromSelf:fromSelf];
}

- (void)publisher:(OTPublisherKit*)publisher
didFailWithError:(OTError*) error
{
    NSLog(@"publisher didFailWithError %@", error);
    [self cleanupPublisher];
}

# pragma mark - OTSubscriber delegate callbacks

- (void)subscriberDidConnectToStream:(OTSubscriberKit*)subscriber
{
    NSLog(@"subscriberDidConnectToStream (%@)",
          subscriber.stream.connection.connectionId);
    [_subscriber.view setFrame:CGRectMake(0, 0, _subscriberView.bounds.size.width,
                                          _subscriberView.bounds.size.height)];
    [_subscriberView addSubview:_subscriber.view];
    
    _subscriberAudioBtn.hidden = NO;
    [_subscriberAudioBtn addTarget:self
                           action:@selector(toggleSubscriberAudio)
                 forControlEvents:UIControlEventTouchUpInside];

}

- (void)subscriber:(OTSubscriberKit*)subscriber
  didFailWithError:(OTError*)error
{
    NSLog(@"subscriber %@ didFailWithError %@",
          subscriber.stream.streamId,
          error);
}

# pragma mark - UITextFieldDelegate callbacks

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    _chatInputTextField.text = @"";
    // CGPoint bottomOffset = CGPointMake(0, 260);
    // [_chatScrollView setContentOffset:bottomOffset animated:YES];
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendChatMessage];
    // CGPoint bottomOffset = CGPointMake(0, 0);
    // [_chatScrollView setContentOffset:bottomOffset animated:YES];
    return YES;
}


@end