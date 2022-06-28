#import "RNCardConnectReactLibrary.h"
#import <BoltMobileSDK/BoltMobileSDK.h>
#import <BoltMobileSDK/BMSCardInfo.h>
#import <BoltMobileSDK/BMSAccount.h>
#import <BoltMobileSDK/BMSSwiperController.h>
#import <React/RCTLog.h>
#import <React/RCTConvert.h>

@implementation RNCardConnectReactLibrary

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE(BoltSDK)

RCT_EXPORT_METHOD(setupConsumerApiEndpoint:(NSString *)endpoint) {
    [BMSAPI instance].endpoint = endpoint;
    [BMSAPI instance].enableLogging = true;
}

RCT_EXPORT_METHOD(getCardToken:(NSString *)cardNumber expirationDate:(NSString *)expirationDate CVV:(NSString *)CVV                   resolve: (RCTPromiseResolveBlock)resolve
rejecter:(RCTPromiseRejectBlock)reject)
{
    BMSCardInfo *card = [BMSCardInfo new];

    card.cardNumber = cardNumber;
    card.expirationDate = expirationDate;
    card.CVV = CVV;

    [[BMSAPI instance] generateAccountForCard:card completion:^(BMSAccount *account, NSError *error){
        if (account) {
            resolve(account.token);
        } else {
            reject(@"error", error.localizedDescription, error);
        }
    }];
}

RCT_EXPORT_METHOD(discoverDevice) {

    RCTLogInfo(@"discovering devices?!?!");

    self.swiper = [[BMSSwiperController alloc] initWithDelegate:self swiper:BMSSwiperTypeVP3300 loggingEnabled:YES];

    [self.swiper findDevices];
}

RCT_EXPORT_METHOD(connectToDevice:(NSString *)uuid) {

    RCTLogInfo(@"connecting to device?!?!");

    // TODO: stop searching

    NSUUID *converted = [[NSUUID alloc] initWithUUIDString:uuid];

    [_swiper connectToDevice:converted mode:BMSCardReadModeSwipeDipTap];

    _isConnecting = true;
}

- (void)swiper:(BMSSwiperController *)swiper configurationProgress:(float)progress {

    [self sendEventWithName:@"BoltOnDeviceConfigurationProgressUpdate" body:@{@"progress": [NSNumber numberWithFloat:progress]}];
}

- (void)swiper:(BMSSwiperController *)swiper displayMessage:(NSString *)message canCancel:(BOOL)cancelable {

    // TODO: If _isConnecting, and  message == 'PLEASE SWIPE,  TAP, OR INSERT', cancel the transaction
    // TODO: Once cancelled, send device connected event
    if (_isConnecting && message == @"PLEASE SWIPE, TAP, OR INSERT") {
        __weak RNCardConnectReactLibrary *weakSelf = self;
        // This is required to give the terminal enough time to finish starting before canceling
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf.swiper cancelTransaction];
            [weakSelf sendEventWithName:@"BoltOnSwiperConnected" body:@{}];
            weakSelf.isConnecting = false;
        });
    }
    else {
        // TODO: otherwise send the darn message
        [self sendEventWithName:@"BoltOnDeviceMessage" body:@{@"message": message}];
    }
}

- (void)swiper:(BMSSwiper *)swiper connectionStateHasChanged:(BMSSwiperConnectionState)state {

    RCTLogInfo(@"swiper connectionStateHasChanged");

    switch (state) {
        case BMSSwiperConnectionStateConnected:
            NSLog(@"Did Connect Swiper");
            // _swiper.connectionState;
            if (_isConnecting) {
                // TODO: maybe do something?
            }
            [self sendEventWithName:@"BoltOnSwiperConnected" body:@{}];
            break;
        case BMSSwiperConnectionStateDisconnected:

            NSLog(@"Did Disconnect Swiper");

            if (!_isConnecting) {
                [self sendEventWithName:@"BoltOnSwiperDisconnected" body:@{}];
            }
            break;
        case BMSSwiperConnectionStateConfiguring:
            NSLog(@"Configuring Device");
            [self sendEventWithName:@"BoltOnDeviceBusy" body:@{}];
            break;
        case BMSSwiperConnectionStateConnecting:
            NSLog(@"Will Connect Swiper");
            [self sendEventWithName:@"BoltOnSwiperConnecting" body:@{}];
                break;
        case BMSSwiperConnectionStateSearching:
            NSLog(@"searching for Swiper");
            // ignore for now
            break;
        default:
            break;
    }
}

- (void)swiperDidStartCardRead:(BMSSwiper *)swiper
{
    RCTLogInfo(@"swiper swiperDidStartCardRead");

    [self sendEventWithName:@"BoltOnTokenGenerationStart" body:@{}];
}

- (void)swiper:(BMSSwiper *)swiper didGenerateTokenWithAccount:(BMSAccount *)account completion:(void (^)(void))completion
{
    RCTLogInfo(@"swiper didGenerateTokenWithAccount");

    [self sendEventWithName:@"BoltOnTokenGenerated" body:@{@"token": account.token}];

    // todo: call completion();?????
    completion();
}

- (void)swiper:(BMSSwiper *)swiper didFailWithError:(NSError *)error completion:(void (^)(void))completion
{
    RCTLogInfo(@"swiper didFailWithError");
    RCTLogInfo(error.localizedDescription);

    // ignore these errors while connecting
    if (self.isConnecting && error.localizedDescription == @"Failed to connect to device.") {
        return;
    }

    [self sendEventWithName:@"BoltOnSwiperError" body:@{
        @"errorLocalizedDescription": error.localizedDescription?error.localizedDescription:@"no localized description",
        @"errorLocalizedRecoverySuggestion": error.localizedRecoverySuggestion?error.localizedRecoverySuggestion:@"no localized recovery suggestion",
        @"errorLocalizedFailureReason": error.localizedFailureReason?error.localizedFailureReason:@"no localized failure reason"
    }];

    //  hmmmmm?
    //     [errorMessage appendFormat:@"\n\n%@", [error.userInfo valueForKey:@"firmwareVersion"]];

    completion();
}

- (void)swiper:(BMSSwiperController*)swiper foundDevices:(NSArray*)devices
{
    RCTLogInfo(@"swiper foundDevices");

    BMSDevice *device = [devices objectAtIndex:0];
    NSString *uuid = [device.uuid UUIDString];
    // int value = returnedObject.aVariable;
    [self sendEventWithName:@"BoltDeviceFound" body:@{@"macAddress": uuid, @"name": device.name}];
}

- (NSArray<NSString *> *)supportedEvents {
    return @[
        @"BoltDeviceFound",
        @"BoltOnTokenGenerated",
        @"BoltOnTokenGeneratedError",
        @"BoltOnSwiperConnected",
        @"BoltOnSwiperDisconnected",
        @"BoltOnSwiperConnecting",
        @"BoltOnSwiperReady",
        @"BoltOnSwiperError",
        @"BoltOnTokenGenerationStart",
        @"BoltOnRemoveCardRequested",
        @"BoltOnBatteryState",
        @"BoltOnLogUpdate",
        @"BoltOnDeviceConfigurationUpdate",
        @"BoltOnDeviceConfigurationProgressUpdate",
        @"BoltOnDeviceConfigurationUpdateComplete",
        @"BoltOnTimeout",
        @"BoltOnCardRemoved",
        @"BoltOnDeviceBusy",
        @"BoltOnDeviceMessage"
    ];
}

@end
