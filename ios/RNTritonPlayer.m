
#import "RNTritonPlayer.h"
#import "React/RCTConvert.h"

NSString* const EventTrackChanged = @"trackChanged";
NSString* const EventStreamChanged = @"streamChanged";
NSString* const EventStateChanged = @"stateChanged";
NSString* const EventCurrentPlaybackTimeChanged = @"currentPlaybackTimeChanged";

const NSInteger STATE_COMPLETED = 200;
const NSInteger STATE_CONNECTING = 201;
const NSInteger STATE_ERROR = 202;
const NSInteger STATE_PLAYING = 203;
const NSInteger STATE_RELEASED = 204;
const NSInteger STATE_STOPPED = 205;
const NSInteger STATE_PAUSED = 206;

@implementation RNTritonPlayer

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

- (NSArray<NSString *> *)supportedEvents
{
    return @[EventTrackChanged, EventStreamChanged, EventStateChanged, EventCurrentPlaybackTimeChanged];
}

RCT_EXPORT_METHOD(configure:(NSString *)brand)
{
    // Does nothing
}

RCT_EXPORT_METHOD(play:(NSString *)tritonName tritonStation:(NSString *)tritonStation  countryCode:(NSString *) countryCode)
{
    // Init Triton Player if its not set yet
    if (self.tritonPlayer == NULL) {
        self.tritonPlayer = [[TritonPlayer alloc] initWithDelegate:self andSettings:nil];
        self.track = @"-";
        self.title = @"-";
        self.state = 0;
    }
    // Set Station Details
    NSDictionary *settings = @{
                               SettingsStationNameKey : tritonName,
                               SettingsBroadcasterKey : @"Triton Digital",
                               SettingsMountKey : tritonStation,
                               SettingsPlayerServicesRegion: @"EU",
                               SettingsEnableLocationTrackingKey : @(YES),
                               StreamParamExtraCountryKey: countryCode,
                               SettingsTtagKey : @[@"PLAYER:NOPREROLL"],
                               @"csegid" : @(7)
                               };
    
    // mm
    
    // Stop Current Stream (if playing)
    //if ([self.tritonPlayer isExecuting]) {
    [self.tritonPlayer stop];
    //}
    
    // Setup stuff
    [self configureRemoteCommandHandling];
    
    // Update Triton Player settings
    [self.tritonPlayer updateSettings:settings];
    
    // Start Playing!
    [self.tritonPlayer play];
    
    // Notify stream change
    [self sendEventWithName:EventStreamChanged body:@{@"stream": tritonStation}];
}

RCT_EXPORT_METHOD(playOnDemandStream:(NSString *)streamURL )
{
    // Init Triton Player if its not set yet
    if (self.tritonPlayer == NULL) {
        self.tritonPlayer = [[TritonPlayer alloc] initWithDelegate:self andSettings:nil];
        self.track = @"-";
        self.title = @"-";
        self.state = 0;
    }
    
    // Set on demand Stream URL Details
    NSDictionary *settings = @{
                               SettingsContentURLKey: streamURL,
                               SettingsBroadcasterKey : @"Triton Digital",
                               SettingsPlayerServicesRegion: @"EU",
                               SettingsEnableLocationTrackingKey : @(YES),
                               SettingsTtagKey : @[@"PLAYER:NOPREROLL"]
                               };
    
    // mm
    
    // Stop Current Stream (if playing)
    //if ([self.tritonPlayer isExecuting]) {
    [self.tritonPlayer stop];
    //}
    
    // Setup stuff
    [self configureRemoteCommandHandling];
    
    // Update Triton Player settings
    [self.tritonPlayer updateSettings:settings];
    
    // Start Playing!
    [self.tritonPlayer play];
    
    // Notify stream change
    //[self sendEventWithName:EventStreamChanged body:@{@"stream": tritonStation}];
}

RCT_EXPORT_METHOD(getCurrentPlaybackTime:(RCTResponseSenderBlock)successCallback
    withErrorCallback:(RCTResponseSenderBlock)errorCallback
    )
{
    @try {

        if (self.tritonPlayer != NULL) {
            //NSTimeInterval temp = [self.tritonPlayer currentPlaybackTime];

    //        NSDictionary *output = @{
    //                                SettingsStationNameKey: [NSNumber [self.tritonPlayer currentPlaybackTime]]
    //                               };

            NSTimeInterval offset = [self.tritonPlayer currentPlaybackTime];

            [self sendEventWithName:EventCurrentPlaybackTimeChanged body:@{@"offset": [NSNumber numberWithInt:offset]}];

            NSNumber *eventId = [NSNumber numberWithInt:offset];
            successCallback(@[eventId]);
            //callback(@[[NSNumber [self.tritonPlayer currentPlaybackTime]]]);


        }
    }
    @catch(NSException *e) {
        errorCallback(@[e]);
    }
}


RCT_EXPORT_METHOD(seekTo:(NSTimeInterval)offset)
{
    if (self.tritonPlayer != NULL) {
        [self.tritonPlayer seekToTimeInterval:offset];
    }
}

RCT_EXPORT_METHOD(stop)
{
    if (self.tritonPlayer != NULL) {
        [self.tritonPlayer stop];
    }
}

RCT_EXPORT_METHOD(pause)
{
    if (self.tritonPlayer != NULL && self.tritonPlayer.state == kTDPlayerStatePlaying) {
        [self.tritonPlayer pause];
    }
}

RCT_EXPORT_METHOD(unPause)
{
    if (self.tritonPlayer != NULL) {
        [self.tritonPlayer play];
    }
}

RCT_EXPORT_METHOD(quit)
{
    
}


- (void)player:(TritonPlayer *)player didChangeState:(TDPlayerState)state {
    NSInteger eventState;
    
    // Map to Android value..
    switch(state) {
        case kTDPlayerStateStopped:
            eventState = STATE_RELEASED;
            break;
        case kTDPlayerStatePlaying:
            eventState = STATE_PLAYING;
            break;
        case kTDPlayerStateConnecting:
            eventState = STATE_CONNECTING;
            break;
        case kTDPlayerStatePaused:
            eventState = STATE_PAUSED;
            break;
        case kTDPlayerStateError:
            eventState = STATE_ERROR;
            break;
        case kTDPlayerStateCompleted:
            eventState = STATE_COMPLETED;
            break;
    }
    
    self.state = eventState;
    
    // Notify state change
    [self sendEventWithName:EventStateChanged body:@{@"state": @(eventState)}];
    [self configureNowPlayingInfo];
}

- (void)player:(TritonPlayer *)player didReceiveCuePointEvent:(CuePointEvent *)cuePointEvent {
//    NSLog(@"didReceiveCuePointEvent11: %@", cuePointEvent.type);
    if ([cuePointEvent.type isEqualToString:EventTypeAd]) {
//        NSLog(@"didReceiveCuePointEvent: Add");
        // Type CUE ad
        [self sendEventWithName:EventTrackChanged body:@{@"artist": @"-", @"title": @"-", @"isAd": @TRUE}];
        self.track = @"-";
        self.title = @"-";
    } else if ([cuePointEvent.type isEqualToString:EventTypeTrack]) {
        // Type CUE track
        
//        NSLog(@"didReceiveCuePointEvent: track");
        NSString *songTitle = [cuePointEvent.data objectForKey:CommonCueTitleKey];
        NSString *artistName = [cuePointEvent.data objectForKey:TrackArtistNameKey];
        NSString *durationTime = [cuePointEvent.data objectForKey:CommonCueTimeDurationKey];
        
        NSInteger duration = 0;
        
        if (durationTime != NULL) {
            duration = [durationTime integerValue];
        }
        
        [self sendEventWithName:EventTrackChanged body:@{@"artist": artistName, @"title": songTitle, @"duration": @(duration), @"isAd": @FALSE}];
        
        self.track = artistName;
        self.title = songTitle;
    }else{
        [self sendEventWithName:EventTrackChanged body:@{@"artist": @"-", @"title": @"-", @"isAd": @FALSE}];
    }
    [self configureNowPlayingInfo];
}

- (void)playerBeginInterruption:(TritonPlayer *) player {
    if (self.tritonPlayer != NULL && [self.tritonPlayer isExecuting]) {
        [self.tritonPlayer stop];
        [self sendEventWithName:EventStateChanged body:@{@"state": @(STATE_RELEASED)}];
//        self.tritonPlayer = NULL;
        self.interruptedOnPlayback = YES;
    }
}

- (void)playerEndInterruption:(TritonPlayer *) player {
    if (self.tritonPlayer != NULL && self.interruptedOnPlayback) {
        self.interruptedOnPlayback = NO;
    }
}

- (void)configureRemoteCommandHandling
{
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    
    [commandCenter.playCommand setEnabled:true];
    // register to receive remote play event
    [commandCenter.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self.tritonPlayer play];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    
    [commandCenter.pauseCommand setEnabled:true];
    // register to receive remote pause event
    [commandCenter.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self.tritonPlayer pause];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
}

- (void)configureNowPlayingInfo
{
    MPNowPlayingInfoCenter* info = [MPNowPlayingInfoCenter defaultCenter];
    NSMutableDictionary* newInfo = [NSMutableDictionary dictionary];
    
    // Set song title info
    [newInfo setObject:self.title forKey:MPMediaItemPropertyTitle];
    [newInfo setObject:self.track forKey:MPMediaItemPropertyArtist];
    
    if(self.albumArt){
        [newInfo setObject:self.albumArt forKey:MPMediaItemPropertyArtwork];
    }else{
        NSLog(@"Empty Album");
    }
    
    if (self.state == STATE_PAUSED) {
        [newInfo setValue:[NSNumber numberWithDouble:0] forKey:MPNowPlayingInfoPropertyPlaybackRate];
    } else if (self.state == STATE_PLAYING) {
        [newInfo setValue:[NSNumber numberWithDouble:1] forKey:MPNowPlayingInfoPropertyPlaybackRate];
    } else {
        [newInfo setValue:[NSNumber numberWithDouble:0] forKey:MPNowPlayingInfoPropertyPlaybackRate];
    }
    // Update the now playing info
    info.nowPlayingInfo = newInfo;
}

RCT_EXPORT_METHOD(updateNotificationDataWithLocalImage:(id)imageObject: (NSString *)title: (NSString *)subTitle )
{
//    NSLog(@"updateNotificationData: With local image");
    self.title = title;
    self.track = subTitle;
    [self configureNowPlayingInfo];
    UIImage *image = [RCTConvert UIImage:imageObject];
    if(image){
        UIGraphicsEndImageContext();
        MPMediaItemArtwork *imageArtwork = [[MPMediaItemArtwork alloc] initWithImage:image];
        if(imageArtwork){
//            NSLog(@"ImageArtwork Local success");
            self.albumArt = imageArtwork;
            [self configureNowPlayingInfo];
        }else{
//                NSLog(@"ImageArtwork error");
        }
    }else{
//            NSLog(@"Image not found");
    }
}

RCT_EXPORT_METHOD(updateNotificationData:(NSString *)albumArtUrl: (NSString *)title: (NSString *)subTitle )
{
//    NSLog(@"updateNotificationData: ");
    self.title = title;
    self.track = subTitle;
    [self configureNowPlayingInfo];
    
    if(albumArtUrl && ![albumArtUrl isEqualToString: @""]){
        
//        NSLog(@"albumArtUrl success");
        NSURL *url = [NSURL URLWithString:albumArtUrl];
        NSData *data = [NSData dataWithContentsOfURL:url];
    //    UIImage *img = [[[UIImage alloc] initWithData:data] autorelease];
        UIImage * image = [UIImage imageWithData:data];
        
//        NSLog(@"albumArtUrl success end");

        if(image){
            UIGraphicsEndImageContext();
            MPMediaItemArtwork *imageArtwork = [[MPMediaItemArtwork alloc] initWithImage:image];
            if(imageArtwork){
                NSLog(@"ImageArtwork success");
                self.albumArt = imageArtwork;
                [self configureNowPlayingInfo];
            }else{
//                NSLog(@"ImageArtwork error");
            }
        }else{
//            NSLog(@"Image not found");
        }
    }
}

@end
