#import "RNCardConnectReactLibrary.h"
#import <BoltMobileSDK/BoltMobileSDK.h>
#import <BoltMobileSDK/BMSCardInfo.h>
#import <BoltMobileSDK/BMSAccount.h>
#import <BoltMobileSDK/BMSSwiperController.h>
#import <React/RCTLog.h>
#import <React/RCTConvert.h>

@implementation RNCardConnectReactLibrary

RCT_EXPORT_MODULE(BoltSDK)

- (RNCardConnectReactLibrary *)init {
    if (self = [super init]) {
        self.isConnecting = false;
        [BMSAPI instance].enableLogging = true;
        self.swiper = [[BMSSwiperController alloc] initWithDelegate:self swiper:BMSSwiperTypeVP3300 loggingEnabled:YES];
    }
    return self;
}

- (dispatch_queue_t)methodQueue {

    return dispatch_get_main_queue();
}

RCT_EXPORT_METHOD(setupConsumerApiEndpoint:(NSString *)endpoint) {

    [BMSAPI instance].endpoint = endpoint;
}

RCT_EXPORT_METHOD(getCardToken:(NSString *)cardNumber expirationDate:(NSString *)expirationDate CVV:(NSString *)CVV                   resolve: (RCTPromiseResolveBlock)resolve
rejecter:(RCTPromiseRejectBlock)reject) {

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

    [self.swiper findDevices];
}

RCT_EXPORT_METHOD(activateDevice) {

    [self sendEventWithName:@"BoltOnLogUpdate" body:@{@"test": @"activateDevice"}];

    if (self.restartReaderBlock) {
        self.restartReaderBlock();
        self.restartReaderBlock = nil;
    }
}

RCT_EXPORT_METHOD(setCardReadTimeout:(NSInteger *)timeoutValue) {

    self.swiper.cardReadTimeout = timeoutValue;
}

RCT_EXPORT_METHOD(cancelTransaction) {

    [self.swiper cancelTransaction];
}

RCT_EXPORT_METHOD(connectToDevice:(NSString *)uuid) {

    [self sendEventWithName:@"BoltOnLogUpdate" body:@{@"test": @"in display connectToDevice: start"}];

    // TODO: stop searching
    if (_swiper.connectionState == BMSSwiperConnectionStateSearching) {
        [self sendEventWithName:@"BoltOnLogUpdate" body:@{@"test": @"in display connectToDevice: before cancel"}];
        [_swiper cancelFindDevices];
        [self sendEventWithName:@"BoltOnLogUpdate" body:@{@"test": @"in display connectToDevice: after cancel"}];
    }

    NSUUID *converted = [[NSUUID alloc] initWithUUIDString:uuid];

    [self sendEventWithName:@"BoltOnLogUpdate" body:@{@"test": @"in display connectToDevice: before connect"}];
    [_swiper connectToDevice:converted mode:BMSCardReadModeSwipeDipTap];

    self.isConnecting = true;
}

- (void)swiper:(BMSSwiperController *)swiper configurationProgress:(float)progress {

    [self sendEventWithName:@"BoltOnDeviceConfigurationProgressUpdate" body:@{@"progress": [NSNumber numberWithFloat:progress]}];
}

- (void)swiper:(BMSSwiperController *)swiper displayMessage:(NSString *)message canCancel:(BOOL)cancelable {

    // special message we will convert into various events
    if ([message isEqualToString:@"PLEASE SWIPE,\nTAP, OR INSERT"]) {

        // device will automatically activate when connecting, so we silently cancel the transaction
        if (self.isConnecting) {
            [self sendEventWithName:@"BoltOnLogUpdate" body:@{@"test": @"in display message, caught during is connecting, should cancel soon"}];

            __weak RNCardConnectReactLibrary *weakSelf = self;

            // This is required to give the terminal enough time to finish starting before canceling -- found in their example project
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // cancel the transaction to complete the connecting process
                [weakSelf.swiper cancelTransaction];
                [weakSelf sendEventWithName:@"BoltOnLogUpdate" body:@{@"test": @"inside dispatch_after, after cancelTransaction!!!"}];
            });
        }
        else {
            [self sendEventWithName:@"BoltOnLogUpdate" body:@{@"test": @"in display message, swiper ready"}];
            [self sendEventWithName:@"BoltOnSwiperReady" body:@{}];
        }
    }
    else {
        // broadcast the device message to react native
        [self sendEventWithName:@"BoltOnDeviceMessage" body:@{@"message": message}];
    }
}

- (void)swiper:(BMSSwiper *)swiper connectionStateHasChanged:(BMSSwiperConnectionState)state {

    switch (state) {
        case BMSSwiperConnectionStateConnected:

            [self sendEventWithName:@"BoltOnLogUpdate" body:@{@"test": @"connection state changed: connected"}];

            // swallow this message while connecting because we need to wait for the first transaction to cancel
            if (!self.isConnecting) {
                [self sendEventWithName:@"BoltOnSwiperConnected" body:@{}];
            }
            break;
        case BMSSwiperConnectionStateDisconnected:

            [self sendEventWithName:@"BoltOnLogUpdate" body:@{@"test": @"connection state changed: disconnected"}];

            // we will repeatedly receive a disconnected state change while the device is connecting
            // silently swallow these
            if (!self.isConnecting) {
                [self sendEventWithName:@"BoltOnSwiperDisconnected" body:@{}];
            }
            break;
        case BMSSwiperConnectionStateConfiguring:

            [self sendEventWithName:@"BoltOnLogUpdate" body:@{@"test": @"connection state changed: configuring"}];

            // TODO: is this right, does it fire??
            [self sendEventWithName:@"BoltOnDeviceBusy" body:@{}];
            break;
        case BMSSwiperConnectionStateConnecting:

            [self sendEventWithName:@"BoltOnLogUpdate" body:@{@"test": @"connection state changed: connecting"}];

            [self sendEventWithName:@"BoltOnSwiperConnecting" body:@{}];
            break;
        case BMSSwiperConnectionStateSearching:
            [self sendEventWithName:@"BoltOnLogUpdate" body:@{@"test": @"connection state changed: searching"}];
            // ignore for now?
            break;
        default:
            break;
    }
}

- (void)swiperDidStartCardRead:(BMSSwiper *)swiper {

    [self sendEventWithName:@"BoltOnTokenGenerationStart" body:@{}];
    [self sendEventWithName:@"BoltOnLogUpdate" body:@{@"test": @"swiperDidStartCardRead -- is this generating the right event? -- BoltOnTokenGenerationStart"}];
}

- (void)swiper:(BMSSwiper *)swiper didGenerateTokenWithAccount:(BMSAccount *)account completion:(void (^)(void))completion {

    [self sendEventWithName:@"BoltOnTokenGenerated" body:@{@"token": account.token}];

    // store the completion block, so we can reactivate the device when needed
    self.restartReaderBlock = completion;
}

- (void)swiper:(BMSSwiper *)swiper didFailWithError:(NSError *)error completion:(void (^)(void))completion {

    // store the completion block, so we can reactivate the device when needed
    self.restartReaderBlock = completion;

    // this error will get issued repeatedly while connecting, ignore
    if (self.isConnecting && [error.localizedDescription isEqualToString:@"Failed to connect to device."]) {
        [self sendEventWithName:@"BoltOnLogUpdate" body:@{@"test": @"didFailWithError: ignoring"}];
        return;
    }

    // the device will automatically activate after connecting
    // we cancel this transaction to complete the connection process
    if (self.isConnecting && [error.localizedDescription isEqualToString:@"Canceled transaction."]) {
        [self sendEventWithName:@"BoltOnLogUpdate" body:@{@"test": @"didFailWithError: canceled transaction -- we're connected!"}];
        [self sendEventWithName:@"BoltOnSwiperConnected" body:@{}];
        self.isConnecting = false;
        return;
    }

    if ([error.localizedDescription isEqualToString:@"Timeout"]) {
        [self sendEventWithName:@"BoltOnLogUpdate" body:@{@"test": @"didFailWithError: Timeout"}];
        [self sendEventWithName:@"BoltOnTimeout" body:@{}];
        self.isConnecting = false;
        return;
    }

    [self sendEventWithName:@"BoltOnSwiperError" body:@{ @"errorLocalizedDescription": error.localizedDescription?error.localizedDescription:@"unknown error" }];
}

- (void)swiper:(BMSSwiperController*)swiper foundDevices:(NSArray*)devices {

    BMSDevice *device = [devices objectAtIndex:0];
    NSString *uuid = [device.uuid UUIDString];

    [self sendEventWithName:@"BoltDeviceFound" body:@{@"id": uuid, @"name": device.name}];
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
