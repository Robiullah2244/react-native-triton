
#import "RNTritonPlayer.h"

NSString* const EventTrackChanged = @"trackChanged";
NSString* const EventStreamChanged = @"streamChanged";
NSString* const EventStateChanged = @"stateChanged";

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
    return @[EventTrackChanged, EventStreamChanged, EventStateChanged];
}

RCT_EXPORT_METHOD(play:(NSString *)tritonName tritonStation:(NSString *)tritonStation)
{
    // Init Triton Player if its not set yet
    if (self.tritonPlayer == NULL) {
        self.tritonPlayer = [[TritonPlayer alloc] initWithDelegate:self andSettings:nil];
    }
    
    // Set Station Details
    NSDictionary *settings = @{
                               SettingsStationNameKey : tritonName,
                               SettingsBroadcasterKey : @"Triton Digital",
                               SettingsMountKey : tritonStation
                               };
    
    // Stop Current Stream (if playing)
    if (self.tritonPlayer.state == kTDPlayerStatePlaying) {
        [self.tritonPlayer stop];
    }
    
    // Update Triton Player settings
    [self.tritonPlayer updateSettings:settings];
    
    // Start Playing!
    [self.tritonPlayer play];
    
    // Notify stream change
    [self sendEventWithName:EventStreamChanged body:@{@"stream": tritonStation}];
}

- (void)player:(TritonPlayer *)player didChangeState:(TDPlayerState)state {
    NSInteger eventState;
    
    // Map to Android value..
    switch(state) {
        case kTDPlayerStateStopped:
            eventState = STATE_STOPPED;
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
    
    // Notify state change
    [self sendEventWithName:EventStateChanged body:@{@"state": @(eventState)}];
}

- (void)player:(TritonPlayer *)player didReceiveCuePointEvent:(CuePointEvent *)cuePointEvent {
    if ([cuePointEvent.type isEqualToString:EventTypeAd]) {
        // Type CUE ad
        [self sendEventWithName:EventTrackChanged body:@{@"artist": @"-", @"title": @"-", @"isAd": @TRUE}];
    } else if ([cuePointEvent.type isEqualToString:EventTypeTrack]) {
        // Type CUE track
        
        NSString *songTitle = [cuePointEvent.data objectForKey:CommonCueTitleKey];
        NSString *artistName = [cuePointEvent.data objectForKey:TrackArtistNameKey];
        
        [self sendEventWithName:EventTrackChanged body:@{@"artist": artistName, @"title": songTitle, @"isAd": @FALSE}];
        
    }
}

@end
  
