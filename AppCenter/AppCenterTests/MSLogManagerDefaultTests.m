#import "MSAbstractLogInternal.h"
#import "MSChannelUnitConfiguration.h"
#import "MSChannelUnitDefault.h"
#import "MSHttpSenderPrivate.h"
#import "MSChannelGroupDefault.h"
#import "MSTestFrameworks.h"

@interface MSLogManagerDefaultTests : XCTestCase

@end

@implementation MSLogManagerDefaultTests

#pragma mark - Tests

- (void)testNewInstanceWasInitialisedCorrectly {

  // If
  id senderMock = OCMProtocolMock(@protocol(MSSender));
  id storageMock = OCMProtocolMock(@protocol(MSStorage));

  // When
  MSChannelGroupDefault *sut = [[MSChannelGroupDefault alloc] initWithSender:senderMock storage:storageMock];

  // Then
  assertThat(sut, notNilValue());
  assertThat(sut.logsDispatchQueue, notNilValue());
  assertThat(sut.channels, isEmpty());
  assertThat(sut.sender, equalTo(senderMock));
  assertThat(sut.storage, equalTo(storageMock));
}

- (void)testAddNewChannel {

  // If
  NSString *groupId = @"AppCenter";
  MSPriority priority = MSPriorityDefault;
  float flushInterval = 1.0;
  NSUInteger batchSizeLimit = 10;
  NSUInteger pendingBatchesLimit = 3;
  MSChannelGroupDefault *sut = [[MSChannelGroupDefault alloc] initWithSender:OCMProtocolMock(@protocol(MSSender))
                                                                 storage:OCMProtocolMock(@protocol(MSStorage))];

  // Then
  assertThat(sut.channels, isEmpty());

  // When
  id<MSChannelUnitProtocol> addedChannel = [sut addChannelUnitWithConfiguration:
                                            [[MSChannelUnitConfiguration alloc] initWithGroupId:groupId
                                                                                       priority:priority
                                                                                  flushInterval:flushInterval
                                                                                 batchSizeLimit:batchSizeLimit
                                                                            pendingBatchesLimit:pendingBatchesLimit]];

  // Then
  XCTAssertTrue([sut.channels containsObject:addedChannel]);
  assertThat(addedChannel, notNilValue());
  XCTAssertTrue(addedChannel.configuration.priority == priority);
  assertThatFloat(addedChannel.configuration.flushInterval, equalToFloat(flushInterval));
  assertThatUnsignedLong(addedChannel.configuration.batchSizeLimit, equalToUnsignedLong(batchSizeLimit));
  assertThatUnsignedLong(addedChannel.configuration.pendingBatchesLimit, equalToUnsignedLong(pendingBatchesLimit));
}

- (void)testProcessingLogWillTriggerOnProcessingCall {

  // If
  MSPriority priority = MSPriorityDefault;
  NSString *groupId = @"AppCenter";
  MSChannelGroupDefault *sut = [[MSChannelGroupDefault alloc] initWithSender:OCMProtocolMock(@protocol(MSSender))
                                                                 storage:OCMProtocolMock(@protocol(MSStorage))];
  id mockDelegate = OCMProtocolMock(@protocol(MSChannelDelegate));
  [sut addDelegate:mockDelegate];
  id<MSChannelUnitProtocol> addedChannel = [sut addChannelUnitWithConfiguration:
                                            [[MSChannelUnitConfiguration alloc] initWithGroupId:groupId
                                                                                       priority:priority
                                                                                  flushInterval:1.0
                                                                                 batchSizeLimit:10
                                                                            pendingBatchesLimit:3]];
  MSAbstractLog *log = [MSAbstractLog new];

  // When
  [addedChannel enqueueItem:log];

  // Then
  OCMVerify([mockDelegate onEnqueuingLog:log withInternalId:OCMOCK_ANY]);
}

- (void)testDelegatesConcurrentAccess {

  // If
  NSString *groupId = @"AppCenter";
  MSChannelGroupDefault *sut = [[MSChannelGroupDefault alloc] initWithSender:OCMProtocolMock(@protocol(MSSender))
                                                                 storage:OCMProtocolMock(@protocol(MSStorage))];
  MSAbstractLog *log = [MSAbstractLog new];
  for (int j = 0; j < 10; j++) {
    id mockDelegate = OCMProtocolMock(@protocol(MSChannelDelegate));
    [sut addDelegate:mockDelegate];
  }
  id<MSChannelUnitProtocol> addedChannel = [sut addChannelUnitWithConfiguration:
                                            [[MSChannelUnitConfiguration alloc] initWithGroupId:groupId
                                                                                       priority:MSPriorityDefault
                                                                                  flushInterval:1.0
                                                                                 batchSizeLimit:10
                                                                            pendingBatchesLimit:3]];

  // When
  void (^block)() = ^{
    for (int i = 0; i < 10; i++) {
      [addedChannel enqueueItem:log];
    }
    for (int i = 0; i < 100; i++) {
      [sut addDelegate:OCMProtocolMock(@protocol(MSChannelDelegate))];
    }
  };

  // Then
  XCTAssertNoThrow(block());
}

- (void)testResume {

  // If
  MSHttpSender *senderMock = OCMClassMock([MSHttpSender class]);
  id storageMock = OCMProtocolMock(@protocol(MSStorage));

  // When
  MSChannelGroupDefault *sut = [[MSChannelGroupDefault alloc] initWithSender:senderMock storage:storageMock];

  // When
  [sut resume];

  // Then
  OCMVerify([senderMock setEnabled:YES andDeleteDataOnDisabled:NO]);
}

- (void)testSuspend {

  // If
  MSHttpSender *senderMock = OCMClassMock([MSHttpSender class]);
  id storageMock = OCMProtocolMock(@protocol(MSStorage));

  // When
  MSChannelGroupDefault *sut = [[MSChannelGroupDefault alloc] initWithSender:senderMock storage:storageMock];

  // When
  [sut suspend];

  // Then
  OCMVerify([senderMock setEnabled:NO andDeleteDataOnDisabled:NO]);
}
@end
